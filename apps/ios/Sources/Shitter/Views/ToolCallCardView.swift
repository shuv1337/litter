import SwiftUI

struct ToolCallCardView: View {
    let model: ToolCallCardModel
    var textScale: CGFloat = 1.0
    @State private var expanded: Bool

    init(model: ToolCallCardModel, textScale: CGFloat = 1.0) {
        self.model = model
        self.textScale = textScale
        _expanded = State(initialValue: model.defaultExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: model.kind.iconName)
                    .font(.system(size: 12 * textScale, weight: .semibold))
                    .foregroundColor(kindAccent)

                Text(model.summary)
                    .font(ShitterFont.styled(.caption, scale: textScale))
                    .foregroundColor(ShitterTheme.textSystem)
                    .lineLimit(1)

                Spacer()

                if let duration = model.duration, !duration.isEmpty {
                    Text(duration)
                        .font(ShitterFont.styled(.caption2, scale: textScale))
                        .foregroundColor(durationStatusColor)
                        .accessibilityLabel(durationAccessibilityLabel(duration))
                }

                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11 * textScale, weight: .medium))
                    .foregroundColor(ShitterTheme.textMuted)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expanded.toggle()
                }
            }

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(identifiedSections) { section in
                        sectionView(section.value)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onChange(of: model.status) { _, newStatus in
            if newStatus == .failed {
                expanded = true
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var durationStatusColor: Color {
        switch model.status {
        case .completed:
            return ShitterTheme.success
        case .inProgress:
            return ShitterTheme.warning
        case .failed:
            return ShitterTheme.danger
        case .unknown:
            return ShitterTheme.textSecondary
        }
    }

    private func durationAccessibilityLabel(_ duration: String) -> String {
        switch model.status {
        case .completed:
            return "\(duration), completed"
        case .inProgress:
            return "\(duration), in progress"
        case .failed:
            return "\(duration), failed"
        case .unknown:
            return duration
        }
    }

    private var kindAccent: Color {
        switch model.kind {
        case .commandExecution, .commandOutput:
            return ShitterTheme.warning
        case .fileChange, .fileDiff, .webSearch:
            return ShitterTheme.accent
        case .mcpToolCall, .widget:
            return ShitterTheme.accentStrong
        case .mcpToolProgress, .imageView:
            return ShitterTheme.warning
        case .collaboration:
            return ShitterTheme.success
        }
    }

    @ViewBuilder
    private func sectionView(_ section: ToolCallSection) -> some View {
        switch section {
        case .kv(let label, let entries):
            if !entries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel(label)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(identifiedKeyValueEntries(entries)) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.value.key + ":")
                                    .font(ShitterFont.styled(.caption2, weight: .semibold, scale: textScale))
                                    .foregroundColor(ShitterTheme.textSecondary)
                                Text(entry.value.value)
                                    .font(ShitterFont.styled(.caption2, scale: textScale))
                                    .foregroundColor(ShitterTheme.textSystem)
                                    .textSelection(.enabled)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(8)
                    .background(ShitterTheme.surface.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        case .code(let label, let language, let content):
            codeLikeSection(label: label, language: language, content: content)
        case .json(let label, let content):
            codeLikeSection(label: label, language: "json", content: content)
        case .diff(let label, let content):
            diffSection(label: label, content: content)
        case .text(let label, let content):
            inlineTextSection(label: label, content: content)
        case .list(let label, let items):
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel(label)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(identifiedTextItems(items, prefix: "list")) { item in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .font(ShitterFont.styled(.caption, scale: textScale))
                                    .foregroundColor(ShitterTheme.textSecondary)
                                Text(item.value)
                                    .font(ShitterFont.styled(.caption, scale: textScale))
                                    .foregroundColor(ShitterTheme.textSystem)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding(8)
                    .background(ShitterTheme.surface.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        case .progress(let label, let items):
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel(label)
                    VStack(alignment: .leading, spacing: 6) {
                        let identifiedItems = identifiedTextItems(items, prefix: "progress")
                        ForEach(identifiedItems) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(item.index == identifiedItems.count - 1 ? kindAccent : ShitterTheme.textMuted)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 5)
                                Text(item.value)
                                    .font(ShitterFont.styled(.caption, scale: textScale))
                                    .foregroundColor(ShitterTheme.textSystem)
                                    .textSelection(.enabled)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(8)
                    .background(ShitterTheme.surface.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func sectionLabel(_ label: String) -> some View {
        Text(label.uppercased())
            .font(ShitterFont.styled(.caption2, weight: .bold, scale: textScale))
            .foregroundColor(ShitterTheme.textSecondary)
    }

    private func codeLikeSection(label: String, language: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(label)
            CodeBlockView(language: language, code: content, fontSize: 13 * textScale)
        }
    }

    private func inlineTextSection(label: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(label)
            Text(verbatim: content)
                .font(ShitterFont.monospaced(size: 12 * textScale))
                .foregroundColor(ShitterTheme.textBody)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(ShitterTheme.codeBackground.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func diffSection(label: String, content: String) -> some View {
        let lines = content.components(separatedBy: .newlines)

        return VStack(alignment: .leading, spacing: 6) {
            sectionLabel(label)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(verbatim: line.isEmpty ? " " : line)
                        .font(ShitterFont.monospaced(size: 12 * textScale))
                        .foregroundStyle(diffForegroundColor(for: line))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(diffBackgroundColor(for: line))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func diffForegroundColor(for line: String) -> Color {
        if line.hasPrefix("+"), !line.hasPrefix("+++") {
            return ShitterTheme.success
        }
        if line.hasPrefix("-"), !line.hasPrefix("---") {
            return ShitterTheme.danger
        }
        if line.hasPrefix("@@") {
            return ShitterTheme.accentStrong
        }
        return ShitterTheme.textBody
    }

    private func diffBackgroundColor(for line: String) -> Color {
        if line.hasPrefix("+"), !line.hasPrefix("+++") {
            return ShitterTheme.success.opacity(0.12)
        }
        if line.hasPrefix("-"), !line.hasPrefix("---") {
            return ShitterTheme.danger.opacity(0.12)
        }
        if line.hasPrefix("@@") {
            return ShitterTheme.accentStrong.opacity(0.12)
        }
        return ShitterTheme.codeBackground.opacity(0.72)
    }

    private var identifiedSections: [IndexedValue<ToolCallSection>] {
        identifiedValues(model.sections, prefix: "section") { section in
            switch section {
            case .kv(let label, let entries):
                return "\(label)|kv|\(entries.map { "\($0.key)=\($0.value)" }.joined(separator: "|"))"
            case .code(let label, let language, let content):
                return "\(label)|code|\(language)|\(content)"
            case .json(let label, let content):
                return "\(label)|json|\(content)"
            case .diff(let label, let content):
                return "\(label)|diff|\(content)"
            case .text(let label, let content):
                return "\(label)|text|\(content)"
            case .list(let label, let items):
                return "\(label)|list|\(items.joined(separator: "|"))"
            case .progress(let label, let items):
                return "\(label)|progress|\(items.joined(separator: "|"))"
            }
        }
    }

    private func identifiedKeyValueEntries(_ entries: [ToolCallKeyValue]) -> [IndexedValue<ToolCallKeyValue>] {
        identifiedValues(entries, prefix: "kv") { entry in
            "\(entry.key)|\(entry.value)"
        }
    }

    private func identifiedTextItems(_ values: [String], prefix: String) -> [IndexedValue<String>] {
        identifiedValues(values, prefix: prefix) { $0 }
    }

    private func identifiedValues<Value>(
        _ values: [Value],
        prefix: String,
        key: (Value) -> String
    ) -> [IndexedValue<Value>] {
        var seen: [String: Int] = [:]
        return values.enumerated().map { index, value in
            let signature = key(value)
            let occurrence = seen[signature, default: 0]
            seen[signature] = occurrence + 1
            return IndexedValue(
                id: "\(prefix)-\(signature.hashValue)-\(occurrence)",
                index: index,
                value: value
            )
        }
    }
}

private struct IndexedValue<Value>: Identifiable {
    let id: String
    let index: Int
    let value: Value
}

#if DEBUG
#Preview("Tool Call Card") {
    ZStack {
        ShitterTheme.backgroundGradient.ignoresSafeArea()
        ToolCallCardView(model: ShitterPreviewData.sampleToolCallModel)
            .padding(20)
    }
}
#endif
