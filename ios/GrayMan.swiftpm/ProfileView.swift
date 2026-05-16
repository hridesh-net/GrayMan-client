import SwiftUI

// Maps to S3 in the React mockup: profile dashboard with the floating
// "liquid glass" tab bar. The two glass elements are the profile card
// and the tab bar — everything else is flat, just like the mockup.

struct ProfileView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.openURL) private var openURL

    var userName: String = "Ramesh Kumar"
    var worker: Worker? = nil                          // non-nil → viewing another worker
    var voiceInterviewService: VoiceInterviewService = MockVoiceInterviewService()
    var onBack: (() -> Void)? = nil                    // shown only when viewing a worker
    var onExplore: (() -> Void)? = nil                 // tap the Explore tab to navigate

    private var isSelf: Bool { worker == nil }

    @State private var availability: Int = 0
    @State private var activeTab: Int = 0
    @State private var selectedSkills: Set<Int> = [0, 1]
    @State private var isSaved: Bool = false
    @State private var showHireAlert: Bool = false
    @State private var showAddSheet: Bool = false
    @State private var showVoiceInterview: Bool = false
    @State private var showProofOfWork: Bool = false
    @State private var showGiveVouch: Bool = false
    @State private var showSettings: Bool = false

    private let phoneNumber = "+919876543210"

    // MARK: - Derived display data (worker or self defaults)

    private var displayName: String { worker?.name ?? userName }
    private var displayTrade: String { worker?.trade ?? "Electrician · 8 yrs exp" }
    private var displayLocation: String {
        let raw = worker?.location ?? "Mumbai"
        return raw.split(separator: "·").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? raw
    }
    private var displayJobs: String { worker.map { "\($0.jobs)" } ?? "48" }
    private var displayRating: String { worker?.rating ?? "4.9" }
    private var displayVouchScore: Int { worker?.vouchScore ?? 73 }
    private var skills: [String] { worker?.tags ?? ["Wiring", "Installation", "Repair", "Maintenance", "Circuit", "Equipment"] }
    private var verifiedSkillIndices: Set<Int> { worker?.verifiedTagIndices ?? [0, 1] }

    private var initials: String {
        if let worker { return worker.initials }
        let parts = displayName.split(separator: " ")
        let chars = parts.compactMap(\.first).map(String.init)
        return String(chars.prefix(2).joined()).uppercased()
    }

    private var avatarGradientEnd: Color {
        if let worker { return Color(hex: worker.gradientEndHex) }
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
                        profileCard
                        skillsSection
                        workStatsSection
                        availabilitySection
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
        .alert("Send hire request?", isPresented: $showHireAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Send") { /* wire to backend later */ }
        } message: {
            Text("\(displayName.split(separator: " ").first.map(String.init) ?? "They") will be notified on WhatsApp")
        }
        .sheet(isPresented: $showAddSheet) {
            addSheetContent
        }
        .sheet(isPresented: $showGiveVouch) {
            if let w = worker {
                GiveVouchSheet(worker: w)
            }
        }
        .fullScreenCover(isPresented: $showVoiceInterview) {
            VoiceInterviewView(trade: displayTrade, service: voiceInterviewService)
        }
        .fullScreenCover(isPresented: $showProofOfWork) {
            ProofOfWorkView()
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
        .sensoryFeedback(.selection, trigger: activeTab)
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
                Text("GrayMan")
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
                .accessibilityLabel(theme.t("Live", "लाइव"))
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
                        Image(systemName: "checkmark.seal.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.verifiedBlue)
                            .font(.system(size: 16))
                            .accessibilityLabel(theme.t("Verified", "सत्यापित"))
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
                    .onTapGesture { if !isSelf { showGiveVouch = true } }
                    .accessibilityHint(isSelf ? "" : "Tap to give a vouch")
            }
            .padding(.bottom, 18)

            Divider().background(Color.shadowGrey.opacity(0.1))

            HStack(spacing: 0) {
                stat(displayJobs, theme.t("Jobs", "काम"))
                Divider().frame(height: 32).background(Color.shadowGrey.opacity(0.1))
                stat("₹500", theme.t("Per Day", "प्रति दिन"))
                Divider().frame(height: 32).background(Color.shadowGrey.opacity(0.1))
                stat("\(displayRating)★", theme.t("Rating", "रेटिंग"))
                Divider().frame(height: 32).background(Color.shadowGrey.opacity(0.1))
                stat("8yr", theme.t("Exp", "अनुभव"))
            }
            .padding(.top, 16)
        }
        .padding(22)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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

    private var skillsSection: some View {
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
    }

    // MARK: - Work stats

    private var workStatsSection: some View {
        let rows: [[(String, String)]] = [
            [(displayJobs, theme.t("Jobs Done", "काम पूरे")),     ("₹42K", theme.t("Monthly", "मासिक"))],
            [(displayRating, theme.t("Rating", "रेटिंग")),       ("38",   theme.t("Repeat Clients", "नियमित ग्राहक"))]
        ]

        return VStack(alignment: .leading, spacing: 14) {
            sectionLabel(theme.t("Work Stats", "काम के आंकड़े"))
            VStack(spacing: 0) {
                ForEach(0..<rows.count, id: \.self) { r in
                    HStack(spacing: 0) {
                        cell(rows[r][0].0, rows[r][0].1, trailingDivider: true)
                            .padding(.trailing, 20)
                        cell(rows[r][1].0, rows[r][1].1, trailingDivider: false)
                            .padding(.leading, 20)
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.shadowGrey.opacity(0.07))
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    private func cell(_ value: String, _ label: String, trailingDivider: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.black)
                .tracking(-0.8)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.dimText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .overlay(alignment: .trailing) {
            if trailingDivider {
                Rectangle()
                    .fill(Color.shadowGrey.opacity(0.07))
                    .frame(width: 1)
            }
        }
    }

    // MARK: - Availability

    private var availabilitySection: some View {
        let labels = [
            theme.t("Available", "उपलब्ध"),
            theme.t("Busy", "व्यस्त"),
            theme.t("Away", "अनुपस्थित"),
        ]

        return VStack(alignment: .leading, spacing: 12) {
            sectionLabel(theme.t("Availability", "उपलब्धता"))
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    let bg: Color = (i == 0) ? theme.accent : (i == 1) ? Color.mutedText : Color.dimText
                    Button(action: { availability = i }) {
                        Text(labels[i])
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(availability == i ? .white : Color.dimText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(availability == i ? bg : .clear)
                                    .shadow(color: availability == i ? .black.opacity(0.12) : .clear,
                                            radius: 4, x: 0, y: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(labels[i])
                    .accessibilityAddTraits(availability == i ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.soft)
            )
        }
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
                Button(action: { /* TODO: edit profile sheet */ }) {
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

                ShareLink(item: "Check out my GrayMan profile, \(displayName).") {
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
        HStack(spacing: 0) {
            tabItem(idx: 1, icon: "house.fill",
                    label: theme.t("Home", "होम"))
            tabItem(idx: 2, icon: "square.grid.2x2.fill",
                    label: theme.t("Explore", "खोजें"),
                    action: onExplore)
            addButton
            tabItem(idx: 0, icon: "person.crop.circle.fill",
                    label: theme.t("Profile", "प्रोफ़ाइल"),
                    forceActive: isSelf)
            tabItem(idx: 4, icon: "gearshape.fill",
                    label: theme.t("Settings", "सेटिंग्स"),
                    action: { showSettings = true })
        }
        .padding(.horizontal, 8)
        .frame(height: 68)
        // iOS 26 native liquid glass — locked to light mode via the
        // root WindowGroup's .preferredColorScheme(.light), so the glass
        // tone stays consistent regardless of system appearance.
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 8)
    }

    private func tabItem(
        idx: Int,
        icon: String,
        label: String,
        action: (() -> Void)? = nil,
        forceActive: Bool = false
    ) -> some View {
        let active = forceActive || activeTab == idx
        return Button {
            if let action { action() } else { activeTab = idx }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 19))
                    .foregroundStyle(active ? theme.accent : Color.shadowGrey.opacity(0.35))
                    .accessibilityHidden(true)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(active ? theme.accent : Color.dimText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }

    private var addButton: some View {
        Button(action: { showAddSheet = true }) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(theme.accent))
                .shadow(color: theme.accent.opacity(0.42), radius: 8, x: 0, y: 4)
                .accessibilityHidden(true)
        }
        .buttonStyle(PressScaleStyle(scale: 0.92))
        .accessibilityLabel(theme.t("Create new job", "नया काम बनाएं"))
        .accessibilityHint("Open the job creation sheet")
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
