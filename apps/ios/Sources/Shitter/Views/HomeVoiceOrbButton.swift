import SwiftUI

struct HomeVoiceOrbButton: View {
    let session: VoiceSessionState?
    let isAvailable: Bool
    let isStarting: Bool
    let action: () -> Void

    private var phase: VoiceSessionPhase? {
        if isStarting {
            return .connecting
        }
        return session?.phase
    }

    private var isActive: Bool {
        phase != nil && phase != .error
    }

    private var pulseLevel: CGFloat {
        if isStarting {
            return 0.35
        }
        return CGFloat(session?.activeLevel ?? 0)
    }

    private var orbColor: Color {
        guard let phase else { return ShitterTheme.accentStrong }
        switch phase {
        case .connecting, .listening:
            return ShitterTheme.accentStrong
        case .speaking, .thinking, .handoff:
            return ShitterTheme.warning
        case .error:
            return ShitterTheme.danger
        }
    }

    private var buttonDiameter: CGFloat {
        isActive ? 68 : 60
    }

    private var hasRecoverableError: Bool {
        phase == .error
    }

    private var isDisabled: Bool {
        !isAvailable || isStarting || (session != nil && !hasRecoverableError)
    }

    private var accessibilityLabel: String {
        if !isAvailable {
            return "Realtime voice unavailable"
        }
        if isStarting {
            return "Connecting realtime voice"
        }
        if hasRecoverableError {
            return "Retry realtime voice"
        }
        return "Start realtime voice"
    }

    private var glassTint: Color {
        orbColor.opacity(isActive ? 0.3 : 0.18)
    }

    var body: some View {
        orbButton
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var orbButton: some View {
        if #available(iOS 26.0, *), isAvailable, !hasRecoverableError {
            Button(action: action) {
                ZStack {
                    Color.white
                        .opacity(0.001)
                        .frame(width: buttonDiameter, height: buttonDiameter)
                        .glassEffect(.regular.tint(glassTint), in: .circle)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(isActive ? 0.34 : 0.18), lineWidth: 0.9)
                        }

                    orbGlyph
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Starts a local realtime voice conversation.")
        } else {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    orbColor.opacity(isDisabled ? 0.45 : 0.96),
                                    orbColor.opacity(isDisabled ? 0.24 : 0.58),
                                    ShitterTheme.surface.opacity(0.92)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(isActive ? 0.24 : 0.14), lineWidth: 1)
                        }
                        .shadow(color: orbColor.opacity(isDisabled ? 0.12 : 0.3), radius: 22, y: 10)
                        .frame(width: buttonDiameter, height: buttonDiameter)

                    orbGlyph
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Starts a local realtime voice conversation.")
        }
    }

    @ViewBuilder
    private var orbGlyph: some View {
        if isStarting {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.15)
        } else {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isDisabled ? .white.opacity(0.72) : .white)
        }
    }
}
