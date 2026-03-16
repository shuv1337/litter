import XCTest
@testable import Shitter

@MainActor
final class ConversationPlanSemanticsTests: XCTestCase {
    func testResumedPlanItemDecodesAsProposedPlan() throws {
        let data = """
        {
          "type": "plan",
          "id": "plan-1",
          "text": "# Final plan\\n- first\\n- second\\n"
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(ResumedThreadItem.self, from: data)

        guard case .proposedPlan(let content, _) = item else {
            return XCTFail("Expected proposed plan item")
        }
        XCTAssertEqual(content, "# Final plan\n- first\n- second\n")
    }

    func testResumedTodoListDecodesChecklistEntries() throws {
        let data = """
        {
          "type": "todo-list",
          "id": "todo-1",
          "plan": [
            { "step": "Inspect renderer", "status": "completed" },
            { "step": "Patch iOS client", "status": "in_progress" }
          ]
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(ResumedThreadItem.self, from: data)

        guard case .todoList(let entries, _) = item else {
            return XCTFail("Expected todo list item")
        }
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].step, "Inspect renderer")
        XCTAssertEqual(entries[0].status, "completed")
        XCTAssertEqual(entries[1].step, "Patch iOS client")
        XCTAssertEqual(entries[1].status, "in_progress")
    }

    func testTurnPlanUpdatedCreatesTodoListItem() async {
        let manager = ServerManager()
        let key = ThreadKey(serverId: "server-1", threadId: "thread-1")
        let thread = ThreadState(serverId: key.serverId, threadId: key.threadId, serverName: "Preview", serverSource: .manual)
        manager.threads[key] = thread

        let payload = """
        {
          "params": {
            "threadId": "thread-1",
            "turnId": "turn-1",
            "plan": [
              { "step": "Inspect renderer", "status": "pending" },
              { "step": "Patch iOS client", "status": "in_progress" }
            ]
          }
        }
        """.data(using: .utf8)!

        await manager.handleNotification(serverId: key.serverId, method: "turn/plan/updated", data: payload)

        XCTAssertEqual(thread.items.count, 1)
        guard case .todoList(let data) = thread.items[0].content else {
            return XCTFail("Expected todo list content")
        }
        XCTAssertEqual(data.steps.map(\.step), ["Inspect renderer", "Patch iOS client"])
        XCTAssertEqual(data.steps.map(\.status), [.pending, .inProgress])
    }

    func testPlanDeltaCreatesProposedPlanItem() async {
        let manager = ServerManager()
        let key = ThreadKey(serverId: "server-1", threadId: "thread-1")
        let thread = ThreadState(serverId: key.serverId, threadId: key.threadId, serverName: "Preview", serverSource: .manual)
        manager.threads[key] = thread
        thread.activeTurnId = "turn-1"

        let payload = """
        {
          "params": {
            "threadId": "thread-1",
            "turnId": "turn-1",
            "itemId": "plan-item-1",
            "delta": "# Final plan\\n- first\\n"
          }
        }
        """.data(using: .utf8)!

        await manager.handleNotification(serverId: key.serverId, method: "item/plan/delta", data: payload)

        XCTAssertEqual(thread.items.count, 1)
        guard case .proposedPlan(let data) = thread.items[0].content else {
            return XCTFail("Expected proposed plan content")
        }
        XCTAssertEqual(data.content, "# Final plan\n- first")
    }
}
