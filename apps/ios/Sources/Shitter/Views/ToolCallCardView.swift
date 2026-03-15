import SwiftUI

struct ToolCallCardView: View {
    let model: ToolCallCardModel
    @State private var expanded: Bool

    init(model: ToolCallCardModel) {
        self.model = model
        _expanded = State(initialValue: model.defaultExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: model.kind.iconName)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundColor(kindAccent)

                Text(model.summary)
                    .font(ShitterFont.styled(.caption))
                    .foregroundColor(ShitterTheme.textSystem)
                    .lineLimit(1)

                Spacer()

                statusChip

                if let duration = model.duration, !duration.isEmpty {
                    Text(duration)
                        .font(ShitterFont.styled(.caption2))
                        .foregroundColor(ShitterTheme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(ShitterTheme.surfaceLight.opacity(0.7))
                        .clipShape(Capsule())
                }

                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(.caption2, weight: .medium))
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
        .modifier(GlassRectModifier(cornerRadius: 12))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1)
                .fill(kindAccent.opacity(0.9))
                .frame(width: 3)
                .padding(.vertical, 6)
        }
        .onChange(of: model.status) { _, newStatus in
            if newStatus == .failed {
                expanded = true
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusChip: some View {
        Text(model.status.label)
            .font(ShitterFont.styled(.caption2, weight: .semibold))
            .foregroundColor(statusChipText)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(statusChipBackground)
            .clipShape(Capsule())
    }

    private var kindAccent: Color {
        switch model.kind {
        case .commandExecution, .commandOutput:
            return ShitterTheme.adaptive(light: "#8B6914", dark: "#C7B072")
        case .fileChange:
            return ShitterTheme.adaptive(light: "#2B6CB0", dark: "#7CAFD9")
        case .fileDiff:
            return ShitterTheme.adaptive(light: "#2563AA", dark: "#6FA9D8")
        case .mcpToolCall:
            return ShitterTheme.adaptive(light: "#8B3FAF", dark: "#C797D8")
        case .mcpToolProgress:
            return ShitterTheme.adaptive(light: "#9A6B20", dark: "#D3A85E")
        case .webSearch:
            return ShitterTheme.adaptive(light: "#3B8A8B", dark: "#88C6C7")
        case .collaboration:
            return ShitterTheme.adaptive(light: "#3D7A30", dark: "#9BCF8E")
        case .imageView:
            return ShitterTheme.adaptive(light: "#B5712B", dark: "#E3A66F")
        case .widget:
            return ShitterTheme.adaptive(light: "#6B3FA0", dark: "#B088D0")
        }
    }

    private var statusChipBackground: Color {
        switch model.status {
        case .completed:
            return ShitterTheme.success.opacity(0.2)
        case .inProgress:
            return ShitterTheme.warning.opacity(0.2)
        case .failed:
            return ShitterTheme.danger.opacity(0.2)
        case .unknown:
            return ShitterTheme.surfaceLight.opacity(0.7)
        }
    }

    private var statusChipText: Color {
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
                                    .font(ShitterFont.styled(.caption2, weight: .semibold))
                                    .foregroundColor(ShitterTheme.textSecondary)
                                Text(entry.value.value)
                                    .font(ShitterFont.styled(.caption2))
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
            codeLikeSection(label: label, language: "diff", content: content)
        case .text(let label, let content):
            codeLikeSection(label: label, language: "text", content: content)
        case .list(let label, let items):
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel(label)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(identifiedTextItems(items, prefix: "list")) { item in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .font(ShitterFont.styled(.caption))
                                    .foregroundColor(ShitterTheme.textSecondary)
                                Text(item.value)
                                    .font(ShitterFont.styled(.caption))
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
                                    .font(ShitterFont.styled(.caption))
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
            .font(ShitterFont.styled(.caption2, weight: .bold))
            .foregroundColor(ShitterTheme.textSecondary)
    }

    private func codeLikeSection(label: String, language: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(label)
            CodeBlockView(language: language, code: content)
        }
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
