# AGENTS.md

## Repo rules

- Keep changes scoped to the task at hand.
- Do not commit secrets.
- Store API keys only in the macOS Keychain.
- Commit after each meaningful milestone.
- Push after each task.
- Do not fake working model support.
- If a provider or model cannot be implemented yet, make it visibly unavailable and document the exact blocker.

## Implementation expectations

- Prefer native macOS UI and system frameworks over web views.
- Keep the app buildable from the command line.
- Use Swift Package Manager for dependencies.
- Preserve truthful placeholder states until real functionality exists.
