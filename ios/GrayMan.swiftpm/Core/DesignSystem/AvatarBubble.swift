import SwiftUI

// MARK: - Avatar bubble
//
// Circular profile picture with a deterministic initials fallback when
// no avatar URL is present (or the image fetch fails). Used in feed
// post headers, profile edit sheets, and anywhere else a worker's
// face needs to render.
//
// Backed by `AsyncImage` so it shares `URLCache.shared` — the app's
// cache is bumped in `GrayManApp.init`.

struct AvatarBubble: View {
    let name: String
    let avatarURL: String?
    let size: CGFloat

    private var initials: String {
        let chars = name.split(separator: " ").compactMap(\.first).map(String.init)
        return chars.prefix(2).joined().uppercased()
    }

    var body: some View {
        Group {
            if let avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        initialsCircle
                    }
                }
            } else {
                initialsCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialsCircle: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.shadowGrey, Color.shadowGrey.opacity(0.6)],
                    startPoint: .topLeading, endPoint: .bottomTrailing,
                ))
            Text(initials)
                .font(.system(size: size * 0.36, weight: .heavy))
                .foregroundStyle(.white)
        }
    }
}
