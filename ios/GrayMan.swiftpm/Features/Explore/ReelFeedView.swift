import AVKit
import SwiftUI
import UIKit

// MARK: - Reel feed (vertical TikTok-style discovery)
//
// Replaces the swipe-card ExploreView. Vertical paged scroll over
// workers' reels. Key behaviours:
//
//   • iOS-17 paging scroll, one active AVPlayer at a time.
//   • Bottom-anchored action area: worker info → wide Hire button →
//     compact Call / Chat / Vouch / Save row. Sits ABOVE the morphing
//     tab bar so neither overlaps the right-edge of the video.
//   • Morphing tab bar: full FloatingTabBar by default; collapses to a
//     bottom-right FAB the moment the user swipes to a new reel; tap
//     the FAB to re-expand. (Inspired by the original Explore "morphing
//     nav" pattern.)
//   • Infinite circular scroll: when `/explore` is exhausted the view
//     model appends the seed list again so the user can keep scrolling
//     past the end and the same workers reappear in order.
//   • Next-2 reel preload via `ReelPreloader` so swipes feel instant.

struct ReelFeedView: View {
    @Environment(AppTheme.self) private var theme
    let onBack: () -> Void
    let onViewProfile: (Worker) -> Void
    let onGoProfile: () -> Void
    let onGoHome: () -> Void
    let onGoSettings: () -> Void

    @State private var model = ExploreViewModel()
    /// Position into `model.workers` (index, not worker id — duplicate
    /// workers appear when circular wrap kicks in, so worker.id alone
    /// isn't unique enough to track scroll position).
    @State private var currentIndex: Int? = 0
    @State private var tabBarExpanded: Bool = true
    @State private var showVouchSheet = false
    @State private var hireToast: String?

    /// Set to `true` when the in-reel comment / message shortcut should return.
    private static let showExploreReelCommentButton = false

    private var workers: [Worker] { model.workers }
    private var currentWorker: Worker? {
        guard let i = currentIndex, workers.indices.contains(i) else { return nil }
        return workers[i]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if workers.isEmpty {
                emptyOrLoading
            } else {
                feed
            }

            // Subtle bottom-up dark gradient for outdoor readability —
            // not opaque enough to be a visual block on its own.
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.black.opacity(0.0), .black.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom,
                )
                .frame(height: 280)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            // Top chrome (back + radius pill + scroll hint + categories).
            VStack {
                topChrome
                Spacer()
            }

