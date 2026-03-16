import Foundation
import Observation

@MainActor
@Observable
final class HomeDashboardModel {
    private struct Snapshot {
        let connectedServers: [ServerConnection]
        let recentSessions: [ThreadState]
    }

    private(set) var connectedServers: [ServerConnection] = []
    private(set) var recentSessions: [ThreadState] = []

    @ObservationIgnored private weak var serverManager: ServerManager?
    @ObservationIgnored private(set) var rebuildCount = 0
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var observationGeneration = 0

    func bind(serverManager: ServerManager) {
        self.serverManager = serverManager
        guard isActive else { return }
        refreshState()
    }

    func activate() {
        guard !isActive else { return }
        isActive = true
        refreshState()
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        observationGeneration &+= 1
    }

    private func refreshState() {
        guard isActive, let serverManager else {
            connectedServers = []
            recentSessions = []
            return
        }

        observationGeneration &+= 1
        let generation = observationGeneration
        let snapshot = withObservationTracking {
            let nextConnectedServers = HomeDashboardSupport.sortedConnectedServers(
                from: Array(serverManager.connections.values),
                activeServerId: serverManager.activeThreadKey?.serverId
            )
            let nextRecentSessions = HomeDashboardSupport.recentConnectedSessions(
                from: serverManager.sortedThreads,
                connectedServerIds: Set(nextConnectedServers.map(\.id))
            )
            return Snapshot(
                connectedServers: nextConnectedServers,
                recentSessions: nextRecentSessions
            )
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isActive, self.observationGeneration == generation else { return }
                self.refreshState()
            }
        }

        rebuildCount += 1
        connectedServers = snapshot.connectedServers
        recentSessions = snapshot.recentSessions
    }
}
