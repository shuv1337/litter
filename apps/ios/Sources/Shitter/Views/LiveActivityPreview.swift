#if DEBUG
import SwiftUI

private let allCards: [(String, CodexTurnAttributes.ContentState, String)] = [
    (
        "explore the project structure and find bugs",
        .init(phase: .thinking, elapsedSeconds: 35, toolCallCount: 9, activeThreadCount: 1,
              outputSnippet: "Looking at the project structure to understand the codebase...",
              fileChangeCount: 4, contextPercent: 42),
        "0:35"
    ),
    (
        "add push notification support for iOS",
        .init(phase: .toolCall, toolName: "write_file", elapsedSeconds: 252, toolCallCount: 12, activeThreadCount: 1,
              outputSnippet: "I'll create the push proxy service using Cloudflare Durable Objects...",
              fileChangeCount: 3, contextPercent: 67),
        "4:12"
    ),
    (
        "list the files in the repo root",
        .init(phase: .completed, elapsedSeconds: 408, toolCallCount: 5, activeThreadCount: 1,
              outputSnippet: "Here are the files in the repository root: README.md, package.json...",
              fileChangeCount: 0, contextPercent: 23),
        "6:48"
    ),
    (
        "deploy to production",
        .init(phase: .failed, elapsedSeconds: 3, toolCallCount: 0, activeThreadCount: 1,
              fileChangeCount: 0, contextPercent: 8),
        "0:03"
    ),
]

private struct AdaptiveTimer: View {
    let text: String
    let active: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text)
            .font(.system(size: 15, design: .monospaced))
            .monospacedDigit()
            .fontWeight(.regular)
            .foregroundStyle(
                colorScheme == .dark
                    ? Color.white.opacity(active ? 0.7 : 0.45)
                    : Color.black.opacity(active ? 0.6 : 0.35)
            )
    }
}

private struct CardStack: View {
    let cards = allCards

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                    LockScreenCardView(
                        prompt: card.0,
                        model: "gpt-5.4",
                        cwd: "/Users/dev/codex-ios",
                        state: card.1,
                        timerContent: AnyView(
                            AdaptiveTimer(
                                text: card.2,
                                active: card.1.phase == .thinking || card.1.phase == .toolCall
                            )
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(12)
        }
        .background(Color(.systemBackground))
    }
}

#Preview("Dark Mode") {
    CardStack()
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    CardStack()
        .preferredColorScheme(.light)
}
#endif
