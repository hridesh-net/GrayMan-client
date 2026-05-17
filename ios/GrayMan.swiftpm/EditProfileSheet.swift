import SwiftUI

// Lightweight form for editing the user's own profile (PUT /workers/me).
// Driven from ProfileView's "Edit Profile" button. Only the fields the
// backend supports are exposed.

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

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool { trimmedName.count >= 2 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.canvas.ignoresSafeArea()
                Blobs(accent: theme.accent, opacity: 0.4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
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
