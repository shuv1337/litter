import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8) & 0xFF) / 255
        let b = CGFloat(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Central Theme

enum ShitterTheme {
    static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }

    static let accent        = adaptive(light: "#4A4A4A", dark: "#B0B0B0")
    static let accentStrong  = adaptive(light: "#00995D", dark: "#00FF9C")
    static let textPrimary   = adaptive(light: "#1A1A1A", dark: "#FFFFFF")
    static let textSecondary = adaptive(light: "#6B6B6B", dark: "#888888")
    static let textMuted     = adaptive(light: "#9E9E9E", dark: "#555555")
    static let textBody      = adaptive(light: "#2D2D2D", dark: "#E0E0E0")
    static let textSystem    = adaptive(light: "#3A4A3F", dark: "#C6D0CA")
    static let surface       = adaptive(light: "#F2F2F7", dark: "#1A1A1A")
    static let surfaceLight  = adaptive(light: "#E5E5EA", dark: "#2A2A2A")
    static let border        = adaptive(light: "#D1D1D6", dark: "#333333")
    static let separator     = adaptive(light: "#E0E0E0", dark: "#1E1E1E")
    static let danger        = adaptive(light: "#D32F2F", dark: "#FF5555")
    static let success       = adaptive(light: "#2E7D32", dark: "#6EA676")
    static let warning       = adaptive(light: "#E65100", dark: "#E2A644")
    static let textOnAccent  = adaptive(light: "#FFFFFF", dark: "#0D0D0D")
    static let codeBackground = adaptive(light: "#F0F0F5", dark: "#111111")

    static let overlayScrim: Color = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.5)
            : UIColor.black.withAlphaComponent(0.3)
    })

    static var gradientColors: [Color] {
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        if isDark {
            return [Color(hex: "#0A0A0A"), Color(hex: "#0F0F0F"), Color(hex: "#080808")]
        } else {
            return [Color(hex: "#FFFFFF"), Color(hex: "#F8F8FA"), Color(hex: "#F5F5F7")]
        }
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var headerScrim: [Color] {
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        if isDark {
            return [.black.opacity(0.5), .black.opacity(0.2), .clear]
        } else {
            return [.white.opacity(0.7), .white.opacity(0.3), .clear]
        }
    }
}

enum FontFamilyOption: String, CaseIterable, Identifiable {
    case mono = "mono"
    case system = "system"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mono: return "Monospaced"
        case .system: return "System (SF Pro)"
        }
    }

    var isMono: Bool { self == .mono }
}

enum ShitterFont {
    private static let berkeleyRegular = "BerkeleyMono-Regular"
    private static let berkeleyBold = "BerkeleyMono-Bold"

    static var storedFamily: FontFamilyOption {
        let raw = UserDefaults.standard.string(forKey: "fontFamily") ?? "mono"
        return FontFamilyOption(rawValue: raw) ?? .mono
    }

    static var markdownFontName: String {
        switch storedFamily {
        case .mono:
            return preferredMonoFontName(weight: .regular) ?? "SFMono-Regular"
        case .system:
            return ".AppleSystemUIFont"
        }
    }

    static func styled(
        _ style: Font.TextStyle,
        weight: Font.Weight = .regular,
        scale: CGFloat = 1.0
    ) -> Font {
        let pointSize = UIFont.preferredFont(forTextStyle: style.uiTextStyle).pointSize * scale
        return styled(size: pointSize, weight: weight, relativeTo: style)
    }

    static func styled(size: CGFloat, weight: Font.Weight = .regular, scale: CGFloat = 1.0) -> Font {
        styled(size: size * scale, weight: weight, relativeTo: nil)
    }

    static func monospaced(
        _ style: Font.TextStyle,
        weight: Font.Weight = .regular,
        scale: CGFloat = 1.0
    ) -> Font {
        let pointSize = UIFont.preferredFont(forTextStyle: style.uiTextStyle).pointSize * scale
        return monoFont(size: pointSize, weight: weight, relativeTo: style)
    }

    static func monospaced(size: CGFloat, weight: Font.Weight = .regular, scale: CGFloat = 1.0) -> Font {
        monoFont(size: size * scale, weight: weight, relativeTo: nil)
    }

    private static func styled(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle?) -> Font {
        if storedFamily.isMono {
            return monoFont(size: size, weight: weight, relativeTo: style)
        }
        if let style {
            return .system(style, weight: weight)
        }
        return .system(size: size, weight: weight)
    }

    private static func monoFont(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle?) -> Font {
        if let fontName = preferredMonoFontName(weight: weight) {
            if let style {
                return .custom(fontName, size: size, relativeTo: style)
            }
            return .custom(fontName, size: size)
        }
        if let style {
            return .system(style, design: .monospaced, weight: weight)
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    private static func preferredMonoFontName(weight: Font.Weight) -> String? {
        let preferred = isBold(weight: weight) ? berkeleyBold : berkeleyRegular
        if UIFont(name: preferred, size: 12) != nil {
            return preferred
        }
        if UIFont(name: berkeleyRegular, size: 12) != nil {
            return berkeleyRegular
        }
        return nil
    }

    private static func isBold(weight: Font.Weight) -> Bool {
        switch weight {
        case .semibold, .bold, .heavy, .black:
            return true
        default:
            return false
        }
    }

    static func uiMonoFont(size: CGFloat, bold: Bool = false) -> UIFont {
        let name = bold
            ? preferredMonoFontName(weight: .bold) ?? "SFMono-Bold"
            : preferredMonoFontName(weight: .regular) ?? "SFMono-Regular"
        return UIFont(name: name, size: size) ?? UIFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    static func sampleFont(family: FontFamilyOption, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if family.isMono {
            return monoFont(size: size, weight: weight, relativeTo: nil)
        }
        return .system(size: size, weight: weight)
    }
}

private extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
}

func serverIconName(for source: ServerSource) -> String {
    switch source {
    case .local: return "iphone"
    case .bonjour: return "desktopcomputer"
    case .ssh: return "terminal"
    case .tailscale: return "network"
    case .manual: return "server.rack"
    }
}

func abbreviateHomePath(_ path: String) -> String {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "~" }
    for basePrefix in ["/Users", "/home"] {
        let prefix = basePrefix + "/"
        guard trimmed.hasPrefix(prefix) else { continue }
        let remainder = trimmed.dropFirst(prefix.count)
        guard let slashIndex = remainder.firstIndex(of: "/") else { return "~" }
        return "~" + remainder[slashIndex...]
    }
    return trimmed
}

func relativeDate(_ timestamp: Int64) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}

// MARK: - Glass Effect Availability Wrappers

struct GlassRectModifier: ViewModifier {
    let cornerRadius: CGFloat
    var tint: Color?

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                content.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
            } else {
                content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content
                .background(ShitterTheme.surfaceLight.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke((tint ?? ShitterTheme.border).opacity(0.4), lineWidth: 1)
                )
        }
    }
}

struct GlassRoundedRectModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(ShitterTheme.surfaceLight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

struct GlassCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(ShitterTheme.surfaceLight)
                .clipShape(Capsule())
        }
    }
}

struct GlassCircleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .circle)
        } else {
            content
                .background(ShitterTheme.surfaceLight)
                .clipShape(Circle())
        }
    }
}
