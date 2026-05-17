import AVFoundation
import Foundation

// MARK: - Reel preloader
//
// Vertical reel feeds feel "snappy" only when the next video starts
// playing within a beat of the user swiping. The trick is to begin
// loading the next 1-2 assets BEFORE they're on screen — so by the time
// AVPlayer is handed the URL, its HTTP cache already has the HLS master
// playlist and the first segment.
//
// Two-fold strategy:
//   1. `AVURLAsset` with `automatic` precaching. We ask the asset to
//      asynchronously load `playable` + `tracks`, which forces the
//      AVAsset loader to begin fetching the master playlist + first
//      variant playlist. Those land in URLCache.shared.
//   2. The cached `AVURLAsset` instances are held briefly so the
//      framework doesn't tear down the in-flight load when the local
//      reference drops.
//
// Caller hands us the *upcoming* worker URLs after every paging event
// and we make a best-effort preload — failures are silent because
// preloading is opportunistic.

actor ReelPreloader {

    static let shared = ReelPreloader()

    /// Cap the active warming pool so we don't accidentally pin a dozen
    /// assets in memory when the user scrolls quickly.
    private let maxCached: Int = 4

    /// LRU-ish cache keyed by URL string. We don't aggressively evict —
    /// SwiftUI's view recycling will release the AVPlayerItem soon
    /// enough.
    private var cache: [String: AVURLAsset] = [:]
    private var order: [String] = []

    /// Begin warming the URLs in `urls`. Already-warmed entries are
    /// silently skipped. Drops the oldest cached asset when the cap is
    /// exceeded. Fire-and-forget — never throws.
    func preload(urls: [URL]) {
        for url in urls {
            let key = url.absoluteString
            if cache[key] != nil { continue }

            let asset = AVURLAsset(
                url: url,
                options: [
                    AVURLAssetPreferPreciseDurationAndTimingKey: false,
                ],
            )
            cache[key] = asset
            order.append(key)

            // Kick off the load. iOS 16+ has the async load API; the
            // older callback API still works on 26.
            Task {
                _ = try? await asset.load(.tracks, .duration)
            }

            // Evict oldest when over cap.
            while order.count > maxCached, let oldest = order.first {
                order.removeFirst()
                cache.removeValue(forKey: oldest)
            }
        }
    }

    /// Hand the caller the warmed asset if we have one. Returns nil
    /// when no preload happened (caller should construct AVURLAsset
    /// fresh). NOT removed from the cache — repeated peeks are cheap
    /// and the next eviction will reclaim it.
    func cachedAsset(for url: URL) -> AVURLAsset? {
        cache[url.absoluteString]
    }
}
