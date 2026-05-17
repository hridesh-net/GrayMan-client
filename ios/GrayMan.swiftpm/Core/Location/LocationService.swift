import CoreLocation
import Foundation

// MARK: - Location Service
//
// Provides a best-effort current location for radius filtering + "X km away"
// labels. We deliberately ask for *approximate* accuracy:
//
//   - `kCLLocationAccuracyThreeKilometers` is enough for a city-scale radius
//     filter and saves battery vs precise GPS.
//   - Even if the user picked "Precise location: On" in Settings, iOS still
//     returns ~3km accuracy with this preset; we never see street-level GPS.
//
// Three layers of fallback so callers never hang and never throw:
//
//   1. In-memory cache (10-min TTL).
//   2. Last-known persisted in UserDefaults.
//   3. Mumbai city centre (APIConfig.defaultLat/defaultLng).
//
// First call after launch:
//   - If permission is .notDetermined → triggers the system prompt + queues
//     the request.
//   - If denied → returns the persisted last-known, else Mumbai.
//   - If authorised → one-shot CLLocationManager.requestLocation() with a
//     5-second timeout (else fallback).

/// Reverse-geocoded place. `shortLabel` is what the profile screen renders;
/// `lat`/`lng` are also exposed for the rare caller that wants both.
struct Place: Sendable, Hashable {
    let lat: Double
    let lng: Double
    let locality: String?   // sub-locality / neighbourhood (e.g. "Andheri West")
    let city: String?       // locality (e.g. "Mumbai")
    let admin: String?      // administrative area (e.g. "Maharashtra")

    /// Best label for a one-line "📍 …" UI string. Falls back through
    /// neighbourhood → city → state.
    var shortLabel: String? {
        if let locality, let city, locality.lowercased() != city.lowercased() {
            return "\(locality), \(city)"
        }
        if let l = locality, !l.isEmpty { return l }
        if let c = city,     !c.isEmpty { return c }
        if let a = admin,    !a.isEmpty { return a }
        return nil
    }
}


@MainActor
final class LocationService: NSObject {

    static let shared = LocationService()

    /// 10 minutes — we don't need to re-query for every API call.
    private let cacheTTL: TimeInterval = 600
    /// How long we wait for a single fix before giving up + using a fallback.
    /// 15s gives a cold-start GPS lock on most devices (vs. our previous 5s
    /// which routinely fell back to the Mumbai dummy coords).
    private let fixTimeout: TimeInterval = 15
    /// If the user hasn't moved more than this distance, the cached
    /// reverse-geocoded place is reused without a fresh CLGeocoder hit.
    /// 250 m matches our new ~best-accuracy fixes so the label updates
    /// the moment the user actually moves to a new street.
    private let placeReuseRadiusMeters: Double = 250

    private let manager: CLLocationManager
    private var cached: (lat: Double, lng: Double, at: Date)?
    private var cachedPlace: Place?
    private var pending: [CheckedContinuation<(lat: Double, lng: Double), Never>] = []
    private var timeoutTask: Task<Void, Never>?

