import ActivityKit
import Foundation

struct CodexTurnAttributes: ActivityAttributes {
    let threadId: String
    let model: String
    let cwd: String
    let startDate: Date
    let prompt: String

    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case thinking
            case toolCall
            case completed
            case failed
        }

        var phase: Phase
        var toolName: String?
        var elapsedSeconds: Int
        var toolCallCount: Int
        var activeThreadCount: Int
        var outputSnippet: String?
        var pushCount: Int?
        var fileChangeCount: Int
        var contextPercent: Int
    }
}
