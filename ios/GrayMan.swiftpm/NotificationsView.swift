import SwiftUI

// Notifications inbox — currently the only kind is `reel_analysis_ready`,
// which proposes a profile update extracted from the worker's reel. The user
// reviews the proposal then either accepts (profile updates + verified badge)
// or rejects (no change). See app/agents/reel_agent.py for what's emitted.

struct NotificationsView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    /// Called after an accept that flipped is_verified or applied skills, so
    /// the host (ProfileView) can refresh its worker.
    let onProfileChanged: () -> Void

    @State private var model = NotificationsViewModel()
    @State private var selected: NotificationDTO?

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            Blobs(accent: theme.accent, opacity: 0.35)

            VStack(spacing: 0) {
                navBar
                content
            }
        }
        .task { await model.load() }
        .sheet(item: $selected) { notif in
            ReelAnalysisReviewSheet(
                notification: notif,
                onAccept: { await accept(notif) },
                onReject: { await reject(notif) }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.shadowGrey)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.soft))
            }
            .accessibilityLabel("Close notifications")
            Spacer()
            Text(theme.t("Notifications", "सूचनाएँ"))
                .scaledFont(size: 16, weight: .heavy, relativeTo: .headline)
                .foregroundStyle(Color.shadowGrey)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            VStack { Spacer(); ProgressView().tint(theme.accent); Spacer() }
        case .failed(let msg):
            failureView(msg)
        case .loaded:
            if model.notifications.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.notifications) { notif in
                            row(for: notif)
                                .onTapGesture {
                                    Task { await model.markRead(notif.id) }
                                    selected = notif
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .refreshable { await model.load() }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 44))
                .foregroundStyle(Color.dimText)
            Text(theme.t("You're all caught up", "सब कुछ देखा हो गया"))
                .scaledFont(size: 16, weight: .heavy, relativeTo: .headline)
                .foregroundStyle(Color.shadowGrey)
            Text(theme.t("Updates from the AI agents will show here.",
                         "AI एजेंट्स के अपडेट यहाँ दिखेंगे।"))
                .scaledFont(size: 12, relativeTo: .caption)
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private func failureView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color(hex: "#E63946"))
            Text(theme.t("Couldn't load notifications", "सूचनाएँ लोड नहीं हो पाईं"))
                .scaledFont(size: 15, weight: .semibold, relativeTo: .subheadline)
            Text(msg)
                .scaledFont(size: 12, relativeTo: .caption)
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button { Task { await model.load() } } label: {
                Text(theme.t("Try again", "दोबारा कोशिश"))
                    .scaledFont(size: 14, weight: .bold, relativeTo: .body)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(theme.accent))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
    }

    private func row(for notif: NotificationDTO) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.accent.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon(for: notif.kind))
                    .foregroundStyle(theme.accent)
                    .font(.system(size: 18, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title(for: notif))
                    .scaledFont(size: 14, weight: .heavy, relativeTo: .subheadline)
                    .foregroundStyle(Color.shadowGrey)
                    .lineLimit(1)
                Text(subtitle(for: notif))
                    .scaledFont(size: 12, relativeTo: .caption)
                    .foregroundStyle(Color.mutedText)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            badge(for: notif)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.soft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(notif.status == "unread" ? theme.accent.opacity(0.25) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title(for: notif)). \(subtitle(for: notif))")
    }

    @ViewBuilder
    private func badge(for notif: NotificationDTO) -> some View {
        switch notif.status {
        case "unread":
            Circle().fill(theme.accent).frame(width: 9, height: 9)
        case "accepted":
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.verifiedBlue)
        case "rejected":
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.dimText)
        default:
            EmptyView()
        }
    }

    private func icon(for kind: String) -> String {
        switch kind {
        case "reel_analysis_ready": return "sparkles"
        default:                    return "bell.fill"
        }
    }

    private func title(for notif: NotificationDTO) -> String {
        switch notif.kind {
        case "reel_analysis_ready":
            return theme.t("Reel analysis ready", "रील विश्लेषण तैयार")
        default:
            return notif.kind.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func subtitle(for notif: NotificationDTO) -> String {
        switch notif.kind {
        case "reel_analysis_ready":
            let count = notif.payload.reelAnalysis?.skills.count ?? 0
            return theme.t(
                count > 0 ? "Review \(count) extracted skills + verification" : "Review extracted profile data",
                count > 0 ? "\(count) कौशल और सत्यापन देखें" : "निकाला हुआ डेटा देखें"
            )
        default:
            return ""
        }
    }

    private func accept(_ notif: NotificationDTO) async {
        await model.accept(notif.id)
        if case .accepted = model.lastDecision { onProfileChanged() }
        selected = nil
    }

    private func reject(_ notif: NotificationDTO) async {
        await model.reject(notif.id)
        selected = nil
    }
}

// MARK: - Review sheet

private struct ReelAnalysisReviewSheet: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    let notification: NotificationDTO
    let onAccept: () async -> Void
    let onReject: () async -> Void

    @State private var isBusy = false

    private var proposal: ReelAnalysisProposalDTO? { notification.payload.reelAnalysis }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        if let p = proposal {
                            tradeRow(p)
                            skillsBlock(p)
                            evidenceBlock(p)
                            verificationBlock(p)
                            if let bio = p.bio, !bio.isEmpty { bioBlock(bio) }
                        } else {
                            Text(theme.t("This notification has no reviewable data.",
                                         "इस सूचना में समीक्षा-योग्य कोई डेटा नहीं है।"))
                                .scaledFont(size: 13, relativeTo: .footnote)
                                .foregroundStyle(Color.mutedText)
                        }
                    }
                    .padding(20)
                }
                if notification.status != "accepted" && notification.status != "rejected" {
                    actionBar
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(theme.accent)
                    .font(.system(size: 20, weight: .bold))
                Text(theme.t("Profile update proposed", "प्रोफ़ाइल अपडेट प्रस्तावित"))
                    .scaledFont(size: 18, weight: .heavy, relativeTo: .title3)
                    .foregroundStyle(Color.shadowGrey)
                Spacer()
            }
            Text(theme.t(
                "Our AI analysed your reel and proposes the following changes. Accept to update your profile.",
                "हमारे AI ने आपकी रील देखी। ये बदलाव प्रस्तावित हैं। स्वीकार करने पर प्रोफ़ाइल बदलेगी।"
            ))
            .scaledFont(size: 12, relativeTo: .caption)
            .foregroundStyle(Color.mutedText)
        }
    }

    private func tradeRow(_ p: ReelAnalysisProposalDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(theme.t("Trade & experience", "ट्रेड और अनुभव"))
            HStack {
                Text(p.trade ?? "—")
                    .scaledFont(size: 16, weight: .heavy, relativeTo: .headline)
                Spacer()
                if let y = p.years, y > 0 {
                    Text("\(y) yrs")
                        .scaledFont(size: 13, weight: .semibold, relativeTo: .footnote)
                        .foregroundStyle(Color.mutedText)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.soft))
        }
    }

    private func skillsBlock(_ p: ReelAnalysisProposalDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(theme.t("Skills proposed", "प्रस्तावित कौशल"))
            FlowLayout(spacing: 8) {
                ForEach(p.skills, id: \.self) { sk in
                    Text(sk)
                        .scaledFont(size: 12, weight: .semibold, relativeTo: .caption)
                        .foregroundStyle(Color.shadowGrey)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(theme.accent.opacity(0.12)))
                }
            }
        }
    }

    @ViewBuilder
    private func evidenceBlock(_ p: ReelAnalysisProposalDTO) -> some View {
        if !p.skillEvidence.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle(theme.t("Evidence from reel", "रील से प्रमाण"))
                VStack(spacing: 0) {
                    ForEach(p.skillEvidence) { ev in
                        HStack {
                            Text(ev.skill)
                                .scaledFont(size: 13, weight: .semibold, relativeTo: .footnote)
                                .foregroundStyle(Color.shadowGrey)
                            Spacer()
                            evidencePill(ev.evidence)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        if ev.id != p.skillEvidence.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.soft))
            }
        }
    }

    private func evidencePill(_ kind: String) -> some View {
        let label: String
        let color: Color
        switch kind {
        case "shown":      label = theme.t("Shown", "दिखाया");        color = Color.verifiedBlue
        case "described":  label = theme.t("Described", "बताया");     color = theme.accent
        default:           label = theme.t("Inferred", "अनुमानित");  color = Color.dimText
        }
        return Text(label)
            .scaledFont(size: 11, weight: .heavy, relativeTo: .caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    @ViewBuilder
    private func verificationBlock(_ p: ReelAnalysisProposalDTO) -> some View {
        if let v = p.verification {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle(theme.t("Trade match", "ट्रेड मिलान"))
                HStack(spacing: 14) {
                    VouchScoreRing(score: v.tradeMatchScore, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        if v.tradeMatchScore >= 60 {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.seal.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, Color.verifiedBlue)
                                Text(theme.t("Eligible for verified badge",
                                             "सत्यापित बैज के योग्य"))
                                    .scaledFont(size: 12, weight: .heavy, relativeTo: .caption)
                                    .foregroundStyle(Color.verifiedBlue)
                            }
                        } else {
                            Text(theme.t("Below verified-badge threshold",
                                         "बैज सीमा से कम"))
                                .scaledFont(size: 12, weight: .heavy, relativeTo: .caption)
                                .foregroundStyle(Color.dimText)
                        }
                        if !v.flags.isEmpty {
                            Text(v.flags.joined(separator: " · "))
                                .scaledFont(size: 11, relativeTo: .caption2)
                                .foregroundStyle(Color(hex: "#E63946"))
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.soft))
            }
        }
    }

    private func bioBlock(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(theme.t("Bio suggestion", "बायो सुझाव"))
            Text(bio)
                .scaledFont(size: 13, relativeTo: .footnote)
                .foregroundStyle(Color.shadowGrey)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.soft))
        }
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s.uppercased())
            .scaledFont(size: 11, weight: .heavy, relativeTo: .caption2)
            .foregroundStyle(Color.dimText)
            .tracking(1.2)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                Task { isBusy = true; await onReject(); isBusy = false }
            } label: {
                Text(theme.t("Reject", "अस्वीकार"))
                    .scaledFont(size: 15, weight: .heavy, relativeTo: .headline)
                    .foregroundStyle(Color.shadowGrey)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.soft))
            }
            .disabled(isBusy)
            Button {
                Task { isBusy = true; await onAccept(); isBusy = false }
            } label: {
                HStack(spacing: 8) {
                    if isBusy {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "checkmark")
                    }
                    Text(theme.t("Accept", "स्वीकार"))
                }
                .scaledFont(size: 15, weight: .heavy, relativeTo: .headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 14).fill(theme.accent))
            }
            .disabled(isBusy)
        }
        .padding(.horizontal, 20).padding(.bottom, 24).padding(.top, 8)
        .background(Color.canvas)
    }
}

