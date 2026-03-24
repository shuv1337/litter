# Realtime Resume Session

Goal: let realtime handoff continue work in a specific existing Codex thread, not just a per-server scratch handoff thread.

## Preferred Design

Implement `codex(server, prompt, thread_id?)` for realtime.

- `server`: target local or remote server
- `prompt`: delegated task text
- `thread_id` optional: existing thread/session to continue

If `thread_id` is present, the handoff router should resume that thread and send the turn there instead of creating a new handoff thread.

## Why This Version

- Keeps the model interface simple and explicit.
- Reuses the existing realtime `codex` delegation path instead of teaching the model a separate resume-only tool first.
- Makes “continue that session” a first-class handoff action.
- Preserves the current dynamic tools (`list_sessions`, `read_session`, `run_on_server`) as discovery helpers.

## Required Changes

### 1. Realtime codex tool schema

Extend the built-in realtime `codex` function tool to accept:

- `server` required
- `prompt` required
- `thread_id` optional

This likely means updating the realtime session tool definition in the codex websocket layer and its tests.

### 2. Realtime handoff payload

Extend the parsed `RealtimeHandoffRequested` payload to carry optional `thread_id`.

Today we already extract:

- transcript
- server

We would also extract:

- `thread_id`

### 3. iOS handoff routing

Update the handoff routing path in `ServerManager` so that when a handoff includes `thread_id`:

- build `ThreadKey(serverId:, threadId:)`
- call `resumeThread(...)` before sending the turn
- cache that key in `voiceHandoffThreads[serverId]`
- stream output from that resumed thread back into the realtime handoff

If no `thread_id` is supplied, keep the current behavior:

- reuse the cached handoff thread for that server, or
- create a new one

### 4. Sticky follow-up behavior

After a handoff resumes a specific thread, follow-up voice turns for that server should keep using that same resumed thread until the user switches context.

This avoids:

- resuming the same thread repeatedly
- falling back to an unrelated scratch thread on the next turn

### 5. Prompting guidance

Update the voice/realtime prompt so the model knows:

- use `list_sessions` or `read_session` to find the right thread when needed
- pass `thread_id` into `codex(...)` when the user wants to continue a specific session

## Runtime Sequence

Desired flow:

1. User says “continue that session on bigpc.”
2. Realtime model uses `list_sessions` / `read_session` if needed.
3. Realtime model calls `codex(server=\"bigpc\", prompt=\"...\", thread_id=\"thr_123\")`.
4. Handoff event reaches iOS with `server` and `thread_id`.
5. iOS calls `thread/resume` for `thr_123`.
6. iOS sends the delegated turn into `thr_123`.
7. iOS streams resulting assistant output back through `resolveHandoff(...)`.
8. iOS finishes with `finalizeHandoff(...)`.

## Notes

- `thread/resume` already exists on the app-server side.
- `thread/realtime/start` is already thread-scoped, but realtime transport state is ephemeral.
- The main missing work is passing `thread_id` through the realtime handoff contract and honoring it in the iOS handoff router.
- The main correctness risk is ensuring the resumed thread is subscribed and hydrated before streaming handoff output from it.
