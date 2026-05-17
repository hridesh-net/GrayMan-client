import AVFoundation
import AVKit
import Network
import SwiftUI

// MARK: - HLS reel player
//
// AVPlayer-backed view that prefers the HLS master playlist (with adaptive
// bitrate variants produced by the backend transcoder) and falls back to
// the raw mp4/mov upload when the transcode hasn't landed yet. The whole
// point of this component is "show the first frame fast, never stall for
// more than a heartbeat on Tier-3 networks":
//
//   - `preferredPeakBitRate` capped to ~300 kbps on cellular so AVPlayer
//     biases toward the 240/480p HLS rungs over 720p. On Wi-Fi we leave
//     it unbounded.
//   - `automaticallyWaitsToMinimizeStalling = false` so AVPlayer starts
//     playing as soon as the first segment is decodable — at 2s HLS
//     segments that's a sub-second start.
//   - Optional thumbnail blurred behind the player so the first paint is
//     never an opaque black square.
//   - Quiet by default (mute on first appear; caller flips for Explore).

struct ReelPlayerView: View {
    let playbackURL: URL
    let thumbnailURL: URL?
    let isMuted: Bool
    let autoplay: Bool

    @State private var player: AVPlayer?
    @State private var capObserver: Any?

    init(
        playbackURL: URL,
        thumbnailURL: URL? = nil,
        isMuted: Bool = true,
        autoplay: Bool = true
    ) {
        self.playbackURL = playbackURL
        self.thumbnailURL = thumbnailURL
        self.isMuted = isMuted
        self.autoplay = autoplay
    }