// MARK: - View model

@Observable @MainActor
final class NotificationsViewModel {
    enum LoadState: Equatable { case idle, loading, loaded, failed(String) }
    enum Decision: Equatable { case none, accepted, rejected }

    private(set) var state: LoadState = .idle
    private(set) var notifications: [NotificationDTO] = []
    private(set) var unreadCount: Int = 0
    private(set) var lastDecision: Decision = .none

    func load() async {
        state = .loading
        do {
            let resp = try await WorkerService.shared.fetchNotifications()
            notifications = resp.notifications
            unreadCount = resp.unreadCount
            state = .loaded
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func markRead(_ id: String) async {
        guard let idx = notifications.firstIndex(where: { $0.id == id }) else { return }
        guard notifications[idx].status == "unread" else { return }
        _ = try? await WorkerService.shared.markNotificationRead(id: id)
        if let updated = try? await WorkerService.shared.fetchNotifications() {
            notifications = updated.notifications
            unreadCount = updated.unreadCount
        }
    }

    func accept(_ id: String) async {
        do {
            _ = try await WorkerService.shared.acceptNotification(id: id)
            lastDecision = .accepted
            await load()
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func reject(_ id: String) async {
        do {
            _ = try await WorkerService.shared.rejectNotification(id: id)
            lastDecision = .rejected
            await load()
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
