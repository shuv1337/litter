import SwiftUI

struct InlineVoiceButton: View {
    let session: VoiceSessionState?
    let isAvailable: Bool
    let onStart: () -> Void
    let onStop: () -> Void

    private var phase: VoiceSessionPhase? {
        session?.phase
    }

    private var isActive: Bool {
        phase != nil && phase != .error
    }

    private var pulseLevel: CGFloat {
        CGFloat(session?.activeLevel ?? 0)
    }

    private var iconColor: Color {
        guard let phase else { return ShitterTheme.textSecondary }
        switch phase {
        case .connecting, .listening:
            return ShitterTheme.accent
        case .speaking, .thinking, .handoff:
            return ShitterTheme.warning
        case .error:
            return ShitterTheme.danger
        }
    }

    private var buttonSize: CGFloat { isActive ? 56 : 36 }
    private var iconSize: CGFloat { isActive ? 22 : 16 }

    var body: some View {
        if isAvailable {
            Button(action: isActive ? onStop : onStart) {
                Circle()
                    .fill(isActive ? iconColor : ShitterTheme.surfaceLight)
                    .frame(width: buttonSize, height: buttonSize)
                    .overlay {
                        if phase == .connecting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                                .transition(.opacity)
                        } else {
                            VoiceButtonWaveform(
                                level: isActive ? pulseLevel : 0,
                                barCount: isActive ? 5 : 3
                            )
                            .frame(width: iconSize, height: iconSize * 0.8)
                            .foregroundStyle(isActive ? .white : iconColor)
                            .transition(.opacity)
                        }
                    }
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isActive)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: phase)
        }
    }
}

private struct VoiceButtonWaveform: View {
    let level: CGFloat
    let barCount: Int

    var body: some View {
        Canvas { context, size in
            let barWidth: CGFloat = 2.5
            let totalWidth = barWidth * CGFloat(barCount)
            let gap = barCount > 1
                ? (size.width - totalWidth) / CGFloat(barCount - 1)
                : 0
            let midY = size.height / 2

            for index in 0..<barCount {
                let center = CGFloat(barCount - 1) / 2.0
                let distance = abs(CGFloat(index) - center) / max(center, 1)
                let base = 1.0 - distance * 0.6
                let activeLevel = max(0.25, level)
                let height = max(0.18, base * activeLevel) * size.height
                let x = CGFloat(index) * (barWidth + gap)
                let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 1.2),
                    with: .foreground
                )
            }
        }
    }
}