    var body: some View {
        ZStack {
            if let thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill().blur(radius: 12)
                    } else {
                        Color.black
                    }
                }
            } else {
                Color.black
            }
            if let player {
                // No .ignoresSafeArea() here — the parent cell already
                // sizes us to the full viewport via GeometryReader, and
                // letting this layer expand past that frame causes
                // resizeAspectFill calculations to use the wrong bounds
                // (which is what made the video appear stretched).
                VideoPlayerLayer(player: player)
            } else {
                ProgressView().tint(.white)
            }
        }
        .onAppear {
            // Configure the audio session for reel playback the first
            // time any player appears. Default category is
            // `soloAmbient`, which is silenced by the hardware mute
            // switch and ducked by background music — neither is right
            // for a Reels-style feed where audio is part of the
            // creator's pitch.
            configureAudioSessionIfNeeded()

            // Player construction is async because we inspect the
            // asset's first video track to detect broken-orientation
            // recordings — see `makePlayer()`.
            Task {
                let p = await makePlayer()
                self.player = p
                if autoplay { p.play() }
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func makePlayer() async -> AVPlayer {
        let asset = AVURLAsset(url: playbackURL)
        let item = AVPlayerItem(asset: asset)
        // Soft cap on bitrate when on cellular. The HLS master playlist
        // exposes BANDWIDTH on each variant; AVPlayer picks the highest
        // that fits under this cap.
        item.preferredPeakBitRate = currentBitrateCap()

        // Diagnostic — paste this from Xcode console if video doesn't
        // render. Shows the URL, the path the orientation-fix takes,
        // and any post-creation status / error so we can pinpoint
        // whether the issue is at the asset, the player item, or the
        // player layer.
        let isHLS = playbackURL.pathExtension.lowercased() == "m3u8"
        print("[ReelPlayer] makePlayer url=\(playbackURL.absoluteString) isHLS=\(isHLS) bitrateCap=\(item.preferredPeakBitRate)")

        // Defensive orientation fix: reels recorded before
        // `AVCaptureConnection.videoRotationAngle` was wired in
        // `AVRecordingService` were saved as landscape with an identity
        // preferredTransform. AVPlayer obeys preferredTransform, so
        // those files play sideways. For file-based assets we apply a
        // videoComposition that rotates 90° at playback.
        //
        // CRITICAL: `AVMutableVideoComposition` is documented as
        // file-based-asset only. On HLS streams (.m3u8) it silently
        // FAILS to produce video frames — audio still plays, but the
        // player layer renders nothing, leaving the user staring at
        // the blurred thumbnail with sound. So we only build a
        // composition when the playback URL is a raw video file.
        // Sideways HLS streams (legacy uploads transcoded from broken
        // landscape sources) need a server-side re-transcode to fix;
        // new uploads recorded with the rotation-fixed pipeline are
        // already portrait at the file level so no rotation is needed.
        if !isHLS, let composition = await rotationFixVideoComposition(for: asset) {
            item.videoComposition = composition
            print("[ReelPlayer] composition applied (raw file, rotation fix)")
        } else {
            print("[ReelPlayer] composition skipped (isHLS=\(isHLS))")
        }

        let p = AVPlayer(playerItem: item)
        // Let AVPlayer buffer to avoid starting on zero frames — the
        // earlier `automaticallyWaitsToMinimizeStalling = false` was
        // pushing playback to start before any decodable data had
        // arrived, which on HLS over a slow link manifests as
        // "audio plays but no video frames ever appear". Default
        // behaviour buffers a small amount first, then plays.
        p.automaticallyWaitsToMinimizeStalling = true
        p.isMuted = isMuted

        // Surface terminal failures: AVPlayerItem reports `.failed`
        // for unrecognised codecs, network 403/404, and decoder
        // errors. Without this hook those just look like "blank
        // forever" from the UI.
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item, queue: .main,
        ) { note in
            let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
            print("[ReelPlayer] item failed to play to end: \(err?.localizedDescription ?? "unknown")")
        }
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewErrorLogEntry,
            object: item, queue: .main,
        ) { _ in
            if let last = item.errorLog()?.events.last {
                print("[ReelPlayer] error log: \(last.errorComment ?? "n/a") status=\(last.errorStatusCode) domain=\(last.errorDomain ?? "n/a")")
            }
        }
        return p
    }

    /// Returns a video composition that rotates the asset 90° when its
    /// effective rendered output would be landscape. The previous
    /// heuristic (identity-transform + landscape natural size) was too
    /// narrow — files whose preferredTransform sets a non-identity
    /// scale/translation but leaves the result landscape were slipping
    /// through. Now we compute the size AVPlayer *would* render at by
    /// applying preferredTransform to naturalSize and reject anything
    /// where width > height. This is a portrait-only reel app — any
    /// landscape stream is a recording-time bug we patch over here.
    private func rotationFixVideoComposition(for asset: AVURLAsset) async -> AVVideoComposition? {
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let (naturalSize, preferredTransform) = try? await track.load(
                .naturalSize, .preferredTransform,
              ),
              naturalSize.width > 0, naturalSize.height > 0
        else {
            return nil
        }

        // Effective output dimensions AVPlayer would render at without a
        // composition. abs() because preferredTransform can flip axes.
        let effective = naturalSize.applying(preferredTransform)
        let effW = abs(effective.width)
        let effH = abs(effective.height)
        guard effW > effH else { return nil }   // already portrait — skip

        // Render into a portrait-shaped box (width = source height, etc.).
        let renderSize = CGSize(width: effH, height: effW)
        let composition = AVMutableVideoComposition()
        composition.renderSize = renderSize
        composition.frameDuration = CMTime(value: 1, timescale: 30)

        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        // Build the layer transform as: (any preferredTransform) →
        // rotate 90° CLOCKWISE → translate back into the positive
        // quadrant of the renderSize box.
        //
        // This app records exclusively from the iPhone front camera —
        // when its sensor produces a landscape file without rotation
        // metadata, the "up" direction of the person's head is on the
        // LEFT side of the source frame. Rotating clockwise (-π/2)
        // brings their head to the top in the rendered output.
        // (Using +π/2 / CCW would have rotated the wrong way and
        // produced an upside-down result.)
        let rotation = CGAffineTransform(rotationAngle: -.pi / 2)
        let translation = CGAffineTransform(translationX: 0, y: effW)
        let combined = preferredTransform
            .concatenating(rotation)
            .concatenating(translation)
        layer.setTransform(combined, at: .zero)

        // Bound the instruction to the actual asset duration. Some
        // versions of AVFoundation refuse to render frames when
        // `duration` is `.positiveInfinity`, which is part of the
        // same family of silent-failure bugs as the HLS+composition
        // case above.
        let assetDuration = (try? await asset.load(.duration)) ?? CMTime(seconds: 60, preferredTimescale: 600)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: assetDuration)
        instruction.layerInstructions = [layer]
        composition.instructions = [instruction]
        return composition
    }

    /// Sets the shared AVAudioSession to `.playback` (mixWithOthers
    /// disabled) so reel audio plays even when the hardware silent
    /// switch is on. Idempotent — safe to call from every onAppear.
    private func configureAudioSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        guard session.category != .playback else { return }
        try? session.setCategory(.playback, mode: .moviePlayback, options: [])
        try? session.setActive(true, options: [])
    }

    private func currentBitrateCap() -> Double {
        // 300 kbps on cellular biases toward 240/480p rungs; 0 means
        // unbounded.  We probe synchronously via NWPathMonitor.currentPath
        // — works on iOS 16+ and matches our deployment target (26).
        let monitor = NWPathMonitor()
        defer { monitor.cancel() }
        // currentPath populates synchronously after .start; that's why we
        // start and immediately read.
        let path = monitor.currentPath
        if path.usesInterfaceType(.cellular) || path.isExpensive || path.isConstrained {
            return 600_000
        }
        return 0
    }
}

