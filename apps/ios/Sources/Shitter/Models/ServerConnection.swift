import Foundation
import Observation
import SwiftUI

enum ConnectionHealth: Equatable {
    case disconnected
    case connecting
    case connected
    case unresponsive

    var settingsLabel: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .unresponsive: "Unresponsive"
        }
    }

    var settingsColor: Color {
        switch self {
        case .connected: ShitterTheme.accent
        case .connecting, .unresponsive: .orange
        case .disconnected: ShitterTheme.textSecondary
        }
    }
}

@MainActor
@Observable
final class ServerConnection: Identifiable {
    private static let defaultSandboxMode = "workspace-write"
    private static let localSandboxMode = "danger-full-access"
    private static let fallbackSandboxMode = "danger-full-access"

    let id: String
    let server: DiscoveredServer
    let target: ConnectionTarget

    var connectionHealth: ConnectionHealth = .disconnected
    var isConnected: Bool { connectionHealth == .connected }
    var connectionPhase: String = ""
    var authStatus: AuthStatus = .unknown
    var hasOpenAIApiKey = false
    var oauthURL: URL? = nil
    var lastAuthError: String?
    var isChatGPTLoginInProgress = false
    var loginCompleted = false {
        didSet {
            guard loginCompleted else { return }
            onLoginCompleted?()
        }
    }
    var models: [CodexModel] = []
    var modelsLoaded = false
    var rateLimits: RateLimitSnapshot?

    @ObservationIgnored let client = JSONRPCClient()
    @ObservationIgnored private(set) var channelClient: CodexChannel?
    @ObservationIgnored private var serverURL: URL?
    @ObservationIgnored private var pendingLoginId: String?

    @ObservationIgnored var onNotification: ((String, Data) -> Void)?
    @ObservationIgnored var onServerRequest: ((_ requestId: String, _ method: String, _ data: Data) -> Bool)?
    @ObservationIgnored var onDisconnect: (() -> Void)?
    @ObservationIgnored var onLoginCompleted: (() -> Void)?

    init(server: DiscoveredServer, target: ConnectionTarget) {
        self.id = server.id
        self.server = server
        self.target = target
        self.hasOpenAIApiKey = Self.localRealtimeAPIKeyIsSaved(for: target)
    }

    private struct ConnectionRetryPolicy {
        let maxAttempts: Int
        let retryDelay: Duration
        let initializeTimeout: Duration
        let attemptTimeout: Duration
    }

    func connect() async {
        guard connectionHealth != .connected, connectionHealth != .connecting else { return }
        connectionHealth = .connecting
        connectionPhase = "start"
        do {
            switch target {
            case .local:
                guard OnDeviceCodexFeature.isEnabled else {
                    connectionPhase = OnDeviceCodexFeature.compiledIn ? "local-disabled" : "local-unavailable"
                    connectionHealth = .disconnected
                    return
                }
                applyLocalRealtimeAPIKeyEnvironment()
                connectionPhase = "local-channel-starting"
                let channel = try await CodexBridge.shared.ensureChannelStarted()
                channelClient = channel
                connectionPhase = "local-channel-setup"
                await setupChannelNotifications(channel)
                await setupChannelDisconnect(channel)
                // Initialize handshake already done by Rust in_process::start
                await restoreLocalChatGPTAuthIfNeeded()
                await checkAuth()
                await fetchRateLimits()
                connectionHealth = .connected
                connectionPhase = "ready"
                return
            case .remote(let host, let port):
                guard let url = websocketURL(host: host, port: port) else {
                    connectionPhase = "invalid-url"
                    connectionHealth = .disconnected
                    return
                }
                serverURL = url
                connectionPhase = "remote-url"
            case .remoteURL(let url):
                serverURL = url
                connectionPhase = "remote-url"
            case .sshThenRemote:
                connectionPhase = "sshThenRemote-not-supported"
                connectionHealth = .disconnected
                return
            }
            guard serverURL != nil else {
                connectionPhase = "no-url"
                connectionHealth = .disconnected
                return
            }
            connectionPhase = "setup-notifications"
            await setupNotifications()
            await setupDisconnectHandler()
            await setupHealthHandler()
            connectionPhase = "connect-and-initialize"
            try await connectAndInitialize()
            await configureLocalRealtimeConversationFeatureIfNeeded()
            connectionHealth = .connected
            connectionPhase = "ready"
            Task { [weak self] in
                await self?.checkAuth()
                await self?.fetchRateLimits()
            }
        } catch {
            connectionPhase = "error: \(error.localizedDescription)"
            connectionHealth = .disconnected
        }
    }

    func disconnect() {
        if let channelClient {
            Task { await CodexBridge.shared.disconnectChannelIfCurrent(channelClient) }
            self.channelClient = nil
        }
        Task { await client.disconnect() }
        connectionHealth = .disconnected
        serverURL = nil
        rateLimits = nil
    }

    func forwardOAuthCallback(_ url: URL) {
        switch target {
        case .local:
            Task { _ = try? await URLSession.shared.data(from: url) }
        case .remote, .remoteURL:
            Task {
                _ = try? await execCommand(["curl", "-s", "-4", "-L", "--max-time", "10", url.absoluteString])
            }
        case .sshThenRemote:
            break
        }
    }

