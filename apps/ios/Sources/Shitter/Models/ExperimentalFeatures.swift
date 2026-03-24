import Foundation
import Observation

enum ShitterFeature: String, CaseIterable, Identifiable {
    case realtimeVoice = "realtime_voice"
    case generativeUI = "generative_ui"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .realtimeVoice: return "Realtime"
        case .generativeUI: return "Generative UI"
        }
    }

    var description: String {
        switch self {
        case .realtimeVoice: return "Show the realtime voice launcher on the home screen."
        case .generativeUI: return "Show interactive widgets, diagrams, and charts inline in conversations. Requires starting a new thread."
        }
    }

    var defaultEnabled: Bool {
        switch self {
        case .realtimeVoice: return true
        case .generativeUI: return false
        }
    }
}

@Observable
final class ExperimentalFeatures {
    static let shared = ExperimentalFeatures()

    @ObservationIgnored private let key = "shitter.experimentalFeatures"
    private var overrides: [String: Bool]

    private init() {
        overrides = UserDefaults.standard.dictionary(forKey: key) as? [String: Bool] ?? [:]
    }

    private func persistOverrides() {
        UserDefaults.standard.set(overrides, forKey: key)
    }

    func isEnabled(_ feature: ShitterFeature) -> Bool {
        overrides[feature.rawValue] ?? feature.defaultEnabled
    }

    func setEnabled(_ feature: ShitterFeature, _ value: Bool) {
        var map = overrides
        if value == feature.defaultEnabled {
            map.removeValue(forKey: feature.rawValue)
        } else {
            map[feature.rawValue] = value
        }
        overrides = map
        persistOverrides()
    }
}
