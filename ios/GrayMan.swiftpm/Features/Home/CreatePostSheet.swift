import SwiftUI
import PhotosUI
import UIKit

// Compose-and-publish a new feed post. Body is required (max 2 000
// chars per backend validator); image is optional. We capture the
// user's last-known location at submit time so the backend's
// geo-filter can rank this post in nearby feeds.

struct CreatePostSheet: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    let onPosted: (PostDTO) -> Void

    @State private var postBody: String = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var image: UIImage?
    @State private var submitting: Bool = false
    @State private var errorMessage: String?

    private var trimmedBody: String { postBody.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSubmit: Bool { !trimmedBody.isEmpty && !submitting }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(theme.t("Share what you've been working on.",
                                 "बताइए आप क्या काम कर रहे हैं।"))
                        .scaledFont(size: 13, relativeTo: .footnote)
                        .foregroundStyle(Color.mutedText)

                    TextField(
                        theme.t("Wrote new wiring for a 3-BHK in Andheri today. Clean panel work.",
                                "आज अंधेरी में 3-BHK की नई वायरिंग पूरी की। पैनल का काम साफ़।"),
                        text: $postBody, axis: .vertical,
                    )
                    .lineLimit(5...12)
                    .scaledFont(size: 15, relativeTo: .body)
                    .foregroundStyle(Color.shadowGrey)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.soft)
                    )

                    imagePickerRow

                    if let errorMessage {
                        Text(errorMessage)
                            .scaledFont(size: 12, relativeTo: .caption)
                            .foregroundStyle(Color(hex: "#E63946"))
                    }
                }
                .padding(20)
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle(theme.t("New Post", "नया पोस्ट"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(theme.t("Cancel", "रद्द करें")) { dismiss() }
                        .foregroundStyle(Color.mutedText)
                        .disabled(submitting)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 6) {
                            if submitting { ProgressView().controlSize(.small) }
                            Text(submitting
                                 ? theme.t("Posting…", "पोस्ट हो रहा…")
                                 : theme.t("Post", "पोस्ट"))
                        }
                        .fontWeight(.bold)
                    }
                    .foregroundStyle(canSubmit ? theme.accent : Color.dimText)
                    .disabled(!canSubmit)
                }
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            Task {
                guard let item = newItem,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let ui = UIImage(data: data) else {
                    return
                }
                imageData = data
                image = ui
            }
        }
    }

    @ViewBuilder
    private var imagePickerRow: some View {
        if let image {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Button {
                    self.image = nil
                    self.imageData = nil
                    self.pickerItem = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white, .black.opacity(0.5))
                }
                .padding(10)
                .accessibilityLabel(theme.t("Remove image", "तस्वीर हटाएं"))
            }
        } else {
            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 10) {
                    Image(systemName: "photo")
                        .font(.system(size: 16))
                    Text(theme.t("Add photo (optional)", "तस्वीर जोड़ें (वैकल्पिक)"))
                        .scaledFont(size: 14, weight: .semibold, relativeTo: .footnote)
                }
                .foregroundStyle(Color.shadowGrey)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.shadowGrey.opacity(0.16),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                )
            }
        }
    }

    @MainActor
    private func submit() async {
        submitting = true
        errorMessage = nil
        defer { submitting = false }

        var imageURL: String?
        if let image {
            do {
                imageURL = try await ImageUploader.uploadPostImage(image)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                return
            }
        }

        let fix = LocationService.shared.lastKnown
        do {
            let dto = try await WorkerService.shared.createPost(
                body: trimmedBody, imageURL: imageURL, lat: fix?.lat, lng: fix?.lng,
            )
            onPosted(dto)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
