import SwiftUI

// MARK: - Floating glass tab bar
//
// Shared between Home and Profile (and any future top-level screen).
// Renders 4 tab items split around a central round "+" action button,
// inside the iOS-26 `.glassEffect()` capsule.
//
// Callers describe their tabs as `[TabItem]`. The bar marks `selected`
// as active and calls `onSelect` when any item is tapped. The centre
// "+" button is mandatory — it's part of the visual identity — and
// fires `onCenterAction` independently.

struct FloatingTabBar: View {
    /// One slot in the bar. `accessibilityLabel` defaults to `label`
    /// but callers can override (e.g. "Notifications. 3 unread.").
    struct TabItem: Identifiable {
        let id: String
        let icon: String
        let label: String
        let accessibilityLabel: String?

        init(id: String, icon: String, label: String,
             accessibilityLabel: String? = nil) {
            self.id = id
            self.icon = icon
            self.label = label
            self.accessibilityLabel = accessibilityLabel
        }
    }

    let items: [TabItem]
    let selectedID: String
    let onSelect: (String) -> Void
    let centerIcon: String
    let centerAccessibilityLabel: String
    let onCenterAction: () -> Void

    @Environment(AppTheme.self) private var theme

    /// Tabs render 2 on the left of the centre "+" and the rest on the
    /// right. We split exactly down the middle of the supplied list
    /// (caller is responsible for ordering — usually Home / Explore on
    /// the left, Profile / Settings on the right).
    private var leftItems: [TabItem]  { Array(items.prefix(items.count / 2)) }
    private var rightItems: [TabItem] { Array(items.dropFirst(items.count / 2)) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(leftItems) { item in tab(item) }
            centerButton
            ForEach(rightItems) { item in tab(item) }
        }
        .padding(.horizontal, 8)
        .frame(height: 68)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 8)
    }

    @ViewBuilder
    private func tab(_ item: TabItem) -> some View {
        let active = item.id == selectedID
        Button {
            onSelect(item.id)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.icon)
                    .font(.system(size: 19))
                    .foregroundStyle(active ? theme.accent : Color.shadowGrey.opacity(0.35))
                    .accessibilityHidden(true)
                Text(item.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(active ? theme.accent : Color.dimText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.accessibilityLabel ?? item.label)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }

    private var centerButton: some View {
        Button(action: onCenterAction) {
            Image(systemName: centerIcon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(theme.accent))
                .shadow(color: theme.accent.opacity(0.42), radius: 8, x: 0, y: 4)
                .accessibilityHidden(true)
        }
        .buttonStyle(PressScaleStyle(scale: 0.92))
        .accessibilityLabel(centerAccessibilityLabel)
    }
}
