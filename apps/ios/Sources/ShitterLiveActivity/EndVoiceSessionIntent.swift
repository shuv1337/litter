import AppIntents

struct EndVoiceSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End Voice Session"
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        VoiceSessionControl.requestEnd()
        return .result()
    }
}
