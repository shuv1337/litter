import Foundation

@MainActor
enum HomeDashboardSupport {
    static func recentConnectedSessions(
        from threads: [ThreadState],
        connectedServerIds: Set<String>,
        limit: Int = 3
    ) -> [ThreadState] {
        Array(
            threads
                .filter { connectedServerIds.contains($0.serverId) }
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(limit)
        )
    }

    static func sortedConnectedServers(
        from connections: [ServerConnection],
        activeServerId: String?
    ) -> [ServerConnection] {
        var seenServerKeys: Set<String> = []

        return connections
            .filter(\.isConnected)
            .sorted { lhs, rhs in
                let lhsIsActive = lhs.id == activeServerId
                let rhsIsActive = rhs.id == activeServerId
                if lhsIsActive != rhsIsActive {
                    return lhsIsActive && !rhsIsActive
                }

                let byName = lhs.server.name.localizedCaseInsensitiveCompare(rhs.server.name)
                if byName != .orderedSame {
                    return byName == .orderedAscending
                }

                return lhs.id < rhs.id
            }
            .filter { connection in
                seenServerKeys.insert(connection.server.deduplicationKey).inserted
            }
    }

    static func serverSubtitle(for server: DiscoveredServer) -> String {
        if server.source == .local {
            return "In-process server"
        }

        let visiblePort = server.hasCodexServer ? server.port : server.sshPort
        let hostAndPort = if let port = visiblePort {
            "\(server.hostname):\(port)"
        } else {
            server.hostname
        }

        if server.hasCodexServer {
            return "\(hostAndPort) | \(server.source.rawString)"
        }

        return "\(hostAndPort) | ssh via \(server.source.rawString)"
    }

    static func workspaceLabel(for thread: ThreadState) -> String? {
        let trimmed = thread.cwd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lastPathComponent = URL(fileURLWithPath: trimmed).lastPathComponent
        return lastPathComponent.isEmpty ? trimmed : lastPathComponent
    }
}
