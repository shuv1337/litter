import SwiftUI

struct InlineVoiceStatusStrip: View {
    let session: VoiceSessionState
    let onToggleSpeaker: () -> Void

    private var inputLevel: Float {
        session.isListening ? max(0.08, session.scaledInputLevel) : max(0, session.scaledInputLevel)
    }

    private var outputLevel: Float {
        session.isSpeaking ? max(0.08, session.scaledOutputLevel) : max(0, session.scaledOutputLevel)
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Circle()
                    .fill(session.isListening ? ShitterTheme.accent : ShitterTheme.textMuted.opacity(0.4))
                    .frame(width: 5, height: 5)
                Text("YOU")
                    .font(ShitterFont.monospaced(.caption2, weight: .bold))
                    .foregroundColor(session.isListening ? ShitterTheme.textPrimary : ShitterTheme.textMuted)
                AudioWaveformView(level: inputLevel, tint: ShitterTheme.accent)
                    .frame(width: 48, height: 14)
            }

            HStack(spacing: 5) {
                Circle()
                    .fill(session.isSpeaking ? ShitterTheme.warning : ShitterTheme.textMuted.opacity(0.4))
                    .frame(width: 5, height: 5)
                Text("CODEX")
                    .font(ShitterFont.monospaced(.caption2, weight: .bold))
                    .foregroundColor(session.isSpeaking ? ShitterTheme.textPrimary : ShitterTheme.textMuted)
                AudioWaveformView(level: outputLevel, tint: ShitterTheme.warning)
                    .frame(width: 48, height: 14)
            }

            Spacer()

            Button(action: onToggleSpeaker) {
                HStack(spacing: 4) {
                    Image(systemName: session.route.iconName)
                        .font(.system(size: 10, weight: .semibold))
                    Text(session.route.label)
                        .font(ShitterFont.styled(.caption2, weight: .semibold))
                }
                .foregroundColor(session.route.supportsSpeakerToggle ? ShitterTheme.textPrimary : ShitterTheme.textMuted)
            }
            .buttonStyle(.plain)
            .disabled(!session.route.supportsSpeakerToggle)

            Text(session.phase.displayTitle)
                .font(ShitterFont.monospaced(.caption2, weight: .medium))
                .foregroundColor(phaseColor(session.phase))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(ShitterTheme.surface.opacity(0.6))
    }

    private func phaseColor(_ phase: VoiceSessionPhase) -> Color {
        switch phase {
        case .connecting, .thinking, .handoff:
            return ShitterTheme.warning
        case .listening, .speaking:
            return ShitterTheme.accent
        case .error:
            return ShitterTheme.danger
        }
    }
}
