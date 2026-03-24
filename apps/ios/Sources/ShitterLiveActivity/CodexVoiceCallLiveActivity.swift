import ActivityKit
import SwiftUI
import WidgetKit

struct CodexVoiceCallLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CodexVoiceCallAttributes.self) { context in
            VoiceCallLockScreenCardView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image("brand_logo")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.threadTitle)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: EndVoiceSessionIntent()) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        Text(context.state.phase.rawValue)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                        Spacer()
                        Text(context.state.routeLabel)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            } compactLeading: {
                Image("brand_logo")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            } compactTrailing: {
                Image(systemName: "waveform")
                    .foregroundStyle(.white.opacity(0.85))
            } minimal: {
                Image(systemName: "waveform")
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}
