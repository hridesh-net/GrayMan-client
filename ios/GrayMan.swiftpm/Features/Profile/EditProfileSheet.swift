import SwiftUI
import PhotosUI
import UIKit

// Lightweight form for editing the user's own profile (PUT /workers/me).
// Driven from ProfileView's "Edit Profile" button. Only the fields the
// backend supports are exposed.
//
// Avatar picker: top of the sheet. Tapping the bubble opens a
// PhotosPicker. On pick we immediately upload to S3 + PUT the new
// avatar_url so the avatar reflects everywhere — the form save below
// only touches the text fields.

struct EditProfileSheet: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    let initial: Worker?
    let onSave: (WorkerUpdateRequest) -> Void

    @State private var name: String = ""
    @State private var trade: String = ""
    @State private var bio: String = ""
    @State private var city: String = ""
    @State private var skillTagsText: String = ""

    // Avatar state — separate from the text-field save path because the
    // image upload happens immediately on pick.
    @State private var avatarURL: String? = nil
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var uploadingAvatar: Bool = false
    @State private var avatarError: String?

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool { trimmedName.count >= 2 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.canvas.ignoresSafeArea()
                Blobs(accent: theme.accent, opacity: 0.4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        avatarSection
                        labelledField(theme.t("Name", "नाम"), text: $name, placeholder: "Ramesh Kumar")
                        labelledPicker(theme.t("Trade", "व्यापार"), selection: $trade)
                        labelledField(theme.t("City", "शहर"), text: $city, placeholder: "Mumbai")
                        labelledMultiline(theme.t("About", "बारे में"), text: $bio, placeholder: theme.t("Short intro shown on your profile", "प्रोफ़ाइल पर छोटा परिचय"))
                        labelledField(theme.t("Skills (comma-separated)", "कौशल (कॉमा-अलग)"),
                                      text: $skillTagsText,
                                      placeholder: "Wiring, Panel, Industrial")
                    }
                    .padding(20)
                }
            }
            .navigationTitle(theme.t("Edit Profile", "प्रोफ़ाइल संपादित करें"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(theme.t("Cancel", "रद्द करें")) { dismiss() }
                        .foregroundStyle(Color.mutedText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(theme.t("Save", "सेव करें")) { save() }
                        .fontWeight(.bold)
                        .foregroundStyle(isValid ? theme.accent : Color.dimText)
                        .disabled(!isValid)
                }
            }
        }
        .onAppear {
            name = initial?.name ?? ""
            trade = initial?.trade ?? Worker.allCategories.first(where: { $0 != "All" }) ?? "Electrician"
            bio = initial?.bio ?? ""
            city = initial?.location.split(separator: "·").first
                .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
            skillTagsText = (initial?.tags ?? []).joined(separator: ", ")
            avatarURL = initial?.avatarURL
        }
        .onChange(of: pickerItem) { _, newItem in
            Task { await loadAndUploadAvatar(newItem) }
        }
    }

    // MARK: - Avatar section

    private var avatarSection: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let pickedImage {
                        Image(uiImage: pickedImage)
                            .resizable().scaledToFill()
                    } else {
                        AvatarBubble(name: trimmedName.isEmpty ? "·" : trimmedName,
                                     avatarURL: avatarURL, size: 96)
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(Circle().stroke(theme.accent.opacity(0.30), lineWidth: 2))

                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(theme.accent))
                        .shadow(color: theme.accent.opacity(0.4), radius: 4, x: 0, y: 2)
                }
                .disabled(uploadingAvatar)
                .accessibilityLabel(theme.t("Change profile picture", "प्रोफ़ाइल तस्वीर बदलें"))
            }

            if uploadingAvatar {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(theme.t("Uploading photo…", "तस्वीर अपलोड हो रही है…"))
                        .scaledFont(size: 12, relativeTo: .caption)
                        .foregroundStyle(Color.mutedText)
                }
            } else if let avatarError {
                Text(avatarError)
                    .scaledFont(size: 12, relativeTo: .caption)
                    .foregroundStyle(Color(hex: "#E63946"))
            } else {
                Text(theme.t("Tap the camera to update your photo",
                             "तस्वीर बदलने के लिए कैमरा दबाइए"))
                    .scaledFont(size: 11, relativeTo: .caption2)
                    .foregroundStyle(Color.dimText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @MainActor
    private func loadAndUploadAvatar(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        avatarError = nil
        guard let data = try? await item.loadTransferable(type: Data.self),
              let ui = UIImage(data: data) else {
            avatarError = "Couldn't read that image."
            return
        }
        pickedImage = ui
        uploadingAvatar = true
        defer { uploadingAvatar = false }
        do {
            let url = try await ImageUploader.uploadAvatar(ui)
            avatarURL = url
        } catch {
            avatarError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func save() {
        let tags = skillTagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let update = WorkerUpdateRequest(
            name: trimmedName,
            trade: trade.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bio,
            skillTags: tags.isEmpty ? nil : tags,
            verifiedTagIndices: nil,
            city: city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : city,
            lat: nil,
            lng: nil
        )
        onSave(update)
        dismiss()
    }

    // MARK: - Field helpers

    private func labelledField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(label)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.words)
                .scaledFont(size: 16, relativeTo: .body)
                .foregroundStyle(Color.shadowGrey)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white)
                )
        }
    }

    private func labelledMultiline(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(label)
            TextField(placeholder, text: text, axis: .vertical)
                .scaledFont(size: 15, relativeTo: .body)
                .foregroundStyle(Color.shadowGrey)
                .lineLimit(3, reservesSpace: true)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white)
                )
        }
    }

    private func labelledPicker(_ label: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(label)
            Menu {
                ForEach(Worker.allCategories.filter { $0 != "All" }, id: \.self) { cat in
                    Button(cat) { selection.wrappedValue = cat }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue.isEmpty ? "Select…" : selection.wrappedValue)
                        .scaledFont(size: 16, relativeTo: .body)
                        .foregroundStyle(Color.shadowGrey)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.dimText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white)
                )
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .scaledFont(size: 11, weight: .heavy, relativeTo: .caption2)
            .foregroundStyle(Color.dimText)
            .tracking(1.0)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
