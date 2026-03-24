Summary

- Added realtime voice mode on iPhone: you can launch a live voice session directly from the home screen and use the new fullscreen realtime voice UI.
- Improved realtime auth flow: the voice screen can save and reuse a local OpenAI API key for realtime without forcing you to log out of ChatGPT OAuth.
- Better realtime conversation behavior: transcript streaming, autoscroll, inline handoff display, and cross-server session tools are more reliable and easier to follow.
- Expanded voice session support: lock screen / Dynamic Island live activity, background audio handling, and route behavior were tightened up for longer-running voice sessions.

What to test

- Turn on `Experimental > Realtime`, launch voice from the home screen, and confirm the new orb launcher opens the realtime voice screen cleanly.
- While logged into ChatGPT, start realtime voice and verify you can save, update, and delete the local realtime API key without breaking normal account login.
- Hold a longer voice conversation and confirm transcript updates persist in order, stay scrolled to the latest content, and handoff activity appears inline without freezing the UI.
- Trigger a handoff or session lookup flow and confirm the model can find recent sessions, explain what it is doing, and continue after the handoff returns.
- Lock the device during a live voice session and confirm the Live Activity, lock screen card, and background audio/session behavior remain stable.
