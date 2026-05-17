import SwiftUI

// MARK: - Post card
//
// A single feed entry rendered in the Home screen's scrolling list.
// Author header (avatar + name + trade + verified badge), body text,
// optional image, relative timestamp. Caller passes `onTap` to handle
// taps anywhere on the card (used to route to the author's profile).

struct PostCard: View {
    @Environment(AppTheme.self) private var theme
    let post: PostDTO
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                AvatarBubble(name: post.author.name, avatarURL: post.author.avatarURL, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(post.author.name)
                            .scaledFont(size: 14, weight: .heavy, relativeTo: .subheadline)
                            .foregroundStyle(Color.shadowGrey)
                            .lineLimit(1)
                        if post.author.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.verifiedBlue)
                                .font(.system(size: 12))
                                .accessibilityLabel(theme.t("Verified", "सत्यापित"))
                        }
                    }
                    Text(post.author.trade)
                        .scaledFont(size: 12, relativeTo: .footnote)
                        .foregroundStyle(Color.mutedText)
                        .lineLimit(1)
                }
                Spacer()
                Text(relative(post.createdAt))
                    .scaledFont(size: 11, weight: .semibold, relativeTo: .caption2)
                    .foregroundStyle(Color.dimText)
            }
            Text(post.body)
                .scaledFont(size: 14, relativeTo: .body)
                .foregroundStyle(Color.shadowGrey)
                .multilineTextAlignment(.leading)
            if let imageURL = post.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.shadowGrey.opacity(0.10))
                            .frame(height: 180)
                    case .success(let img):
                        img.resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    case .failure:
                        EmptyView()
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.soft)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
