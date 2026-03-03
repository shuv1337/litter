package io.latitudes.shitter.android.state

import org.junit.Assert.assertEquals
import org.junit.Test

class ThreadPlaceholderPrunePolicyTest {
    @Test
    fun prunesPlaceholderMissingFromAuthoritativeList() {
        val target = key(serverId = "server-1", threadId = "placeholder-1")
        val threads =
            mapOf(
                target to placeholderThread(target),
                key(serverId = "server-1", threadId = "real-1") to realThread(serverId = "server-1", threadId = "real-1"),
            )

        val pruned =
            computePlaceholderKeysToPrune(
                serverId = "server-1",
                authoritativeKeys = setOf(key(serverId = "server-1", threadId = "real-1")),
                activeThreadKey = null,
                threadsByKey = threads,
            )

        assertEquals(setOf(target), pruned)
    }

    @Test
    fun keepsActivePlaceholderEvenWhenMissingFromAuthoritativeList() {
        val target = key(serverId = "server-1", threadId = "placeholder-active")
        val threads = mapOf(target to placeholderThread(target))

        val pruned =
            computePlaceholderKeysToPrune(
                serverId = "server-1",
                authoritativeKeys = emptySet(),
                activeThreadKey = target,
                threadsByKey = threads,
            )

        assertEquals(emptySet<ThreadKey>(), pruned)
    }

    @Test
    fun doesNotPruneNonPlaceholderThreads() {
        val key = key(serverId = "server-1", threadId = "real-thread")
        val threads = mapOf(key to realThread(serverId = "server-1", threadId = "real-thread"))

        val pruned =
            computePlaceholderKeysToPrune(
                serverId = "server-1",
                authoritativeKeys = emptySet(),
                activeThreadKey = null,
                threadsByKey = threads,
            )

        assertEquals(emptySet<ThreadKey>(), pruned)
    }

    @Test
    fun onlyPrunesPlaceholdersForTargetServer() {
        val targetServerPlaceholder = key(serverId = "server-1", threadId = "placeholder-1")
        val otherServerPlaceholder = key(serverId = "server-2", threadId = "placeholder-2")
        val threads =
            mapOf(
                targetServerPlaceholder to placeholderThread(targetServerPlaceholder),
                otherServerPlaceholder to placeholderThread(otherServerPlaceholder),
            )

        val pruned =
            computePlaceholderKeysToPrune(
                serverId = "server-1",
                authoritativeKeys = emptySet(),
                activeThreadKey = null,
                threadsByKey = threads,
            )

        assertEquals(setOf(targetServerPlaceholder), pruned)
    }

    private fun key(
        serverId: String,
        threadId: String,
    ): ThreadKey = ThreadKey(serverId = serverId, threadId = threadId)

    private fun placeholderThread(key: ThreadKey): ThreadState =
        ThreadState(
            key = key,
            serverName = "Server",
            serverSource = ServerSource.REMOTE,
            preview = key.threadId,
            cwd = "/tmp",
            isPlaceholder = true,
        )

    private fun realThread(
        serverId: String,
        threadId: String,
    ): ThreadState =
        ThreadState(
            key = ThreadKey(serverId = serverId, threadId = threadId),
            serverName = "Server",
            serverSource = ServerSource.REMOTE,
            preview = threadId,
            cwd = "/tmp",
            isPlaceholder = false,
        )
}
