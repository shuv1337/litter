import SwiftUI

struct ConversationComposerEntryRowView: View {
    @Binding var inputText: String
    let isComposerFocused: FocusState<Bool>.Binding
    let voiceManager: VoiceTranscriptionManager
    let isTurnActive: Bool
    let onShowAttachMenu: () -> Void
    let onSendText: () -> Void
    let onStopRecording: () -> Void
    let onStartRecording: () -> Void
    let onInterrupt: () -> Void

    private var hasText: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if !voiceManager.isRecording && !voiceManager.isTranscribing && !isTurnActive {
                Button(action: onShowAttachMenu) {
                    Image(systemName: "plus")
                        .font(.system(.body, weight: .semibold))
                        .foregroundColor(ShitterTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .modifier(GlassCircleModifier())
                }
                .transition(.scale.combined(with: .opacity))
            }

            HStack(spacing: 0) {
                TextField("Message shitter...", text: $inputText, axis: .vertical)
                    .font(.system(.body))
                    .foregroundColor(ShitterTheme.textPrimary)
                    .lineLimit(1...5)
                    .focused(isComposerFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding(.leading, 16)
                    .padding(.vertical, 10)

                if hasText {
                    Button(action: onSendText) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(.title2))
                            .foregroundColor(ShitterTheme.accent)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .padding(.trailing, 4)
                } else if voiceManager.isRecording {
                    AudioWaveformView(level: voiceManager.audioLevel)
                        .frame(width: 48, height: 20)

                    Button(action: onStopRecording) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(.title2))
                            .foregroundColor(ShitterTheme.accentStrong)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .padding(.trailing, 4)
                } else if voiceManager.isTranscribing {
                    ProgressView()
                        .tint(ShitterTheme.accent)
                        .padding(.trailing, 8)
                } else {
                    Button(action: onStartRecording) {
                        Image(systemName: "mic.fill")
                            .font(.system(.subheadline))
                            .foregroundColor(ShitterTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .padding(.trailing, 4)
                }
            }
            .frame(minHeight: 36)
            .modifier(GlassRoundedRectModifier(cornerRadius: 20))

            if isTurnActive {
                Button(action: onInterrupt) {
                    Text("Cancel")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundColor(ShitterTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .modifier(GlassCapsuleModifier())
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: isTurnActive)
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }
}
