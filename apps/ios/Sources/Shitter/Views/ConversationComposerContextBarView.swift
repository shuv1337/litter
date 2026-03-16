import SwiftUI

struct ConversationComposerContextBarView: View {
    let rateLimits: RateLimitSnapshot?
    let contextPercent: Int64?

    private var hasAnything: Bool {
        rateLimits?.primary != nil || rateLimits?.secondary != nil || contextPercent != nil
    }

    var body: some View {
        if hasAnything {
            HStack(spacing: 4) {
                if let primary = rateLimits?.primary {
                    RateLimitBadgeView(
                        label: formatWindowLabel(primary),
                        percent: normalizedPercent(primary.usedPercent)
                    )
                }

                if let secondary = rateLimits?.secondary {
                    RateLimitBadgeView(
                        label: formatWindowLabel(secondary),
                        percent: normalizedPercent(secondary.usedPercent)
                    )
                }

                if let contextPercent {
                    ContextBadgeView(
                        percent: Int(contextPercent),
                        tint: contextTint(percent: contextPercent)
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, -2)
            .padding(.trailing, 40)
        }
    }

    private func normalizedPercent(_ raw: Double) -> Int {
        let used = raw > 1 ? min(Int(raw), 100) : min(Int(raw * 100), 100)
        return max(0, 100 - used)
    }

    private func formatWindowLabel(_ window: RateLimitWindow) -> String {
        guard let mins = window.windowDurationMins else { return "" }
        if mins >= 1440 { return "\(mins / 1440)d" }
        if mins >= 60 { return "\(mins / 60)h" }
        return "\(mins)m"
    }

    private func contextTint(percent: Int64) -> Color {
        switch percent {
        case ...15: return ShitterTheme.danger
        case ...35: return ShitterTheme.warning
        default: return ShitterTheme.success
        }
    }
}
