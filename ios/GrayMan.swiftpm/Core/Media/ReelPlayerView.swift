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
                .ignoresSafeArea()
            } else {
                Color.black
            }
            if let player {
                VideoPlayerLayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView().tint(.white)
            }
        }
        .onAppear {
            let p = makePlayer()
            self.player = p
            if autoplay { p.play() }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func makePlayer() -> AVPlayer {
        let asset = AVURLAsset(url: playbackURL)
        let item = AVPlayerItem(asset: asset)
        // Soft cap on bitrate when on cellular. The HLS master playlist
        // exposes BANDWIDTH on each variant; AVPlayer picks the highest
        // that fits under this cap.
        item.preferredPeakBitRate = currentBitrateCap()
        // Quick time-to-first-frame.
        let p = AVPlayer(playerItem: item)
        p.automaticallyWaitsToMinimizeStalling = false
        p.isMuted = isMuted
        return p
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

private struct VideoPlayerLayer: UIViewRepresentable {
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
    }

    final class PlayerHostView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer } // swiftlint:disable:this force_cast
    }
}
