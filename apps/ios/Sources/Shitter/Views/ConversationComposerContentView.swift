import SwiftUI
import UIKit

struct ConversationComposerContentView: View {
    let attachedImage: UIImage?
    let pendingUserInputRequest: ServerManager.PendingUserInputRequest?
    let rateLimits: RateLimitSnapshot?
    let contextPercent: Int64?
    let isTurnActive: Bool
    let voiceManager: VoiceTranscriptionManager
    let onClearAttachment: () -> Void
    let onRespondToPendingUserInput: ([String: [String]]) -> Void
    let onShowAttachMenu: () -> Void
    let onSendText: () -> Void
    let onStopRecording: () -> Void
    let onStartRecording: () -> Void
    let onInterrupt: () -> Void
    @Binding var inputText: String
    let isComposerFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 0) {
            if let attachedImage {
                HStack {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: attachedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button(action: onClearAttachment) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(.body))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        .offset(x: 4, y: -4)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            VStack(alignment: .trailing, spacing: 0) {
                if let pendingUserInputRequest {
                    PendingUserInputPromptView(request: pendingUserInputRequest, onSubmit: onRespondToPendingUserInput)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                }

                ConversationComposerEntryRowView(
                    inputText: $inputText,
                    isComposerFocused: isComposerFocused,
                    voiceManager: voiceManager,
                    isTurnActive: isTurnActive,
                    onShowAttachMenu: onShowAttachMenu,
                    onSendText: onSendText,
                    onStopRecording: onStopRecording,
                    onStartRecording: onStartRecording,
                    onInterrupt: onInterrupt
                )

                ConversationComposerContextBarView(
                    rateLimits: rateLimits,
                    contextPercent: contextPercent
                )
            }
        }
    }
}