    // MARK: - RPC Methods

    func listThreads(cwd: String? = nil, cursor: String? = nil, limit: Int? = 20) async throws -> ThreadListResponse {
        try await routedSendRequest(
            method: "thread/list",
            params: ThreadListParams(cursor: cursor, limit: limit, sortKey: "updated_at", cwd: cwd),
            responseType: ThreadListResponse.self
        )
    }

    func startThread(
        cwd: String,
        model: String? = nil,
        approvalPolicy: String = "never",
        sandboxMode: String? = nil,
        dynamicTools: [DynamicToolSpec]? = nil
    ) async throws -> ThreadStartResponse {
        let preferredSandbox = sandboxMode ?? (target == .local ? Self.localSandboxMode : Self.defaultSandboxMode)
        do {
            return try await startThread(
                cwd: cwd,
                model: model,
                approvalPolicy: approvalPolicy,
                sandbox: preferredSandbox,
                dynamicTools: dynamicTools
            )
        } catch {
            guard sandboxMode == nil, preferredSandbox == Self.defaultSandboxMode, shouldRetryWithoutLinuxSandbox(error) else { throw error }
            return try await startThread(
                cwd: cwd,
                model: model,
                approvalPolicy: approvalPolicy,
                sandbox: Self.fallbackSandboxMode,
                dynamicTools: dynamicTools
            )
        }
    }

    func resumeThread(
        threadId: String,
        cwd: String,
        approvalPolicy: String = "never",
        sandboxMode: String? = nil
    ) async throws -> ThreadResumeResponse {
        let preferredSandbox = sandboxMode ?? (target == .local ? Self.localSandboxMode : Self.defaultSandboxMode)
        do {
            return try await resumeThread(
                threadId: threadId,
                cwd: cwd,
                approvalPolicy: approvalPolicy,
                sandbox: preferredSandbox
            )
        } catch {
            guard sandboxMode == nil, preferredSandbox == Self.defaultSandboxMode, shouldRetryWithoutLinuxSandbox(error) else { throw error }
            return try await resumeThread(
                threadId: threadId,
                cwd: cwd,
                approvalPolicy: approvalPolicy,
                sandbox: Self.fallbackSandboxMode
            )
        }
    }

    func forkThread(
        threadId: String,
        cwd: String? = nil,
        approvalPolicy: String = "never",
        sandboxMode: String? = nil
    ) async throws -> ThreadForkResponse {
        let preferredSandbox = sandboxMode ?? (target == .local ? Self.localSandboxMode : Self.defaultSandboxMode)
        do {
            return try await forkThread(
                threadId: threadId,
                cwd: cwd,
                approvalPolicy: approvalPolicy,
                sandbox: preferredSandbox
            )
        } catch {
            guard sandboxMode == nil, preferredSandbox == Self.defaultSandboxMode, shouldRetryWithoutLinuxSandbox(error) else { throw error }
            return try await forkThread(
                threadId: threadId,
                cwd: cwd,
                approvalPolicy: approvalPolicy,
                sandbox: Self.fallbackSandboxMode
            )
        }
    }

    private func startThread(cwd: String, model: String?, approvalPolicy: String, sandbox: String, dynamicTools: [DynamicToolSpec]? = nil) async throws -> ThreadStartResponse {
        let instructions = target == .local ? Self.localSystemInstructions : nil
        return try await routedSendRequest(
            method: "thread/start",
            params: ThreadStartParams(model: model, cwd: cwd, approvalPolicy: approvalPolicy, sandbox: sandbox, dynamicTools: dynamicTools, developerInstructions: instructions),
            responseType: ThreadStartResponse.self
        )
    }

    func readThread(threadId: String) async throws -> ThreadReadResponse {
        try await routedSendRequest(
            method: "thread/read",
            params: ThreadReadParams(threadId: threadId),
            responseType: ThreadReadResponse.self
        )
    }

    private func resumeThread(
        threadId: String,
        cwd: String,
        approvalPolicy: String,
        sandbox: String
    ) async throws -> ThreadResumeResponse {
        let instructions = target == .local ? Self.localSystemInstructions : nil
        return try await routedSendRequest(
            method: "thread/resume",
            params: ThreadResumeParams(
                threadId: threadId,
                cwd: cwd,
                approvalPolicy: approvalPolicy,
                sandbox: sandbox,
                developerInstructions: instructions
            ),
            responseType: ThreadResumeResponse.self
        )
    }

    private func forkThread(
        threadId: String,
        cwd: String?,
        approvalPolicy: String,
        sandbox: String
    ) async throws -> ThreadForkResponse {
        let instructions = target == .local ? Self.localSystemInstructions : nil
        return try await routedSendRequest(
            method: "thread/fork",
            params: ThreadForkParams(
                threadId: threadId,
                cwd: cwd,
                approvalPolicy: approvalPolicy,
                sandbox: sandbox,
                developerInstructions: instructions
            ),
            responseType: ThreadForkResponse.self
        )
    }

