package io.latitudes.shitter.android.feature.sessions

import io.latitudes.shitter.android.core.bridge.CodexRpcClient
import io.latitudes.shitter.android.core.bridge.SessionSummary

class SessionsFeature(
    private val rpcClient: CodexRpcClient,
) {
    fun loadSessions(): List<SessionSummary> = rpcClient.listSessions()
}
