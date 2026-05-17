import Foundation

// MARK: - WorkerService — thin wrapper around APIClient for worker/explore/vouch endpoints

@MainActor
final class WorkerService {
    static let shared = WorkerService()

    private let client: APIClient

    /// Set once per app session after we successfully push the device's
    /// approximate location to /workers/me. Prevents redundant PUTs on
    /// every profile open while still letting a fresh launch re-sync.
    private var hasSyncedLocationThisSession = false

    init(client: APIClient = .shared) { self.client = client }

    // MARK: Location sync

    /// Best-effort push of the device's current approximate location to
    /// the backend so the explore feed can rank the user against their
    /// real city. Silent on failure — the UI never blocks on this.
    ///
    /// Only runs once per app session, and only when a real (strict) GPS
    /// fix is available — we never push the Mumbai fallback.
    func syncSelfLocationIfNeeded() async {
        guard !hasSyncedLocationThisSession else { return }
        guard TokenStore.shared.token != nil else { return }
        guard let place = await LocationService.shared.currentPlaceStrict() else { return }
        let cityLabel = place.city ?? place.shortLabel
        do {
            _ = try await updateSelf(WorkerUpdateRequest(
                city: cityLabel, lat: place.lat, lng: place.lng,
            ))
            hasSyncedLocationThisSession = true
        } catch {
            // Silent: a one-off failure shouldn't surface a banner. We'll
            // retry on the next launch.
        }
    }

    // MARK: Explore feed

    func fetchExplore(
        trade: String? = nil,
        radiusKm: Double,
        page: Int = 1,
        limit: Int = 30,
    ) async throws -> [Worker] {
        let (lat, lng) = await LocationService.shared.current()
        var query: [URLQueryItem] = [
            URLQueryItem(name: "lat",       value: String(lat)),
            URLQueryItem(name: "lng",       value: String(lng)),
            URLQueryItem(name: "radius_km", value: String(radiusKm)),
            URLQueryItem(name: "page",      value: String(page)),
            URLQueryItem(name: "limit",     value: String(limit)),
            // Reel feed surface — never show workers who haven't
            // uploaded a reel, so the discovery scroll is always video.
            URLQueryItem(name: "has_reel",  value: "true"),
        ]
        if let trade, trade != "All" {
            query.append(URLQueryItem(name: "trade", value: trade))
        }
        let dtos: [WorkerDTO] = try await client.request(.GET, "/explore", query: query, authenticated: false)
        return dtos.map { Worker(dto: $0, userLat: lat, userLng: lng) }
    }

    // MARK: Profiles

    func fetchSelf() async throws -> Worker {
        // No GPS wait — distance-from-self is meaningless (always 0), so
        // there is nothing to compute from the user's coordinates here.
        // Avoids stalling the profile open on a cold-start 15s GPS lock.
        let dto: WorkerDTO = try await client.request(.GET, "/workers/me")
        return Worker(dto: dto, userLat: 0, userLng: 0)
    }

    func fetchWorker(id: String) async throws -> Worker {
        // Use whatever fix we have synchronously (in-memory or persisted
        // from a prior session). Never block this call on a fresh GPS
        // lock — a missing "3.2 km" distance is preferable to a 15s
        // stall on the worker profile.
        let fix = LocationService.shared.lastKnown ?? (lat: 0, lng: 0)
        let dto: WorkerDTO = try await client.request(.GET, "/workers/\(id)", authenticated: false)
        return Worker(dto: dto, userLat: fix.lat, userLng: fix.lng)
    }

    func updateSelf(_ update: WorkerUpdateRequest) async throws -> Worker {
        // Same reasoning as `fetchSelf` — no GPS wait. The PUT itself
        // already carries the lat/lng when this is invoked from
        // `syncSelfLocationIfNeeded`, so we don't need a fix here.
        let dto: WorkerDTO = try await client.request(.PUT, "/workers/me", body: update)
        return Worker(dto: dto, userLat: 0, userLng: 0)
    }

