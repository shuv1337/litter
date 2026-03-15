import SwiftUI
import Combine

extension Notification.Name {
    static let themeDidChange = Notification.Name("io.latitudes.shitter.themeDidChange")
}

/// Thread-safe store for resolved themes, accessible from any isolation context.
/// ThemeManager writes here; ShitterTheme reads from here.
final class ThemeStore: Sendable {
    static let shared = ThemeStore()

    nonisolated(unsafe) var light: ResolvedTheme = .defaultLight
    nonisolated(unsafe) var dark: ResolvedTheme = .defaultDark
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let appGroupSuite = ShitterPalette.appGroupSuite

    @Published private(set) var lightTheme: ResolvedTheme = .defaultLight
    @Published private(set) var darkTheme: ResolvedTheme = .defaultDark
    @Published private(set) var themeVersion: Int = 0
    @Published private(set) var themeIndex: [ThemeIndexEntry] = []

    var selectedLightSlug: String {
        get { UserDefaults.standard.string(forKey: "selectedLightTheme") ?? "codex-light" }
        set { UserDefaults.standard.set(newValue, forKey: "selectedLightTheme") }
    }

    var selectedDarkSlug: String {
        get { UserDefaults.standard.string(forKey: "selectedDarkTheme") ?? "codex-dark" }
        set { UserDefaults.standard.set(newValue, forKey: "selectedDarkTheme") }
    }

    var lightThemes: [ThemeIndexEntry] {
        themeIndex.filter { $0.type == .light }
    }

    var darkThemes: [ThemeIndexEntry] {
        themeIndex.filter { $0.type == .dark }
    }

    private var definitionCache: [String: ThemeDefinition] = [:]

    private init() {
        loadThemeIndex()
        lightTheme = loadAndResolve(selectedLightSlug) ?? .defaultLight
        darkTheme = loadAndResolve(selectedDarkSlug) ?? .defaultDark
        syncStore()
        writeToSharedDefaults()
    }

    private func syncStore() {
        ThemeStore.shared.light = lightTheme
        ThemeStore.shared.dark = darkTheme
    }

    // MARK: - Public API

    func selectLightTheme(_ slug: String) {
        selectedLightSlug = slug
        lightTheme = loadAndResolve(slug) ?? .defaultLight
        syncStore()
        themeVersion += 1
        writeToSharedDefaults()
        notifyHighlighter()
    }

    func selectDarkTheme(_ slug: String) {
        selectedDarkSlug = slug
        darkTheme = loadAndResolve(slug) ?? .defaultDark
        syncStore()
        themeVersion += 1
        writeToSharedDefaults()
        notifyHighlighter()
    }

    private func notifyHighlighter() {
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
    }

    func resolvedTheme(for colorScheme: ColorScheme) -> ResolvedTheme {
        colorScheme == .dark ? darkTheme : lightTheme
    }

    // MARK: - Loading

    private func loadThemeIndex() {
        guard let url = Bundle.main.url(forResource: "theme-manifest", withExtension: "json") else {
            NSLog("[ThemeManager] theme-manifest.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            themeIndex = try JSONDecoder().decode([ThemeIndexEntry].self, from: data)
            NSLog("[ThemeManager] Loaded %d themes from manifest", themeIndex.count)
        } catch {
            NSLog("[ThemeManager] Failed to load theme manifest: %@", error.localizedDescription)
        }
    }

    private func loadAndResolve(_ slug: String) -> ResolvedTheme? {
        guard let def = loadDefinition(slug) else { return nil }
        return ResolvedTheme(slug: slug, definition: def)
    }

    private func loadDefinition(_ slug: String) -> ThemeDefinition? {
        if let cached = definitionCache[slug] { return cached }
        guard let url = Bundle.main.url(forResource: slug, withExtension: "json") else {
            NSLog("[ThemeManager] Theme file not found: %@", slug)
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let def = try JSONDecoder().decode(ThemeDefinition.self, from: data)
            definitionCache[slug] = def
            return def
        } catch {
            NSLog("[ThemeManager] Failed to parse theme %@: %@", slug, error.localizedDescription)
            return nil
        }
    }

    // MARK: - Shared UserDefaults for Live Activity widget

    private func writeToSharedDefaults() {
        guard let shared = UserDefaults(suiteName: Self.appGroupSuite) else { return }
        let pairs: [(String, String, String)] = [
            ("surface", lightTheme.surface, darkTheme.surface),
            ("surfaceLight", lightTheme.surfaceLight, darkTheme.surfaceLight),
            ("textPrimary", lightTheme.textPrimary, darkTheme.textPrimary),
            ("textSecondary", lightTheme.textSecondary, darkTheme.textSecondary),
            ("textMuted", lightTheme.textMuted, darkTheme.textMuted),
            ("textBody", lightTheme.textBody, darkTheme.textBody),
            ("textSystem", lightTheme.textSystem, darkTheme.textSystem),
            ("accent", lightTheme.accent, darkTheme.accent),
            ("accentStrong", lightTheme.accentStrong, darkTheme.accentStrong),
            ("border", lightTheme.border, darkTheme.border),
            ("separator", lightTheme.separator, darkTheme.separator),
            ("danger", lightTheme.danger, darkTheme.danger),
            ("success", lightTheme.success, darkTheme.success),
            ("warning", lightTheme.warning, darkTheme.warning),
            ("textOnAccent", lightTheme.textOnAccent, darkTheme.textOnAccent),
            ("codeBackground", lightTheme.codeBackground, darkTheme.codeBackground),
        ]
        for (key, light, dark) in pairs {
            shared.set(light, forKey: "theme.light.\(key)")
            shared.set(dark, forKey: "theme.dark.\(key)")
        }
    }
}
