import SwiftUI

// SExplore — full-screen "swipe to discover" view of nearby workers.
// Vertical drag switches between workers; the radius pill widens/narrows
// the candidate pool; the morphing FAB in the bottom-trailing corner
// expands into a floating tab bar.

struct ExploreView: View {
    @Environment(AppTheme.self) private var theme
    let onBack: () -> Void
    let onViewProfile: (Worker) -> Void
    let onGoProfile: () -> Void

    @State private var model = ExploreViewModel()
    @State private var index: Int = 0
    @State private var trayOpen: Bool = false
    @State private var showVouchSheet = false
    @State private var showMessageSheet = false
    @State private var draftMessage: String = ""
    @State private var messageError: String? = nil
    @State private var sendingMessage: Bool = false

    private let radiusSteps = Worker.radiusSteps

    // Radius and category live on the VM; expose bindings here.
    private var radius: Int { model.radius }
    private var selectedCategory: String { model.selectedCategory }

    private var filtered: [Worker] { model.workers }

    private var safeIndex: Int {
        max(0, min(index, filtered.count - 1))
    }

    private var currentWorker: Worker? {
        filtered.indices.contains(safeIndex) ? filtered[safeIndex] : nil
    }

    var body: some View {
        ZStack {
            background
            vignette

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 6)
                    .padding(.horizontal, 16)

                categoryBar
                    .padding(.top, 10)

                swipeHint
                    .padding(.top, 6)

                Group {
                    if let worker = currentWorker {
                        workerContent(worker: worker)
                            .transition(.opacity)
                            .id(worker.id)
                    } else {
                        emptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }

            morphingNav
                .padding(.trailing, 12)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .gesture(swipeGesture)
        .animation(.easeInOut(duration: 0.2), value: safeIndex)
        .sheet(isPresented: $showVouchSheet) {
            if let worker = currentWorker {
                GiveVouchSheet(worker: worker)
            }
        }
        .task { await model.onAppear() }
        .onChange(of: model.workers) { _, _ in
            // When the result set changes, snap back to the first card.
            if !filtered.indices.contains(index) { index = 0 }
            if let id = currentWorker?.id {
                Task { await model.loadInteractions(for: id) }
            }
        }
        .onChange(of: safeIndex) { _, _ in
            if let id = currentWorker?.id {
                Task { await model.loadInteractions(for: id) }
            }
        }
        .sheet(isPresented: $showMessageSheet) {
            messageComposer
                .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var messageComposer: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.shadowGrey.opacity(0.2))
                .frame(width: 44, height: 5)
                .padding(.top, 10)
            Text(theme.t("Send a message", "संदेश भेजें"))
                .scaledFont(size: 20, weight: .heavy, relativeTo: .title2)
                .foregroundStyle(Color.shadowGrey)
            if let worker = currentWorker {
                Text(theme.t("to \(worker.name)", "\(worker.name) को"))
                    .scaledFont(size: 13, relativeTo: .footnote)
                    .foregroundStyle(Color.mutedText)
            }
            TextField(theme.t("Hi! Are you available this week?",
                              "नमस्ते! क्या आप इस सप्ताह उपलब्ध हैं?"),
                      text: $draftMessage, axis: .vertical)
                .lineLimit(4, reservesSpace: true)
                .scaledFont(size: 15, relativeTo: .body)
                .foregroundStyle(Color.shadowGrey)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.soft))
                .padding(.horizontal, 20)
            if let err = messageError {
                Text(err)
                    .scaledFont(size: 12, weight: .semibold, relativeTo: .caption)
                    .foregroundStyle(Color(hex: "#E63946"))
            }
            Button { sendMessage() } label: {
                HStack(spacing: 8) {
                    if sendingMessage {
                        ProgressView().controlSize(.small).tint(.white)
                    }
                    Text(sendingMessage ? theme.t("Sending…", "भेज रहे हैं…")
                                       : theme.t("Send", "भेजें"))
                        .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.accent))
            }
            .padding(.horizontal, 20)
            .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sendingMessage)
            Spacer()
        }
    }

    private func sendMessage() {
        guard let worker = currentWorker else { return }
        let body = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        sendingMessage = true
        messageError = nil
        Task {
            defer { sendingMessage = false }
            do {
                try await model.sendMessage(to: worker.id, body: body)
                draftMessage = ""
                showMessageSheet = false
            } catch {
                messageError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - Category filter bar

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Worker.allCategories, id: \.self) { cat in
                    let on = cat == selectedCategory
                    Button {
                        model.selectedCategory = cat
                        index = 0
                    } label: {
                        Text(cat)
                            .scaledFont(size: 12, weight: .bold, relativeTo: .caption)
                            .foregroundStyle(on ? .white : .white.opacity(0.75))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(on ? theme.accent : .white.opacity(0.14))
                                    .overlay(Capsule().stroke(.white.opacity(on ? 0 : 0.20), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(cat)
                    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Background layers

    @ViewBuilder
    private var background: some View {
        if let worker = currentWorker {
            LinearGradient(
                colors: [Color(hex: worker.gradientStartHex), Color(hex: worker.gradientEndHex)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.45), value: worker.id)
        } else {
            Color(hex: "#111111").ignoresSafeArea()
        }
    }

    private var vignette: some View {
        LinearGradient(
            colors: [.black.opacity(0.50), .clear, .clear, .black.opacity(0.82)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Swipe gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let dy = value.translation.height
                if dy < -50 { goTo(safeIndex + 1) }
                else if dy > 50 { goTo(safeIndex - 1) }
            }
    }

    private func goTo(_ newIndex: Int) {
        guard filtered.indices.contains(newIndex), newIndex != safeIndex else { return }
        withAnimation(.easeInOut(duration: 0.2)) { index = newIndex }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.white.opacity(0.20), lineWidth: 1)
                            )
                    )
                    .accessibilityHidden(true)
            }
            .accessibilityLabel(theme.t("Back", "वापस"))

            progressDots
                .frame(maxWidth: .infinity)

            radiusPill
        }
    }

    @ViewBuilder
    private var progressDots: some View {
        if filtered.isEmpty {
            Text(theme.t("No workers found", "कोई कामगार नहीं मिला"))
                .scaledFont(size: 12, relativeTo: .caption)
                .foregroundStyle(.white.opacity(0.45))
        } else {
            HStack(spacing: 5) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { i, _ in
                    let isActive = i == safeIndex
                    Button { goTo(i) } label: {
                        Capsule()
                            .fill(isActive ? .white : .white.opacity(0.30))
                            .frame(width: isActive ? 22 : 6, height: 6)
                            .animation(.easeInOut(duration: 0.25), value: isActive)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(theme.t("Worker \(i + 1) of \(filtered.count)", "कामगार \(i + 1) / \(filtered.count)"))
                    .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }

    private var radiusPill: some View {
        HStack(spacing: 0) {
            Button { changeRadius(by: -1) } label: {
                Text("−")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
            }
            .accessibilityLabel(theme.t("Decrease radius", "दूरी घटाएं"))

            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
                Text("\(radius) km")
                    .scaledFont(size: 12, weight: .heavy, relativeTo: .caption)
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(theme.t("Search radius \(radius) kilometres", "\(radius) किलोमीटर की दूरी"))

            Button { changeRadius(by: 1) } label: {
                Text("+")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
            }
            .accessibilityLabel(theme.t("Increase radius", "दूरी बढ़ाएं"))
        }
        .background(
            Capsule()
                .fill(.white.opacity(0.12))
                .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 1))
        )
    }

    private func changeRadius(by delta: Int) {
        guard let i = radiusSteps.firstIndex(of: radius) else { return }
        let newIndex = max(0, min(radiusSteps.count - 1, i + delta))
        model.radius = radiusSteps[newIndex]
        if safeIndex >= filtered.count { index = max(0, filtered.count - 1) }
    }

    private var swipeHint: some View {
        Text(theme.t("↕ swipe to browse", "↕ ब्राउज़ करने के लिए स्वाइप करें"))
            .scaledFont(size: 11, weight: .medium, relativeTo: .caption2)
            .foregroundStyle(.white.opacity(0.60))
    }

    // MARK: - Worker content

    @ViewBuilder
    private func workerContent(worker: Worker) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            avatarBlock(worker: worker)

            Spacer(minLength: 12)

            HStack(alignment: .bottom, spacing: 16) {
                workerInfo(worker: worker)
                    .frame(maxWidth: .infinity, alignment: .leading)
                actionColumn
            }
            .padding(.horizontal, 18)
            // Clearance for the floating nav FAB anchored at bottom-trailing
            // (56pt + 20pt inset + a small breathing gap).
            .padding(.bottom, 96)
        }
    }

    private func avatarBlock(worker: Worker) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 2))
                    .frame(width: 110, height: 110)
                    .shadow(color: .black.opacity(0.40), radius: 20, x: 0, y: 8)
                Text(worker.emoji)
                    .font(.system(size: 54))
            }
            .accessibilityHidden(true)

            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                Text("\(worker.vouched) Vouched")
                    .scaledFont(size: 12, weight: .heavy, relativeTo: .caption)
                    .foregroundStyle(.white.opacity(0.90))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.white.opacity(0.12))
                    .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 1))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(worker.vouched) vouched")
        }
    }

    private func workerInfo(worker: Worker) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: worker.gradientStartHex), theme.accent],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(.white.opacity(0.20), lineWidth: 1.5)
                        )
                    Text(worker.initials)
                        .scaledFont(size: 14, weight: .heavy, relativeTo: .footnote)
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(worker.name)
                        .scaledFont(size: 18, weight: .heavy, relativeTo: .title3)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(worker.trade)
                        .scaledFont(size: 13, relativeTo: .footnote)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 11))
                Text(worker.location)
                    .scaledFont(size: 12, relativeTo: .caption)
            }
            .foregroundStyle(.white.opacity(0.50))
            .padding(.top, 4)

            FlowLayout(spacing: 6) {
                ForEach(worker.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .scaledFont(size: 11, weight: .semibold, relativeTo: .caption2)
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.12))
                                .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 1))
                        )
                }
            }
            .padding(.top, 4)

            HStack(spacing: 12) {
                statInline(value: "\(worker.rating)★", label: "Rating")
                statInline(value: "\(worker.jobs)", label: "Jobs")
            }
            .padding(.top, 6)

            Button { onViewProfile(worker) } label: {
                HStack(spacing: 8) {
                    Text(theme.t("View Profile", "प्रोफ़ाइल देखें"))
                        .scaledFont(size: 14, weight: .bold, relativeTo: .subheadline)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.accent)
                )
                .shadow(color: theme.accent.opacity(0.44), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PressScaleStyle(scale: 0.96))
            .padding(.top, 10)
            .accessibilityLabel(theme.t("View \(worker.name)'s profile", "\(worker.name) की प्रोफ़ाइल देखें"))
        }
    }

    private func statInline(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .scaledFont(size: 14, weight: .heavy, relativeTo: .subheadline)
                .foregroundStyle(.white)
            Text(label)
                .scaledFont(size: 12, relativeTo: .caption)
                .foregroundStyle(.white.opacity(0.45))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Right-hand action column

    private var actionColumn: some View {
        let workerID = currentWorker?.id ?? ""
        let snap = model.interactions[workerID] ?? .init()
        return VStack(spacing: 16) {
            actionTile(
                icon: snap.hasLiked ? "heart.fill" : "heart",
                label: "\(snap.counts.likes)",
                tint: snap.hasLiked ? Color(hex: "#E63946") : .white,
                a11y: snap.hasLiked ? "Unlike" : "Like"
            ) {
                Task { await model.toggleLike(workerID: workerID) }
            }
            actionTile(
                icon: "bubble.left.fill",
                label: "\(snap.counts.messages)",
                tint: .white,
                a11y: theme.t("Message", "संदेश")
            ) {
                showMessageSheet = true
            }
            ShareLink(item: shareItem) {
                actionTileLabel(icon: "arrow.up.right", label: nil, tint: .white)
            }
            .accessibilityLabel(theme.t("Share", "शेयर"))
            actionTile(
                icon: snap.hasSaved ? "bookmark.fill" : "bookmark",
                label: nil,
                tint: snap.hasSaved ? Color(hex: "#F4A261") : .white,
                a11y: snap.hasSaved ? theme.t("Unsave", "अनसेव") : theme.t("Save", "सेव")
            ) {
                Task { await model.toggleSave(workerID: workerID) }
            }
            actionTile(
                icon: snap.hasVouched ? "checkmark.seal.fill" : "star.fill",
                label: theme.t(snap.hasVouched ? "Vouched" : "Vouch",
                               snap.hasVouched ? "Vouch किया" : "Vouch करें"),
                tint: snap.hasVouched ? Color.verifiedBlue : .white,
                a11y: theme.t("Vouch", "Vouch करें")
            ) {
                showVouchSheet = true
            }
        }
        .padding(.bottom, 4)
        .disabled(currentWorker == nil)
    }

    private var shareItem: String {
        if let w = currentWorker {
            return "Check out \(w.name) on sthapna.ai — \(w.trade) in \(w.location)"
        }
        return "Check out sthapna.ai, a network of skilled workers."
    }

    private func actionTile(
        icon: String, label: String?, tint: Color, a11y: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            actionTileLabel(icon: icon, label: label, tint: tint)
        }
        .buttonStyle(PressScaleStyle(scale: 0.90))
        .accessibilityLabel(a11y)
    }

    private func actionTileLabel(icon: String, label: String?, tint: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.12))
                    .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 1))
                    .frame(width: 46, height: 46)
                    .shadow(color: .black.opacity(0.30), radius: 6, x: 0, y: 4)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(tint)
            }
            if let label {
                Text(label)
                    .scaledFont(size: 10, weight: .semibold, relativeTo: .caption2)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        switch model.state {
        case .loading, .idle:
            VStack(spacing: 14) {
                ProgressView().tint(.white)
                Text(theme.t("Finding workers near you…", "आस-पास के कामगार ढूंढ रहे हैं…"))
                    .scaledFont(size: 13, relativeTo: .footnote)
                    .foregroundStyle(.white.opacity(0.65))
            }
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.6))
                Text(theme.t("Couldn't reach the server", "सर्वर से कनेक्ट नहीं हो सका"))
                    .scaledFont(size: 16, weight: .heavy, relativeTo: .headline)
                    .foregroundStyle(.white)
                Text(message)
                    .scaledFont(size: 12, relativeTo: .caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                Button(theme.t("Try again", "फिर कोशिश करें")) {
                    Task { await model.reload() }
                }
                .scaledFont(size: 13, weight: .bold, relativeTo: .footnote)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Capsule().fill(theme.accent))
            }
            .padding(.horizontal, 40)
        case .loaded:
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.5))
                Text(theme.t("No workers in \(radius) km", "\(radius) km में कोई कामगार नहीं"))
                    .scaledFont(size: 16, weight: .heavy, relativeTo: .headline)
                    .foregroundStyle(.white)
                Text(theme.t("Try increasing the radius above", "ऊपर से दूरी बढ़ाएं"))
                    .scaledFont(size: 13, relativeTo: .footnote)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Morphing nav (collapsed circle → glass tab bar)

    private var morphingNav: some View {
        ZStack(alignment: .center) {
            collapsedIcon
                .opacity(trayOpen ? 0 : 1)
                .allowsHitTesting(!trayOpen)

            expandedTabBar
                .opacity(trayOpen ? 1 : 0)
                .allowsHitTesting(trayOpen)
        }
        .frame(width: trayOpen ? 366 : 56, height: trayOpen ? 68 : 56)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(trayOpen ? Color.white.opacity(0.90) : Color.white.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(trayOpen ? Color.white.opacity(0.95) : Color.white.opacity(0.36),
                                lineWidth: trayOpen ? 1 : 1.5)
                )
                .shadow(color: .black.opacity(trayOpen ? 0.18 : 0.45),
                        radius: trayOpen ? 12 : 16, x: 0, y: 8)
        )
        .animation(.spring(duration: 0.42, bounce: 0.30), value: trayOpen)
    }

    private var collapsedIcon: some View {
        Button {
            trayOpen = true
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 56, height: 56)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
        }
        .accessibilityLabel(theme.t("Open navigation", "नेविगेशन खोलें"))
    }

    private var expandedTabBar: some View {
        HStack(spacing: 0) {
            tabTile(icon: "house.fill", label: theme.t("Home", "होम"), active: false) {
                onGoProfile()
            }
            tabTile(icon: "square.grid.2x2.fill", label: theme.t("Explore", "एक्सप्लोर"), active: true) {
                trayOpen = false
            }
            addPlusButton
            tabTile(icon: "person.crop.circle.fill", label: theme.t("Profile", "प्रोफ़ाइल"), active: false) {
                onGoProfile()
            }
            tabTile(icon: "bubble.left.fill", label: theme.t("Messages", "संदेश"), active: false) {
                trayOpen = false
            }
        }
        .padding(.horizontal, 8)
    }

    private func tabTile(icon: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 19))
                    .foregroundStyle(active ? theme.accent : Color.shadowGrey.opacity(0.30))
                    .accessibilityHidden(true)
                Text(label)
                    .scaledFont(size: 10, weight: .bold, relativeTo: .caption2)
                    .foregroundStyle(active ? theme.accent : Color.dimText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }

    private var addPlusButton: some View {
        Button {
            trayOpen = false
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(theme.accent))
                .shadow(color: theme.accent.opacity(0.42), radius: 8, x: 0, y: 4)
                .accessibilityHidden(true)
        }
        .accessibilityLabel(theme.t("Create new job", "नया काम बनाएं"))
    }
}
