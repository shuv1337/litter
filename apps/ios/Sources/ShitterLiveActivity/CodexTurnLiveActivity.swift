import ActivityKit
import SwiftUI
import WidgetKit

struct CodexTurnLiveActivity: Widget {
    // Dynamic Island is always dark — resolve palette colors once for .dark scheme
    private var warningColor: Color { ShitterPalette.warning.color(for: .dark) }
    private var dangerColor: Color { ShitterPalette.danger.color(for: .dark) }
    private var primaryText: Color { ShitterPalette.textPrimary.color(for: .dark) }
    private var secondaryText: Color { ShitterPalette.textSecondary.color(for: .dark) }
    private var mutedText: Color { ShitterPalette.textMuted.color(for: .dark) }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CodexTurnAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    shitterLogo(size: 18)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.attributes.prompt)
                            .font(.system(size: 11, weight: .medium, design: ShitterPalette.fontDesign))
                            .foregroundStyle(primaryText)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            phaseBadge(context.state)
                            if context.state.toolCallCount > 0 {
                                Label("\(context.state.toolCallCount)", systemImage: "chevron.left.forwardslash.chevron.right")
                                    .font(.system(size: 9, design: ShitterPalette.fontDesign))
                                    .foregroundStyle(mutedText)
                            }
                            if context.state.fileChangeCount > 0 {
                                Label("\(context.state.fileChangeCount)", systemImage: "doc.text")
                                    .font(.system(size: 9, design: ShitterPalette.fontDesign))
                                    .foregroundStyle(mutedText)
                            }
                            if context.state.contextPercent > 0 {
                                ctxBadge(context.state.contextPercent)
                            }
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    liveTimer(context: context, size: 11)
                        .foregroundStyle(secondaryText)
                }
            } compactLeading: {
                shitterLogo(size: 16)
                    .frame(maxWidth: 16, alignment: .leading)
            } compactTrailing: {
                compactTimer(context: context)
                    .frame(width: 42)
            } minimal: {
                shitterLogo(size: 16)
            }
        }
    }

    // MARK: - Lock Screen

    private func lockScreenView(context: ActivityViewContext<CodexTurnAttributes>) -> some View {
        LockScreenCardView(
            prompt: context.attributes.prompt,
            model: context.attributes.model,
            cwd: context.attributes.cwd,
            state: context.state,
            timerContent: AnyView(
                AdaptiveLiveTimer(context: context)
            )
        )
    }

    // MARK: - Components

    private func shitterLogo(size: CGFloat) -> some View {
        Image("brand_logo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
    }

    private func displayText(_ state: CodexTurnAttributes.ContentState) -> String {
        if let snippet = state.outputSnippet, !snippet.isEmpty {
            return snippet
        }
        return statusText(state)
    }

    private func snippetColor(_ state: CodexTurnAttributes.ContentState) -> Color {
        if state.outputSnippet != nil {
            return secondaryText
        }
        switch state.phase {
        case .thinking, .toolCall: return warningColor.opacity(0.6)
        case .completed: return secondaryText
        case .failed: return dangerColor.opacity(0.6)
        }
    }

    private func phaseBadge(_ state: CodexTurnAttributes.ContentState) -> some View {
        Text(phaseBadgeText(state))
            .font(.system(size: 10, weight: .medium, design: ShitterPalette.fontDesign))
            .foregroundStyle(phaseColor(state))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(phaseBgColor(state))
            )
    }

    private func metaChip(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 9))
                .foregroundStyle(mutedText.opacity(0.7))
            Text(text)
                .font(.system(size: 10, design: ShitterPalette.fontDesign))
                .foregroundStyle(mutedText)
                .lineLimit(1)
        }
        .padding(.trailing, 10)
    }

    private func ctxBadge(_ percent: Int) -> some View {
        Text("\(percent)%")
            .font(.system(size: 9, weight: .semibold, design: ShitterPalette.fontDesign))
            .foregroundStyle(ctxColor(percent))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ctxBgColor(percent))
            )
    }

    @ViewBuilder
    private func liveTimer(context: ActivityViewContext<CodexTurnAttributes>, size: CGFloat) -> some View {
        if isActive(context.state) {
            Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
                .font(.system(size: size, design: ShitterPalette.fontDesign))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else {
            Text(formatElapsed(context.state.elapsedSeconds))
                .font(.system(size: size, design: ShitterPalette.fontDesign))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
    }

    private func compactTimer(context: ActivityViewContext<CodexTurnAttributes>) -> some View {
        Text(compactElapsedText(context: context))
            .font(.system(size: 10, weight: .medium, design: ShitterPalette.fontDesign))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(secondaryText)
            .frame(width: 20, alignment: .trailing)
    }

    // MARK: - Helpers

    private func isActive(_ state: CodexTurnAttributes.ContentState) -> Bool {
        state.phase == .thinking || state.phase == .toolCall
    }

    private func statusText(_ state: CodexTurnAttributes.ContentState) -> String {
        switch state.phase {
        case .thinking: return "Thinking..."
        case .toolCall: return state.toolName ?? "Running tool..."
        case .completed: return "Done"
        case .failed: return "Failed"
        }
    }

    private func phaseBadgeText(_ state: CodexTurnAttributes.ContentState) -> String {
        switch state.phase {
        case .thinking: return "thinking"
        case .toolCall: return "tool"
        case .completed: return "done"
        case .failed: return "failed"
        }
    }

    private func phaseColor(_ state: CodexTurnAttributes.ContentState) -> Color {
        switch state.phase {
        case .thinking, .toolCall: return warningColor
        case .completed: return secondaryText
        case .failed: return dangerColor
        }
    }

    private func phaseBgColor(_ state: CodexTurnAttributes.ContentState) -> Color {
        switch state.phase {
        case .thinking, .toolCall: return warningColor.opacity(0.12)
        case .completed: return primaryText.opacity(0.06)
        case .failed: return dangerColor.opacity(0.12)
        }
    }

    private func ctxColor(_ percent: Int) -> Color {
        if percent >= 80 { return dangerColor }
        if percent >= 60 { return warningColor }
        return mutedText
    }

    private func ctxBgColor(_ percent: Int) -> Color {
        if percent >= 80 { return dangerColor.opacity(0.1) }
        if percent >= 60 { return warningColor.opacity(0.1) }
        return primaryText.opacity(0.05)
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func compactElapsedText(context: ActivityViewContext<CodexTurnAttributes>) -> String {
        if isActive(context.state) {
            let elapsed = max(0, Int(Date().timeIntervalSince(context.attributes.startDate)))
            return compactDurationText(elapsed)
        }
        return compactDurationText(context.state.elapsedSeconds)
    }

    private func compactDurationText(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }

        return "\(minutes / 60)h"
    }

}

// MARK: - Adaptive timer for lock screen (respects color scheme)

private struct AdaptiveLiveTimer: View {
    let context: ActivityViewContext<CodexTurnAttributes>
    @Environment(\.colorScheme) private var colorScheme

    private var isActive: Bool {
        context.state.phase == .thinking || context.state.phase == .toolCall
    }

    private var timerColor: Color {
        let text = ShitterPalette.textSecondary.color(for: colorScheme)
        return isActive ? text : text.opacity(0.65)
    }

    var body: some View {
        Group {
            if isActive {
                Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
            } else {
                let m = context.state.elapsedSeconds / 60
                let s = context.state.elapsedSeconds % 60
                Text(String(format: "%d:%02d", m, s))
            }
        }
        .font(.system(size: 15, design: ShitterPalette.fontDesign))
        .monospacedDigit()
        .fontWeight(.regular)
        .foregroundStyle(timerColor)
        .multilineTextAlignment(.trailing)
    }
}