    private func shouldRetryWithoutLinuxSandbox(_ error: Error) -> Bool {
        guard case let JSONRPCClientError.serverError(_, message) = error else {
            return false
        }
        let lower = message.lowercased()
        return lower.contains("codex-linux-sandbox was required but not provided") ||
            lower.contains("missing codex-linux-sandbox executable path")
    }

    @discardableResult
    func sendTurn(
        threadId: String,
        text: String,
        approvalPolicy: String? = nil,
        sandboxMode: String? = nil,
        model: String? = nil,
        effort: String? = nil,
        serviceTier: String? = nil,
        additionalInput: [UserInput] = []
    ) async throws -> TurnStartResponse {
        let inputs = ConversationAttachmentSupport.buildTurnInputs(text: text, additionalInput: additionalInput)
        guard !inputs.isEmpty else {
            throw NSError(
                domain: "Shitter",
                code: 1020,
                userInfo: [NSLocalizedDescriptionKey: "Cannot send an empty turn"]
            )
        }
        return try await routedSendRequest(
            method: "turn/start",
            params: TurnStartParams(
                threadId: threadId,
                input: inputs,
                approvalPolicy: approvalPolicy,
                sandboxPolicy: TurnSandboxPolicy(mode: sandboxMode),
                model: model,
                effort: effort,
                serviceTier: serviceTier
            ),
            responseType: TurnStartResponse.self
        )
    }

    func interrupt(threadId: String, turnId: String) async {
        struct Empty: Decodable {}
        _ = try? await routedSendRequest(
            method: "turn/interrupt",
            params: TurnInterruptParams(threadId: threadId, turnId: turnId),
            responseType: Empty.self
        )
    }

    func prepareLocalRealtimeConversationIfNeeded() async {
        await configureLocalRealtimeConversationFeatureIfNeeded()
    }

    func startRealtimeConversation(
        threadId: String,
        prompt: String,
        sessionId: String? = nil,
        clientControlledHandoff: Bool = false,
        dynamicTools: [DynamicToolSpec]? = nil
    ) async throws {
        let _: ThreadRealtimeStartResponse = try await routedSendRequest(
            method: "thread/realtime/start",
            params: ThreadRealtimeStartParams(
                threadId: threadId,
                prompt: prompt,
                sessionId: sessionId,
                clientControlledHandoff: clientControlledHandoff ? true : nil,
                dynamicTools: dynamicTools
            ),
            responseType: ThreadRealtimeStartResponse.self
        )
    }

    func resolveRealtimeHandoff(threadId: String, handoffId: String, outputText: String) async throws {
        let _: ThreadRealtimeResolveHandoffResponse = try await routedSendRequest(
            method: "thread/realtime/resolveHandoff",
            params: ThreadRealtimeResolveHandoffParams(
                threadId: threadId,
                handoffId: handoffId,
                outputText: outputText
            ),
            responseType: ThreadRealtimeResolveHandoffResponse.self
        )
    }

    func finalizeRealtimeHandoff(threadId: String, handoffId: String) async throws {
        let _: ThreadRealtimeFinalizeHandoffResponse = try await routedSendRequest(
            method: "thread/realtime/finalizeHandoff",
            params: ThreadRealtimeFinalizeHandoffParams(
                threadId: threadId,
                handoffId: handoffId
            ),
            responseType: ThreadRealtimeFinalizeHandoffResponse.self
        )
    }

    func appendRealtimeAudio(threadId: String, audio: ThreadRealtimeAudioChunk) async throws {
        let _: ThreadRealtimeAppendAudioResponse = try await routedSendRequest(
            method: "thread/realtime/appendAudio",
            params: ThreadRealtimeAppendAudioParams(threadId: threadId, audio: audio),
            responseType: ThreadRealtimeAppendAudioResponse.self
        )
    }

    func appendRealtimeText(threadId: String, text: String) async throws {
        let _: ThreadRealtimeAppendTextResponse = try await routedSendRequest(
            method: "thread/realtime/appendText",
            params: ThreadRealtimeAppendTextParams(threadId: threadId, text: text),
            responseType: ThreadRealtimeAppendTextResponse.self
        )
    }

    func stopRealtimeConversation(threadId: String) async throws {
        let _: ThreadRealtimeStopResponse = try await routedSendRequest(
            method: "thread/realtime/stop",
            params: ThreadRealtimeStopParams(threadId: threadId),
            responseType: ThreadRealtimeStopResponse.self
        )
    }

    func rollbackThread(threadId: String, numTurns: Int) async throws -> ThreadRollbackResponse {
        try await routedSendRequest(
            method: "thread/rollback",
            params: ThreadRollbackParams(threadId: threadId, numTurns: numTurns),
            responseType: ThreadRollbackResponse.self
        )
    }

    func archiveThread(threadId: String) async throws {
        let _: ThreadArchiveResponse = try await routedSendRequest(
            method: "thread/archive",
            params: ThreadArchiveParams(threadId: threadId),
            responseType: ThreadArchiveResponse.self
        )
    }

    func listModels() async throws -> ModelListResponse {
        try await routedSendRequest(
            method: "model/list",
            params: ModelListParams(limit: 50, includeHidden: false),
            responseType: ModelListResponse.self
        )
    }