    // ".v2" suffix invalidates the cache from our prior 3 km-accuracy era
    // so the first launch after this upgrade ignores the stale (often
    // "Kurla West, Mumbai") entry and re-resolves from a fresh fix.
    private let storeKey = "grayman.location.last.v2"
    private let placeStoreKey = "grayman.location.place.v2"

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        // Best accuracy: we want the real device coordinates so the
        // profile header shows the user's actual neighbourhood. The
        // previous 100m / 3km settings let Apple's geocoder snap the
        // fix to whichever generic neighborhood it defaulted to (often
        // "Kurla West" in Mumbai), which read as plain-wrong.
        manager.desiredAccuracy = kCLLocationAccuracyBest
        // Hydrate from disk so first-launch isn't always Mumbai.
        if let dict = UserDefaults.standard.dictionary(forKey: storeKey),
           let lat = dict["lat"] as? Double, let lng = dict["lng"] as? Double {
            // Mark as stale so we still re-request a fresh fix this session.
            cached = (lat, lng, .distantPast)
        }
        if let dict = UserDefaults.standard.dictionary(forKey: placeStoreKey),
           let lat = dict["lat"] as? Double, let lng = dict["lng"] as? Double {
            cachedPlace = Place(
                lat: lat, lng: lng,
                locality: (dict["locality"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                city:     (dict["city"]     as? String).flatMap { $0.isEmpty ? nil : $0 },
                admin:    (dict["admin"]    as? String).flatMap { $0.isEmpty ? nil : $0 }
            )
        }
    }

    /// Last-known fix, returned synchronously without ever waiting for
    /// GPS. May come from the persisted UserDefaults cache (so it's
    /// available even on the very first call after a relaunch) or from
    /// the in-memory cache filled by `didUpdateLocations`. Returns nil
    /// only when the device has never produced a fix for this app.
    ///
    /// Use this when the caller just needs *some* coordinates for a
    /// non-blocking secondary computation (e.g. distance-from-me on a
    /// fetched worker) and absolutely cannot afford to stall on a cold
    /// GPS lock — i.e. anywhere a 15-second wait would degrade UX.
    var lastKnown: (lat: Double, lng: Double)? {
        cached.map { (lat: $0.lat, lng: $0.lng) }
    }

    /// Best-effort current location. Never throws. Never hangs longer than
    /// ``fixTimeout``.
    func current() async -> (lat: Double, lng: Double) {
        if let c = cached, Date().timeIntervalSince(c.at) < cacheTTL {
            return (c.lat, c.lng)
        }

        let status = manager.authorizationStatus
        switch status {
        case .restricted, .denied:
            return fallback()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // Fall through — iOS will queue requestLocation until the user
            // decides; if they deny, our delegate's didFail handler fires.
        default:
            break
        }

        return await withCheckedContinuation { cont in
            pending.append(cont)
            // Cap the wait so a slow GPS lock can't stall API calls.
            if timeoutTask == nil {
                timeoutTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(self?.fixTimeout ?? 5))
                    guard let self else { return }
                    self.resumeAll(with: self.fallback())
                }
            }
            manager.requestLocation()
        }
    }

    /// Best-effort reverse-geocoded current place. Same fallback ladder as
    /// :func:`current` — never throws. Reuses the in-memory cache when the
    /// device hasn't meaningfully moved so we don't hammer Apple's geocoder
    /// (which is rate-limited per-app).
    func currentPlace() async -> Place {
        let (lat, lng) = await current()
        if let cp = cachedPlace,
           _distanceMeters(lat1: cp.lat, lng1: cp.lng, lat2: lat, lng2: lng) < placeReuseRadiusMeters {
            return cp
        }
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(
            CLLocation(latitude: lat, longitude: lng)
        ).first
        let place = Place(
            lat: lat, lng: lng,
            locality: (placemark?.subLocality ?? "").isEmpty ? nil : placemark?.subLocality,
            city:     (placemark?.locality    ?? "").isEmpty ? nil : placemark?.locality,
            admin:    (placemark?.administrativeArea ?? "").isEmpty ? nil : placemark?.administrativeArea
        )
        cachedPlace = place
        UserDefaults.standard.set([
            "lat": lat, "lng": lng,
            "locality": place.locality ?? "",
            "city":     place.city     ?? "",
            "admin":    place.admin    ?? "",
        ], forKey: placeStoreKey)
        return place
    }

    /// Like ``currentPlace`` but returns nil when we don't have a real
    /// device fix (permission denied, GPS truly unavailable, or the fix
    /// timed out). Use this for user-visible labels — better to show
    /// nothing than to show the Mumbai dummy.
    func currentPlaceStrict() async -> Place? {
        guard let (lat, lng) = await currentStrict() else { return nil }
        if let cp = cachedPlace,
           _distanceMeters(lat1: cp.lat, lng1: cp.lng, lat2: lat, lng2: lng) < placeReuseRadiusMeters {
            return cp
        }
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(
            CLLocation(latitude: lat, longitude: lng)
        ).first
        let place = Place(
            lat: lat, lng: lng,
            locality: (placemark?.subLocality ?? "").isEmpty ? nil : placemark?.subLocality,
            city:     (placemark?.locality    ?? "").isEmpty ? nil : placemark?.locality,
            admin:    (placemark?.administrativeArea ?? "").isEmpty ? nil : placemark?.administrativeArea
        )
        cachedPlace = place
        UserDefaults.standard.set([
            "lat": lat, "lng": lng,
            "locality": place.locality ?? "",
            "city":     place.city     ?? "",
            "admin":    place.admin    ?? "",
        ], forKey: placeStoreKey)
        return place
    }

    /// Like ``current`` but returns nil instead of the Mumbai dummy when
    /// the GPS truly hasn't given us a real fix. Used by UI surfaces
    /// (profile city pill) that should prefer to render nothing over a
    /// fake city. Re-uses the in-memory cache from `current()` if it
    /// holds a real fix (filled by didUpdateLocations); otherwise waits
    /// up to ``fixTimeout`` for one and returns nil on failure.
    func currentStrict() async -> (lat: Double, lng: Double)? {
        // Real fix already in memory? Use it.
        if let c = cached, c.at != .distantPast,
           Date().timeIntervalSince(c.at) < cacheTTL {
            return (c.lat, c.lng)
        }
        let status = manager.authorizationStatus
        switch status {
        case .restricted, .denied:
            return nil
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
        // Hold a one-shot listener that returns nil on timeout instead
        // of falling back to Mumbai.
        return await withCheckedContinuation { (cont: CheckedContinuation<(lat: Double, lng: Double)?, Never>) in
            var resumed = false
            let lock = NSLock()
            let resume: (CLLocation?) -> Void = { loc in
                lock.lock(); defer { lock.unlock() }
                if resumed { return }
                resumed = true
                if let loc {
                    cont.resume(returning: (loc.coordinate.latitude, loc.coordinate.longitude))
                } else {
                    cont.resume(returning: nil)
                }
            }
            // Hook the standard delegate-driven update via cached, which
            // is populated on didUpdateLocations. Poll briefly with a
            // sleep ladder + cap at fixTimeout — this avoids needing a
            // second delegate plumbing layer.
            Task { [weak self] in
                guard let self else { resume(nil); return }
                let deadline = Date().addingTimeInterval(self.fixTimeout)
                while Date() < deadline {
                    if let c = self.cached, c.at != .distantPast {
                        resume(CLLocation(latitude: c.lat, longitude: c.lng))
                        return
                    }
                    try? await Task.sleep(for: .milliseconds(200))
                }
                resume(nil)
            }
            manager.requestLocation()
        }
    }

    // MARK: - Internals

    private func fallback() -> (lat: Double, lng: Double) {
        if let c = cached { return (lat: c.lat, lng: c.lng) }
        return (lat: APIConfig.defaultLat, lng: APIConfig.defaultLng)
    }

    private func resumeAll(with location: (lat: Double, lng: Double)) {
        timeoutTask?.cancel()
        timeoutTask = nil
        let waiters = pending
        pending.removeAll()
        for cont in waiters { cont.resume(returning: location) }
    }

    fileprivate func ingest(coordinate: CLLocationCoordinate2D) {
        let lat = coordinate.latitude
        let lng = coordinate.longitude
        cached = (lat, lng, Date())
        UserDefaults.standard.set(["lat": lat, "lng": lng], forKey: storeKey)
        resumeAll(with: (lat: lat, lng: lng))
    }

    fileprivate func handleFailure() {
        resumeAll(with: fallback())
    }

    /// Haversine distance in metres. Used only to decide whether the cached
    /// reverse-geocoded label is still good — exact precision isn't needed.
    fileprivate func _distanceMeters(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let R = 6_371_000.0
        let p1 = lat1 * .pi / 180
        let p2 = lat2 * .pi / 180
        let dp = (lat2 - lat1) * .pi / 180
        let dl = (lng2 - lng1) * .pi / 180
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

// MARK: - CLLocationManagerDelegate
//
// Apple's delegate is documented to fire on the main thread when the manager
// was created on the main thread, so the @MainActor hops are cheap.

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        guard let loc = locations.last else { return }
        let coord = loc.coordinate
        Task { @MainActor [weak self] in
            self?.ingest(coordinate: coord)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager, didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.handleFailure()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // If the user just granted permission, kick off a fresh request so
        // any queued continuation resolves quickly.
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        Task { @MainActor [weak self] in
            self?.manager.requestLocation()
        }
    }
}
