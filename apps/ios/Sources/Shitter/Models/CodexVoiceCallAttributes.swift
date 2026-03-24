import ActivityKit
import Foundation

struct CodexVoiceCallAttributes: ActivityAttributes {
    let threadId: String
    let threadTitle: String
    let model: String
    let startDate: Date

    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case connecting
            case listening
            case thinking
            case speaking
            case error
        }

        var phase: Phase
        var routeLabel: String
        var transcriptText: String?
        var lastError: String?
    }
}