    func execCommand(_ command: [String], cwd: String? = nil) async throws -> CommandExecResponse {
        try await routedSendRequest(
            method: "command/exec",
            params: CommandExecParams(command: command, cwd: cwd),
            responseType: CommandExecResponse.self
        )
    }

    func fuzzyFileSearch(query: String, roots: [String], cancellationToken: String?) async throws -> FuzzyFileSearchResponse {
        try await routedSendRequest(
            method: "fuzzyFileSearch",
            params: FuzzyFileSearchParams(query: query, roots: roots, cancellationToken: cancellationToken),
            responseType: FuzzyFileSearchResponse.self
        )
    }

    func listSkills(cwds: [String]?, forceReload: Bool = false) async throws -> SkillsListResponse {
        try await routedSendRequest(
            method: "skills/list",
            params: SkillsListParams(cwds: cwds, forceReload: forceReload),
            responseType: SkillsListResponse.self
        )
    }

    func respondToServerRequest(id: String, result: [String: Any]) {
        Task {
            routedSendResult(id: id, result: result)
        }
    }

    func respondToServerRequestError(id: String, code: Int = -32000, message: String) {
        Task {
            routedSendError(id: id, code: code, message: message)
        }
    }

    func listExperimentalFeatures(cursor: String? = nil, limit: Int? = 100) async throws -> ExperimentalFeatureListResponse {
        try await routedSendRequest(
            method: "experimentalFeature/list",
            params: ExperimentalFeatureListParams(cursor: cursor, limit: limit),
            responseType: ExperimentalFeatureListResponse.self
        )
    }

    func readConfig(cwd: String?) async throws -> ConfigReadResponse {
        try await routedSendRequest(
            method: "config/read",
            params: ConfigReadParams(includeLayers: false, cwd: cwd),
            responseType: ConfigReadResponse.self
        )
    }

    func writeConfigValue<Value: Encodable>(
        keyPath: String,
        value: Value,
        mergeStrategy: String = "upsert"
    ) async throws -> ConfigWriteResponse {
        try await routedSendRequest(
            method: "config/value/write",
            params: ConfigValueWriteParams(keyPath: keyPath, value: value, mergeStrategy: mergeStrategy, filePath: nil, expectedVersion: nil),
            responseType: ConfigWriteResponse.self
        )
    }

    func writeConfigBatch(
        edits: [ConfigEdit],
        reloadUserConfig: Bool = false
    ) async throws -> ConfigWriteResponse {
        try await routedSendRequest(
            method: "config/batchWrite",
            params: ConfigBatchWriteParams(
                edits: edits,
                filePath: nil,
                expectedVersion: nil,
                reloadUserConfig: reloadUserConfig
            ),
            responseType: ConfigWriteResponse.self
        )
    }

    @discardableResult
    func setExperimentalFeature(
        named featureName: String,
        enabled: Bool,
        reloadUserConfig: Bool = true
    ) async throws -> ConfigWriteResponse {
        try await writeConfigBatch(
            edits: [
                ConfigEdit(
                    keyPath: "features.\(featureName)",
                    value: AnyEncodable(enabled),
                    mergeStrategy: "upsert"
                )
            ],
            reloadUserConfig: reloadUserConfig
        )
    }

    func setThreadName(threadId: String, name: String) async throws {
        let _: ThreadSetNameResponse = try await routedSendRequest(
            method: "thread/name/set",
            params: ThreadSetNameParams(threadId: threadId, name: name),
            responseType: ThreadSetNameResponse.self
        )
    }

    func startReview(threadId: String) async throws -> ReviewStartResponse {
        try await routedSendRequest(
            method: "review/start",
            params: ReviewStartParams(threadId: threadId, target: .uncommittedChanges, delivery: "inline"),
            responseType: ReviewStartResponse.self
        )
    }

    // MARK: - Auth

