import SwiftUI
import Textual
import UIKit

struct ConversationTurnTimeline: View {
    let items: [ConversationItem]
    let isLive: Bool
    let renderMode: ConversationTurnRenderMode
    let serverId: String
    let agentDirectoryVersion: Int
    let messageActionsDisabled: Bool
    let onStreamingSnapshotRendered: (() -> Void)?
    let resolveTargetLabel: (String) -> String?
    let onWidgetPrompt: (String) -> Void
    let onEditUserItem: (ConversationItem) -> Void
    let onForkFromUserItem: (ConversationItem) -> Void
    var onOpenConversation: ((ThreadKey) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(rowDescriptors) { row in
                rowView(row)
                    .id(row.id)
            }
        }
    }

    private var rowDescriptors: [ConversationTimelineRowDescriptor] {
        ConversationTimelineRowDescriptor.build(from: items)
    }

    private var streamingAssistantItemId: String? {
        guard isLive else { return nil }
        return items.last(where: \.isAssistantItem)?.id
    }

    @ViewBuilder
    private func rowView(_ row: ConversationTimelineRowDescriptor) -> some View {
        switch row {
        case .item(let item):
            ConversationTimelineItemRow(
                item: item,
                serverId: serverId,
                agentDirectoryVersion: agentDirectoryVersion,
                renderMode: renderMode,
                isStreamingMessage: item.id == streamingAssistantItemId,
                messageActionsDisabled: messageActionsDisabled,
                onStreamingSnapshotRendered: item.id == streamingAssistantItemId ? onStreamingSnapshotRendered : nil,
                resolveTargetLabel: resolveTargetLabel,
                onWidgetPrompt: onWidgetPrompt,
                onEditUserItem: onEditUserItem,
                onForkFromUserItem: onForkFromUserItem,
                onOpenConversation: onOpenConversation
            )
        case .exploration(let id, let items):
            ConversationExplorationGroupRow(id: id, items: items)
        case .subagentGroup(_, let merged, _):
            SubagentCardView(
                data: merged,
                serverId: serverId
            )
        }
    }
}

private enum ConversationTimelineRowDescriptor: Identifiable, Equatable {
    case item(ConversationItem)
    case exploration(id: String, items: [ConversationItem])
    case subagentGroup(id: String, merged: ConversationMultiAgentActionData, sourceItems: [ConversationItem])

    var id: String {
        switch self {
        case .item(let item):
            return item.id
        case .exploration(let id, _):
            return id
        case .subagentGroup(let id, _, _):
            return id
        }
    }

    static func build(from items: [ConversationItem]) -> [ConversationTimelineRowDescriptor] {
        var rows: [ConversationTimelineRowDescriptor] = []
        var explorationBuffer: [ConversationItem] = []
        var subagentBuffer: [(item: ConversationItem, data: ConversationMultiAgentActionData)] = []
        var subagentTool: String?

        func flushExplorationBuffer() {
            guard !explorationBuffer.isEmpty else { return }
            if explorationBuffer.count == 1 {
                rows.append(.item(explorationBuffer[0]))
            } else {
                let seed = explorationBuffer.first?.id ?? UUID().uuidString
                rows.append(.exploration(id: "exploration-\(seed)", items: explorationBuffer))
            }
            explorationBuffer.removeAll(keepingCapacity: true)
        }

        func flushSubagentBuffer() {
            guard !subagentBuffer.isEmpty else { return }
            if subagentBuffer.count == 1 {
                rows.append(.item(subagentBuffer[0].item))
            } else {
                let seed = subagentBuffer.first?.item.id ?? UUID().uuidString
                // Merge all targets, threadIds, states, pick the latest status
                var mergedTargets: [String] = []
                var mergedThreadIds: [String] = []
                var mergedStates: [ConversationMultiAgentState] = []
                var mergedPrompts: [String] = []
                var latestStatus = "completed"
                let tool = subagentBuffer.first?.data.tool ?? "spawnAgent"

                for entry in subagentBuffer {
                    mergedTargets.append(contentsOf: entry.data.targets)
                    mergedThreadIds.append(contentsOf: entry.data.receiverThreadIds)
                    mergedStates.append(contentsOf: entry.data.agentStates)
                    if let p = entry.data.prompt, !p.isEmpty {
                        mergedPrompts.append(p)
                    }
                    if entry.data.isInProgress {
                        latestStatus = "in_progress"
                    }
                }

                let merged = ConversationMultiAgentActionData(
                    tool: tool,
                    status: latestStatus,
                    prompt: nil,
                    targets: mergedTargets,
                    receiverThreadIds: mergedThreadIds,
                    agentStates: mergedStates,
                    perAgentPrompts: mergedPrompts
                )
                rows.append(.subagentGroup(
                    id: "subagent-group-\(seed)",
                    merged: merged,
                    sourceItems: subagentBuffer.map(\.item)
                ))
            }
            subagentBuffer.removeAll(keepingCapacity: true)
            subagentTool = nil
        }

        for item in items {
            if case .multiAgentAction(let data) = item.content {
                let tool = data.tool.lowercased()
                if let currentTool = subagentTool, currentTool == tool {
                    subagentBuffer.append((item, data))
                } else {
                    flushExplorationBuffer()
                    flushSubagentBuffer()
                    subagentBuffer.append((item, data))
                    subagentTool = tool
                }
            } else if case .commandExecution(let data) = item.content, data.isPureExploration {
                flushSubagentBuffer()
                explorationBuffer.append(item)
            } else {
                flushExplorationBuffer()
                flushSubagentBuffer()
                rows.append(.item(item))
            }
        }

        flushExplorationBuffer()
        flushSubagentBuffer()
        return rows
    }
}