    // MARK: Vouches

    @discardableResult
    func giveVouch(toWorkerID: String, skillIndices: [Int], voiceNoteURL: String? = nil) async throws -> VouchDTO {
        let body = VouchCreateRequest(
            toWorkerID: toWorkerID,
            skillIndices: skillIndices,
            voiceNoteURL: voiceNoteURL
        )
        return try await client.request(.POST, "/vouches", body: body)
    }

    func fetchReceivedVouches(for workerID: String) async throws -> [VouchDTO] {
        try await client.request(.GET, "/vouches/received/\(workerID)", authenticated: false)
    }

    func fetchGivenVouches() async throws -> [VouchDTO] {
        try await client.request(.GET, "/vouches/given")
    }

    // MARK: Likes / Saves

    func like(workerID: String) async throws {
        try await client.requestVoid(.POST, "/likes/\(workerID)")
    }

    func unlike(workerID: String) async throws {
        try await client.requestVoid(.DELETE, "/likes/\(workerID)")
    }

    func save(workerID: String) async throws {
        try await client.requestVoid(.POST, "/saves/\(workerID)")
    }

    func unsave(workerID: String) async throws {
        try await client.requestVoid(.DELETE, "/saves/\(workerID)")
    }

    func fetchInteractionCounts(workerID: String) async throws -> InteractionCountsDTO {
        try await client.request(.GET, "/\(workerID)/counts", authenticated: false)
    }

    func fetchMyActionState(workerID: String) async throws -> WorkerActionStateDTO {
        try await client.request(.GET, "/\(workerID)/state")
    }

    // MARK: Messages

    @discardableResult
    func sendMessage(toWorkerID: String, body: String) async throws -> MessageDTO {
        try await client.request(
            .POST, "/messages",
            body: MessageCreateRequest(toWorkerID: toWorkerID, body: body)
        )
    }

    func fetchThread(with workerID: String) async throws -> [MessageDTO] {
        try await client.request(.GET, "/messages/\(workerID)")
    }

    // MARK: Reels

    func requestReelUploadURL() async throws -> ReelUploadURLDTO {
        try await client.request(.POST, "/reels/upload-url")
    }

    func finalizeReel(key: String) async throws -> AnalysisStatusDTO {
        try await client.request(.POST, "/reels/finalize", body: ReelFinalizeRequest(key: key))
    }

    func fetchAnalysisStatus() async throws -> AnalysisStatusDTO {
        try await client.request(.GET, "/reels/analysis")
    }

    // MARK: Multipart upload (production reel path)

    func initMultipartUpload(partCount: Int, contentType: String = "video/mp4")
        async throws -> MultipartInitResponseDTO
    {
        try await client.request(
            .POST, "/reels/upload/init",
            body: MultipartInitRequest(partCount: partCount, contentType: contentType)
        )
    }

    func completeMultipartUpload(
        key: String, uploadID: String,
        parts: [CompletedPartDTO], transcript: String? = nil
    ) async throws -> AnalysisStatusDTO {
        let trimmed = transcript?.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await client.request(
            .POST, "/reels/upload/complete",
            body: MultipartCompleteRequest(
                key: key, uploadID: uploadID, parts: parts,
                transcript: (trimmed?.isEmpty == false) ? trimmed : nil
            )
        )
    }

    func abortMultipartUpload(key: String, uploadID: String) async throws {
        try await client.requestVoid(
            .POST, "/reels/upload/abort",
            body: MultipartAbortRequest(key: key, uploadID: uploadID)
        )
    }

    // MARK: Work history

    func fetchWorkHistory(workerID: String) async throws -> [WorkHistoryDTO] {
        try await client.request(.GET, "/workers/\(workerID)/history", authenticated: false)
    }

    @discardableResult
    func createWorkHistory(_ body: WorkHistoryCreateRequest) async throws -> WorkHistoryDTO {
        try await client.request(.POST, "/workers/me/history", body: body)
    }

