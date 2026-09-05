# AGENTS.md — GhostCursor

GhostCursor is a tiny **macOS menu bar app** that hides the mouse cursor after
idle and reveals it on movement. Native **Swift 6 + SwiftUI**, XcodeGen project,
one third-party dependency (**Sparkle** for updates).

Full product intent lives in local `PROJECT_SPEC.md` (gitignored). Implementation
history lives in local `plans/` (gitignored). Public docs: `README.md`,
`CHANGELOG.md`.

---

## Golden rules (MUST follow)

1. **Prefer AskQuestion / AskUserQuestion** for any multiple-choice or gate
   decision — including `/ghostcursor-update` CHANGELOG/Release/build prompts,
   naming, destructive actions, and ambiguous scope. Do not guess irreversible
   choices.
2. **Update `CHANGELOG.md` when users would notice** — friendly public language
   under `[Unreleased]`. Skip for refactor/agent docs/skills (no TRACKER.md;
   local `plans/` is maintainer-only).
3. **Keep `.gitignore` updated** for new tooling/generated files. Never commit
   secrets, `dist/`, Keychain material, or release binaries.
4. **Keep this AGENTS.md current** as commands, conventions, or release flow
   change.
5. **Privacy product promises are load-bearing:** no Accessibility / Input
   Monitoring prompts, no telemetry, no analytics, no crash reporters. The only
   network path is Sparkle checking for updates — automatic and daily
   (`SUScheduledCheckInterval`) by default since plan 015, with silent install
   available as an opt-in toggle (off by default). `README.md`'s "Updates"
   section and privacy bullet state this cadence and these defaults in plain
   language; keep them in sync with `project.yml`'s Sparkle keys and
   `UpdaterManager.swift` if either changes.
6. **Cursor safety:** hide/show must go through the existing CursorHider /
   EmergencyCursorRestore paths. Never invent a “show cursor from another
   process” rescue — WindowServer hide counts are per-connection. Recovery
   guidance stays “quit GhostCursor” / `pkill -x GhostCursor`.
7. **GitHub Issues status:** Never close an issue unless the owner explicitly
   asks. Finishing a fix ≠ closing it.

---

## Commands

Run from repo root (`app/`). Always set before `xcodebuild` / `xcrun` / `swift`:

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
```

| Command | Purpose |
|---------|---------|
| `xcodegen generate` | Regenerate `GhostCursor.xcodeproj` from `project.yml` |
| `swift test --package-path Core` | Logic tests (GhostCursorKit) |
| `xcodebuild -project GhostCursor.xcodeproj -scheme GhostCursor -configuration Debug build` | Debug build |
| `./scripts/release.sh` | Signed/notarized Release archive + DMG (`~/.ghostcursor-release-env`) |
| `./scripts/publish-release.sh` | Appcast → R2 → GitHub Release (requires HEAD on `origin/main`) |
| `./scripts/verify-release-bundle.sh <app> [dmg]` | codesign / stapling checks |

Open in Xcode: `xcodegen generate && open GhostCursor.xcodeproj`.

---

## Stack & layout

```
app/
  AGENTS.md                 # this file
  CHANGELOG.md              # user-facing release notes
  README.md                 # public docs
  project.yml               # XcodeGen — MARKETING_VERSION + CURRENT_PROJECT_VERSION
  GhostCursor/              # app target (SwiftUI, menu bar, settings, Sparkle)
  Core/                     # GhostCursorKit package + tests
  scripts/                  # release.sh, publish-release.sh, verify-…
  docs/                     # README screenshots / icon
  .cursor/skills/           # /ghostcursor-update
```

- Bundle id: `sa.ni.GhostCursor`
- Sparkle feed: `https://ghostcursor.ni.sa/appcast.xml`
- Public download: `https://ghostcursor.ni.sa/GhostCursor.dmg`
- GitHub: `ielyas/ghost-cursor` (public, GPL-3.0)
- Copyright: © 2026 National Idea LLC

Do not change the bundle id, feed URL, or `SUPublicEDKey` without a deliberate
migration plan.

---

## CHANGELOG.md (user-facing)

| Change type | Update `CHANGELOG.md`? |
|-------------|-------------------------|
| New feature users can see | Yes — **Added** |
| UX / behavior change | Yes — **Changed** |
| Bug fix users hit | Yes — **Fixed** |
| Refactor, agent docs, skills, local plans | No |

Language: plain English for people who use the app, not file names. Plain
bullets only (no tables/nested lists/raw HTML) so publish can MD→HTML for
Sparkle. `CHANGELOG.md` is the **only** authored release-notes source; GitHub
Markdown and Sparkle HTML are generated at publish from the `## [X.Y.Z]`
section. Do not hand-write `release-notes/`.

---

## `/ghostcursor-update` (commit + local release)

Project skill: [`.cursor/skills/ghostcursor-update/SKILL.md`](.cursor/skills/ghostcursor-update/SKILL.md).
Prefer **`/ghostcursor-update`** over global `/git-commit-push`.

Order: **CHANGELOG gate → Release gate → build/debug → commit → push → (if
release) `scripts/release.sh` → `scripts/publish-release.sh`**.

Do not `git add`/`commit` until both gates resolve.

- **CHANGELOG gate:** Diff → user-visible? → match `[Unreleased]` → AskQuestion
  (Approve / Edit / Skip changelog / Cancel).
- **Release gate:** AskQuestion (Yes release / No commit only / Cancel). On Yes:
  bump **both** `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in
  `project.yml` (Sparkle needs a new build number), finalize **only**
  `CHANGELOG.md` (summary line + plain bullets; no `release-notes/`),
  `xcodegen generate`, commit/push to **main**, then release + publish.
  Do not manually tag before `publish-release.sh`.
- Never publish if push failed or HEAD is not on `origin/main`.

---

## Local publish

- `~/.ghostcursor-release-env` — Apple notarization vars; never commit or echo.
- Sparkle EdDSA **private** key lives in the login Keychain (not a file). Public
  key is `SUPublicEDKey` in `project.yml`.
- `scripts/release.sh` — tests → archive → Developer ID export → notarize app →
  DMG → notarize/staple DMG.
- `scripts/publish-release.sh` — `changelog-release-notes.sh` (MD + HTML from
  `CHANGELOG.md`) → signed appcast → R2 (`ghostcursor-updates`) →
  `gh release create`. Requires a `## [X.Y.Z]` section for the version being
  shipped.

---

## Conventions

- **Swift 6** language mode; prefer Swift Testing in `Core`.
- Exhaustive `switch` with `never` / `@unknown default` where appropriate.
- No event taps / global event monitors for idle detection — polling via
  `CGEventSource.secondsSinceLastEventType` is intentional (no Accessibility
  prompt).
- Private API (`CGSSetConnectionProperty`) only via `dlsym`, with graceful
  degradation if missing.
- UI copy: Title Case for buttons/menus; sentence case elsewhere. Verb + object
  buttons. Errors: what failed + why + next step.
- Commits: Conventional Commits; include CHANGELOG in the same commit when
  user-visible (publish generates GitHub/Sparkle notes from it).
