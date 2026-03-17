import XCTest
@testable import Shitter

@MainActor
final class HomeDashboardSupportTests: XCTestCase {
    func testRecentConnectedSessionsFiltersDisconnectedServersAndLimitsToThreeNewest() {
        let threads = [
            makeThread(serverId: "server-b", threadId: "b-older", updatedAt: 20),
            makeThread(serverId: "server-a", threadId: "a-newest", updatedAt: 50),
            makeThread(serverId: "server-c", threadId: "c-disconnected", updatedAt: 60),
            makeThread(serverId: "server-a", threadId: "a-mid", updatedAt: 40),
            makeThread(serverId: "server-b", threadId: "b-mid", updatedAt: 30),
            makeThread(serverId: "server-a", threadId: "a-oldest", updatedAt: 10)
        ]

        let result = HomeDashboardSupport.recentConnectedSessions(
            from: threads,
            connectedServerIds: ["server-a", "server-b"],
            limit: 3
        )

        XCTAssertEqual(result.map(\.threadId), ["a-newest", "a-mid", "b-mid"])
    }

    func testDefaultConnectedServerIdPrefersPreferredThenActiveThenFirstConnected() {
        XCTAssertEqual(
            SessionLaunchSupport.defaultConnectedServerId(
                connectedServerIds: ["server-a", "server-b"],
                activeThreadKey: ThreadKey(serverId: "server-b", threadId: "thread-1"),
                preferredServerId: "server-a"
            ),
            "server-a"
        )

        XCTAssertEqual(
            SessionLaunchSupport.defaultConnectedServerId(
                connectedServerIds: ["server-a", "server-b"],
                activeThreadKey: ThreadKey(serverId: "server-b", threadId: "thread-1"),
                preferredServerId: "server-missing"
            ),
            "server-b"
        )

        XCTAssertEqual(
            SessionLaunchSupport.defaultConnectedServerId(
                connectedServerIds: ["server-a", "server-b"],
                activeThreadKey: nil,
                preferredServerId: nil
            ),
            "server-a"
        )

        XCTAssertNil(
            SessionLaunchSupport.defaultConnectedServerId(
                connectedServerIds: [],
                activeThreadKey: nil,
                preferredServerId: nil
            )
        )
    }

    func testSavedServerMigratesLegacySshPortIntoDedicatedField() throws {
        let data = """
        {
          "id": "legacy-ssh",
          "name": "Legacy SSH",
          "hostname": "mac-mini.local",
          "port": 9234,
          "source": "manual",
          "hasCodexServer": false,
          "wakeMAC": null,
          "sshPortForwardingEnabled": true
        }
        """.data(using: .utf8)!

        let saved = try JSONDecoder().decode(SavedServer.self, from: data)
        let discovered = saved.toDiscoveredServer()

        XCTAssertNil(discovered.port)
        XCTAssertEqual(discovered.sshPort, 9234)
        XCTAssertEqual(discovered.resolvedSSHPort, 9234)
        XCTAssertFalse(discovered.hasCodexServer)
    }

    func testAddServerInstallsNetworkMonitorCallbacks() async {
        let manager = ServerManager()
        let server = DiscoveredServer(
            id: "network-monitor-test",
            name: "Network Monitor Test",
            hostname: "network-monitor-test.local",
            port: 9234,
            source: .manual,
            hasCodexServer: true
        )
        defer { manager.removeServer(id: server.id) }

        XCTAssertFalse(manager.hasInstalledNetworkMonitorCallbacks)

        await manager.addServer(server, target: .remote(host: "", port: 9234))

        XCTAssertTrue(manager.hasInstalledNetworkMonitorCallbacks)
    }

    func testHomeDashboardModelRefreshesWhenObservedConnectionChanges() async {
        let server = DiscoveredServer(
            id: "server-a",
            name: "Server A",
            hostname: "server-a.local",
            port: 9234,
            source: .manual,
            hasCodexServer: true
        )
        let connection = ServerConnection(server: server, target: .remote(host: server.hostname, port: 9234))
        let manager = ServerManager()
        manager.connections = [server.id: connection]
        let model = HomeDashboardModel()
        model.bind(serverManager: manager)
        model.activate()

        connection.connectionHealth = .connected
        await flushMainQueue()

        XCTAssertEqual(model.connectedServers.map(\.id), [server.id])
    }