    @discardableResult
    func updateWorkHistory(id: String, body: WorkHistoryUpdateRequest) async throws -> WorkHistoryDTO {
        try await client.request(.PUT, "/workers/me/history/\(id)", body: body)
    }

    func deleteWorkHistory(id: String) async throws {
        try await client.requestVoid(.DELETE, "/workers/me/history/\(id)")
    }

    // MARK: Showcase

    func fetchShowcase(workerID: String, kind: String? = nil) async throws -> [ShowcaseItemDTO] {
        var query: [URLQueryItem] = []
        if let kind { query.append(URLQueryItem(name: "kind", value: kind)) }
        return try await client.request(
            .GET, "/workers/\(workerID)/showcase",
            query: query, authenticated: false,
        )
    }

    @discardableResult
    func createShowcaseItem(_ body: ShowcaseCreateRequest) async throws -> ShowcaseItemDTO {
        try await client.request(.POST, "/workers/me/showcase", body: body)
    }

    @discardableResult
    func updateShowcaseItem(id: String, body: ShowcaseUpdateRequest) async throws -> ShowcaseItemDTO {
        try await client.request(.PUT, "/workers/me/showcase/\(id)", body: body)
    }

    func deleteShowcaseItem(id: String) async throws {
        try await client.requestVoid(.DELETE, "/workers/me/showcase/\(id)")
    }

    func requestShowcaseUploadURL(kind: String, contentType: String) async throws -> ShowcaseUploadURLResponse {
        try await client.request(
            .POST, "/showcase/upload-url",
            body: ShowcaseUploadURLRequest(kind: kind, contentType: contentType),
        )
    }

    func initShowcaseMultipart(
        kind: String, contentType: String, partCount: Int,
    ) async throws -> ShowcaseMultipartInitResponseDTO {
        try await client.request(
            .POST, "/showcase/upload/init",
            body: ShowcaseMultipartInitRequest(
                kind: kind, contentType: contentType, partCount: partCount,
            ),
        )
    }

    func completeShowcaseMultipart(
        key: String, uploadID: String, parts: [CompletedPartDTO],
    ) async throws {
        try await client.requestVoid(
            .POST, "/showcase/upload/complete",
            body: ShowcaseMultipartCompleteRequest(key: key, uploadID: uploadID, parts: parts),
        )
    }

    func abortShowcaseMultipart(key: String, uploadID: String) async throws {
        try await client.requestVoid(
            .POST, "/showcase/upload/abort",
            body: ShowcaseMultipartAbortRequest(key: key, uploadID: uploadID),
        )
    }

    // MARK: Voice guide

    /// Mint an ephemeral Gemini Live token scoped to TTS-only playback for
    /// the onboarding voice narrator. Token is short-lived (~30 min) and
    /// supports a small number of session-opens before needing refresh.
    func voiceGuideToken(lang: AppLanguage) async throws -> VoiceGuideTokenResponse {
        try await client.request(
            .POST, "/voice-guide/token",
            body: VoiceGuideTokenRequest(lang: lang.geminiLangCode)
        )
    }

    /// Translate an English voice-guide script into the target Indian
    /// language. Used for languages where the iOS modifier only ships an
    /// English fallback script (mr, te, ta, kn) — the native-audio Live
    /// model ignores system instructions asking it to translate, so we
    /// pre-translate on the server using a plain text model.
    func voiceGuideTranslate(text: String, lang: AppLanguage) async throws -> VoiceGuideTranslateResponse {
        try await client.request(
            .POST, "/voice-guide/translate",
            body: VoiceGuideTranslateRequest(text: text, lang: lang.geminiLangCode)
        )
    }

    // MARK: Hires

    @discardableResult
    func createHire(workerID: String, message: String? = nil) async throws -> HireDTO {
        try await client.request(
            .POST, "/hires",
            body: HireCreateRequest(workerID: workerID, message: message),
        )
    }

    /// `direction` ∈ {"outgoing", "incoming", "both"}. Default both.
    func fetchHires(direction: String = "both") async throws -> [HireDTO] {
        try await client.request(
            .GET, "/hires",
            query: [URLQueryItem(name: "direction", value: direction)],
        )
    }

