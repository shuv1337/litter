import Foundation
import Observation
import WatchConnectivity
import os

/// Relays Shitter state to the paired Apple Watch via WatchConnectivity.
/// Handles:
///   - Broadcasting thread list and server status (applicationContext)
///   - Sending approval requests (transferUserInfo, guaranteed delivery)
///   - Sending turn events (transferUserInfo)
///   - Real-time turn progress (sendMessage, when Watch is reachable)
///   - Receiving dictation replies and approval decisions from Watch
@MainActor
@Observable
final class WatchRelay: NSObject {
    nonisolated private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.latitudes.shitter.ios",
        category: "WatchRelay"
    )


    // MARK: - State

    var isWatchPaired: Bool = false
    var isWatchReachable: Bool = false

    // MARK: - Dependencies

    @ObservationIgnored
    weak var serverManager: ServerManager?

    // MARK: - Private

    @ObservationIgnored
    private var wcSession: WCSession?

    @ObservationIgnored
    private var lastBroadcastHash: Int = 0

    // MARK: - Lifecycle

    func activate() {
        guard WCSession.isSupported() else {
            Self.logger.info("WCSession not supported (no paired Watch)")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        wcSession = session
        Self.logger.info("WCSession activation requested")
    }

    // MARK: - Broadcast Thread State

    /// Call this after `refreshSessions()` completes or when thread state changes.
    func broadcastThreadState() {
        guard let sm = serverManager, let session = wcSession, session.activationState == .activated else { return }

        var threadDicts: [[String: Any]] = []
        for thread in sm.sortedThreads {
            let statusString: String
            switch thread.status {
            case .idle:       statusString = "idle"
            case .ready:      statusString = "ready"
            case .thinking:   statusString = "thinking"
            case .error:      statusString = "error"
            case .connecting: statusString = "connecting"
            }

            var dict: [String: Any] = [
                "id": thread.threadId,
                "serverId": thread.serverId,
                "serverName": thread.serverName,
                "preview": thread.preview,
                "status": statusString,
                "model": thread.model,
                "cwd": thread.cwd,
                "updatedAt": thread.updatedAt.timeIntervalSince1970
            ]

            if case .error(let message) = thread.status {
                dict["errorMessage"] = message
            }

            threadDicts.append(dict)
        }

        var serverDicts: [[String: Any]] = []
        for (id, conn) in sm.connections {
            let healthString: String
            switch conn.connectionHealth {
            case .connected:    healthString = "connected"
            case .disconnected: healthString = "disconnected"
            case .connecting:   healthString = "connecting"
            case .unresponsive: healthString = "unresponsive"
            }

            serverDicts.append([
                "id": id,
                "name": conn.server.name,
                "health": healthString
            ])
        }

        let context: [String: Any] = [
            "type": "threadSync",
            "threads": threadDicts,
            "servers": serverDicts
        ]

        // Deduplicate — don't send identical state
        let hash = "\(threadDicts.count)-\(serverDicts.count)-\(threadDicts.map { ($0["status"] as? String ?? "") + ($0["id"] as? String ?? "") }.joined())".hashValue
        guard hash != lastBroadcastHash else { return }
        lastBroadcastHash = hash

        do {
            try session.updateApplicationContext(context)
            Self.logger.info("Broadcast thread state: \(threadDicts.count) threads, \(serverDicts.count) servers")
        } catch {
            Self.logger.error("Failed to update applicationContext: \(error.localizedDescription)")
        }
    }

    // MARK: - Broadcast Approval Requests

    /// Send an approval request to the Watch. Uses transferUserInfo for guaranteed delivery.
    func sendApprovalToWatch(_ approval: ServerManager.PendingApproval) {
        guard let session = wcSession, session.activationState == .activated else { return }

        let payload: [String: Any] = [
            "type": "approval",
            "requestId": approval.requestId,
            "serverId": approval.serverId,
            "threadId": approval.threadId ?? "",
            "kind": approval.kind.rawValue,
            "command": approval.command ?? "",
            "cwd": approval.cwd ?? "",
            "reason": approval.reason ?? "",
            "createdAt": approval.createdAt.timeIntervalSince1970
        ]

        session.transferUserInfo(payload)
        Self.logger.info("Sent approval to Watch: \(approval.requestId)")
    }

    // MARK: - Broadcast Turn Events

    func sendTurnComplete(serverId: String, threadId: String, preview: String?) {
        guard let session = wcSession, session.activationState == .activated else { return }

        var payload: [String: Any] = [
            "type": "turnComplete",
            "serverId": serverId,
            "threadId": threadId
        ]
        if let preview { payload["preview"] = preview }

        session.transferUserInfo(payload)
        Self.logger.debug("Sent turnComplete to Watch for thread \(threadId)")
    }

    func sendTurnError(serverId: String, threadId: String, errorMessage: String?) {
        guard let session = wcSession, session.activationState == .activated else { return }

        var payload: [String: Any] = [
            "type": "turnError",
            "serverId": serverId,
            "threadId": threadId
        ]
        if let errorMessage { payload["errorMessage"] = errorMessage }

        session.transferUserInfo(payload)
        Self.logger.debug("Sent turnError to Watch for thread \(threadId)")
    }

    // MARK: - Real-time Turn Progress

    func sendTurnProgress(serverId: String, threadId: String, status: String, toolCallCount: Int) {
        guard let session = wcSession, session.isReachable else { return }

        let payload: [String: Any] = [
            "type": "turnProgress",
            "serverId": serverId,
            "threadId": threadId,
            "status": status,
            "toolCallCount": toolCallCount
        ]

        session.sendMessage(payload, replyHandler: nil, errorHandler: { error in
            Self.logger.debug("sendMessage turnProgress failed (Watch may be inactive): \(error.localizedDescription)")
        })
    }

    // MARK: - Approval Resolution

    func sendApprovalResolved(requestId: String) {
        guard let session = wcSession, session.activationState == .activated else { return }

        let payload: [String: Any] = [
            "type": "approvalResolved",
            "requestId": requestId
        ]

        session.transferUserInfo(payload)
        Self.logger.debug("Sent approvalResolved to Watch: \(requestId)")
    }
}

