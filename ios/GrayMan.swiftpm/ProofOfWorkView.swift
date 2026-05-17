import PhotosUI
import SwiftUI

// Proof-of-Work (Time-Lapse) Reels — doc §3B.
//
// Workers capture "Day 1 → Done" photo sessions. Each captured photo is
// uploaded to S3 as a `kind=photo` ShowcaseItem (see app/routers/showcase.py)
// so they survive across devices and can later be compiled server-side into
// a single time-lapse video.
//
// Data sources, in priority order:
//   1. Backend showcase items (WorkerService.fetchShowcase(workerID:kind:))
//   2. If the worker has none yet, fall back to a Hindi/English-localized
//      sample timeline so the screen is never blank.

struct ProofOfWorkView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var items: [ShowcaseItemDTO] = []
    @State private var isLoading: Bool = true
    @State private var lastError: String?

    @State private var showAddSheet: Bool = false
    @State private var showComingSoon: Bool = false

    // For the placeholder when the worker hasn't uploaded anything yet.
    private var sampleSessions: [POWSession] { POWSession.samples(theme: theme) }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            Blobs(accent: theme.accent, opacity: 0.45)

            VStack(spacing: 0) {
                navBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        header
                        if isLoading && items.isEmpty {
                            ProgressView()
                                .tint(theme.accent)
                                .padding(.vertical, 30)
                        } else if items.isEmpty {
                            sampleTimeline    // placeholder
                        } else {
                            uploadedTimeline
                            if items.count >= 2 {
                                compileButton
                            }
                        }
                        addButton
                        if let msg = lastError {
                            Text(msg)
                                .scaledFont(size: 12, relativeTo: .caption)
                                .foregroundStyle(Color(hex: "#E63946"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddProgressSheet(
                onUploadComplete: { newItem in
                    items.insert(newItem, at: 0)
                    showAddSheet = false
                },
                dayLabel: theme.t("Day \(items.count + 1)", "दिन \(items.count + 1)")
            )
            .environment(theme)
        }
        .alert(theme.t("Coming soon", "जल्द आ रहा है"), isPresented: $showComingSoon) {
            Button(theme.t("OK", "ठीक है"), role: .cancel) { }
        } message: {
            Text(theme.t(
                "Time-lapse compilation runs server-side once the FFmpeg job is wired. Your uploaded photos are already saved.",
                "FFmpeg जॉब के तैयार होते ही टाइम-लैप्स कंपाइलेशन सर्वर पर चलेगा। आपकी अपलोड की गई फ़ोटो सेव हो चुकी हैं।"
            ))
        }
        .task { await loadItems() }
    }

    // MARK: - Data loading

    private func loadItems() async {
        isLoading = true
        defer { isLoading = false }
        guard let workerID = TokenStore.shared.workerID else { return }
        do {
            items = try await WorkerService.shared.fetchShowcase(
                workerID: workerID, kind: "photo"
            )
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription
                       ?? error.localizedDescription
        }
    }

    // MARK: - Nav

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.shadowGrey)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.soft))
                    .accessibilityHidden(true)
            }
            .accessibilityLabel(theme.t("Close", "बंद करें"))
            Spacer()
            Text(theme.t("Proof of Work", "काम का सबूत"))
                .scaledFont(size: 16, weight: .heavy, relativeTo: .headline)
                .foregroundStyle(Color.shadowGrey)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(theme.t("Day 1 → Done", "दिन 1 → पूरा"))
                .scaledFont(size: 26, weight: .heavy, relativeTo: .largeTitle)
                .foregroundStyle(Color.shadowGrey)
            Text(theme.t(
                "Document each stage of a project. We'll compile your photos into a time-lapse reel clients can trust.",
                "प्रोजेक्ट का हर चरण दर्ज करें। हम आपकी फ़ोटो से एक टाइम-लैप्स रील बनाएंगे जिस पर ग्राहक भरोसा कर सकें।"
            ))
            .scaledFont(size: 14, relativeTo: .body)
            .foregroundStyle(Color.mutedText)
            .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sample timeline (placeholder; never shown once worker has items)

    private var sampleTimeline: some View {
        VStack(spacing: 0) {
            ForEach(Array(sampleSessions.enumerated()), id: \.element.id) { idx, session in
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle().fill(theme.accent).frame(width: 36, height: 36)
                            Text(session.emoji).font(.system(size: 17))
                        }
                        if idx < sampleSessions.count - 1 {
                            Rectangle()
                                .fill(theme.accent.opacity(0.20))
                                .frame(width: 2).frame(minHeight: 60)
                        }
                    }
                    .frame(width: 36)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(session.dayLabel)
                                .scaledFont(size: 11, weight: .heavy, relativeTo: .caption2)
                                .foregroundStyle(theme.accent).tracking(0.8)
                            Spacer()
                            Text(session.date)
                                .scaledFont(size: 12, relativeTo: .caption)
                                .foregroundStyle(Color.dimText)
                        }
                        Text(session.caption)
                            .scaledFont(size: 15, weight: .semibold, relativeTo: .body)
                            .foregroundStyle(Color.shadowGrey)
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.soft).frame(height: 130)
                            VStack(spacing: 6) {
                                Image(systemName: "photo")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color.dimText)
                                Text(theme.t("Sample · \(session.date)", "नमूना · \(session.date)"))
                                    .scaledFont(size: 12, relativeTo: .caption)
                                    .foregroundStyle(Color.dimText)
                            }
                        }
                    }
                    .padding(.bottom, idx < sampleSessions.count - 1 ? 20 : 4)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .overlay(alignment: .topTrailing) {
            Text(theme.t("Sample", "नमूना"))
                .scaledFont(size: 10, weight: .heavy, relativeTo: .caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.dimText))
                .padding(12)
        }
    }

    // MARK: - Real (uploaded) timeline

    private var uploadedTimeline: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle().fill(theme.accent).frame(width: 36, height: 36)
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                        if idx < items.count - 1 {
                            Rectangle()
                                .fill(theme.accent.opacity(0.20))
                                .frame(width: 2).frame(minHeight: 60)
                        }
                    }
                    .frame(width: 36)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(theme.t("Day \(items.count - idx)", "दिन \(items.count - idx)"))
                                .scaledFont(size: 11, weight: .heavy, relativeTo: .caption2)
                                .foregroundStyle(theme.accent).tracking(0.8)
                            Spacer()
                        }
                        Text(item.title)
                            .scaledFont(size: 15, weight: .semibold, relativeTo: .body)
                            .foregroundStyle(Color.shadowGrey)
                        if let desc = item.description, !desc.isEmpty {
                            Text(desc)
                                .scaledFont(size: 13, relativeTo: .footnote)
                                .foregroundStyle(Color.mutedText)
                                .lineLimit(3)
                        }
                        AsyncImage(url: URL(string: item.mediaURL)) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                            case .failure:
                                Image(systemName: "photo")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color.dimText)
                            default:
                                ProgressView().tint(theme.accent)
                            }
                        }
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .background(Color.soft)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.bottom, idx < items.count - 1 ? 20 : 4)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }

    // MARK: - Compile

    private var compileButton: some View {
        Button { showComingSoon = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "film.stack").font(.system(size: 18))
                Text(theme.t("Compile Time-Lapse Reel", "टाइम-लैप्स रील बनाएं"))
                    .scaledFont(size: 15, weight: .bold, relativeTo: .body)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.shadowGrey, theme.accent],
                        startPoint: .leading, endPoint: .trailing
                    ))
            )
            .shadow(color: theme.accent.opacity(0.34), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PressScaleStyle())
    }

    // MARK: - Add button

    private var addButton: some View {
        Button { showAddSheet = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "camera.fill").font(.system(size: 16))
                Text(theme.t("Add Today's Progress", "आज की प्रगति जोड़ें"))
                    .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
            }
            .foregroundStyle(theme.accent)
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.accent.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(PressScaleStyle())
    }
}