enum ConversationTurnRenderMode {
    case lightweight
    case rich
}

private struct ConversationTimelineItemRow: View {
    private let renderCache = MessageRenderCache.shared
    @Environment(ThemeManager.self) private var themeManager

    let item: ConversationItem
    let serverId: String
    let agentDirectoryVersion: Int
    let renderMode: ConversationTurnRenderMode
    let isStreamingMessage: Bool
    let messageActionsDisabled: Bool
    let onStreamingSnapshotRendered: (() -> Void)?
    let resolveTargetLabel: (String) -> String?
    let onWidgetPrompt: (String) -> Void
    let onEditUserItem: (ConversationItem) -> Void
    let onForkFromUserItem: (ConversationItem) -> Void
    var onOpenConversation: ((ThreadKey) -> Void)? = nil

    var body: some View {
        switch item.content {
        case .user(let data):
            userRow(data)
        case .assistant(let data):
            assistantRow(data)
        case .reasoning(let data):
            ConversationReasoningRow(data: data)
        case .todoList(let data):
            ConversationTodoListRow(data: data)
        case .proposedPlan(let data):
            ConversationProposedPlanRow(data: data, renderMode: renderMode)
        case .commandExecution(let data):
            ConversationCommandExecutionRow(item: item, data: data)
        case .fileChange(let data):
            ConversationToolCardRow(model: makeFileChangeModel(data))
        case .turnDiff(let data):
            ConversationTurnDiffRow(data: data)
        case .mcpToolCall(let data):
            ConversationToolCardRow(model: makeMcpModel(data))
        case .dynamicToolCall(let data):
            ConversationToolCardRow(model: makeDynamicToolModel(data))
        case .multiAgentAction(let data):
            SubagentCardView(
                data: data,
                serverId: serverId
            )
        case .webSearch(let data):
            ConversationToolCardRow(model: makeWebSearchModel(data))
        case .widget(let data):
            WidgetContainerView(
                widget: data.widgetState,
                onMessage: handleWidgetMessage
            )
        case .userInputResponse(let data):
            ConversationUserInputResponseRow(data: data)
        case .divider(let kind):
            ConversationDividerRow(kind: kind)
        case .error(let data):
            ConversationSystemCardRow(
                title: data.title.isEmpty ? "Error" : data.title,
                content: [data.message, data.details].compactMap { $0 }.joined(separator: "\n\n"),
                accent: ShitterTheme.danger,
                iconName: "exclamationmark.triangle.fill",
                renderMode: renderMode
            )
        case .note(let data):
            ConversationSystemCardRow(
                title: data.title,
                content: data.body,
                accent: ShitterTheme.accent,
                iconName: "info.circle.fill",
                renderMode: renderMode
            )
        }
    }

    private func userRow(_ data: ConversationUserMessageData) -> some View {
        UserBubble(text: data.text, images: data.images)
            .contextMenu {
                if item.isFromUserTurnBoundary {
                    Button("Edit Message") {
                        onEditUserItem(item)
                    }
                    .disabled(messageActionsDisabled)

                    Button("Fork From Here") {
                        onForkFromUserItem(item)
                    }
                    .disabled(messageActionsDisabled)
                }
            }
    }