// MARK: - WCSessionDelegate

extension WatchRelay: WCSessionDelegate {

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error {
                Self.logger.error("WCSession activation failed: \(error.localizedDescription)")
            } else {
                Self.logger.info("WCSession activated: \(activationState.rawValue)")
                isWatchPaired = session.isPaired
                isWatchReachable = session.isReachable

                // Broadcast current state immediately
                broadcastThreadState()
            }
        }
    }

    // Required on iOS
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Self.logger.info("WCSession became inactive")
    }

    // Required on iOS
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Self.logger.info("WCSession deactivated, reactivating...")
        // Reactivate after deactivation (required for multi-Watch support)
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
            Self.logger.info("Watch reachability changed: \(session.isReachable)")
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchPaired = session.isPaired
            Self.logger.info("Watch state changed — paired: \(session.isPaired)")
        }
    }

    // MARK: - Receive from Watch

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handleWatchMessage(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            handleWatchMessage(message)
            replyHandler(["status": "ok"])
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            handleWatchMessage(userInfo)
        }
    }

    // MARK: - Message Routing

    @MainActor
    private func handleWatchMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else {
            Self.logger.warning("Received Watch message without type key")
            return
        }

        switch type {
        case "sendMessage":
            handleDictationReply(message)

        case "approvalResponse":
            handleApprovalResponse(message)

        case "refreshRequest":
            handleRefreshRequest()

        default:
            Self.logger.warning("Unknown Watch message type: \(type)")
        }
    }

    @MainActor
    private func handleDictationReply(_ message: [String: Any]) {
        guard let sm = serverManager,
              let serverId = message["serverId"] as? String,
              let threadId = message["threadId"] as? String,
              let text = message["text"] as? String else {
            Self.logger.error("Invalid dictation reply payload")
            return
        }

        Self.logger.info("Watch dictation reply: \"\(text)\" → server=\(serverId) thread=\(threadId)")

        let key = ThreadKey(serverId: serverId, threadId: threadId)
        if sm.threads[key] != nil {
            sm.activeThreadKey = key
            let thread = sm.threads[key]!
            Task {
                await sm.send(
                    text,
                    cwd: thread.cwd.isEmpty ? "/tmp" : thread.cwd,
                    approvalPolicy: "suggest"
                )
            }
        } else {
            Self.logger.error("Thread not found for Watch reply: \(threadId)")
        }
    }

    @MainActor
    private func handleApprovalResponse(_ message: [String: Any]) {
        guard let sm = serverManager,
              let requestId = message["requestId"] as? String,
              let decisionString = message["decision"] as? String else {
            Self.logger.error("Invalid approval response payload")
            return
        }

        let decision: ServerManager.ApprovalDecision
        switch decisionString {
        case "accept":            decision = .accept
        case "acceptForSession":  decision = .acceptForSession
        case "decline":           decision = .decline
        case "cancel":            decision = .cancel
        default:
            Self.logger.error("Unknown approval decision: \(decisionString)")
            return
        }

        Self.logger.info("Watch approval decision: \(decisionString) for \(requestId)")
        sm.respondToPendingApproval(requestId: requestId, decision: decision)
        sendApprovalResolved(requestId: requestId)
    }

    @MainActor
    private func handleRefreshRequest() {
        guard let sm = serverManager else { return }
        Self.logger.info("Watch requested thread refresh")
        Task {
            await sm.refreshAllSessions()
            broadcastThreadState()
        }
    }
}
