import Foundation
import Observation

struct ConversationTranscriptSnapshot {
    var items: [ConversationItem]
    var threadStatus: ConversationStatus
    var followScrollToken: Int
    var agentDirectoryVersion: Int

    static let empty = ConversationTranscriptSnapshot(
        items: [],
        threadStatus: .ready,
        followScrollToken: 0,
        agentDirectoryVersion: 0
    )
}

struct ConversationComposerSnapshot {
    var threadKey: ThreadKey
    var pendingUserInputRequest: ServerManager.PendingUserInputRequest?
    var composerPrefillRequest: ServerManager.ComposerPrefillRequest?
    var isTurnActive: Bool
    var threadPreview: String
    var threadModel: String
    var threadReasoningEffort: String?
    var modelContextWindow: Int64?
    var contextTokensUsed: Int64?
    var rateLimits: RateLimitSnapshot?
    var availableModels: [CodexModel]
    var isConnected: Bool

    static let empty = ConversationComposerSnapshot(
        threadKey: ThreadKey(serverId: "", threadId: ""),
        pendingUserInputRequest: nil,
        composerPrefillRequest: nil,
        isTurnActive: false,
        threadPreview: "",
        threadModel: "",
        threadReasoningEffort: nil,
        modelContextWindow: nil,
        contextTokensUsed: nil,
        rateLimits: nil,
        availableModels: [],
        isConnected: false
    )
}

@MainActor
@Observable
final class ConversationScreenModel {
    private struct Snapshot {
        let items: [ConversationItem]
        let threadStatus: ConversationStatus
        let updatedAt: Date
        let isTurnActive: Bool
        let agentDirectoryVersion: Int
        let composer: ConversationComposerSnapshot
    }

    private(set) var transcript: ConversationTranscriptSnapshot = .empty
    private(set) var pinnedContextItems: [ConversationItem] = []
    private(set) var composer: ConversationComposerSnapshot = .empty

    @ObservationIgnored private var thread: ThreadState?
    @ObservationIgnored private var connection: ServerConnection?
    @ObservationIgnored private var serverManager: ServerManager?
    @ObservationIgnored private var followScrollToken = 0
    @ObservationIgnored private var observationGeneration = 0
    @ObservationIgnored private var lastObservedUpdatedAt: Date?

    func bind(
        thread: ThreadState,
        connection: ServerConnection,
        serverManager: ServerManager
    ) {
        let needsRebind =
            self.thread !== thread ||
            self.connection !== connection ||
            self.serverManager !== serverManager

        self.thread = thread
        self.connection = connection
        self.serverManager = serverManager

        if needsRebind {
            followScrollToken = 0
            lastObservedUpdatedAt = nil
        }

        refreshState()
    }

    private func refreshState() {
        guard let thread, let connection, let serverManager else {
            transcript = .empty
            pinnedContextItems = []
            composer = .empty
            lastObservedUpdatedAt = nil
            return
        }

        observationGeneration &+= 1
        let generation = observationGeneration
        let snapshot = withObservationTracking {
            Snapshot(
                items: thread.items,
                threadStatus: thread.status,
                updatedAt: thread.updatedAt,
                isTurnActive: thread.hasTurnActive,
                agentDirectoryVersion: serverManager.agentDirectoryVersion,
                composer: ConversationComposerSnapshot(
                    threadKey: thread.key,
                    pendingUserInputRequest: serverManager.pendingUserInputRequest(for: thread.key),
                    composerPrefillRequest: serverManager.composerPrefillRequest,
                    isTurnActive: thread.hasTurnActive,
                    threadPreview: thread.preview,
                    threadModel: thread.model,
                    threadReasoningEffort: thread.reasoningEffort,
                    modelContextWindow: thread.modelContextWindow,
                    contextTokensUsed: thread.contextTokensUsed,
                    rateLimits: connection.rateLimits,
                    availableModels: connection.models,
                    isConnected: connection.isConnected
                )
            )
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.observationGeneration == generation else { return }
                self.refreshState()
            }
        }

        if let lastObservedUpdatedAt,
           snapshot.updatedAt != lastObservedUpdatedAt,
           snapshot.isTurnActive {
            followScrollToken &+= 1
        }
        lastObservedUpdatedAt = snapshot.updatedAt

        pinnedContextItems = snapshot.items
        transcript = ConversationTranscriptSnapshot(
            items: snapshot.items,
            threadStatus: snapshot.threadStatus,
            followScrollToken: followScrollToken,
            agentDirectoryVersion: snapshot.agentDirectoryVersion
        )
        composer = snapshot.composer
    }
}