    @ViewBuilder
    private func assistantRow(_ data: ConversationAssistantMessageData) -> some View {
        let assistantLabel = AgentLabelFormatter.format(
            nickname: data.agentNickname,
            role: data.agentRole
        )

        if isStreamingMessage {
            StreamingAssistantBubble(
                text: data.text,
                label: assistantLabel,
                themeVersion: themeManager.themeVersion,
                onSnapshotRendered: onStreamingSnapshotRendered
            )
        } else if renderMode == .lightweight {
            ConversationPlainAssistantRow(
                data: data,
                label: assistantLabel
            )
        } else {
            let revisionKey = MessageRenderCache.makeRevisionKey(
                for: item,
                serverId: serverId,
                agentDirectoryVersion: agentDirectoryVersion,
                isStreaming: false
            )
            let parsed = renderCache.assistantSegments(
                text: data.text,
                messageId: item.id,
                key: revisionKey
            )
            let hasImages = parsed.contains { segment in
                if case .image = segment.kind { return true }
                return false
            }

            if !hasImages,
               let first = parsed.first,
               case .markdown(let content, let identity) = first.kind {
                AssistantBubble(
                    markdownString: content,
                    markdownIdentity: identity,
                    label: assistantLabel,
                    themeVersion: themeManager.themeVersion
                )
            } else {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let assistantLabel {
                            Text(assistantLabel)
                                .shitterFont(.caption2, weight: .semibold)
                                .foregroundColor(ShitterTheme.textSecondary)
                        }
                        ForEach(parsed) { segment in
                            switch segment.kind {
                            case .markdown(let content, _):
                                StructuredText(markdown: content)
                                    .shitterContentMarkdown()
                            case .image(let image):
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 300)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 20)
                }
            }
        }
    }

    private func handleWidgetMessage(_ body: Any) {
        guard let dict = body as? [String: Any],
              let type = dict["_type"] as? String else { return }
        switch type {
        case "sendPrompt":
            if let text = dict["text"] as? String, !text.isEmpty {
                onWidgetPrompt(text)
            }
        case "openLink":
            if let urlString = dict["url"] as? String, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
    }

    private func makeFileChangeModel(_ data: ConversationFileChangeData) -> ToolCallCardModel {
        let changedPaths = data.changes.map(\.path)
        let summary: String
        if let first = changedPaths.first {
            summary = changedPaths.count == 1 ? "Changed \(first)" : "Changed \(changedPaths.count) files"
        } else {
            summary = "File changes"
        }

        var sections: [ToolCallSection] = []
        if !changedPaths.isEmpty {
            sections.append(.list(label: "Files", items: changedPaths))
        }
        let diffSections = data.changes.compactMap { change -> ToolCallSection? in
            guard !change.diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return .diff(label: change.path, content: change.diff)
        }
        sections.append(contentsOf: diffSections)
        if let outputDelta = data.outputDelta?.trimmingCharacters(in: .whitespacesAndNewlines), !outputDelta.isEmpty {
            sections.append(.text(label: "Output", content: outputDelta))
        }

        return ToolCallCardModel(
            kind: .fileChange,
            title: "File Change",
            summary: summary,
            status: toolCallStatus(from: data.status),
            duration: nil,
            sections: sections
        )
    }

    private func makeMcpModel(_ data: ConversationMcpToolCallData) -> ToolCallCardModel {
        var sections: [ToolCallSection] = []
        if let arguments = data.argumentsJSON, !arguments.isEmpty {
            sections.append(.json(label: "Arguments", content: arguments))
        }
        if let contentSummary = data.contentSummary, !contentSummary.isEmpty {
            sections.append(.text(label: "Result", content: contentSummary))
        }
        if let structured = data.structuredContentJSON, !structured.isEmpty {
            sections.append(.json(label: "Structured", content: structured))
        }
        if let raw = data.rawOutputJSON, !raw.isEmpty {
            sections.append(.json(label: "Raw Output", content: raw))
        }
        if !data.progressMessages.isEmpty {
            sections.append(.progress(label: "Progress", items: data.progressMessages))
        }
        if let error = data.errorMessage, !error.isEmpty {
            sections.append(.text(label: "Error", content: error))
        }

        let summary = data.server.isEmpty
            ? data.tool
            : "\(data.server).\(data.tool)"

        return ToolCallCardModel(
            kind: .mcpToolCall,
            title: "MCP Tool Call",
            summary: summary,
            status: toolCallStatus(from: data.status),
            duration: formatDuration(data.durationMs),
            sections: sections
        )
    }

    private func makeDynamicToolModel(_ data: ConversationDynamicToolCallData) -> ToolCallCardModel {
        var sections: [ToolCallSection] = []
        if let arguments = data.argumentsJSON, !arguments.isEmpty {
            sections.append(.json(label: "Arguments", content: arguments))
        }
        if let contentSummary = data.contentSummary, !contentSummary.isEmpty {
            sections.append(.text(label: "Result", content: contentSummary))
        }
        if let success = data.success {
            sections.insert(
                .kv(label: "Metadata", entries: [ToolCallKeyValue(key: "Success", value: success ? "true" : "false")]),
                at: 0
            )
        }

        return ToolCallCardModel(
            kind: .mcpToolCall,
            title: "Dynamic Tool Call",
            summary: data.tool,
            status: toolCallStatus(from: data.status),
            duration: formatDuration(data.durationMs),
            sections: sections
        )
    }

    private func makeWebSearchModel(_ data: ConversationWebSearchData) -> ToolCallCardModel {
        var sections: [ToolCallSection] = []
        if !data.query.isEmpty {
            sections.append(.text(label: "Query", content: data.query))
        }
        if let action = data.actionJSON, !action.isEmpty {
            sections.append(.json(label: "Action", content: action))
        }
        return ToolCallCardModel(
            kind: .webSearch,
            title: "Web Search",
            summary: data.query.isEmpty ? "Web search" : "Web search for \(data.query)",
            status: data.isInProgress ? .inProgress : .completed,
            duration: nil,
            sections: sections
        )
    }
}

