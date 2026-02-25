package io.latitudes.shitter.android.feature.conversation

import io.latitudes.shitter.android.core.bridge.CodexRpcClient

class ConversationFeature(
    private val rpcClient: CodexRpcClient,
) {
    fun sendPrompt(prompt: String): String = rpcClient.startTurn(prompt)
}
