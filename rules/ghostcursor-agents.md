# GhostCursor — agent rules

_GhostCursor agent instructions from AGENTS.md (actionable only)_

## Golden rules

1. **AskQuestion / AskUserQuestion** for any multiple-choice or gate decision
   (CHANGELOG/Release/build, naming, destructive actions, ambiguous scope). Do
   not guess irreversible choices.
2. **Update CHANGELOG.md** when users would notice — friendly public language
   under `[Unreleased]`. Skip for refactor/agent docs/skills.
3. **Keep `.gitignore` updated.** Never commit secrets, `dist/`, or Keychain
   material. `PROJECT_SPEC.md` and `plans/` stay local (gitignored).
4. **Keep AGENTS.md current** as commands or conventions change.
5. **Privacy promises:** no Accessibility/Input Monitoring prompts, no
   telemetry, no background network. Only user-initiated Sparkle checks.
6. **Cursor safety:** use existing hide/show paths; recovery is quit/`pkill`,
   never a second-process “show cursor” script.
7. **GitHub Issues:** never close unless the owner explicitly asks.

## `/ghostcursor-update` gates

Prefer **`/ghostcursor-update`** (`.cursor/skills/ghostcursor-update/SKILL.md`)
over global `/git-commit-push`.

Order: **CHANGELOG → Release → build/debug → commit → push → (if release)
`./scripts/release.sh` → `./scripts/publish-release.sh`**.

- Release bumps **both** `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in
  `project.yml` (Sparkle compares build number). Finalize **only**
  `CHANGELOG.md` (plain bullets; no hand-written `release-notes/`), then
  `xcodegen generate`. Publish extracts GitHub MD + Sparkle HTML from the
  version section.
- Publish requires HEAD on `origin/main`. Do not manually tag before
  `publish-release.sh`.
- Never read/echo `~/.ghostcursor-release-env`.

## Commands

Always: `export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`
before `xcodebuild` / `xcrun` / `swift`. Do not `sudo xcode-select -s`.

- Tests: `swift test --package-path Core`
- Debug build: `xcodegen generate && xcodebuild -project GhostCursor.xcodeproj -scheme GhostCursor -configuration Debug build`
- Ship: `./scripts/release.sh` then `./scripts/publish-release.sh`

## Identity

- Bundle id `sa.ni.GhostCursor` — do not change casually.
- Feed `https://ghostcursor.ni.sa/appcast.xml`; public DMG
  `https://ghostcursor.ni.sa/GhostCursor.dmg`.
- GPL-3.0: Release tags must point at the commit that built the DMG.
