import SwiftUI
import PhotosUI
import UIKit

// MARK: - Onboarding avatar step
//
// Shown once during onboarding, immediately after NameEntry. Optional —
// the "Skip" button advances without uploading anything. If the user
// picks a photo we upload it eagerly so they don't sit on a spinner at
// the next step.

struct AvatarPickerView: View {
    @Environment(AppTheme.self) private var theme
    let name: String
    let goBack: () -> Void
    let goNext: () -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var picked: UIImage?
    @State private var uploading: Bool = false
    @State private var uploaded: Bool = false
    @State private var errorMessage: String?

    private var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            Blobs(accent: theme.accent, opacity: 0.6)

            VStack(alignment: .leading, spacing: 0) {
                Button(action: goBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.shadowGrey)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.soft)
                        )
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .accessibilityLabel(theme.t("Back", "वापस"))

                VStack(alignment: .leading, spacing: 8) {
                    Text(theme.t("Add a photo,\n\(firstName)?", "एक तस्वीर\nजोड़ें, \(firstName)?"))
                        .scaledFont(size: 30, weight: .heavy, relativeTo: .largeTitle)
                        .foregroundStyle(Color.shadowGrey)
                        .tracking(-1.0)
                        .lineSpacing(2)
                    Text(theme.t("Clients are 2× more likely to hire workers with a real photo.",
                                 "असली तस्वीर वाले कारीगरों को क्लाइंट 2 गुना ज़्यादा हायर करते हैं।"))
                        .scaledFont(size: 15, relativeTo: .subheadline)
                        .foregroundStyle(Color.mutedText)
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)
                .padding(.bottom, 28)

                Spacer(minLength: 0)

                avatarBubble
                    .frame(maxWidth: .infinity)

                if let errorMessage {
                    Text(errorMessage)
                        .scaledFont(size: 12, weight: .semibold, relativeTo: .caption)
                        .foregroundStyle(Color(hex: "#E63946"))
                        .padding(.horizontal, 28)
                        .padding(.top, 14)
                } else if uploaded {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.accent)
                        Text(theme.t("Photo saved", "तस्वीर सेव हो गई"))
                            .scaledFont(size: 13, weight: .semibold, relativeTo: .footnote)
                            .foregroundStyle(theme.accent)
                    }
                    .padding(.top, 14)
                }

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                        HStack(spacing: 10) {
                            if uploading { ProgressView().tint(.white) }
                            Image(systemName: picked == nil ? "camera.fill" : "checkmark")
                                .font(.system(size: 14, weight: .bold))
                            Text(picked == nil
                                 ? theme.t("Choose Photo", "तस्वीर चुनें")
                                 : theme.t("Change Photo", "तस्वीर बदलें"))
                                .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.accent)
                        )
                        .shadow(color: theme.accent.opacity(0.36), radius: 12, x: 0, y: 6)
                    }
                    .disabled(uploading)

                    Button(action: goNext) {
                        Text(picked == nil
                             ? theme.t("Skip for now", "अभी छोड़ें")
                             : theme.t("Continue", "जारी रखें"))
                            .scaledFont(size: 15, weight: .semibold, relativeTo: .body)
                            .foregroundStyle(picked == nil ? Color.mutedText : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(picked == nil ? Color.clear : Color.shadowGrey)
                            )
                    }
                    .buttonStyle(PressScaleStyle(scale: 0.98))
                    .disabled(uploading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            Task { await loadAndUpload(newItem) }
        }
    }

    private var avatarBubble: some View {
        ZStack {
            Circle()
                .fill(Color.soft)
                .frame(width: 160, height: 160)
                .overlay(Circle().stroke(theme.accent.opacity(0.20), lineWidth: 2))
            if let picked {
                Image(uiImage: picked)
                    .resizable().scaledToFill()
                    .frame(width: 156, height: 156)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.dimText)
            }
        }
        .accessibilityHidden(true)
    }

    @MainActor
    private func loadAndUpload(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        errorMessage = nil
        uploaded = false
        guard let data = try? await item.loadTransferable(type: Data.self),
              let ui = UIImage(data: data) else {
            errorMessage = "Couldn't read that image."
            return
        }
        picked = ui
        uploading = true
        defer { uploading = false }
        do {
            _ = try await ImageUploader.uploadAvatar(ui)
            uploaded = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