    func checkAuth() async {
        do {
            let resp: GetAccountResponse = try await withThrowingTaskGroup(of: GetAccountResponse.self) { group in
                group.addTask {
                    try await self.routedSendRequest(
                        method: "account/read",
                        params: GetAccountParams(refreshToken: false),
                        responseType: GetAccountResponse.self
                    )
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(4))
                    throw URLError(.timedOut)
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            if let account = resp.account {
                switch account.type {
                case "chatgpt": authStatus = .chatgpt(email: account.email ?? "")
                case "apiKey":  authStatus = .apiKey
                default:        authStatus = .notLoggedIn
                }
            } else {
                authStatus = .notLoggedIn
            }
            hasOpenAIApiKey = Self.realtimeAPIKeyIsSaved(for: target)
        } catch {
            authStatus = .notLoggedIn
            hasOpenAIApiKey = Self.realtimeAPIKeyIsSaved(for: target)
        }
    }

    func getAuthToken() async -> (method: String?, token: String?) {
        do {
            let resp: GetAuthStatusResponse = try await routedSendRequest(
                method: "getAuthStatus",
                params: GetAuthStatusParams(includeToken: true, refreshToken: false),
                responseType: GetAuthStatusResponse.self
            )
            return (resp.authMethod, resp.authToken)
        } catch {
            return (nil, nil)
        }
    }

    func loginWithChatGPT() async {
        guard !isChatGPTLoginInProgress else { return }
        isChatGPTLoginInProgress = true
        defer { isChatGPTLoginInProgress = false }

        await checkAuth()
        guard authStatus == .notLoggedIn else { return }

        do {
            lastAuthError = nil
            oauthURL = nil
            pendingLoginId = nil
            let tokens = try await ChatGPTOAuth.login()
            let _: LoginStartResponse = try await routedSendRequest(
                method: "account/login/start",
                params: LoginStartChatGPTAuthTokensParams(
                    accessToken: tokens.accessToken,
                    chatgptAccountId: tokens.accountID,
                    chatgptPlanType: tokens.planType
                ),
                responseType: LoginStartResponse.self
            )
            await checkAuth()
        } catch ChatGPTOAuthError.cancelled {
            return
        } catch {
            lastAuthError = error.localizedDescription
            NSLog("[auth] ChatGPT login failed: %@", error.localizedDescription)
        }
    }

    func loginWithApiKey(_ key: String) async {
        do {
            lastAuthError = nil
            let _: LoginStartResponse = try await routedSendRequest(
                method: "account/login/start",
                params: LoginStartApiKeyParams(apiKey: key),
                responseType: LoginStartResponse.self
            )
            await checkAuth()
        } catch {
            lastAuthError = error.localizedDescription
        }
    }

    func saveOpenAIApiKey(_ key: String) async {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            lastAuthError = "API key cannot be empty"
            return
        }

        guard target == .local else {
            lastAuthError = "Realtime API key is only used for on-device Codex."
            return
        }

        do {
            lastAuthError = nil
            try RealtimeAPIKeyStore.shared.save(trimmedKey)
            try RealtimeAPIKeyStore.shared.applyProcessEnvironment()
            hasOpenAIApiKey = Self.realtimeAPIKeyIsSaved(for: target)
        } catch {
            lastAuthError = error.localizedDescription
            hasOpenAIApiKey = Self.realtimeAPIKeyIsSaved(for: target)
        }
    }

    func clearOpenAIApiKey() async {
        guard target == .local else {
            lastAuthError = "Realtime API key is only used for on-device Codex."
            return
        }

        do {
            lastAuthError = nil
            try RealtimeAPIKeyStore.shared.clear()
            try RealtimeAPIKeyStore.shared.applyProcessEnvironment()
            hasOpenAIApiKey = Self.realtimeAPIKeyIsSaved(for: target)
        } catch {
            lastAuthError = error.localizedDescription
            hasOpenAIApiKey = Self.realtimeAPIKeyIsSaved(for: target)
        }
    }

    func logout() async {
        struct Empty: Decodable {}
        struct EmptyParams: Encodable {}
        _ = try? await routedSendRequest(
            method: "account/logout",
            params: EmptyParams(),
            responseType: Empty.self
        )
        if target == .local {
            try? ChatGPTOAuth.clearStoredTokens()
        }
        authStatus = .notLoggedIn
        hasOpenAIApiKey = Self.localRealtimeAPIKeyIsSaved(for: target)
        lastAuthError = nil
        oauthURL = nil
        pendingLoginId = nil
        isChatGPTLoginInProgress = false
    }

    func cancelLogin() async {
        guard let loginId = pendingLoginId else { return }
        struct Empty: Decodable {}
        _ = try? await routedSendRequest(
            method: "account/login/cancel",
            params: CancelLoginParams(loginId: loginId),
            responseType: Empty.self
        )
        pendingLoginId = nil
        oauthURL = nil
    }

    // MARK: - Rate Limits

    func fetchRateLimits() async {
        struct EmptyParams: Encodable {}
        guard let resp = try? await routedSendRequest(
            method: "account/rateLimits/read",
            params: EmptyParams(),
            responseType: GetAccountRateLimitsResponse.self
        ) else { return }
        rateLimits = resp.rateLimits
    }

    // MARK: - Account Notifications

    func handleAccountNotification(method: String, data: Data) {
        switch method {
        case "account/login/completed":
            if let notif = try? JSONDecoder().decode(AccountLoginCompletedNotification.self, from: extractParams(data)) {
                oauthURL = nil
                pendingLoginId = nil
                isChatGPTLoginInProgress = false
                if notif.success {
                    lastAuthError = nil
                    loginCompleted = true
                    Task { await self.checkAuth() }
                } else {
                    lastAuthError = notif.error ?? "ChatGPT login failed."
                }
            }
        case "account/updated":
            lastAuthError = nil
            Task { await self.checkAuth() }
        case "account/rateLimits/updated":
            if let notif = try? JSONDecoder().decode(AccountRateLimitsUpdatedNotification.self, from: extractParams(data)) {
                rateLimits = notif.rateLimits
            }
        default:
            break
        }
    }

    // MARK: - Local System Instructions