    func testHomeDashboardModelRefreshesRecentSessionsWhenObservedThreadChanges() async {
        let server = DiscoveredServer(
            id: "server-a",
            name: "Server A",
            hostname: "server-a.local",
            port: 9234,
            source: .manual,
            hasCodexServer: true
        )
        let connection = ServerConnection(server: server, target: .remote(host: server.hostname, port: 9234))
        connection.connectionHealth = .connected
        let olderThread = makeThread(serverId: server.id, threadId: "thread-older", updatedAt: 20)
        let newerThread = makeThread(serverId: server.id, threadId: "thread-newer", updatedAt: 40)
        let manager = ServerManager()
        manager.connections = [server.id: connection]
        manager.threads = [olderThread.key: olderThread, newerThread.key: newerThread]
        let model = HomeDashboardModel()
        model.bind(serverManager: manager)
        model.activate()

        olderThread.updatedAt = Date(timeIntervalSince1970: 60)
        await flushMainQueue()

        XCTAssertEqual(model.recentSessions.map(\.threadId), ["thread-older", "thread-newer"])
    }

    func testHomeDashboardModelRefreshesRecentSessionsWhenThreadsArriveAfterBind() async {
        let server = DiscoveredServer(
            id: "server-a",
            name: "Server A",
            hostname: "server-a.local",
            port: 9234,
            source: .manual,
            hasCodexServer: true
        )
        let connection = ServerConnection(server: server, target: .remote(host: server.hostname, port: 9234))
        connection.connectionHealth = .connected
        let manager = ServerManager()
        manager.connections = [server.id: connection]
        let model = HomeDashboardModel()
        model.bind(serverManager: manager)
        model.activate()

        let thread = makeThread(serverId: server.id, threadId: "thread-late", updatedAt: 80)
        manager.threads[thread.key] = thread
        await flushMainQueue()

        XCTAssertEqual(model.recentSessions.map(\.threadId), ["thread-late"])
    }

    func testHomeDashboardModelIgnoresThreadChangesWhileInactiveAndRefreshesOnReactivate() async {
        let server = DiscoveredServer(
            id: "server-a",
            name: "Server A",
            hostname: "server-a.local",
            port: 9234,
            source: .manual,
            hasCodexServer: true
        )
        let connection = ServerConnection(server: server, target: .remote(host: server.hostname, port: 9234))
        connection.connectionHealth = .connected
        let initialThread = makeThread(serverId: server.id, threadId: "thread-initial", updatedAt: 20)
        let lateThread = makeThread(serverId: server.id, threadId: "thread-late", updatedAt: 80)
        let manager = ServerManager()
        manager.connections = [server.id: connection]
        manager.threads = [initialThread.key: initialThread]
        let model = HomeDashboardModel()
        model.bind(serverManager: manager)
        model.activate()

        XCTAssertEqual(model.recentSessions.map(\.threadId), ["thread-initial"])
        let rebuildCountBeforeDeactivate = model.rebuildCount

        model.deactivate()
        manager.threads[lateThread.key] = lateThread
        await flushMainQueue()

        XCTAssertEqual(model.recentSessions.map(\.threadId), ["thread-initial"])
        XCTAssertEqual(model.rebuildCount, rebuildCountBeforeDeactivate)

        model.activate()
        await flushMainQueue()

        XCTAssertEqual(model.recentSessions.map(\.threadId), ["thread-late", "thread-initial"])
        XCTAssertGreaterThan(model.rebuildCount, rebuildCountBeforeDeactivate)
    }

    private func makeThread(serverId: String, threadId: String, updatedAt: TimeInterval) -> ThreadState {
        let thread = ThreadState(
            serverId: serverId,
            threadId: threadId,
            serverName: serverId,
            serverSource: .manual
        )
        thread.preview = threadId
        thread.updatedAt = Date(timeIntervalSince1970: updatedAt)
        return thread
    }

    private func flushMainQueue() async {
        await Task.yield()
        await Task.yield()
    }
}
