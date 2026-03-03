package io.latitudes.shitter.android.state

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AppStateToolTargetLabelsTest {
    @Test
    fun toolTargetLabelsAreExposedForThreadAndAgentIds() {
        val labels =
            mapOf(
                "thread-alpha" to "Planner [code]",
                "agent-42" to "Planner [code]",
            )
        val state = AppState(toolTargetLabelsById = labels)

        assertEquals("Planner [code]", state.toolTargetLabelsById["thread-alpha"])
        assertEquals("Planner [code]", state.toolTargetLabelsById["agent-42"])
        assertTrue(state.toolTargetLabelsById.keys.containsAll(listOf("thread-alpha", "agent-42")))
    }
}