    private static let localSystemInstructions = """
    You are running on an iOS device with limited shell capabilities via ios_system.

    Environment:
    - Working directory: /home/codex (inside the app's sandboxed filesystem — persistent across app launches)
    - Filesystem layout: ~/Documents acts as root with /home/codex, /tmp, /var/log, /etc
    - Shell: ios_system (in-process, not a full POSIX shell — no fork/exec)
    - If you need a shell wrapper, the executable itself must be `sh`.
    - Use `sh -c '...'` directly. Do NOT emit `/bin/bash`, `bash`, `/bin/zsh`, `zsh`, `/bin/sh -lc`, or nested wrappers like `/bin/bash -lc "sh -c '...'"`.
    - /bin/sh runs in-process — compound commands (&&, ||, pipes) work

    Available tools:
    - Shell: ls, cat, echo, touch, cp, mv, rm, mkdir, rmdir, pwd, chmod, ln, du, df, env, date, uname, whoami, which, true, false, yes, printenv, basename, dirname, realpath, readlink
    - Text: grep, sed, awk, wc, sort, uniq, head, tail, tr, tee, cut, paste, comm, diff, expand, unexpand, fold, fmt, nl, rev, strings
    - Files: find, stat, tar, xargs
    - Network: curl (full HTTP client), ssh, scp, sftp
    - Git: lg2 (libgit2 CLI — use `lg2` instead of `git`, supports clone, init, add, commit, push, pull, status, log, diff, branch, checkout, merge, remote, tag, stash)
    - Other: bc (calculator)

    Limitations:
    - apply_patch may fail with "Operation not permitted" — fall back to echo/cat with redirection.
    - Use RELATIVE paths, not absolute /var/mobile/Containers/... paths.
    - Container UUID changes between installs — absolute paths from previous sessions are invalid.
    - No package managers (npm, pip, brew) and no Python/Node.
    - Use `lg2` not `git` for git operations.
    - Commands run synchronously — avoid long-running operations.

    Best practices:
    - Use relative paths for all file operations.
    - Prefer direct argv commands like `pwd`, `find`, `ls`, `rg`, `sed`.
    - Only wrap with `sh -c '...'` when shell syntax is actually required.
    - Never prepend `sh -c` with `bash -lc` or `zsh -lc`.
    - Prefer simple, single commands over complex pipelines.
    - For file creation: try apply_patch first, fall back to echo/cat redirection.
    - For scripting: use shell scripts or awk.
    - Be concise — this is a mobile device.
    """

    // MARK: - Transport Routing

    /// Routes sendRequest to the channel client (local) or WebSocket client (remote).
    private func routedSendRequest<P: Encodable, R: Decodable>(
        method: String, params: P, responseType: R.Type
    ) async throws -> R {
        if let channelClient {
            return try await channelClient.sendRequest(method: method, params: params, responseType: responseType)
        }
        return try await client.sendRequest(method: method, params: params, responseType: responseType)
    }

    /// Routes sendResult to the appropriate client.
    private func routedSendResult(id: String, result: Any) {
        if let channelClient {
            Task { await channelClient.sendResult(id: id, result: result) }
        } else {
            Task { await self.client.sendResult(id: id, result: result) }
        }
    }

    private func routedSendError(id: String, code: Int, message: String) {
        if let channelClient {
            Task { await channelClient.sendError(id: id, code: code, message: message) }
        } else {
            Task { await self.client.sendError(id: id, code: code, message: message) }
        }
    }