private struct ConversationExplorationGroupRow: View {
    let id: String
    let items: [ConversationItem]

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: toggleExpanded) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .shitterFont(size: 12, weight: .semibold)
                        .foregroundColor(ShitterTheme.textSecondary)
                    Text(summaryText)
                        .shitterFont(.caption)
                        .foregroundColor(ShitterTheme.textSystem)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .shitterFont(size: 11, weight: .medium)
                        .foregroundColor(ShitterTheme.textMuted)
                }
            }
            .buttonStyle(.plain)

            let visibleItems = expanded ? items : Array(items.prefix(3))
            VStack(alignment: .leading, spacing: 6) {
                ForEach(visibleItems) { item in
                    if case .commandExecution(let data) = item.content {
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(data.isInProgress ? ShitterTheme.warning : ShitterTheme.textMuted)
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
                            Text(explorationLabel(for: data))
                                .shitterFont(.caption)
                                .foregroundColor(ShitterTheme.textSecondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                if !expanded && items.count > visibleItems.count {
                    Text("+\(items.count - visibleItems.count) more")
                        .shitterFont(.caption2)
                        .foregroundColor(ShitterTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var summaryText: String {
        let count = items.count
        if let first = items.first,
           case .commandExecution(let data) = first.content {
            let prefix = data.isInProgress ? "Exploring" : "Explored"
            return count == 1 ? "\(prefix) 1 location" : "\(prefix) \(count) locations"
        }
        return count == 1 ? "Exploration" : "\(count) exploration steps"
    }

    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.5)) {
            expanded.toggle()
        }
    }

    private func explorationLabel(for data: ConversationCommandExecutionData) -> String {
        if let action = data.actions.first {
            switch action.kind {
            case .read:
                return action.path.map { "Read \($0)" } ?? action.command
            case .search:
                if let query = action.query, let path = action.path {
                    return "Searched for \(query) in \(path)"
                }
                if let query = action.query {
                    return "Searched for \(query)"
                }
                return action.command
            case .listFiles:
                return action.path.map { "Listed files in \($0)" } ?? action.command
            case .unknown:
                break
            }
        }
        return data.command
    }
}

private struct ConversationCommandExecutionRow: View {
    let item: ConversationItem
    let data: ConversationCommandExecutionData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            shellLine
            ConversationCommandOutputViewport(
                output: renderedOutput,
                status: toolCallStatus(from: data.status),
                durationText: formatDuration(data.durationMs)
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var shellLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("$")
                .shitterMonoFont(size: 12, weight: .semibold)
                .foregroundColor(ShitterTheme.warning)

            Text(data.command.isEmpty ? "command" : data.command)
                .shitterMonoFont(size: 12)
                .foregroundColor(ShitterTheme.textSystem)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var renderedOutput: String {
        let trimmed = data.output?.trimmingCharacters(in: .newlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
        return data.isInProgress ? "Waiting for output…" : "No output"
    }
}

private struct ConversationCommandOutputViewport: View {
    let output: String
    let status: ToolCallStatus
    let durationText: String?
    @Environment(\.textScale) private var textScale

    private let bottomAnchorId = "command-output-bottom"

    private var lineFontSize: CGFloat {
        11 * textScale
    }

    private var viewportHeight: CGFloat {
        (ShitterFont.uiMonoFont(size: lineFontSize).lineHeight * 3) + 16
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: output)
                        .shitterMonoFont(size: 11)
                        .foregroundColor(ShitterTheme.textBody)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorId)
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .frame(height: viewportHeight)
            .background(ShitterTheme.codeBackground.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [ShitterTheme.codeBackground.opacity(0.96), ShitterTheme.codeBackground.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                if let durationText, !durationText.isEmpty {
                    Text(durationText)
                        .foregroundColor(statusColor)
                        .accessibilityLabel(durationAccessibilityLabel(durationText))
                        .shitterFont(.caption2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(alignment: .bottom) {
                            LinearGradient(
                                colors: [.clear, ShitterTheme.codeBackground.opacity(0.94)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(ShitterTheme.border.opacity(0.35), lineWidth: 1)
            }
            .onAppear {
                scrollToBottom(proxy)
            }
            .onChange(of: output) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private var statusColor: Color {
        switch status {
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
        switch status {
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

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo(bottomAnchorId, anchor: .bottom)
        }
    }
}

private struct ConversationReasoningRow: View {
    let data: ConversationReasoningData

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(reasoningText)
                .shitterFont(.footnote)
                .italic()
                .foregroundColor(ShitterTheme.textSecondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 20)
        }
    }

    private var reasoningText: String {
        (data.summary + data.content)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }
}

private struct ConversationTodoListRow: View {
    let data: ConversationTodoListData
    private let bodySize: CGFloat = 13
    private let codeSize: CGFloat = 12
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggleExpanded) {
                HStack(spacing: 8) {
                    Image(systemName: headerIconName)
                        .shitterFont(size: 12, weight: .semibold)
                        .foregroundColor(headerTint)
                    Text("To Do")
                        .shitterFont(.caption, weight: .semibold)
                        .foregroundColor(ShitterTheme.textPrimary)
                    Text(summaryText)
                        .shitterFont(.caption2, weight: .semibold)
                        .foregroundColor(progressTint)
                    Spacer(minLength: 8)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .shitterFont(size: 11, weight: .medium)
                        .foregroundColor(ShitterTheme.textMuted)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if expanded {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(data.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 8) {
                                todoStatusView(for: step.status)
                                    .padding(.top, 2)
                                Text("\(index + 1).")
                                    .shitterFont(.caption, weight: .semibold)
                                    .foregroundColor(ShitterTheme.textMuted)
                                    .padding(.top, 1)
                                StructuredText(markdown: step.step)
                                    .shitterContentMarkdown(bodySize: bodySize, codeSize: codeSize)
                                    .strikethrough(step.status == .completed, color: ShitterTheme.textMuted)
                                    .opacity(step.status == .completed ? 0.78 : 1.0)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(10)
                }
                .frame(maxHeight: 160)
                .background(ShitterTheme.surface.opacity(0.45))
                .mask {
                    VStack(spacing: 0) {
                        Rectangle().fill(.black)
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 18)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var completedCount: Int {
        data.completedCount
    }

    private var hasInProgressStep: Bool {
        data.steps.contains { $0.status == .inProgress }
    }

    private var headerIconName: String {
        if data.isComplete { return "checkmark.circle.fill" }
        if hasInProgressStep { return "checklist.checked" }
        return "checklist"
    }

    private var headerTint: Color {
        if data.isComplete { return ShitterTheme.success }
        if hasInProgressStep { return ShitterTheme.warning }
        return ShitterTheme.accent
    }

    private var summaryText: String {
        "\(completedCount) out of \(data.steps.count) task\(data.steps.count == 1 ? "" : "s") completed"
    }

    private var progressTint: Color {
        data.isComplete ? ShitterTheme.success : (hasInProgressStep ? ShitterTheme.warning : ShitterTheme.textSecondary)
    }

    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.2)) {
            expanded.toggle()
        }
    }

    @ViewBuilder
    private func todoStatusView(for status: ConversationPlanStepStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .shitterFont(size: 11, weight: .semibold)
                .foregroundColor(ShitterTheme.textMuted)
        case .inProgress:
            ProgressView()
                .controlSize(.mini)
                .tint(ShitterTheme.warning)
                .frame(width: 11, height: 11)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .shitterFont(size: 11, weight: .semibold)
                .foregroundColor(ShitterTheme.success)
        }
    }
}

private struct ConversationProposedPlanRow: View {
    let data: ConversationProposedPlanData
    let renderMode: ConversationTurnRenderMode

    private var trimmedContent: String? {
        let trimmed = data.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        if let trimmedContent {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle.portrait.fill")
                        .shitterFont(size: 12, weight: .semibold)
                        .foregroundColor(ShitterTheme.accent)
                    Text("Plan")
                        .shitterFont(.caption, weight: .semibold)
                        .foregroundColor(ShitterTheme.textPrimary)
                }

                if renderMode == .rich {
                    StructuredText(markdown: trimmedContent)
                        .shitterSystemMarkdown()
                } else {
                    ConversationPlainTextBlock(
                        text: trimmedContent,
                        font: .caption,
                        foregroundColor: ShitterTheme.textSecondary
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
}

private struct ConversationTurnDiffRow: View {
    let data: ConversationTurnDiffData
    @State private var showingDetails = false

    var body: some View {
        Button {
            showingDetails = true
        } label: {
            DiffIndicatorLabel(diff: data.diff)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetails) {
            ConversationDiffDetailSheet(
                title: "Turn Diff",
                diff: data.diff
            )
        }
    }
}

private struct ConversationToolCardRow: View {
    let model: ToolCallCardModel

    var body: some View {
        ToolCallCardView(model: model)
    }
}

private struct ConversationUserInputResponseRow: View {
    let data: ConversationUserInputResponseData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.bubble.fill")
                    .shitterFont(size: 12, weight: .semibold)
                    .foregroundColor(ShitterTheme.warning)
                Text("Requested Input")
                    .shitterFont(.caption, weight: .semibold)
                    .foregroundColor(ShitterTheme.textPrimary)
            }

            ForEach(Array(data.questions.enumerated()), id: \.element.id) { _, question in
                VStack(alignment: .leading, spacing: 4) {
                    if let header = question.header, !header.isEmpty {
                        Text(header.uppercased())
                            .shitterFont(.caption2, weight: .bold)
                            .foregroundColor(ShitterTheme.textSecondary)
                    }
                    Text(question.question)
                        .shitterFont(.caption, weight: .semibold)
                        .foregroundColor(ShitterTheme.textPrimary)
                    Text(question.answer)
                        .shitterFont(.caption)
                        .foregroundColor(ShitterTheme.textSecondary)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct ConversationDividerRow: View {
    let kind: ConversationDividerKind

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(ShitterTheme.border)
                .frame(height: 1)
            dividerContent
            Capsule()
                .fill(ShitterTheme.border)
                .frame(height: 1)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var dividerContent: some View {
        switch kind {
        case .contextCompaction(let isComplete):
            HStack(spacing: 6) {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .shitterFont(size: 10, weight: .semibold)
                        .foregroundColor(ShitterTheme.success)
                } else {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(ShitterTheme.warning)
                }

                Text(title)
                    .shitterFont(.caption2, weight: .semibold)
                    .foregroundColor(isComplete ? ShitterTheme.textMuted : ShitterTheme.warning)
                    .lineLimit(1)
            }
        default:
            Text(title)
                .shitterFont(.caption2, weight: .semibold)
                .foregroundColor(ShitterTheme.textMuted)
                .lineLimit(1)
        }
    }

    private var title: String {
        switch kind {
        case .contextCompaction(let isComplete):
            return isComplete ? "Context compacted" : "Compacting context"
        case .modelRerouted(let fromModel, let toModel, let reason):
            let base = fromModel.map { "\($0) -> \(toModel)" } ?? "Routed to \(toModel)"
            if let reason, !reason.isEmpty {
                return "\(base) · \(reason)"
            }
            return base
        case .reviewEntered(let review):
            return review.isEmpty ? "Entered review" : "Entered review: \(review)"
        case .reviewExited(let review):
            return review.isEmpty ? "Exited review" : "Exited review: \(review)"
        case .workedFor(let duration):
            return duration
        case .generic(let title, let detail):
            if let detail, !detail.isEmpty {
                return "\(title): \(detail)"
            }
            return title
        }
    }
}

private struct ConversationSystemCardRow: View {
    let title: String
    let content: String
    let accent: Color
    let iconName: String
    var renderMode: ConversationTurnRenderMode = .rich

    var bodyView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .shitterFont(size: 11, weight: .semibold)
                    .foregroundColor(accent)
                Text(title.uppercased())
                    .shitterFont(.caption2, weight: .bold)
                    .foregroundColor(accent)
            }
            if !content.isEmpty {
                if renderMode == .rich {
                    StructuredText(markdown: content)
                        .shitterSystemMarkdown()
                } else {
                    ConversationPlainTextBlock(
                        text: content,
                        font: .caption,
                        foregroundColor: ShitterTheme.textSecondary
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View { bodyView }
}

struct ConversationPinnedContextStrip: View {
    let items: [ConversationItem]
    @State private var todoExpanded = false
    @State private var selectedDiff: PresentedDiff?

    var body: some View {
        if pinnedPlan != nil || pinnedDiff != nil {
            VStack(alignment: .leading, spacing: 8) {
                if let plan = pinnedPlan, let diff = pinnedDiff {
                    HStack(alignment: .top, spacing: 10) {
                        compactTodoAccordion(for: plan)
                            .layoutPriority(1)
                        diffIndicatorButton(for: diff)
                    }
                } else {
                    if let plan = pinnedPlan {
                        compactTodoAccordion(for: plan)
                    }

                    if let diff = pinnedDiff {
                        diffIndicatorButton(for: diff)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .sheet(item: $selectedDiff) { presentedDiff in
                ConversationDiffDetailSheet(
                    title: presentedDiff.title,
                    diff: presentedDiff.diff
                )
            }
        }
    }

    private var pinnedPlan: ConversationItem? {
        items.last(where: {
            if case .todoList(let data) = $0.content {
                return !data.steps.isEmpty
            }
            return false
        })
    }

    private var pinnedDiff: ConversationItem? {
        items.last(where: {
            if case .turnDiff = $0.content { return true }
            return false
        })
    }

    @ViewBuilder
    private func compactTodoAccordion(for item: ConversationItem) -> some View {
        if case .todoList(let data) = item.content {
            let completed = data.completedCount
            let total = data.steps.count
            let summary: String = {
                if completed == 0 {
                    return "To do list created with \(total) tasks"
                }
                return "\(completed) out of \(total) tasks completed"
            }()

            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        todoExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: completed == total && total > 0 ? "checkmark.circle.fill" : "checklist")
                            .shitterFont(size: 11, weight: .semibold)
                            .foregroundColor(completed == total && total > 0 ? ShitterTheme.success : ShitterTheme.accent)
                        Text(summary)
                            .shitterFont(.caption, weight: .semibold)
                            .foregroundColor(ShitterTheme.textPrimary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.down")
                            .shitterFont(size: 11, weight: .medium)
                            .foregroundColor(ShitterTheme.textMuted)
                            .rotationEffect(.degrees(todoExpanded ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                if todoExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(data.steps.enumerated()), id: \.offset) { _, step in
                            HStack(alignment: .top, spacing: 8) {
                                compactTodoStatusView(for: step.status)
                                    .padding(.top, 2)
                                StructuredText(markdown: step.step)
                                    .shitterContentMarkdown(bodySize: 12, codeSize: 11)
                                    .strikethrough(step.status == .completed, color: ShitterTheme.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    @ViewBuilder
    private func compactTodoStatusView(for status: ConversationPlanStepStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .shitterFont(size: 10, weight: .semibold)
                .foregroundColor(ShitterTheme.textMuted)
        case .inProgress:
            ProgressView()
                .controlSize(.mini)
                .tint(ShitterTheme.warning)
                .frame(width: 10, height: 10)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .shitterFont(size: 10, weight: .semibold)
                .foregroundColor(ShitterTheme.success)
        }
    }

    @ViewBuilder
    private func diffIndicatorButton(for item: ConversationItem) -> some View {
        if case .turnDiff(let data) = item.content {
            Button {
                selectedDiff = PresentedDiff(
                    id: item.id,
                    title: "Turn Diff",
                    diff: data.diff
                )
            } label: {
                DiffIndicatorLabel(diff: data.diff)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ConversationPlainAssistantRow: View {
    let data: ConversationAssistantMessageData
    let label: String?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                if let label {
                    Text(label)
                        .shitterFont(.caption2, weight: .semibold)
                        .foregroundColor(ShitterTheme.textSecondary)
                }

                ConversationPlainTextBlock(
                    text: data.text,
                    font: .body,
                    foregroundColor: ShitterTheme.textBody
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 20)
        }
    }
}

private struct ConversationPlainTextBlock: View {
    let text: String
    let font: Font.TextStyle
    var weight: Font.Weight = .regular
    let foregroundColor: Color

    var body: some View {
        Text(verbatim: text.isEmpty ? " " : text)
            .shitterFont(font, weight: weight)
            .foregroundColor(foregroundColor)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PresentedDiff: Identifiable {
    let id: String
    let title: String
    let diff: String
}

private struct DiffStats {
    let additions: Int
    let deletions: Int

    var hasChanges: Bool {
        additions > 0 || deletions > 0
    }
}

private struct DiffIndicatorLabel: View {
    let diff: String

    private var stats: DiffStats {
        summarizeDiff(diff)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .shitterFont(size: 11, weight: .semibold)
                .foregroundColor(ShitterTheme.accent)

            if stats.hasChanges {
                HStack(spacing: 6) {
                    Text("+\(stats.additions)")
                        .shitterFont(.caption2, weight: .semibold)
                        .foregroundColor(ShitterTheme.success)
                    Text("-\(stats.deletions)")
                        .shitterFont(.caption2, weight: .semibold)
                        .foregroundColor(ShitterTheme.danger)
                }
            } else {
                Text("Diff")
                    .shitterFont(.caption2, weight: .semibold)
                    .foregroundColor(ShitterTheme.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(ShitterTheme.surface.opacity(0.72))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if stats.hasChanges {
            return "Show diff details. \(stats.additions) additions, \(stats.deletions) deletions."
        }
        return "Show diff details."
    }
}

private struct ConversationDiffDetailSheet: View {
    let title: String
    let diff: String
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    private var stats: DiffStats {
        summarizeDiff(diff)
    }

    private var lines: [String] {
        diff.components(separatedBy: .newlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("+\(stats.additions)")
                            .shitterFont(.caption2, weight: .semibold)
                            .foregroundColor(ShitterTheme.success)
                        Text("-\(stats.deletions)")
                            .shitterFont(.caption2, weight: .semibold)
                            .foregroundColor(ShitterTheme.danger)
                    }

                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            ConversationDiffLineView(
                                line: line
                            )
                        }
                    }
                    .textSelection(.enabled)
                }
                .padding(16)
            }
            .background(ShitterTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .id(themeManager.themeVersion)
    }
}

private struct ConversationDiffLineView: View {
    let line: String

    var body: some View {
        Text(verbatim: line.isEmpty ? " " : line)
            .shitterMonoFont(size: 12)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var foregroundColor: Color {
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

    private var backgroundColor: Color {
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
}

private func summarizeDiff(_ diff: String) -> DiffStats {
    var additions = 0
    var deletions = 0

    for line in diff.split(whereSeparator: \.isNewline) {
        if line.hasPrefix("+"), !line.hasPrefix("+++") {
            additions += 1
        } else if line.hasPrefix("-"), !line.hasPrefix("---") {
            deletions += 1
        }
    }

    return DiffStats(additions: additions, deletions: deletions)
}

private func toolCallStatus(from rawStatus: String) -> ToolCallStatus {
    let normalized = rawStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalized.contains("progress") || normalized.contains("running") || normalized.contains("pending") {
        return .inProgress
    }
    if normalized.contains("fail") || normalized.contains("error") || normalized.contains("denied") {
        return .failed
    }
    if normalized.contains("complete") || normalized.contains("success") || normalized.contains("done") || normalized == "ok" {
        return .completed
    }
    return .unknown
}

private func formatDuration(_ durationMs: Int?) -> String? {
    guard let durationMs, durationMs >= 0 else { return nil }
    if durationMs >= 1_000 {
        return String(format: "%.1fs", Double(durationMs) / 1_000.0)
    }
    return "\(durationMs)ms"
}