// MARK: - Player surface
//
// Wraps `AVPlayerViewController` (controls hidden) rather than rolling
// our own `AVPlayerLayer`-backed UIView. The custom-layer approach was
// missing the scene/window context that AVPlayer needs in iOS 17+ multi-
// scene apps — leading to "audio plays but no frames" and the
// `FigApplicationStateMonitor signalled err=-19431` log noise. The
// view-controller path is what Apple documents and tests.
//
// Compromise: AVPlayerViewController carries a UIViewController
// lifecycle which is heavier than a bare UIView. For a paged reel feed
// where one player is alive at a time, that cost is negligible
// (single-digit ms per cell) and well worth the rendering reliability.

private struct VideoPlayerLayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = false           // raw video, no chrome
        vc.videoGravity = .resizeAspectFill
        vc.view.backgroundColor = .black
        vc.allowsPictureInPicturePlayback = false  // PiP makes no sense in a feed
        vc.entersFullScreenWhenPlaybackBegins = false
        vc.exitsFullScreenWhenPlaybackEnds = false
        vc.updatesNowPlayingInfoCenter = false     // we're not a media app
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        // Re-apply on every update — SwiftUI recycles representable
        // hosts aggressively in paged LazyVStacks.
        if vc.player !== player {
            vc.player = player
        }
        vc.videoGravity = .resizeAspectFill
        vc.showsPlaybackControls = false
    }
}

// MARK: - Legacy custom-layer wrapper (kept for reference)
//
// Was the first attempt at the player surface. Replaced by the
// AVPlayerViewController path above because the bare UIView wasn't
// getting the scene/window context AVPlayer needs to render frames in
// some iOS 26 layouts. Left here behind an underscore so a future
// rewrite can compare.

private struct _LegacyVideoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerHostView {
        let v = PlayerHostView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PlayerHostView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
        uiView.playerLayer.videoGravity = .resizeAspectFill
    }

    final class PlayerHostView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer } // swiftlint:disable:this force_cast

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
            isOpaque = true
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            // Defensively pin the AVPlayerLayer's frame to the view's
            // current bounds, with implicit animations disabled so the
            // layer doesn't lerp during paged-scroll transitions (which
            // is one well-known cause of "audio plays but video stays
            // blank" — the layer's frame is zero or stale).
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = bounds
            CATransaction.commit()
        }
    }
}
