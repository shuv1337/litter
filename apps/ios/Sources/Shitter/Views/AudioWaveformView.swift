import SwiftUI

struct AudioWaveformView: View {
    let level: Float
    var tint: Color = ShitterTheme.accentStrong

    private static let barCount = 24

    @State private var smoothedLevel: CGFloat = 0
    @State private var ring = [CGFloat](repeating: 0, count: AudioWaveformView.barCount)
    @State private var head = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            Canvas { ctx, size in
                let _ = timeline.date
                let midY = size.height / 2
                let barWidth: CGFloat = 2
                let gap = (size.width - barWidth * CGFloat(Self.barCount)) / CGFloat(Self.barCount - 1)

                for i in 0..<Self.barCount {
                    let ri = (head + i) % Self.barCount
                    let h = ring[ri]
                    let barHeight = max(2, h * size.height * 0.9)
                    let x = CGFloat(i) * (barWidth + gap)
                    let rect = CGRect(x: x, y: midY - barHeight / 2, width: barWidth, height: barHeight)
                    ctx.fill(
                        Path(roundedRect: rect, cornerRadius: 1),
                        with: .color(tint.opacity(0.35 + 0.65 * h))
                    )
                }
            }
            .onChange(of: timeline.date) { _, _ in pushLevel() }
        }
        .onAppear { pushLevel() }
    }

    private func pushLevel() {
        smoothedLevel += (CGFloat(level) - smoothedLevel) * 0.3
        ring[head] = smoothedLevel
        head = (head + 1) % Self.barCount
    }
}