            // Bottom row: worker block on the left, action rail on the
            // right. The outer VStack { Spacer(); HStack } anchors the
            // row to the BOTTOM of the ZStack — without it the HStack
            // would be centred vertically (ZStack default alignment).
            // HStack alignment .bottom keeps the worker block and the
            // action rail bottom-aligned within their own row.
            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 12) {
                    bottomWorkerBlock
                        .layoutPriority(1)
                    Spacer(minLength: 0)
                    rightActionRail
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 96)
            }

            // Bottom-most: morphing tab bar / FAB.
            VStack {
                Spacer()
                morphingTabBar
                    .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
        .task { await model.onAppear() }
        .onChange(of: workers) { _, fresh in
            // Snap to the first reel after a filter change or first load.
            if currentIndex == nil || (currentIndex.map { !fresh.indices.contains($0) } ?? true) {
                currentIndex = fresh.isEmpty ? nil : 0
            }
            preloadNeighbours(around: currentIndex)
        }
        .onChange(of: currentIndex) { _, newIdx in
            guard let newIdx, workers.indices.contains(newIdx) else { return }
            // The user just swiped to a new reel → collapse the tab bar
            // to the FAB. Only scroll-induced changes do this; tapping
            // an action button doesn't fire this onChange.
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                tabBarExpanded = false
            }
            Task {
                await model.loadMoreIfNeeded(currentIndex: newIdx)
                await model.loadInteractions(for: workers[newIdx].id)
            }
            preloadNeighbours(around: newIdx)
        }
        .sheet(isPresented: $showVouchSheet) {
            if let w = currentWorker { GiveVouchSheet(worker: w) }
        }
        .alert(theme.t("Hire", "हायर"),
               isPresented: Binding(get: { hireToast != nil },
                                    set: { if !$0 { hireToast = nil } })) {
            Button("OK", role: .cancel) { hireToast = nil }
        } message: {
            Text(hireToast ?? "")
        }
    }

    // MARK: - The vertical paged feed
    //
    // GeometryReader gives us the exact viewport size; every cell is
    // pinned to that height. Without it `.containerRelativeFrame(.vertical)`
    // was leaving a thin slice of the next cell visible at the bottom
    // — that's where the "black line" came from.

    private var feed: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(workers.enumerated()), id: \.offset) { idx, worker in
                        ReelFeedCell(
                            worker: worker,
                            isCurrent: idx == currentIndex,
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                        .id(idx)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentIndex)
            .contentMargins(.zero, for: .scrollContent)
            .scrollIndicators(.hidden)
        }
        .ignoresSafeArea()
    }

    private var emptyOrLoading: some View {
        VStack(spacing: 12) {
            switch model.state {
            case .loading, .idle:
                ProgressView().tint(.white)
                Text(theme.t("Finding workers near you…",
                             "आस-पास के कारीगर ढूंढ रहे हैं…"))
                    .scaledFont(size: 14, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            case .failed(let msg):
                Text(msg)
                    .scaledFont(size: 14, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(.white)
                Button(theme.t("Retry", "फिर कोशिश करें")) {
                    Task { await model.reload() }
                }
                .foregroundStyle(theme.accent)
                .padding(.top, 4)
            case .loaded:
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.6))
                Text(theme.t("No reels in this radius yet.",
                             "इस रेडियस में अभी कोई रील नहीं।"))
                    .scaledFont(size: 14, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(30)
    }

    // MARK: - Top chrome (back + radius +/- + scroll hint + categories)

    private var topChrome: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.black.opacity(0.45)))
                        .accessibilityHidden(true)
                }
                .accessibilityLabel(theme.t("Back", "वापस"))

                Spacer()

                // − / 50 km / + radius adjuster. Steps through
                // `Worker.radiusSteps` so we never land on a value the
                // backend rejects.
                radiusStepper

                Spacer()

                // Invisible spacer matching the back button width so
                // the radius stepper actually centres.
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .overlay(alignment: .center) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 9, weight: .bold))
                    Text(theme.t("scroll to browse", "स्क्रॉल करें"))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.55))
                .offset(y: 28)
                .allowsHitTesting(false)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Worker.allCategories, id: \.self) { cat in
                        Button { model.selectedCategory = cat } label: {
                            Text(cat)
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(model.selectedCategory == cat
                                                 ? .white
                                                 : .white.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(
                                        model.selectedCategory == cat
                                        ? theme.accent
                                        : .black.opacity(0.45)
                                    )
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 18)   // leave room for the centred hint above
        }
    }

    private var radiusStepper: some View {
        HStack(spacing: 0) {
            Button {
                if let idx = Worker.radiusSteps.firstIndex(of: model.radius), idx > 0 {
                    model.radius = Worker.radiusSteps[idx - 1]
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel(theme.t("Decrease radius", "रेडियस घटाएं"))

            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12))
                Text("\(model.radius) km")
                    .font(.system(size: 13, weight: .heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)

            Button {
                if let idx = Worker.radiusSteps.firstIndex(of: model.radius),
                   idx < Worker.radiusSteps.count - 1 {
                    model.radius = Worker.radiusSteps[idx + 1]
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel(theme.t("Increase radius", "रेडियस बढ़ाएं"))
        }
        .background(Capsule().fill(.black.opacity(0.45)))
    }

    // MARK: - Bottom-left worker block
    //
    // Avatar + name + trade + location + skill chips + rating/jobs
    // stats + a primary "View Profile" CTA. Text floats directly on
    // the gradient — no opaque card — matching the target design.

    @ViewBuilder
    private var bottomWorkerBlock: some View {
        if let worker = currentWorker {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    AvatarBubble(name: worker.name, avatarURL: worker.avatarURL, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(worker.name)
                                .scaledFont(size: 18, weight: .heavy, relativeTo: .title3)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if worker.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, Color.verifiedBlue)
                                    .font(.system(size: 13))
                            }
                        }
                        Text(worker.trade)
                            .scaledFont(size: 13, weight: .semibold, relativeTo: .subheadline)
                            .foregroundStyle(.white.opacity(0.80))
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11))
                    Text(worker.location)
                }
                .scaledFont(size: 12, weight: .semibold, relativeTo: .caption)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)

                if !worker.tags.isEmpty {
                    skillChips(worker)
                }

                statsRow(worker)

                viewProfileButton(worker)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Up to 3 skill tags rendered as #hashtag chips. Beyond 3 we drop
    /// the tail — keeps the bottom block from pushing the rail down on
    /// trade tag-heavy profiles.
    private func skillChips(_ worker: Worker) -> some View {
        HStack(spacing: 6) {
            ForEach(worker.tags.prefix(3), id: \.self) { tag in
                Text("#" + tag)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.90))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.10)))
                    .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
            }
        }
    }

    private func statsRow(_ worker: Worker) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                Text(worker.rating)
                    .font(.system(size: 14, weight: .heavy))
                Text("★")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.yellow)
                Text(theme.t("Rating", "रेटिंग"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Text("·")
                .foregroundStyle(.white.opacity(0.55))
            HStack(spacing: 3) {
                Text("\(worker.jobs)")
                    .font(.system(size: 14, weight: .heavy))
                Text(theme.t("Jobs", "काम"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .foregroundStyle(.white)
    }

    private func viewProfileButton(_ worker: Worker) -> some View {
        Button { onViewProfile(worker) } label: {
            HStack(spacing: 8) {
                Text(theme.t("View Profile", "प्रोफ़ाइल देखें"))
                Image(systemName: "arrow.right")
            }
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.accent)
            )
            .shadow(color: theme.accent.opacity(0.36), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
        .accessibilityLabel(theme.t("View \(worker.name)'s profile",
                                    "\(worker.name) की प्रोफ़ाइल देखें"))
    }

    // MARK: - Right action rail
    //
    // Like / Chat / Share / Save vertical column anchored to the right
    // edge above the FAB. Pure icon + small count under each, so the
    // rail is narrow and never pushes into the worker block on the
    // left.

    @ViewBuilder
    private var rightActionRail: some View {
        if let worker = currentWorker {
            let snap = model.interactions[worker.id]
            VStack(spacing: 16) {
                railButton(
                    icon: snap?.hasLiked == true ? "heart.fill" : "heart",
                    count: snap?.counts.likes ?? 0,
                    tint: snap?.hasLiked == true ? Color.red : .white,
                    a11y: theme.t("Like", "लाइक"),
                ) {
                    Task { await model.toggleLike(workerID: worker.id) }
                }
                if Self.showExploreReelCommentButton {
                    // Opens the worker's profile (where the in-app composer
                    // lives). Hidden from the reel rail for now — see `showExploreReelCommentButton`.
                    railButton(
                        icon: "bubble.left.fill",
                        count: snap?.counts.messages ?? 0,
                        tint: .white,
                        a11y: theme.t("Comment", "टिप्पणी"),
                    ) {
                        onViewProfile(worker)
                    }
                }
                railButton(
                    icon: "checkmark.seal.fill",
                    count: nil,
                    tint: snap?.hasVouched == true ? Color(hex: "#2D6A4F") : .white,
                    a11y: theme.t("Vouch for worker", "कारीगर को Vouch दें"),
                ) {
                    showVouchSheet = true
                }
                railButton(
                    icon: "arrow.up.right",
                    count: nil,
                    tint: .white,
                    a11y: theme.t("Share profile", "प्रोफ़ाइल शेयर करें"),
                ) {
                    // ShareLink lives elsewhere; route through URL scheme.
                }
                railButton(
                    icon: snap?.hasSaved == true ? "bookmark.fill" : "bookmark",
                    count: snap?.counts.saves ?? 0,
                    tint: snap?.hasSaved == true ? theme.accent : .white,
                    a11y: theme.t("Save", "सेव"),
                ) {
                    Task { await model.toggleSave(workerID: worker.id) }
                }
            }
        }
    }

    /// Single rail item — circular tap target + optional count below.
    /// 44pt button + 14pt text fits in a ~48pt-wide column so the
    /// left-side worker block can use the rest of the screen.
    private func railButton(icon: String, count: Int?, tint: Color,
                            a11y: String, onTap: @escaping () -> Void) -> some View {
        VStack(spacing: 3) {
            Button(action: onTap) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.black.opacity(0.45)))
            }
            .buttonStyle(PressScaleStyle(scale: 0.90))
            .accessibilityLabel(count.map { "\(a11y). \($0)" } ?? a11y)
            if let count, count > 0 {
                Text(formatCount(count))
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
    }

    private func formatCount(_ n: Int) -> String {
        switch n {
        case 0..<1000: return "\(n)"
        case 1000..<1_000_000:
            let k = Double(n) / 1000
            return String(format: "%.1fk", k)
        default:
            let m = Double(n) / 1_000_000
            return String(format: "%.1fM", m)
        }
    }

    // MARK: - Morphing tab bar
    //
    // Two states animated via .transition:
    //   • Expanded: full FloatingTabBar across the bottom.
    //   • Collapsed: small round FAB pinned to the bottom-right.
    // Scrolling to a new reel collapses; tapping the FAB expands.

    @ViewBuilder
    private var morphingTabBar: some View {
        if tabBarExpanded {
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
                selectedID: "explore",
                onSelect: { id in
                    switch id {
                    case "home":     onGoHome()
                    case "profile":  onGoProfile()
                    case "settings": onGoSettings()
                    default: break
                    }
                },
                centerIcon: "magnifyingglass",
                centerAccessibilityLabel: theme.t("Search filters", "फ़िल्टर खोजें"),
                onCenterAction: {
                    // No dedicated search sheet yet — collapse so the
                    // user can interact with the category strip up top.
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        tabBarExpanded = false
                    }
                },
            )
            .padding(.horizontal, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        tabBarExpanded = true
                    }
                } label: {
                    Image(systemName: "rectangle.3.group.bubble.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(theme.accent))
                        .shadow(color: theme.accent.opacity(0.42), radius: 10, x: 0, y: 4)
                        .accessibilityHidden(true)
                }
                .buttonStyle(PressScaleStyle(scale: 0.92))
                .accessibilityLabel(theme.t("Show navigation", "नेविगेशन दिखाएं"))
            }
            .padding(.trailing, 16)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
        }
    }

    // MARK: - Helpers

    @MainActor
    private func sendHire(_ worker: Worker) async {
        do {
            _ = try await WorkerService.shared.createHire(workerID: worker.id)
            hireToast = theme.t("Hire request sent.", "अनुरोध भेज दिया गया।")
        } catch {
            hireToast = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    /// Warm next 2 / previous 1 reels' HLS metadata so paging feels
    /// instant. Silent on missing playback URLs.
    private func preloadNeighbours(around idx: Int?) {
        guard let idx else { return }
        let neighbours = [idx - 1, idx + 1, idx + 2]
            .filter { workers.indices.contains($0) }
            .compactMap { workers[$0].reelPlaybackURL }
            .compactMap { URL(string: $0) }
        Task { await ReelPreloader.shared.preload(urls: neighbours) }
    }
}

// MARK: - One cell in the vertical feed
//
// Purely the video / thumbnail / placeholder layer. The bottom action
// overlay lives in the parent `ReelFeedView` so its state can react
// to the currently-visible worker (vouch state, save state, etc.).

private struct ReelFeedCell: View {
    @Environment(AppTheme.self) private var theme
    let worker: Worker
    /// Only the visible cell plays its video. Sibling cells render the
    /// poster thumbnail and skip the AVPlayer build entirely.
    let isCurrent: Bool

    var body: some View {
        ZStack {
            if isCurrent,
               let raw = worker.reelPlaybackURL,
               let url = URL(string: raw) {
                ReelPlayerView(
                    playbackURL: url,
                    thumbnailURL: worker.reelThumbnailURL.flatMap(URL.init),
                    isMuted: false,
                    autoplay: true,
                )
            } else if let thumbRaw = worker.reelThumbnailURL, let url = URL(string: thumbRaw) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Color.black
                    }
                }
                .clipped()
            } else {
                // Worker has no reel yet — show a centred trade emoji
                // as a placeholder. Defensive: the `has_reel=true`
                // filter on /explore should keep this case off the
                // discovery surface, but a worker can delete their
                // reel mid-session.
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(hex: worker.gradientStartHex),
                            Color(hex: worker.gradientEndHex),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing,
                    )
                    VStack(spacing: 12) {
                        Text(worker.emoji)
                            .font(.system(size: 80))
                        Text(theme.t("No reel yet", "अभी कोई रील नहीं"))
                            .scaledFont(size: 14, weight: .heavy, relativeTo: .subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
