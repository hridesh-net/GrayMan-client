import SwiftUI

// Maps to S3 in the React mockup: profile dashboard with the floating
// "liquid glass" tab bar. The two glass elements are the profile card
// and the tab bar — everything else is flat, just like the mockup.

struct ProfileView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.openURL) private var openURL

    let userName: String
    let worker: Worker?                                 // non-nil → viewing another worker
    let onBack: (() -> Void)?                           // shown only when viewing a worker
    let onExplore: (() -> Void)?                        // tap the Explore tab to navigate
    let onSignOut: (() -> Void)?                        // sign-out from SettingsView routes here
    let onRecordReel: (() -> Void)?                     // re-shoot reel (from failed analysis banner)
    let onHome: (() -> Void)?                           // Home tab → return to HomeView

    private var isSelf: Bool { worker == nil }

    @State private var model: ProfileViewModel
    @State private var selectedSkills: Set<Int> = [0, 1]
    @State private var isSaved: Bool = false
    @State private var showHireAlert: Bool = false
    @State private var hireResultMessage: String? = nil
    @State private var showVouchBlockedAlert: Bool = false
    @State private var showAddSheet: Bool = false
    @State private var showVoiceInterview: Bool = false
    @State private var showProofOfWork: Bool = false
    @State private var showGiveVouch: Bool = false
    @State private var showSettings: Bool = false
    @State private var showEditProfile: Bool = false
    @State private var showNotifications: Bool = false
    @State private var showAddWorkHistory: Bool = false
    /// GPS-derived (reverse-geocoded) place label. Populated for the
    /// self-profile from `LocationService.currentPlace()` so the UI shows
    /// where the user *currently is*, not the legacy hardcoded city.
    @State private var resolvedSelfLocation: String? = nil

    @MainActor
    init(userName: String = "Ramesh Kumar",
         worker: Worker? = nil,
         onBack: (() -> Void)? = nil,
         onExplore: (() -> Void)? = nil,
         onSignOut: (() -> Void)? = nil,
         onRecordReel: (() -> Void)? = nil,
         onHome: (() -> Void)? = nil) {
        self.userName = userName
        self.worker = worker
        self.onBack = onBack
        self.onExplore = onExplore
        self.onSignOut = onSignOut
        self.onRecordReel = onRecordReel
        self.onHome = onHome
        if let w = worker {
            _model = State(wrappedValue: ProfileViewModel(mode: .otherWorker(id: w.id), seed: w))
        } else {
            _model = State(wrappedValue: ProfileViewModel(mode: .selfProfile))
        }
    }

    /// The currently-displayed worker — backend data once loaded, otherwise
    /// the seed passed in via init, otherwise nil (loading state).
    private var loaded: Worker? { model.worker ?? worker }

    /// True only when looking at the signed-in user's own profile and the
    /// backend hasn't returned yet. Drives `.redacted(.placeholder)` over
    /// the data-driven sections so the user sees a skeleton instead of
    /// fake fallback values like "Ramesh Kumar" / "48" / "4.9".
    private var isLoading: Bool { isSelf && model.worker == nil }

    // MARK: - Derived display data (resolved worker, falls back to neutral
    // placeholder strings used as skeleton fillers under `.redacted`).

    private var displayName: String {
        loaded?.name ?? (userName.isEmpty ? "Your name" : userName)
    }
    private var displayTrade: String { loaded?.trade ?? "Your trade" }
    private var displayLocation: String {
        // Self profile: ONLY show the GPS-derived label. If we don't have
        // a real device fix yet, show a "locating" placeholder rather
        // than the backend-cached value (which may be stale / dummy from
        // a previous session) — the user explicitly asked us to never
        // display a faked location.
        if isSelf {
            if let resolved = resolvedSelfLocation, !resolved.isEmpty {
                return resolved
            }
            return theme.t("Locating…", "स्थान खोज रहे हैं…")
        }
        // Other-worker profile: keep the backend-supplied "City · X km"
        // label since it carries the worker's home base + distance.
        let raw = loaded?.location ?? ""
        if !raw.isEmpty {
            return raw.split(separator: "·").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? raw
        }
        return theme.t("Locating…", "स्थान खोज रहे हैं…")
    }
    private var displayJobs: String { loaded.map { "\($0.jobs)" } ?? "00" }
    private var displayRating: String { loaded?.rating ?? "0.0" }
    private var displayVouchScore: Int { loaded?.vouchScore ?? 0 }
    private var skills: [String] {
        if let tags = loaded?.tags, !tags.isEmpty { return tags }
        // During loading we render placeholder pills (redacted into gray
        // shapes). When loaded with no tags, return [] so the section
        // collapses instead of showing fake skill names.
        return isLoading ? ["Skill one", "Skill two", "Skill three", "Skill four"] : []
    }
    private var verifiedSkillIndices: Set<Int> { loaded?.verifiedTagIndices ?? [] }
    private var phoneNumber: String { loaded?.phone ?? "" }

    private var initials: String {
        if let loaded { return loaded.initials }
        if isLoading { return "··" }
        let parts = displayName.split(separator: " ")
        let chars = parts.compactMap(\.first).map(String.init)
        return String(chars.prefix(2).joined()).uppercased()
    }

    private var avatarGradientEnd: Color {
        if let loaded { return Color(hex: loaded.gradientEndHex) }
        return theme.accent
    }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            Blobs(accent: theme.accent, opacity: 0.55)

            VStack(spacing: 0) {
                headerRow
                    .padding(.horizontal, isSelf ? 28 : 20)
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        if isSelf, let banner = analysisBanner { banner }
                        profileCard
                        skillsSection
                        workHistorySection
                        showcaseWorkButton
                        actionsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }

            VStack {
                Spacer()
                tabBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 20)
            }
        }
        .alert(theme.t("Send hire request?", "काम का अनुरोध भेजें?"), isPresented: $showHireAlert) {
            Button(theme.t("Cancel", "रद्द करें"), role: .cancel) {}
            Button(theme.t("Send", "भेजें")) {
                Task {
                    do {
                        _ = try await model.createHire()
                        hireResultMessage = theme.t(
                            "Hire request sent. They'll be notified.",
                            "अनुरोध भेज दिया गया। उन्हें सूचना मिलेगी।"
                        )
                    } catch {
                        hireResultMessage = (error as? LocalizedError)?.errorDescription
                            ?? error.localizedDescription
                    }
                }
            }
        } message: {
            Text(theme.t(
                "\(displayName.split(separator: " ").first.map(String.init) ?? "They") will be notified. After the job is complete they can be vouched.",
                "\(displayName.split(separator: " ").first.map(String.init) ?? "उन्हें") को सूचना मिलेगी। काम पूरा होने पर आप उनके लिए वाउच कर सकते हैं।"
            ))
        }
        .alert(theme.t("Result", "स्थिति"), isPresented: Binding(
            get: { hireResultMessage != nil },
            set: { if !$0 { hireResultMessage = nil } }
        )) {
            Button(theme.t("OK", "ठीक है"), role: .cancel) { hireResultMessage = nil }
        } message: {
            Text(hireResultMessage ?? "")
        }
        .alert(theme.t("Vouch not yet available", "वाउच अभी उपलब्ध नहीं"),
               isPresented: $showVouchBlockedAlert) {
            Button(theme.t("OK", "ठीक है"), role: .cancel) {}
        } message: {
            Text(theme.t(
                "You can vouch for this worker only after you've hired them and marked the job complete. Trust the platform — trust the vouch.",
                "आप इस कारीगर के लिए वाउच केवल तब कर सकते हैं जब आपने उन्हें काम दिया हो और काम पूरा होने की पुष्टि की हो। भरोसा प्लेटफ़ॉर्म पर — भरोसा वाउच पर।"
            ))
        }
        .sheet(isPresented: $showAddSheet) {
            addSheetContent
        }
        .sheet(isPresented: $showGiveVouch) {
            if let w = loaded {
                GiveVouchSheet(worker: w)
            }
        }
        .fullScreenCover(isPresented: $showVoiceInterview) {
            VoiceInterviewView(trade: displayTrade)
        }
        .fullScreenCover(isPresented: $showProofOfWork) {
            ProofOfWorkView()
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView(onSignOut: { onSignOut?() })
        }
        .fullScreenCover(isPresented: $showNotifications) {
            NotificationsView(onProfileChanged: {
                Task { await model.load() }
            })
            .environment(theme)
        }
        .sheet(isPresented: $showAddWorkHistory) {
            WorkHistoryEditorSheet(
                onSave: { body in
                    try await model.addWorkHistory(body)
                }
            )
            .environment(theme)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(initial: loaded) { update in
                Task { await model.update(update) }
            }
        }
        .task { await model.load() }
        // Resolve the GPS-derived label for the self profile. Runs only on
        // the self path — other-worker profiles keep their backend city.
        // Uses the STRICT variant: returns nil rather than the Mumbai
        // fallback if the device hasn't given us a real fix, so we hide
        // the city pill instead of lying about where the user is.
        .task(id: isSelf) {
            guard isSelf else { return }
            if let place = await LocationService.shared.currentPlaceStrict(),
               let label = place.shortLabel, !label.isEmpty {
                resolvedSelfLocation = label
            } else {
                resolvedSelfLocation = nil
            }
            // Persist the approximate fix to the backend so the explore
            // feed has a correct anchor for this worker. Guarded inside
            // the service to run at most once per app session.
            await WorkerService.shared.syncSelfLocationIfNeeded()
        }
    }

    // MARK: - Header row (branded for self, back-button for worker)

    @ViewBuilder
    private var headerRow: some View {
        if let onBack {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.shadowGrey)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.soft)
                        )
                        .accessibilityHidden(true)
                }
                .accessibilityLabel(theme.t("Back", "वापस"))
                Spacer()
            }
        } else {
            HStack {
                Text("sthapna.ai")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Color.shadowGrey)
                    .tracking(-0.3)
                Spacer()
                HStack(spacing: 14) {
                    notificationsBell
                    HStack(spacing: 8) {
                        Circle().fill(theme.accent).frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                        Text(theme.t("Live", "लाइव"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.shadowGrey)
                    }
                    .accessibilityLabel(theme.t("Live", "लाइव"))
                }
            }
        }
    }

    private var notificationsBell: some View {
        Button { showNotifications = true } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.shadowGrey)
                    .frame(width: 30, height: 30)
                if model.unreadNotifications > 0 {
                    Text(model.unreadNotifications > 9 ? "9+" : "\(model.unreadNotifications)")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(theme.accent))
                        .offset(x: 4, y: -4)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityLabel(theme.t(
            "Notifications. \(model.unreadNotifications) unread.",
            "सूचनाएँ। \(model.unreadNotifications) नई।"
        ))
    }

    // MARK: - Reel analysis banner (own profile only)

    @ViewBuilder
    private var analysisBanner: (some View)? {
        if let info = model.analysis {
            switch info.status {
            case "pending", "processing":
                AnyView(
                    HStack(spacing: 12) {
                        ProgressView().tint(theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(theme.t("Analysing your reel…", "आपकी रील का विश्लेषण…"))
                                .scaledFont(size: 14, weight: .heavy, relativeTo: .subheadline)
                                .foregroundStyle(Color.shadowGrey)
                            Text(theme.t("AI is extracting your skills and experience.",
                                         "AI आपके कौशल और अनुभव को पढ़ रहा है।"))
                                .scaledFont(size: 12, relativeTo: .caption)
                                .foregroundStyle(Color.mutedText)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(theme.accent.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(theme.accent.opacity(0.20), lineWidth: 1))
                )
            case "done" where info.extractedTrade != nil && model.hasPendingReelReview:
                AnyView(
                    Button { showNotifications = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.verifiedBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(theme.t("Reel analysis ready — review to apply",
                                             "रील विश्लेषण तैयार — समीक्षा करें"))
                                    .scaledFont(size: 14, weight: .heavy, relativeTo: .subheadline)
                                    .foregroundStyle(Color.shadowGrey)
                                Text(theme.t(
                                    "Accept to update your profile with the AI's findings.",
                                    "स्वीकार करें — AI के निष्कर्ष से प्रोफ़ाइल अपडेट होगी।"
                                ))
                                .scaledFont(size: 12, relativeTo: .caption)
                                .foregroundStyle(Color.mutedText)
                                .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.dimText)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.verifiedBlue.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.verifiedBlue.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(PressScaleStyle(scale: 0.98))
                )
            case "failed":
                AnyView(
                    Button { onRecordReel?() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color(hex: "#E63946"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(theme.t("Reel analysis failed",
                                             "रील विश्लेषण विफल"))
                                    .scaledFont(size: 14, weight: .heavy, relativeTo: .subheadline)
                                    .foregroundStyle(Color.shadowGrey)
                                Text(theme.t("Tap to re-shoot your reel.",
                                             "फिर से रिकॉर्ड करने के लिए टैप करें।"))
                                    .scaledFont(size: 12, relativeTo: .caption)
                                    .foregroundStyle(Color.mutedText)
                            }
                            Spacer()
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "#E63946"))
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(hex: "#E63946").opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(hex: "#E63946").opacity(0.22), lineWidth: 1))
                    }
                    .buttonStyle(PressScaleStyle(scale: 0.98))
                    .disabled(onRecordReel == nil)
                    .accessibilityLabel(theme.t("Reel analysis failed. Tap to re-shoot.",
                                                "रील विश्लेषण विफल। फिर से रिकॉर्ड करने के लिए टैप करें।"))
                )
            default:
                AnyView(EmptyView())
            }
        }
    }

    // MARK: - Profile card (glass #1)

    private var profileCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color.shadowGrey, avatarGradientEnd],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 72, height: 72)
                        .shadow(color: avatarGradientEnd.opacity(0.36),
                                radius: 12, x: 0, y: 8)
                    Text(initials)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(displayName)
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Color.shadowGrey)
                            .tracking(-0.4)
                            .lineLimit(1)
                        if loaded?.isVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.verifiedBlue)
                                .font(.system(size: 16))
                                .accessibilityLabel(theme.t("Verified", "सत्यापित"))
                        }
                    }
                    Text(displayTrade)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.mutedText)
                        .padding(.bottom, 4)
                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 11))
                            Text(displayLocation)
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(Color.dimText)
                        Text(theme.t("● Available", "● उपलब्ध"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(theme.accent)
                    }
                }

                Spacer(minLength: 0)

                VouchScoreRing(score: displayVouchScore, size: 62)
                    .onTapGesture {
                        guard !isSelf else { return }
                        // Backend rejects vouches from someone who has not
                        // completed a hire of this worker. Gate here too so
                        // the user gets a clear product-grade explanation
                        // instead of a generic "403 forbidden" toast.
                        if model.hasCompletedHire {
                            showGiveVouch = true
                        } else {
                            showVouchBlockedAlert = true
                        }
                    }
                    .accessibilityHint(isSelf ? "" : "Tap to give a vouch")
            }
            .padding(.bottom, 18)

            Divider().background(Color.shadowGrey.opacity(0.1))

            HStack(spacing: 0) {
                stat(displayJobs, theme.t("Jobs", "काम"))
                Divider().frame(height: 32).background(Color.shadowGrey.opacity(0.1))
                stat("\(displayRating)★", theme.t("Rating", "रेटिंग"))
            }
            .padding(.top, 16)
        }
        .padding(22)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .redacted(reason: isLoading ? .placeholder : [])
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.black)
                .tracking(-0.4)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.dimText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Skills

    @ViewBuilder
    private var skillsSection: some View {
        // Hide the section when the loaded worker has zero skill tags so
        // we never show a header above an empty area.
        if !isLoading && skills.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel(theme.t("Skills", "कौशल"))
                FlowLayout(spacing: 8) {
                    ForEach(Array(skills.enumerated()), id: \.offset) { i, sk in
                        let isActive = selectedSkills.contains(i)
                        let isVerified = verifiedSkillIndices.contains(i)
                        Button {
                            if isActive { selectedSkills.remove(i) }
                            else        { selectedSkills.insert(i) }
                        } label: {
                            HStack(spacing: 4) {
                                Text(sk)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(isActive ? theme.accent : Color.mutedText)
                                if isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.verifiedBlue)
                                        .font(.system(size: 11))
                                        .accessibilityLabel("Verified skill")
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(isActive ? theme.accent.opacity(0.06) : .clear)
                            )
                            .overlay(
                                Capsule().stroke(
                                    isActive ? theme.accent.opacity(0.38) : Color.shadowGrey.opacity(0.13),
                                    lineWidth: 1.5
                                )
                            )
                        }
                        .buttonStyle(PressScaleStyle(scale: 0.94))
                        .accessibilityLabel(isVerified ? "\(sk), verified skill" : sk)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .sensoryFeedback(.selection, trigger: selectedSkills)
            .redacted(reason: isLoading ? .placeholder : [])
            .disabled(isLoading)
        }
    }

    // MARK: - Work history (timeline)
    //
    // Reads from the backend (`GET /workers/{id}/history` via
    // ProfileViewModel.workHistory). No trade-keyed fallback — empty
    // history stays empty so we never fabricate roles the user didn't add.
    // Skeleton placeholders cover the loading state via `.redacted`.

    @ViewBuilder
    private var workHistorySection: some View {
        // For other-worker view, hide the section entirely when there's
        // nothing real to show. For self profile we still render so the
        // Add button is reachable.
        if !isSelf && !isLoading && model.workHistory.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel(theme.t("Work History", "कार्य इतिहास"))
                VStack(alignment: .leading, spacing: 18) {
                    if isLoading {
                        // 2 skeleton rows redacted into gray bars.
                        ForEach(0..<2, id: \.self) { idx in
                            workHistoryRow(
                                idx: idx, count: 2,
                                role: "Placeholder role title",
                                client: "Placeholder client",
                                period: "0000",
                                desc: "Placeholder description line that fills out the row width."
                            )
                        }
                    } else if model.workHistory.isEmpty {
                        Text(theme.t(
                            "No work history yet. Add roles you've worked to build trust.",
                            "अभी कोई कार्य इतिहास नहीं। भरोसा बनाने के लिए अपनी भूमिकाएँ जोड़ें।"
                        ))
                        .scaledFont(size: 13, relativeTo: .footnote)
                        .foregroundStyle(Color.dimText)
                    } else {
                        ForEach(Array(model.workHistory.enumerated()), id: \.element.id) { idx, dto in
                            workHistoryRow(
                                idx: idx, count: model.workHistory.count,
                                role: dto.role,
                                client: dto.client ?? "",
                                period: dto.periodLabel,
                                desc: dto.description ?? ""
                            )
                        }
                    }

                    if isSelf {
                        Button {
                            showAddWorkHistory = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                Text(theme.t("Add Work History", "कार्य इतिहास जोड़ें"))
                            }
                            .scaledFont(size: 14, weight: .semibold, relativeTo: .footnote)
                            .foregroundStyle(Color.dimText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        Color.shadowGrey.opacity(0.16),
                                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                                    )
                            )
                        }
                        .buttonStyle(PressScaleStyle(scale: 0.98))
                        .padding(.top, 4)
                        .unredacted()
                    }
                }
            }
            .redacted(reason: isLoading ? .placeholder : [])
        }
    }

    private func workHistoryRow(
        idx: Int, count: Int,
        role: String, client: String, period: String, desc: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 4) {
                Circle()
                    .fill(idx == 0 ? theme.accent : Color.shadowGrey.opacity(0.18))
                    .frame(width: 9, height: 9)
                    .padding(.top, 5)
                if idx < count - 1 {
                    Rectangle()
                        .fill(Color.shadowGrey.opacity(0.10))
                        .frame(width: 1)
                        .frame(minHeight: 36)
                }
            }
            .frame(width: 9)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(role)
                        .scaledFont(size: 15, weight: .heavy, relativeTo: .subheadline)
                        .foregroundStyle(Color.shadowGrey)
                    Spacer(minLength: 8)
                    Text(period)
                        .scaledFont(size: 11, weight: .semibold, relativeTo: .caption2)
                        .foregroundStyle(Color.dimText)
                }
                if !client.isEmpty {
                    Text(client)
                        .scaledFont(size: 13, weight: .semibold, relativeTo: .footnote)
                        .foregroundStyle(theme.accent)
                        .padding(.top, 1)
                }
                if !desc.isEmpty {
                    Text(desc)
                        .scaledFont(size: 13, relativeTo: .footnote)
                        .foregroundStyle(Color.mutedText)
                        .lineLimit(3)
                        .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - Showcase work (CTA between Work History and Availability)

    private var showcaseWorkButton: some View {
        Button {
            // Reuse the existing Proof-of-Work cover as the showcase entry
            // point — same purpose (visual portfolio of past jobs).
            showProofOfWork = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(theme.t("Showcase Work", "अपना काम दिखाएँ"))
                    .scaledFont(size: 15, weight: .heavy, relativeTo: .headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.shadowGrey)
                    .shadow(color: Color.shadowGrey.opacity(0.20), radius: 18, x: 0, y: 6)
            )
        }
        .buttonStyle(PressScaleStyle(scale: 0.98))
        .accessibilityLabel(theme.t("Showcase your work", "अपना काम दिखाएँ"))
    }

    // MARK: - Actions
    //
    // Branches on `isSelf`:
    //   - own profile  → "Profile" label + Edit Profile / Share buttons
    //   - other profile → "Actions" label + Hire Now / Call / WhatsApp / Save

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(isSelf ? theme.t("Profile", "प्रोफ़ाइल") : theme.t("Actions", "कार्रवाई"))

            if isSelf {
                selfActions
            } else {
                otherActions
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isSaved)
    }

    private var selfActions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(action: { showEditProfile = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                            .accessibilityHidden(true)
                        Text(theme.t("Edit Profile", "प्रोफ़ाइल संपादित करें"))
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.shadowGrey)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.shadowGrey.opacity(0.14), lineWidth: 1.5)
                    )
                }
                .buttonStyle(PressScaleStyle(scale: 0.98))
                .accessibilityLabel(theme.t("Edit profile", "प्रोफ़ाइल संपादित करें"))

                ShareLink(item: "Check out my sthapna.ai profile, \(displayName).") {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .accessibilityHidden(true)
                        Text(theme.t("Share", "शेयर करें"))
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.accent)
                    )
                    .shadow(color: theme.accent.opacity(0.30), radius: 10, x: 0, y: 5)
                }
                .accessibilityLabel(theme.t("Share profile", "प्रोफ़ाइल शेयर करें"))
            }

            // AI Interview CTA
            Button { showVoiceInterview = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 16))
                        .accessibilityHidden(true)
                    Text(theme.t("Practice AI Interview", "AI इंटरव्यू अभ्यास"))
                        .scaledFont(size: 15, weight: .semibold, relativeTo: .body)
                }
                .foregroundStyle(Color.verifiedBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.verifiedBlue.opacity(0.30), lineWidth: 1.5)
                )
            }
            .buttonStyle(PressScaleStyle(scale: 0.98))
            .accessibilityLabel("Practice AI interview in Hindi, Marathi, Telugu or English")

            // Proof of Work CTA
            Button { showProofOfWork = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 16))
                        .accessibilityHidden(true)
                    Text(theme.t("Add Proof of Work", "काम का सबूत जोड़ें"))
                        .scaledFont(size: 15, weight: .semibold, relativeTo: .body)
                }
                .foregroundStyle(Color.shadowGrey)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.shadowGrey.opacity(0.14), lineWidth: 1.5)
                )
            }
            .buttonStyle(PressScaleStyle(scale: 0.98))
            .accessibilityLabel("Add proof of work time-lapse reel")
        }
    }

    private var otherActions: some View {
        VStack(spacing: 10) {
            Button(action: { showHireAlert = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .accessibilityHidden(true)
                    Text(theme.t("Hire Now", "अभी काम दें"))
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.accent)
                )
                .shadow(color: theme.accent.opacity(0.32),
                        radius: 10, x: 0, y: 6)
            }
            .buttonStyle(PressScaleStyle(scale: 0.98))
            .accessibilityLabel(theme.t("Hire \(displayName) now", "\(displayName) को काम दें"))

            HStack(spacing: 10) {
                actionButton(
                    icon: "phone.fill", label: theme.t("Call", "कॉल करें"),
                    color: Color.shadowGrey,
                    borderColor: Color.shadowGrey.opacity(0.15)
                ) {
                    if let url = URL(string: "tel:\(phoneNumber)") { openURL(url) }
                }
                actionButton(
                    icon: "message.fill", label: theme.t("WhatsApp", "WhatsApp"),
                    color: theme.accent,
                    borderColor: theme.accent.opacity(0.25)
                ) {
                    let digits = phoneNumber.filter(\.isNumber)
                    if let url = URL(string: "https://wa.me/\(digits)") { openURL(url) }
                }
                actionButton(
                    icon: "checkmark.seal.fill", label: theme.t("Vouch", "Vouch करें"),
                    color: Color.verifiedBlue,
                    borderColor: Color.verifiedBlue.opacity(0.25)
                ) {
                    showGiveVouch = true
                }
                actionButton(
                    icon: isSaved ? "bookmark.fill" : "bookmark",
                    label: isSaved ? theme.t("Saved", "सेव हो गया") : theme.t("Save", "सेव करें"),
                    color: Color.shadowGrey,
                    borderColor: Color.shadowGrey.opacity(0.15)
                ) {
                    isSaved.toggle()
                }
                .accessibilityAddTraits(isSaved ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func actionButton(
        icon: String, label: String,
        color: Color, borderColor: Color,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: 1.5)
            )
        }
        .buttonStyle(PressScaleStyle(scale: 0.95))
        .accessibilityLabel(label)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(Color.dimText)
            .tracking(1.0)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Floating LIQUID GLASS tab bar (glass #2)

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
            selectedID: isSelf ? "profile" : "explore",
            onSelect: { id in
                switch id {
                case "home":     onHome?()
                case "explore":  onExplore?()
                case "settings": showSettings = true
                default: break  // already on profile, no-op
                }
            },
            centerIcon: "plus",
            centerAccessibilityLabel: theme.t("Create new job", "नया काम बनाएं"),
            onCenterAction: { showAddSheet = true },
        )
    }

    // MARK: - Add sheet

    private var addSheetContent: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.shadowGrey.opacity(0.18))
                .frame(width: 44, height: 5)
                .padding(.top, 10)

            Text(theme.t("New Job", "नया काम"))
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color.shadowGrey)

            Text(theme.t("Post a job and connect with nearby skilled workers in minutes.", "काम पोस्ट करें और मिनटों में आस-पास के कुशल कामगारों से जुड़ें।"))
                .font(.system(size: 14))
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                ForEach([
                    theme.t("⚡ Electrical", "⚡ इलेक्ट्रिकल"),
                    theme.t("🔧 Plumbing", "🔧 प्लम्बिंग"),
                    theme.t("🪚 Carpentry", "🪚 बढ़ईगिरी"),
                    theme.t("🎨 Painting", "🎨 पेंटिंग")
                ], id: \.self) { item in
                    Button(action: { showAddSheet = false }) {
                        HStack {
                            Text(item)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.shadowGrey)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Color.dimText)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.soft)
                        )
                    }
                    .buttonStyle(PressScaleStyle(scale: 0.98))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            Spacer()

            Button(action: { showAddSheet = false }) {
                Text(theme.t("Cancel", "रद्द करें"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.mutedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .padding(.bottom, 20)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Work-history editor sheet
//
// Presented from ProfileView when the user taps "+ Add Work History".
// Performs the network call via `onSave` so the host can refresh its
// model in one place. Dismisses itself on success; surfaces the error
// inline on failure so the user can fix and retry without losing input.

private struct WorkHistoryEditorSheet: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    let onSave: (WorkHistoryCreateRequest) async throws -> Void

    @State private var role: String = ""
    @State private var client: String = ""
    @State private var period: String = ""
    @State private var description: String = ""
    @State private var saving: Bool = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !period.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Capsule()
                        .fill(Color.shadowGrey.opacity(0.18))
                        .frame(width: 44, height: 5)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)

                    Text(theme.t("Add work history", "कार्य इतिहास जोड़ें"))
                        .scaledFont(size: 22, weight: .heavy, relativeTo: .title2)
                        .foregroundStyle(Color.shadowGrey)
                        .padding(.top, 6)

                    Text(theme.t(
                        "Add one role at a time. You can edit or remove it later.",
                        "एक समय में एक भूमिका जोड़ें। आप इसे बाद में संपादित या हटा सकते हैं।"
                    ))
                    .scaledFont(size: 13, relativeTo: .footnote)
                    .foregroundStyle(Color.mutedText)

                    field(
                        label: theme.t("Role", "भूमिका"),
                        placeholder: theme.t("e.g. Senior Electrician", "जैसे: वरिष्ठ इलेक्ट्रीशियन"),
                        text: $role,
                        required: true
                    )
                    field(
                        label: theme.t("Company or client", "कंपनी या क्लाइंट"),
                        placeholder: theme.t("e.g. Tata Projects (optional)",
                                             "जैसे: टाटा प्रोजेक्ट्स (वैकल्पिक)"),
                        text: $client,
                        required: false
                    )
                    field(
                        label: theme.t("Period", "अवधि"),
                        placeholder: theme.t("e.g. 2022 — Now or 2019 – 22",
                                             "जैसे: 2022 — अब या 2019 – 22"),
                        text: $period,
                        required: true
                    )

                    Text(theme.t("Description", "विवरण"))
                        .scaledFont(size: 12, weight: .heavy, relativeTo: .caption2)
                        .foregroundStyle(Color.dimText)
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .padding(.top, 4)
                    TextField(
                        theme.t("What did you do in this role? (optional)",
                                "इस भूमिका में आपने क्या किया? (वैकल्पिक)"),
                        text: $description,
                        axis: .vertical
                    )
                    .lineLimit(3...5)
                    .scaledFont(size: 14, relativeTo: .body)
                    .foregroundStyle(Color.shadowGrey)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.soft)
                    )

                    if let msg = errorMessage {
                        Text(msg)
                            .scaledFont(size: 12, relativeTo: .caption)
                            .foregroundStyle(Color(hex: "#E63946"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 12) {
                        Button { dismiss() } label: {
                            Text(theme.t("Cancel", "रद्द करें"))
                                .scaledFont(size: 15, weight: .heavy, relativeTo: .headline)
                                .foregroundStyle(Color.shadowGrey)
                                .frame(maxWidth: .infinity).padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.soft)
                                )
                        }
                        .disabled(saving)
                        Button { Task { await save() } } label: {
                            HStack(spacing: 8) {
                                if saving { ProgressView().tint(.white) }
                                Text(saving
                                     ? theme.t("Saving…", "सहेज रहे हैं…")
                                     : theme.t("Save", "सहेजें"))
                            }
                            .scaledFont(size: 15, weight: .heavy, relativeTo: .headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(canSave ? theme.accent : Color.dimText.opacity(0.30))
                            )
                        }
                        .disabled(!canSave || saving)
                    }
                    .padding(.top, 6)
                }
                .padding(20)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private func field(
        label: String, placeholder: String,
        text: Binding<String>, required: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .scaledFont(size: 12, weight: .heavy, relativeTo: .caption2)
                    .foregroundStyle(Color.dimText)
                    .tracking(0.6)
                    .textCase(.uppercase)
                if required {
                    Text("*").foregroundStyle(theme.accent).font(.system(size: 11, weight: .bold))
                }
            }
            TextField(placeholder, text: text)
                .scaledFont(size: 15, weight: .semibold, relativeTo: .body)
                .foregroundStyle(Color.shadowGrey)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.soft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(text.wrappedValue.isEmpty ? .clear : theme.accent.opacity(0.30),
                                        lineWidth: 1.5)
                        )
                )
        }
    }

    private func save() async {
        let r = role.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = period.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !r.isEmpty, !p.isEmpty else { return }
        saving = true
        errorMessage = nil
        defer { saving = false }
        do {
            try await onSave(WorkHistoryCreateRequest(
                role: r,
                client: client.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : client.trimmingCharacters(in: .whitespacesAndNewlines),
                periodLabel: p,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : description.trimmingCharacters(in: .whitespacesAndNewlines),
                position: 0
            ))
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                           ?? error.localizedDescription
        }
    }
}
