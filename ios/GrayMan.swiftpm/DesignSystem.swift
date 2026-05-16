import SwiftUI

// MARK: - Brand palette
//
// Mapped 1:1 from the React mockup. Keeping them as static Color extensions
// means any view can write Color.burntPeach instead of repeating the rgb values.

extension Color {
    static let shadowGrey = Color(red: 39/255,  green: 41/255,  blue: 50/255)   // #272932
    static let burntPeach = Color(red: 238/255, green: 108/255, blue: 77/255)   // #ee6c4d
    static let coralGlow  = Color(red: 243/255, green: 141/255, blue: 104/255)  // #f38d68
    static let canvas     = Color(red: 250/255, green: 250/255, blue: 249/255)  // #FAFAF9
    static let soft       = Color(red: 242/255, green: 240/255, blue: 239/255)  // #F2F0EF
    static let mutedText  = Color(red: 107/255, green: 110/255, blue: 122/255)  // #6B6E7A
    static let dimText    = Color(red: 157/255, green: 161/255, blue: 173/255)  // #9DA1AD
    static let verifiedBlue = Color(red: 29/255,  green: 161/255, blue: 242/255) // Twitter-style verified badge
}

// MARK: - Decorative gradient blobs
//
// SwiftUI note: a `View` is a value type whose `body` describes what to draw.
// `ZStack` overlays its children; `.overlay(alignment:)` pins a child to one
// corner of its parent's bounds — easier than computing offsets manually.

struct Blobs: View {
    var accent: Color = .burntPeach     // default for any caller that doesn't pass one
    var opacity: Double = 0.8

    var body: some View {
        ZStack {
            Color.clear
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accent.opacity(0.20), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 170
                            )
                        )
                        .frame(width: 340, height: 340)
                        .blur(radius: 40)
                        .offset(x: 80, y: -80)
                }

            Color.clear
                .overlay(alignment: .bottomLeading) {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accent.opacity(0.12), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .blur(radius: 32)
                        .offset(x: -60, y: 60)
                }
        }
        .opacity(opacity)
        .allowsHitTesting(false)        // don't intercept taps
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Scaled font (Dynamic Type-aware)
//
// `.font(.system(size:))` uses a fixed point size and does NOT honour
// the user's Dynamic Type setting. This modifier wraps the size in
// `@ScaledMetric` so it grows/shrinks with the chosen text style while
// preserving the design's intended base size.

extension View {
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle = .body
    ) -> some View {
        modifier(ScaledFontModifier(size: size, weight: weight, style: style))
    }
}

private struct ScaledFontModifier: ViewModifier {
    let weight: Font.Weight
    @ScaledMetric private var size: CGFloat

    init(size: CGFloat, weight: Font.Weight, style: Font.TextStyle) {
        self.weight = weight
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

// MARK: - Press-scale button style
//
// In the React mockup, buttons used onMouseDown/onMouseUp to scale on press.
// In SwiftUI we write a ButtonStyle once and reuse it everywhere via
// `.buttonStyle(PressScaleStyle())`. configuration.isPressed flips while held.

struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - FlowLayout (wraps tag chips onto new lines)
//
// SwiftUI's HStack doesn't wrap. iOS 16 introduced the Layout protocol which
// lets us write a minimal flow layout. Used by the Skills section in S3.

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
