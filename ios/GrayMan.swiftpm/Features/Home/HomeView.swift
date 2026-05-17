import SwiftUI
import PhotosUI

// MARK: - Home screen
//
// Post-login landing. Top half is a stats card (Jobs · Experience ·
// Rating · Vouches) for the signed-in worker. Below it scrolls into a
// "Recent Work" feed of nearby posts from other workers, paginated.
//
// Routing: the tab bar shows Home as active and exposes the same
// Profile / Explore / Settings shortcuts as ProfileView's tab bar, so
// users can move between the two screens without going back to a
// chooseRole-style menu.

struct HomeView: View {
    @Environment(AppTheme.self) private var theme

    let userName: String
    let onProfile: () -> Void
    let onExplore: () -> Void
    let onSettings: () -> Void
    let onViewWorker: (Worker) -> Void

    @State private var model = HomeViewModel()
    @State private var showCreatePost: Bool = false
    @State private var resolvedSelfLocation: String? = nil

    private var isLoading: Bool { model.worker == nil }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            Blobs(accent: theme.accent, opacity: 0.55)

            VStack(spacing: 0) {
                headerRow
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        greetingBlock
                        statsCard
                        feedSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }
                .refreshable {
                    await model.load()
                }
            }

            VStack {
                Spacer()
                tabBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 20)
            }
        }
        .task { await model.load() }
        .task {
            if let place = await LocationService.shared.currentPlaceStrict(),
               let label = place.shortLabel, !label.isEmpty {
                resolvedSelfLocation = label
            }
            await WorkerService.shared.syncSelfLocationIfNeeded()
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostSheet(onPosted: { newPost in
                model.prepend(post: newPost)
            })
            .environment(theme)
        }
    }

    // MARK: - Header / greeting

    private var headerRow: some View {
        HStack {
            Text("sthapna.ai")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Color.shadowGrey)
                .tracking(-0.3)
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(theme.accent).frame(width: 7, height: 7)
                    .accessibilityHidden(true)
                Text(theme.t("Live", "लाइव"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.shadowGrey)
            }
        }
    }

    private var greetingBlock: some View {
        let displayName = (model.worker?.name ?? userName)
            .split(separator: " ").first.map(String.init)
            ?? (model.worker?.name ?? userName)
        return VStack(alignment: .leading, spacing: 4) {
            Text(theme.t("Hello, \(displayName)", "नमस्ते, \(displayName)"))
                .scaledFont(size: 26, weight: .heavy, relativeTo: .title)
                .foregroundStyle(Color.shadowGrey)
                .tracking(-0.6)
                .redacted(reason: isLoading ? .placeholder : [])
            if let loc = resolvedSelfLocation {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11))
                    Text(loc)
                        .scaledFont(size: 13, relativeTo: .footnote)
                }
                .foregroundStyle(Color.dimText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Stats card

    private var statsCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                statTile(value: "\(model.jobsDone)",
                         label: theme.t("Jobs", "काम"),
                         icon: "briefcase.fill")
                statTile(value: "\(model.experienceYears)\(theme.t("yr", "स"))",
                         label: theme.t("Experience", "अनुभव"),
                         icon: "calendar")
            }
            HStack(spacing: 12) {
                statTile(value: "\(model.rating)★",
                         label: theme.t("Rating", "रेटिंग"),
                         icon: "star.fill")
                statTile(value: "\(model.vouchesReceived)",
                         label: theme.t("Vouches", "वाउच"),
                         icon: "checkmark.seal.fill")
            }
        }
        .padding(18)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .redacted(reason: isLoading ? .placeholder : [])
    }

    private func statTile(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(theme.accent.opacity(0.10)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .scaledFont(size: 18, weight: .heavy, relativeTo: .title3)
                    .foregroundStyle(Color.shadowGrey)
                    .tracking(-0.3)
                Text(label)
                    .scaledFont(size: 11, weight: .medium, relativeTo: .caption2)
                    .foregroundStyle(Color.dimText)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.canvas.opacity(0.55))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Feed

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(theme.t("Recent Work", "हाल का काम"))
                    .scaledFont(size: 16, weight: .heavy, relativeTo: .headline)
                    .foregroundStyle(Color.shadowGrey)
                Spacer()
                Button { showCreatePost = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 12, weight: .bold))
                        Text(theme.t("Post", "पोस्ट"))
                            .scaledFont(size: 12, weight: .heavy, relativeTo: .footnote)
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(theme.accent.opacity(0.10)))
                }
                .buttonStyle(PressScaleStyle(scale: 0.96))
                .accessibilityLabel(theme.t("Write a new post", "नया पोस्ट लिखें"))
            }

            switch model.feedState {
            case .idle, .loading:
                ForEach(0..<2, id: \.self) { _ in postSkeletonCard }
            case .failed(let msg):
                Text(msg)
                    .scaledFont(size: 13, relativeTo: .footnote)
                    .foregroundStyle(Color(hex: "#E63946"))
            case .loaded:
                if model.posts.isEmpty {
                    emptyFeedState
                } else {
                    ForEach(model.posts) { post in
                        PostCard(post: post) {
                            // Tap → fetch the full Worker (PostAuthorDTO is a
                            // slim snapshot) then hand off to the routing
                            // layer. fetchWorker is cheap; failures are
                            // silent — a tap that doesn't navigate is better
                            // than crashing the feed.
                            Task {
                                if let worker = try? await WorkerService.shared.fetchWorker(id: post.author.id) {
                                    onViewWorker(worker)
                                }
                            }
                        }
                        .task(id: post.id) {
                            await model.loadMoreIfNeeded(currentPostID: post.id)
                        }
                    }
                }
            }
        }
    }

    private var postSkeletonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle().fill(Color.shadowGrey.opacity(0.12)).frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.shadowGrey.opacity(0.12))
                        .frame(width: 130, height: 11)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.shadowGrey.opacity(0.10))
                        .frame(width: 80, height: 9)
                }
                Spacer()
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.shadowGrey.opacity(0.10))
                .frame(maxWidth: .infinity).frame(height: 10)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.shadowGrey.opacity(0.10))
                .frame(maxWidth: .infinity).frame(height: 10)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.soft)
        )
    }

    private var emptyFeedState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(Color.dimText)
            Text(theme.t("No posts near you yet.", "आस-पास अभी कोई पोस्ट नहीं।"))
                .scaledFont(size: 14, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Color.mutedText)
            Text(theme.t("Be the first — tap Post.", "पहला बनिए — Post दबाइए।"))
                .scaledFont(size: 12, relativeTo: .footnote)
                .foregroundStyle(Color.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        FloatingTabBar(
            items: [
                .init(id: "home",     icon: "house.fill",
                      label: theme.t("Home", "होम")),
                .init(id: "explore",  icon: "square.grid.2x2.fill",
                      label: theme.t("Explore", "खोजें")),
                .init(id: "profile",  icon: "person.crop.circle.fill",
                      label: theme.t("Profile", "प्रोफ़ाइल")),
                .init(id: "settings", icon: "gearshape.fill",
                      label: theme.t("Settings", "सेटिंग्स")),
            ],
            selectedID: "home",
            onSelect: { id in
                switch id {
                case "explore":  onExplore()
                case "profile":  onProfile()
                case "settings": onSettings()
                default: break
                }
            },
            centerIcon: "plus",
            centerAccessibilityLabel: theme.t("Create new post", "नया पोस्ट बनाएं"),
            onCenterAction: { showCreatePost = true },
        )
    }
}

// `PostCard` and `AvatarBubble` live in their own files
// (Features/Home/PostCard.swift and Core/DesignSystem/AvatarBubble.swift)
// so they can be reused by other features without dragging HomeView's
// state along for the ride.
