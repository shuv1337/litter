Summary

- SSH bootstrap now resolves `codex` through a real login shell and explicitly supports Bun-installed Codex binaries.
- Big iOS UI refresh with liquid glass styling and a full-screen conversation layout.
- Discovery, auth, and local Codex server flows are more reliable and easier to recover from.
- New personalization controls for theme, font family, and code block scaling.
- Added rate-limit visibility and voice transcription in the composer.

What to test

- Verify SSH startup on Macs where `codex` is only available after shell init or installed under `~/.bun/bin`.
- Try the new mic button and confirm voice transcription inserts cleanly into the composer.
- Check rate-limit indicators and the updated context placement around the input area.
- Switch theme/font settings and verify light mode, typography, and code blocks render correctly.
- Exercise discovery, login, local server startup, and stop/error handling flows.

Merged PRs in the last 24 hours

- PR #21: iOS voice transcription with mic button and waveform.
- PR #20: Rate-limit indicators and updated context badge placement.
- PR #19: Light mode, font family setting, and code block scaling.
- PR #18: Keyboard fix, OAuth callback forwarding, and auth UX improvements.
- PR #17: Local Codex server fixes and bundled TLS root certificates.
- PR #16: Auth-gated discovery, stop button, clearer errors, and local directory picker.
- PR #15: Liquid glass UI and full-screen conversation refresh.
