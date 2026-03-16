Summary

- Home screen: new dashboard shows recent sessions and connected servers at a glance, with direct entry points for new and existing sessions.
- Streamlined navigation: sidebar overlay replaced with a simpler back-button flow between home, sessions, and conversations.
- Rich conversation items: shell commands, file changes, MCP tool calls, web searches, multi-agent actions, and generative UI widgets now render as structured inline cards.
- Tasks and plans: todo lists show live progress, and proposed plans render as expandable markdown sections.
- File diffs: turn-level file diffs now appear inline.
- Collapsible turns: previous turns can collapse into preview cards from Settings -> Conversation -> Collapse Turns.
- Improved networking: better reconnect behavior after backgrounding, more reliable notification streaming, and improved thread sync on resume.
- Improved markdown: migrated to a new markdown renderer for better performance and compatibility.
- Compact Dynamic Island: live activity indicator is smaller during active turns.
- Smaller tool cards: command cards are more compact and wrap command text correctly.
- Bug fixes: fixed the home toolbar disappearing after navigating back, and fixed turn grouping that could split user and assistant messages.

What to test

- Launch to the new home dashboard and confirm recent sessions and connected servers update correctly.
- Start a new session from home, then reopen a recent session from home without using the old sidebar flow.
- Navigate home -> sessions -> conversation and back again, verifying the back-button flow stays consistent.
- In a conversation, verify structured cards render for commands, file changes, MCP calls, web searches, agent actions, widgets, tasks, plans, and diffs.
- Turn on Settings -> Conversation -> Collapse Turns and confirm older turns collapse into preview cards without breaking navigation.
- Background and foreground the app during or after a turn, then verify reconnect, streaming, and resumed thread state behave correctly.
- Confirm markdown-heavy responses still render correctly after the renderer migration.
- Check the live activity / Dynamic Island presentation and confirm the compact layout during active turns.
- Verify compact tool cards wrap long command text cleanly.
- Regression test the home toolbar after navigating back and confirm turn grouping keeps each user message attached to its assistant response.
