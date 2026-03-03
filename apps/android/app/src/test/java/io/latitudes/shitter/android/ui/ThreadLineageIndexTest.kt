package io.latitudes.shitter.android.ui

import io.latitudes.shitter.android.state.ServerSource
import io.latitudes.shitter.android.state.ThreadKey
import io.latitudes.shitter.android.state.ThreadState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ThreadLineageIndexTest {
    @Test
    fun fallsBackToRootThreadWhenDirectParentMissing() {
        val root = thread(id = "thread-root")
        val child =
            thread(
                id = "thread-child",
                parentThreadId = "thread-missing-parent",
                rootThreadId = "thread-root",
            )

        val index = buildThreadLineageIndex(allThreads = listOf(root, child))

        assertEquals(root, index.parentByKey[child.key])
        assertTrue(index.childrenByParentKey[root.key].orEmpty().contains(child))
    }

    @Test
    fun prefersDirectParentOverRootFallback() {
        val root = thread(id = "thread-root")
        val parent = thread(id = "thread-parent", parentThreadId = "thread-root", rootThreadId = "thread-root")
        val child = thread(id = "thread-child", parentThreadId = "thread-parent", rootThreadId = "thread-root")

        val index = buildThreadLineageIndex(allThreads = listOf(root, parent, child))

        assertEquals(parent, index.parentByKey[child.key])
        assertTrue(index.childrenByParentKey[parent.key].orEmpty().contains(child))
    }

    @Test
    fun keepsThreadAtRootWhenNoParentOrRootAvailable() {
        val standalone = thread(id = "thread-standalone")

        val index = buildThreadLineageIndex(allThreads = listOf(standalone))

        assertFalse(index.parentByKey.containsKey(standalone.key))
        assertTrue(index.childrenByParentKey.isEmpty())
    }

    private fun thread(
        id: String,
        parentThreadId: String? = null,
        rootThreadId: String? = null,
    ): ThreadState =
        ThreadState(
            key = ThreadKey(serverId = "server-1", threadId = id),
            serverName = "Server 1",
            serverSource = ServerSource.REMOTE,
            preview = id,
            cwd = "/Users/franklin/workspace",
            parentThreadId = parentThreadId,
            rootThreadId = rootThreadId,
        )
}
