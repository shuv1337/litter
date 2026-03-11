import SwiftUI
import UIKit
import Highlightr

struct CodeBlockView: View {
    let language: String
    let code: String
    var fontSize: CGFloat = 13
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if !language.isEmpty {
                    Text(language)
                        .font(.system(.caption2, weight: .medium))
                        .foregroundColor(ShitterTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(.caption2))
                        .foregroundColor(copied ? ShitterTheme.accent : ShitterTheme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)

            ScrollView(.horizontal, showsIndicators: false) {
                Group {
                    if let highlighted = CodeBlockHighlighter.shared.highlight(code: code, language: language, fontSize: fontSize) {
                        Text(highlighted)
                            .textSelection(.enabled)
                    } else {
                        Text(code)
                            .font(ShitterFont.monospaced(size: fontSize))
                            .foregroundColor(ShitterTheme.textBody)
                            .textSelection(.enabled)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(ShitterTheme.codeBackground.opacity(0.8))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .modifier(GlassRectModifier(cornerRadius: 8))
    }
}

@MainActor
private final class CodeBlockHighlighter {
    static let shared = CodeBlockHighlighter()

    private let darkHighlightr: Highlightr? = {
        let h = Highlightr()
        h?.setTheme(to: "atom-one-dark")
        return h
    }()
    private let lightHighlightr: Highlightr? = {
        let h = Highlightr()
        h?.setTheme(to: "atom-one-light")
        return h
    }()
    private var cache: [Int: AttributedString] = [:]

    func highlight(code: String, language: String, fontSize: CGFloat) -> AttributedString? {
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        let key = cacheKey(code: code, language: language, isDark: isDark, fontSize: fontSize)
        if let cached = cache[key] {
            return cached
        }
        guard let highlightr = isDark ? darkHighlightr : lightHighlightr else { return nil }
        let normalized = language.trimmingCharacters(in: .whitespacesAndNewlines)
        let attributed = highlightr.highlight(code, as: normalized.isEmpty ? nil : normalized)
        guard let attributed else { return nil }
        let scaled = NSMutableAttributedString(attributedString: attributed)
        let monoFont = ShitterFont.uiMonoFont(size: fontSize)
        scaled.enumerateAttribute(.font, in: NSRange(location: 0, length: scaled.length)) { value, range, _ in
            if let existing = value as? UIFont {
                let traits = existing.fontDescriptor.symbolicTraits
                if traits.contains(.traitBold) {
                    scaled.addAttribute(.font, value: ShitterFont.uiMonoFont(size: fontSize, bold: true), range: range)
                } else {
                    scaled.addAttribute(.font, value: monoFont, range: range)
                }
            }
        }
        guard let rendered = try? AttributedString(scaled, including: \.uiKit) else {
            return nil
        }
        cache[key] = rendered
        if cache.count > 512 {
            cache.removeAll(keepingCapacity: true)
        }
        return rendered
    }

    private func cacheKey(code: String, language: String, isDark: Bool, fontSize: CGFloat) -> Int {
        var hasher = Hasher()
        hasher.combine(language.trimmingCharacters(in: .whitespacesAndNewlines))
        hasher.combine(code)
        hasher.combine(isDark)
        hasher.combine(fontSize)
        return hasher.finalize()
    }
}

#if DEBUG
#Preview("Code Block") {
    ZStack {
        ShitterTheme.backgroundGradient.ignoresSafeArea()
        CodeBlockView(
            language: "swift",
            code: """
            struct SchedulerGate {
                let repoJobs = 100_000

                func canEnqueue(_ pending: Int) -> Bool {
                    pending < repoJobs
                }
            }
            """
        )
        .padding(20)
    }
}
#endif
