import CoreFoundation
import Foundation

enum VoiceSessionControl {
    static let realtimeFeatureName = "realtime_conversation"
    static let defaultPrompt = "You are Codex in a live voice conversation inside Shitter. Keep responses short, spoken, and conversational. Avoid markdown and code formatting unless explicitly asked. Before starting a handoff or any other action that may take more than a moment, briefly tell the user what you are about to do."

    static func buildPrompt(remoteServers: [(name: String, hostname: String)]) -> String {
        var serverLines = ["- \"local\" (this device)"]
        serverLines.append(contentsOf: remoteServers.map { "- \"\($0.name)\" (\($0.hostname))" })
        let serverList = serverLines.joined(separator: "\n")
        return """
        \(defaultPrompt)

        Available servers:
        \(serverList)
        When using the codex tool, you MUST specify the "server" parameter. \
        IMPORTANT: To list servers, list sessions, or read session history, you MUST use server="local". \
        The "local" server has special tools that can see sessions across ALL connected servers in one call. \
        Remote servers do NOT have these tools — never ask a remote server to list sessions. \
        Use a remote server name ONLY to run coding tasks, shell commands, or file operations on that machine.
        """
    }

    private static let appGroupSuite = ShitterPalette.appGroupSuite
    private static let endRequestKey = "voice_session.end_request_token"
    static let endRequestDarwinNotification = "io.latitudes.shitter.voice_session.end_request"

    static func requestEnd() {
        let token = UUID().uuidString
        UserDefaults(suiteName: appGroupSuite)?.set(token, forKey: endRequestKey)
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = CFNotificationName(endRequestDarwinNotification as CFString)
        CFNotificationCenterPostNotification(center, name, nil, nil, true)
    }

    static func pendingEndRequestToken(after lastSeenToken: String?) -> String? {
        guard let token = UserDefaults(suiteName: appGroupSuite)?.string(forKey: endRequestKey),
              !token.isEmpty,
              token != lastSeenToken else {
            return nil
        }
        return token
    }
}