    private func setupChannelNotifications(_ channel: CodexChannel) async {
        await channel.setNotificationHandler { [weak self] method, data in
            Task { @MainActor [weak self] in
                self?.onNotification?(method, data)
            }
        }
        await channel.setRequestHandler { [weak self] id, method, data in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let handled = self.onServerRequest?(id, method, data) ?? false
                if !handled {
                    self.routedSendResult(id: id, result: [:] as [String: String])
                }
            }
        }
    }

    private func setupChannelDisconnect(_ channel: CodexChannel) async {
        await channel.setDisconnectHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.connectionHealth == .connected || self.connectionHealth == .unresponsive else { return }
                NSLog("[channel] disconnected, id=%@", self.id)
                self.connectionHealth = .disconnected
                self.onDisconnect?()
            }
        }
    }

    // MARK: - Connection Internals

    private func websocketURL(host: String, port: UInt16) -> URL? {
        var normalized = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        if !normalized.contains(":"), let pct = normalized.firstIndex(of: "%") {
            normalized = String(normalized[..<pct])
        }
        if normalized.contains(":") {
            let unbracketed = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            let escapedScope = unbracketed.replacingOccurrences(of: "%25", with: "%")
                .replacingOccurrences(of: "%", with: "%25")
            return URL(string: "ws://[\(escapedScope)]:\(port)")
        }
        return URL(string: "ws://\(normalized):\(port)")
    }

    private func connectAndInitialize() async throws {
        guard let url = serverURL else { throw URLError(.badURL) }
        let policy = retryPolicy()
        var lastError: Error = URLError(.cannotConnectToHost)
        for attempt in 0..<policy.maxAttempts {
            connectionPhase = "attempt \(attempt + 1)/\(policy.maxAttempts)"
            if attempt > 0 {
                try await Task.sleep(for: policy.retryDelay)
            }
            await client.disconnect()
            do {
                try await connectAndInitializeOnce(
                    url: url,
                    initializeTimeout: policy.initializeTimeout,
                    attemptTimeout: policy.attemptTimeout
                )
                return
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func retryPolicy() -> ConnectionRetryPolicy {
        switch target {
        case .remote, .remoteURL:
            return ConnectionRetryPolicy(
                maxAttempts: 3,
                retryDelay: .milliseconds(300),
                initializeTimeout: .seconds(4),
                attemptTimeout: .seconds(5)
            )
        default:
            return ConnectionRetryPolicy(
                maxAttempts: 30,
                retryDelay: .milliseconds(800),
                initializeTimeout: .seconds(6),
                attemptTimeout: .seconds(12)
            )
        }
    }

    private func connectAndInitializeOnce(
        url: URL,
        initializeTimeout: Duration,
        attemptTimeout: Duration
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                await MainActor.run { self.connectionPhase = "client-connect" }
                try await self.client.connect(url: url)
                await MainActor.run { self.connectionPhase = "initialize" }
                try await self.sendInitialize(timeout: initializeTimeout)
                await MainActor.run { self.connectionPhase = "initialized" }
            }
            group.addTask {
                try await Task.sleep(for: attemptTimeout)
                throw URLError(.timedOut)
            }
            _ = try await group.next()!
            group.cancelAll()
        }
    }

    private func sendInitialize(timeout: Duration) async throws {
        try await withThrowingTaskGroup(of: InitializeResponse.self) { group in
            group.addTask {
                try await self.client.sendRequest(
                    method: "initialize",
                    params: InitializeParams(
                        clientInfo: .init(name: "Shitter", version: "1.0", title: nil),
                        capabilities: .init(experimentalApi: true)
                    ),
                    responseType: InitializeResponse.self
                )
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw URLError(.timedOut)
            }
            _ = try await group.next()!
            group.cancelAll()
        }
    }

    private func setupDisconnectHandler() async {
        await client.setDisconnectHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.connectionHealth == .connected || self.connectionHealth == .unresponsive else {
                    NSLog("[ws] disconnect handler: already disconnected id=%@", self?.id ?? "?")
                    return
                }
                NSLog("[ws] socket died, auto-reconnecting id=%@", self.id)
                self.connectionHealth = .connecting
                self.onDisconnect?()
                do {
                    try await self.connectAndInitialize()
                    await self.configureLocalRealtimeConversationFeatureIfNeeded()
                    self.connectionHealth = .connected
                    NSLog("[ws] auto-reconnect SUCCESS id=%@", self.id)
                } catch {
                    self.connectionHealth = .disconnected
                    NSLog("[ws] auto-reconnect FAILED id=%@ err=%@", self.id, error.localizedDescription)
                }
            }
        }
    }

    private func setupHealthHandler() async {
        await client.setHealthChangeHandler { [weak self] healthy in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if healthy {
                    if self.connectionHealth == .unresponsive {
                        self.connectionHealth = .connected
                    }
                } else {
                    if self.connectionHealth == .connected {
                        self.connectionHealth = .unresponsive
                    }
                }
            }
        }
    }

    private func setupNotifications() async {
        await client.setNotificationHandler { [weak self] method, data in
            Task { @MainActor [weak self] in
                self?.onNotification?(method, data)
            }
        }
        await client.setRequestHandler { [weak self] id, method, data in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let handled = self.onServerRequest?(id, method, data) ?? false
                if !handled {
                    self.routedSendResult(id: id, result: [:] as [String: String])
                }
            }
        }
    }

    private func extractParams(_ data: Data) -> Data {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let params = obj["params"] {
            return (try? JSONSerialization.data(withJSONObject: params)) ?? data
        }
        return data
    }

    private func configureLocalRealtimeConversationFeatureIfNeeded() async {
        guard target == .local else { return }

        do {
            let didEnableFeature = try await ensureExperimentalFeatureEnabled(
                named: VoiceSessionControl.realtimeFeatureName,
                enabled: true
            )
            let didConfigureRealtimeDefaults = try await ensureLocalRealtimeDefaultsConfigured()
            if didEnableFeature || didConfigureRealtimeDefaults {
                connectionPhase = "local-realtime-ready"
            }
        } catch {
            NSLog(
                "[ws] failed enabling local realtime defaults id=%@ err=%@",
                id,
                error.localizedDescription
            )
        }
    }

    private func ensureExperimentalFeatureEnabled(
        named featureName: String,
        enabled: Bool
    ) async throws -> Bool {
        let response = try await listExperimentalFeatures(limit: 200)
        guard let feature = response.data.first(where: { $0.name == featureName }) else {
            return false
        }
        guard feature.enabled != enabled else {
            return false
        }

        connectionPhase = "configuring-\(featureName)"
        _ = try await setExperimentalFeature(
            named: featureName,
            enabled: enabled,
            reloadUserConfig: true
        )

        let updated = try await listExperimentalFeatures(limit: 200)
        guard updated.data.contains(where: { $0.name == featureName && $0.enabled == enabled }) else {
            throw NSError(
                domain: "Shitter",
                code: 3201,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Failed to enable experimental feature \(featureName)"
                ]
            )
        }

        return true
    }

    private func ensureLocalRealtimeDefaultsConfigured() async throws -> Bool {
        let desiredModel = "gpt-realtime-1.5"
        let desiredRealtimeVersion = "v2"
        let desiredRealtimeType = "conversational"
        let currentConfig = try await readConfig(cwd: nil)

        var edits: [ConfigEdit] = []
        let currentModel = configStringValue(
            currentConfig.config.value,
            keyPath: ["experimental_realtime_ws_model"]
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentModel != desiredModel {
            edits.append(
                ConfigEdit(
                    keyPath: "experimental_realtime_ws_model",
                    value: AnyEncodable(desiredModel),
                    mergeStrategy: "upsert"
                )
            )
        }

        let currentRealtimeVersion = configStringValue(
            currentConfig.config.value,
            keyPath: ["realtime", "version"]
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentRealtimeVersion?.lowercased() != desiredRealtimeVersion {
            edits.append(
                ConfigEdit(
                    keyPath: "realtime.version",
                    value: AnyEncodable(desiredRealtimeVersion),
                    mergeStrategy: "upsert"
                )
            )
        }

        let currentRealtimeType = configStringValue(
            currentConfig.config.value,
            keyPath: ["realtime", "type"]
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentRealtimeType?.lowercased() != desiredRealtimeType {
            edits.append(
                ConfigEdit(
                    keyPath: "realtime.type",
                    value: AnyEncodable(desiredRealtimeType),
                    mergeStrategy: "upsert"
                )
            )
        }

        guard !edits.isEmpty else {
            return false
        }

        connectionPhase = "configuring-local-realtime-defaults"
        _ = try await writeConfigBatch(
            edits: edits,
            reloadUserConfig: true
        )

        let updatedConfig = try await readConfig(cwd: nil)
        let updatedModel = configStringValue(
            updatedConfig.config.value,
            keyPath: ["experimental_realtime_ws_model"]
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedRealtimeVersion = configStringValue(
            updatedConfig.config.value,
            keyPath: ["realtime", "version"]
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedRealtimeType = configStringValue(
            updatedConfig.config.value,
            keyPath: ["realtime", "type"]
        )?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard updatedModel == desiredModel,
              updatedRealtimeVersion?.lowercased() == desiredRealtimeVersion,
              updatedRealtimeType?.lowercased() == desiredRealtimeType else {
            throw NSError(
                domain: "Shitter",
                code: 3203,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Failed to configure local realtime defaults"
                ]
            )
        }

        return true
    }

    private func configStringValue(_ root: Any, keyPath: [String]) -> String? {
        var current: Any = root
        for component in keyPath {
            guard let dictionary = current as? [String: Any],
                  let next = dictionary[component] else {
                return nil
            }
            current = next
        }
        return current as? String
    }

    private static func localRealtimeAPIKeyIsSaved(for target: ConnectionTarget) -> Bool {
        guard target == .local else { return false }
        let storedKey = (try? RealtimeAPIKeyStore.shared.load()) ?? nil
        return storedKey?.isEmpty == false
    }

    private static func realtimeAPIKeyIsSaved(for target: ConnectionTarget) -> Bool {
        localRealtimeAPIKeyIsSaved(for: target)
    }

    private func applyLocalRealtimeAPIKeyEnvironment() {
        guard target == .local else { return }
        do {
            try RealtimeAPIKeyStore.shared.applyProcessEnvironment()
            hasOpenAIApiKey = Self.localRealtimeAPIKeyIsSaved(for: target)
        } catch {
            lastAuthError = error.localizedDescription
            hasOpenAIApiKey = false
        }
    }

    private func restoreLocalChatGPTAuthIfNeeded() async {
        guard target == .local else { return }

        do {
            let currentAuth: GetAccountResponse = try await routedSendRequest(
                method: "account/read",
                params: GetAccountParams(refreshToken: false),
                responseType: GetAccountResponse.self
            )
            if currentAuth.account?.type == "chatgpt" {
                return
            }
        } catch {
            // Fall through and attempt local auth replay.
        }

        guard let storedTokens = try? ChatGPTOAuth.loadStoredTokens(),
              !storedTokens.accountID.isEmpty else {
            return
        }

        let tokensForRestore: ChatGPTOAuthTokenBundle
        if let refreshToken = storedTokens.refreshToken, !refreshToken.isEmpty {
            if let refreshed = try? await ChatGPTOAuth.refreshStoredTokens(previousAccountID: storedTokens.accountID) {
                tokensForRestore = refreshed
            } else {
                tokensForRestore = storedTokens
            }
        } else {
            tokensForRestore = storedTokens
        }

        guard !tokensForRestore.accessToken.isEmpty else {
            return
        }

        do {
            let _: LoginStartResponse = try await routedSendRequest(
                method: "account/login/start",
                params: LoginStartChatGPTAuthTokensParams(
                    accessToken: tokensForRestore.accessToken,
                    chatgptAccountId: tokensForRestore.accountID,
                    chatgptPlanType: tokensForRestore.planType
                ),
                responseType: LoginStartResponse.self
            )
        } catch {
            NSLog("[auth] Local ChatGPT auth restore failed: %@", error.localizedDescription)
        }
    }
}
