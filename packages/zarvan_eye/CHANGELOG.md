# Changelog

## 0.1.0

- Added the Dart Eye client with sessions, identity, batching, retries and periodic flushing.
- Added `EyeClient.init` plus `GameActivity` for default session creation, focus/blur, idle detection and game-time events.
- `EyeClient.init` now creates or restores an installation-wide anonymous user id and adds it to every event.
- Added documentation and typed helpers for game lifecycle, level outcomes, purchases, ads, metadata, errors, offline queue persistence, and login/logout identity transitions.