// MARK: - Add-progress sheet — photo picker + upload

private struct AddProgressSheet: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    let onUploadComplete: (ShowcaseItemDTO) -> Void
    let dayLabel: String

    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var caption: String = ""
    @State private var description: String = ""
    @State private var status: Status = .composing
    @State private var errorMessage: String?

    enum Status: Equatable { case composing, uploading, failed }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.shadowGrey.opacity(0.18))
                .frame(width: 44, height: 5)
                .padding(.top, 10)

            Text(dayLabel)
                .scaledFont(size: 22, weight: .heavy, relativeTo: .title2)
                .foregroundStyle(Color.shadowGrey)

            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.soft)
                        .frame(height: 200)
                    if let data = imageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable().scaledToFill()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(theme.accent.opacity(0.70))
                            Text(theme.t("Tap to take / choose photo",
                                         "फ़ोटो लेने / चुनने के लिए टैप करें"))
                                .scaledFont(size: 14, relativeTo: .body)
                                .foregroundStyle(Color.dimText)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    guard let newItem,
                          let data = try? await newItem.loadTransferable(type: Data.self)
                    else { return }
                    imageData = data
                }
            }

            TextField(
                theme.t("Title (e.g. Day 1 — Site assessment)",
                        "शीर्षक (जैसे: दिन 1 — साइट का आकलन)"),
                text: $caption
            )
            .scaledFont(size: 15, relativeTo: .body)
            .foregroundStyle(Color.shadowGrey)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.soft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(caption.isEmpty ? .clear : theme.accent.opacity(0.30), lineWidth: 1.5)
                    )
            )
            .padding(.horizontal, 24)

            TextField(
                theme.t("Description (optional)", "विवरण (वैकल्पिक)"),
                text: $description
            )
            .scaledFont(size: 14, relativeTo: .body)
            .foregroundStyle(Color.shadowGrey)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.soft))
            .padding(.horizontal, 24)

            Button {
                Task { await upload() }
            } label: {
                HStack(spacing: 10) {
                    if status == .uploading {
                        ProgressView().tint(.white)
                    }
                    Text(status == .uploading
                         ? theme.t("Uploading…", "अपलोड हो रहा है…")
                         : theme.t("Save Progress", "प्रगति सेव करें"))
                        .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
                }
                .foregroundStyle(canSave ? .white : Color.dimText)
                .frame(maxWidth: .infinity).padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(canSave ? theme.accent : Color.dimText.opacity(0.30))
                )
            }
            .buttonStyle(PressScaleStyle())
            .disabled(!canSave || status == .uploading)
            .padding(.horizontal, 24)

            if let msg = errorMessage {
                Text(msg)
                    .scaledFont(size: 12, relativeTo: .caption)
                    .foregroundStyle(Color(hex: "#E63946"))
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private var canSave: Bool {
        !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && imageData != nil
    }

    private func upload() async {
        guard let data = imageData else { return }
        let title = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        status = .uploading
        errorMessage = nil
        do {
            // 1. Mint a presigned PUT URL for a JPEG.
            let presigned = try await WorkerService.shared.requestShowcaseUploadURL(
                kind: "photo", contentType: "image/jpeg"
            )
            // 2. PUT bytes directly to S3. ATS allows local-network HTTP +
            //    public HTTPS, so the S3 presigned URL works.
            var req = URLRequest(url: URL(string: presigned.uploadURL)!)
            req.httpMethod = "PUT"
            req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
            let (_, response) = try await URLSession.shared.upload(for: req, from: data)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw NSError(domain: "ShowcaseUpload", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "S3 upload failed",
                ])
            }
            // 3. Tell backend the bytes landed; it persists the row.
            let item = try await WorkerService.shared.createShowcaseItem(
                ShowcaseCreateRequest(
                    kind: "photo",
                    title: title,
                    description: desc.isEmpty ? nil : desc,
                    s3Key: presigned.key,
                    thumbnailURL: nil,
                    durationSeconds: nil,
                    position: 0
                )
            )
            onUploadComplete(item)
        } catch {
            status = .failed
            errorMessage = (error as? LocalizedError)?.errorDescription
                           ?? error.localizedDescription
        }
    }
}

// MARK: - Sample data (placeholder timeline)

struct POWSession: Identifiable, Sendable {
    let id: UUID = UUID()
    let dayLabel: String
    let caption: String
    let emoji: String
    let date: String

    static func samples(theme: AppTheme) -> [POWSession] {
        [
            POWSession(
                dayLabel: theme.t("Day 1", "दिन 1"),
                caption: theme.t("Site assessment & planning",
                                 "साइट का आकलन और योजना"),
                emoji: "📐",
                date: theme.t("12 May", "12 मई")
            ),
            POWSession(
                dayLabel: theme.t("Day 2", "दिन 2"),
                caption: theme.t("Panel installation started",
                                 "पैनल इंस्टॉलेशन शुरू"),
                emoji: "⚡",
                date: theme.t("13 May", "13 मई")
            ),
            POWSession(
                dayLabel: theme.t("Day 3", "दिन 3"),
                caption: theme.t("Wiring 60% complete",
                                 "वायरिंग 60% पूरी"),
                emoji: "🔌",
                date: theme.t("14 May", "14 मई")
            ),
        ]
    }
}
