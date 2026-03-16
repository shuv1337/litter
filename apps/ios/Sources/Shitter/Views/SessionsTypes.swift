import Foundation

extension ThreadState {
    var sessionTitle: String {
        let trimmed = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled session" : trimmed
    }

    var sessionModelLabel: String? {
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else { return nil }
        if let agentLabel = agentDisplayLabel {
            return "\(trimmedModel) (\(agentLabel))"
        }
        return trimmedModel
    }
}

enum WorkspaceSortMode: String, CaseIterable, Identifiable {
    case mostRecent
    case name
    case date

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mostRecent:
            return "Most Recent"
        case .name:
            return "Name"
        case .date:
            return "Date"
        }
    }
}

struct WorkspaceSessionGroup: Identifiable {
    let id: String
    let serverId: String
    let serverName: String
    let serverHost: String
    let workspacePath: String
    let workspaceTitle: String
    let latestUpdatedAt: Date
    let threads: [ThreadState]
    let treeRoots: [SessionTreeNode]
}

struct WorkspaceGroupSection: Identifiable {
    let id: String
    let title: String?
    let groups: [WorkspaceSessionGroup]
}

struct SessionTreeNode: Identifiable {
    let thread: ThreadState
    let children: [SessionTreeNode]

    var id: ThreadKey { thread.key }
}

struct SessionsDerivedData {
    static let empty = SessionsDerivedData(
        allThreads: [],
        allThreadKeys: [],
        filteredThreads: [],
        filteredThreadKeys: [],
        workspaceSections: [],
        workspaceGroupIDs: [],
        workspaceGroupIDByThreadKey: [:],
        parentByKey: [:],
        siblingsByKey: [:],
        childrenByKey: [:]
    )

    let allThreads: [ThreadState]
    let allThreadKeys: [ThreadKey]
    let filteredThreads: [ThreadState]
    let filteredThreadKeys: [ThreadKey]
    let workspaceSections: [WorkspaceGroupSection]
    let workspaceGroupIDs: [String]
    let workspaceGroupIDByThreadKey: [ThreadKey: String]
    let parentByKey: [ThreadKey: ThreadState]
    let siblingsByKey: [ThreadKey: [ThreadState]]
    let childrenByKey: [ThreadKey: [ThreadState]]
}

func normalizedWorkspacePath(_ raw: String) -> String {
    var path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if path.isEmpty {
        return "/"
    }
    path = path.replacingOccurrences(of: "/+", with: "/", options: .regularExpression)
    while path.count > 1 && path.hasSuffix("/") {
        path.removeLast()
    }
    return path.isEmpty ? "/" : path
}

@MainActor
func workspaceGroupID(for thread: ThreadState) -> String {
    "\(thread.serverId)::\(normalizedWorkspacePath(thread.cwd))"
}

func workspaceTitle(for workspacePath: String) -> String {
    if workspacePath == "/" {
        return "/"
    }
    let name = URL(fileURLWithPath: workspacePath).lastPathComponent
    return name.isEmpty ? workspacePath : name
}
