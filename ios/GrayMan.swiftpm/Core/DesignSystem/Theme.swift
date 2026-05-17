import SwiftUI

// MARK: - Language

enum AppLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case hindi   = "hi"
    case marathi = "mr"
    case telugu  = "te"
    case tamil   = "ta"
    case kannada = "kn"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .hindi:   return "हिंदी"
        case .marathi: return "मराठी"
        case .telugu:  return "తెలుగు"
        case .tamil:   return "தமிழ்"
        case .kannada: return "ಕನ್ನಡ"
        }
    }

    var shortCode: String {
        switch self {
        case .english: return "EN"
        case .hindi:   return "हि"
        case .marathi: return "म"
        case .telugu:  return "తె"
        case .tamil:   return "த"
        case .kannada: return "ಕ"
        }
    }
}

// MARK: - App-wide theme
//
// @Observable (iOS 17+) makes this class auto-track property reads inside
// view `body`. Update `accent` or `language` anywhere and every view re-renders.

@Observable
final class AppTheme {
    var accent: Color = Swatch.all[0].color
    var accentHex: String = Swatch.all[0].hex
    var swatchName: String = Swatch.all[0].name

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "app_language") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "app_language") ?? ""
        language = AppLanguage(rawValue: saved) ?? .english
    }

    // Existing 2-arg calls keep working. Add mr/te/ta/kn as needed — omitted = falls back to `en`.
    func t(_ en: String, _ hi: String,
           mr: String? = nil, te: String? = nil,
           ta: String? = nil, kn: String? = nil) -> String {
        switch language {
        case .english: return en
        case .hindi:   return hi
        case .marathi: return mr ?? en
        case .telugu:  return te ?? en
        case .tamil:   return ta ?? en
        case .kannada: return kn ?? en
        }
    }

    func set(_ s: Swatch) {
        accent = s.color
        accentHex = s.hex
        swatchName = s.name
    }

}

// MARK: - Swatches (mirrors the React SWATCHES table)

struct Swatch: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let hex: String
    var color: Color { Color(hex: hex) }

    static let all: [Swatch] = [
        Swatch(name: "Burnt Peach", hex: "#ee6c4d"),
        Swatch(name: "Coral Glow",  hex: "#f38d68"),
        Swatch(name: "Crimson",     hex: "#E63946"),
        Swatch(name: "Terracotta",  hex: "#C1440E"),
        Swatch(name: "Amber",       hex: "#F4A261"),
        Swatch(name: "Golden",      hex: "#E9B44C"),
        Swatch(name: "Forest",      hex: "#2D6A4F"),
        Swatch(name: "Sage",        hex: "#52796F"),
        Swatch(name: "Ocean",       hex: "#118AB2"),
        Swatch(name: "Navy",        hex: "#1D3557"),
        Swatch(name: "Violet",      hex: "#7B2D8B"),
        Swatch(name: "Magenta",     hex: "#C9184A"),
        Swatch(name: "Teal",        hex: "#264653"),
        Swatch(name: "Indigo",      hex: "#4361EE"),
        Swatch(name: "Mint",        hex: "#06D6A0"),
        Swatch(name: "Slate",       hex: "#4A5568"),
    ]
}

// MARK: - Color from hex string

extension Color {
    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(
            red:   Double((v >> 16) & 0xff) / 255,
            green: Double((v >> 8)  & 0xff) / 255,
            blue:  Double( v        & 0xff) / 255
        )
    }
}
