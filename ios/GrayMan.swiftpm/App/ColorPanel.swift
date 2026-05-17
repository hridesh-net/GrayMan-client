import SwiftUI

// Floating palette FAB + slide-up swatch panel. Lives as a top-level
// overlay in GrayManApp so it floats above every screen.

struct ColorPanel: View {
    @Environment(AppTheme.self) private var theme
    @State private var open = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Panel
            panel
                .padding(.horizontal, 16)
                .padding(.bottom, open ? 80 : 16)
                .opacity(open ? 1 : 0)
                .allowsHitTesting(open)
                .animation(.spring(duration: 0.35, bounce: 0.30), value: open)

            // FAB toggle
            Button { open.toggle() } label: {
                Image(systemName: open ? "xmark" : "paintpalette.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(open ? Color.shadowGrey : theme.accent))
                    .shadow(color: theme.accent.opacity(0.40), radius: 10, x: 0, y: 4)
                    .accessibilityHidden(true)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 100)   // sits above floating tab bar on profile
            .accessibilityLabel(open ? "Close colour palette" : "Open colour palette")
        }
    }

    private var panel: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Accent color")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.shadowGrey)
                    Text("\(theme.swatchName) · \(theme.accentHex)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dimText)
                }
                Spacer()
                Circle()
                    .fill(theme.accent)
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.20), radius: 4, x: 0, y: 2)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8),
                spacing: 10
            ) {
                ForEach(Swatch.all) { s in
                    let isOn = s.hex == theme.accentHex
                    Button { theme.set(s) } label: {
                        Circle()
                            .fill(s.color)
                            .overlay(
                                Group {
                                    if isOn {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundStyle(.white)
                                    }
                                }
                            )
                            .overlay(Circle().stroke(.white, lineWidth: isOn ? 2.5 : 0))
                            .scaleEffect(isOn ? 1.15 : 1)
                            .shadow(
                                color: s.color.opacity(isOn ? 0.40 : 0.20),
                                radius: isOn ? 6 : 3, x: 0, y: 2
                            )
                            .animation(.spring(duration: 0.25), value: isOn)
                            .accessibilityHidden(true)
                    }
                    .buttonStyle(.plain)
                    .aspectRatio(1, contentMode: .fit)
                    .accessibilityLabel(s.name)
                    .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 12)
        )
        .sensoryFeedback(.selection, trigger: theme.accentHex)
    }
}