    @discardableResult
    func transitionHire(id: String, to status: String) async throws -> HireDTO {
        // Backend exposes /hires/{id}/{status} for the 4 state transitions.
        try await client.request(.POST, "/hires/\(id)/\(status)")
    }

    /// Has the caller (the authenticated worker) completed a hire of `workerID`?
    /// Used to gate the in-app vouch button — backend enforces it server-side
    /// but the UI hides the action so users don't try-then-fail.
    func hasCompletedHire(of workerID: String) async -> Bool {
        guard let outgoing = try? await fetchHires(direction: "outgoing") else { return false }
        return outgoing.contains { $0.workerID == workerID && $0.status == "completed" }
    }

    // MARK: Posts (Home feed)

    func fetchFeed(
        lat: Double?, lng: Double?, radiusKm: Double = 25,
        page: Int = 1, limit: Int = 20,
    ) async throws -> [PostDTO] {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "radius_km", value: String(radiusKm)),
            URLQueryItem(name: "page",      value: String(page)),
            URLQueryItem(name: "limit",     value: String(limit)),
        ]
        if let lat { query.append(URLQueryItem(name: "lat", value: String(lat))) }
        if let lng { query.append(URLQueryItem(name: "lng", value: String(lng))) }
        return try await client.request(.GET, "/posts/feed", query: query, authenticated: false)
    }

    func fetchPosts(byAuthor authorID: String, page: Int = 1, limit: Int = 20) async throws -> [PostDTO] {
        try await client.request(
            .GET, "/posts/by-author/\(authorID)",
            query: [
                URLQueryItem(name: "page",  value: String(page)),
                URLQueryItem(name: "limit", value: String(limit)),
            ],
            authenticated: false,
        )
    }

    @discardableResult
    func createPost(body: String, imageURL: String? = nil,
                    lat: Double? = nil, lng: Double? = nil) async throws -> PostDTO {
        try await client.request(
            .POST, "/posts",
            body: PostCreateRequest(body: body, imageURL: imageURL, lat: lat, lng: lng),
        )
    }

    func deletePost(id: String) async throws {
        try await client.requestVoid(.DELETE, "/posts/\(id)")
    }

    func requestPostImageUploadURL(contentType: String = "image/jpeg") async throws -> PresignedUploadDTO {
        try await client.request(
            .POST, "/posts/image/upload-url",
            query: [URLQueryItem(name: "content_type", value: contentType)],
        )
    }

    // MARK: Avatar upload

    func requestAvatarUploadURL(contentType: String = "image/jpeg") async throws -> PresignedUploadDTO {
        try await client.request(
            .POST, "/workers/me/avatar/upload-url",
            query: [URLQueryItem(name: "content_type", value: contentType)],
        )
    }

    // MARK: Notifications

    func fetchNotifications(onlyUndecided: Bool = false, limit: Int = 50) async throws -> NotificationListResponseDTO {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if onlyUndecided {
            query.append(URLQueryItem(name: "only_undecided", value: "true"))
        }
        return try await client.request(.GET, "/notifications", query: query)
    }

    @discardableResult
    func markNotificationRead(id: String) async throws -> NotificationDTO {
        try await client.request(.POST, "/notifications/\(id)/read")
    }

    func acceptNotification(id: String) async throws -> NotificationAcceptResponseDTO {
        try await client.request(.POST, "/notifications/\(id)/accept")
    }

    @discardableResult
    func rejectNotification(id: String) async throws -> NotificationDecisionDTO {
        try await client.request(.POST, "/notifications/\(id)/reject")
    }

    /// Direct PUT to S3 using the presigned URL. Returns when the upload
    /// completes; throws on any non-2xx response.
    func uploadReelData(_ data: Data, to urlString: String, contentType: String) async throws {
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.upload(for: req, from: data)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.server(status: status, body: "S3 upload failed")
        }
    }
}
