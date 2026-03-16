import XCTest
@testable import Shitter

@MainActor
final class ThreadOpenHydrationTests: XCTestCase {
    func testViewThreadDoesNotResumeFreshEmptyThread() async {
        let manager = ServerManager()
        let key = ThreadKey(serverId: "server-1", threadId: "thread-1")
        let thread = ThreadState(
            serverId: key.serverId,
            threadId: key.threadId,
            serverName: "Server 1",
            serverSource: .manual
        )
        thread.cwd = "/tmp/work"
        thread.requiresOpenHydration = false
        manager.threads[key] = thread

        let opened = await manager.viewThread(key)

        XCTAssertTrue(opened)
        XCTAssertEqual(manager.activeThreadKey, key)
        XCTAssertFalse(thread.requiresOpenHydration)
    }

    func testViewThreadStillRequiresResumeForSummaryOnlyEmptyThread() async {
        let manager = ServerManager()
        let key = ThreadKey(serverId: "server-1", threadId: "thread-1")
        let thread = ThreadState(
            serverId: key.serverId,
            threadId: key.threadId,
            serverName: "Server 1",
            serverSource: .manual
        )
        thread.cwd = "/tmp/work"
        manager.threads[key] = thread

        let opened = await manager.viewThread(key)

        XCTAssertFalse(opened)
        XCTAssertNil(manager.activeThreadKey)
        XCTAssertTrue(thread.requiresOpenHydration)
    }

    func testViewThreadMarksPopulatedThreadAsHydratedWithoutResume() async {
        let manager = ServerManager()
        let key = ThreadKey(serverId: "server-1", threadId: "thread-1")
        let thread = ThreadState(
            serverId: key.serverId,
            threadId: key.threadId,
            serverName: "Server 1",
            serverSource: .manual
        )
        thread.cwd = "/tmp/work"
        thread.items = [
            ConversationItem(
                id: "user-1",
                content: .user(.init(text: "hello", images: [])),
                sourceTurnIndex: 0,
                isFromUserTurnBoundary: true
            )
        ]
        manager.threads[key] = thread

        let opened = await manager.viewThread(key)

        XCTAssertTrue(opened)
        XCTAssertEqual(manager.activeThreadKey, key)
        XCTAssertFalse(thread.requiresOpenHydration)
    }
}
