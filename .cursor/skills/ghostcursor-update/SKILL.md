---
name: ghostcursor-update
description: >-
  Commit and push GhostCursor changes with CHANGELOG/Release gates; optionally
  ship a local signed release (build, Sparkle appcast, R2, GitHub Release). Use
  when the user says /ghostcursor-update, asks to commit/push/save GhostCursor
  changes, or ship a local release.
---

# GhostCursor Update (`/ghostcursor-update`)

Project fork of git-commit-push for GhostCursor. Prefer this over the global
`/git-commit-push` skill in this repo.

**Release model:** builds and publishes **locally** (`scripts/release.sh` →
`scripts/publish-release.sh`). No GitHub Actions release workflow — shipping is
manual on the maintainer Mac. GitHub Release still appears via `gh release create`
(tag + DMG + notes). Sparkle updates come from the R2 appcast at
`https://ghostcursor.ni.sa/appcast.xml`.

**One authored source for release notes:** edit only `CHANGELOG.md`. GitHub
wants Markdown and Sparkle wants HTML beside the DMG — that packaging split
stays, but both are **generated at publish** from the `## [X.Y.Z]` section.
Do **not** hand-write or commit new `release-notes/<ver>.md` / `.html` files.

Run all commands from the repo root (`app/`). Before any `xcodebuild`, `xcrun`,
or `swift` command:

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
```

Do **not** run `sudo xcode-select -s` to switch the machine globally.

## Prerequisites for a release

| Requirement | Notes |
|-------------|--------|
| `~/.ghostcursor-release-env` | `APPLE_SIGNING_IDENTITY`, `APPLE_ID`, `APPLE_PASSWORD`, `APPLE_TEAM_ID`; optional `CLOUDFLARE_*` (wrangler session may suffice) |
| Developer ID cert in login keychain | `security find-identity -v -p codesigning \| grep "Developer ID Application"` |
| Sparkle EdDSA private key in login Keychain | Public half must match `SUPublicEDKey` in `project.yml` |
| `gh` authenticated | `gh auth status` |
| `wrangler` available | Used by `publish-release.sh` for R2 |
| `xcodegen` | Regenerates the Xcode project from `project.yml` |
| macOS + Xcode | Local notarization only works on a Mac |
| `CHANGELOG.md` section for the version | Publish extracts it; empty/missing section = hard fail |

Never read, paste, or log secrets from `~/.ghostcursor-release-env`.

---

## Writing `CHANGELOG.md` (authoring rules)

`CHANGELOG.md` is the only place the release story is written. Keep a Changelog
shape; plain English for people who use the app, not file names.

### When to update (Gate A)

| Change type | Update? |
|-------------|---------|
| New feature users can see | Yes — **Added** |
| UX / behavior change | Yes — **Changed** |
| Bug fix users hit | Yes — **Fixed** |
| Something removed users notice | Yes — **Removed** |
| Refactor, agent docs, skills, local plans | No |

### Section shape (Gate B finalize)

```markdown
## [X.Y.Z] — YYYY-MM-DD

One-sentence summary of what this release means for the user.

### Added

- Short plain bullet.

### Changed

- …

### Fixed

- …

### Removed

- …
```

Rules:

1. **Heading:** `## [X.Y.Z] — YYYY-MM-DD` (em dash). Version in brackets must
   match `MARKETING_VERSION` exactly so extractors can find it.
2. **Summary line:** first non-empty, non-`###` line under the heading. Used as
   a short blurb; keep it one sentence.
3. **Omit empty subsections** on the finalized version section (no empty
   `### Added` blocks). Keep empty `###` stubs only under `[Unreleased]` if the
   file uses that template.
4. **Plain bullets only** — Sparkle HTML is a short subset produced by a dumb
   MD→HTML converter. Allowed: paragraphs, `###` headings, `- ` lists,
   **bold**, `code`. Avoid: tables, nested lists, images, raw HTML, link-heavy
   prose, footnotes.
5. **User language:** “Idle auto-hide now …” not “Updated `IdleMonitor.swift`.”
6. **No dual authoring:** never create/update a `release-notes/` directory.
   Publish generates Markdown/HTML into temp/dist only.
7. **Footer links:** when finalizing a version, update the compare/tag links at
   the bottom of `CHANGELOG.md` (`[Unreleased]:` → new compare base, add
   `[X.Y.Z]:` release URL).

### Packaging split (do not re-author)

| Consumer | Source at publish |
|----------|-------------------|
| GitHub Release body | Full `## [X.Y.Z]` section as Markdown |
| Sparkle in-app notes | Same bullets as HTML beside the DMG (may drop Keep-a-Changelog `###` headers for a tighter dialog) |
| Repo / README | `CHANGELOG.md` itself |

---

## Workflow

Order (do not skip gates):

```
CHANGELOG gate → Release gate → build/debug prompt → commit → push
  → (if release) scripts/release.sh → scripts/publish-release.sh
```

Do **not** `git add` / `git commit` until CHANGELOG + Release gates resolve
(or Cancel).

Use **AskQuestion** / **AskUserQuestion** for every gate when the tool is
available; otherwise ask the same options in plain chat.

---

### Gate A — CHANGELOG

1. Run in parallel: `git status`, `git diff`, `git diff --staged`,
   `git branch --show-current`, `git log -3 --oneline`.
2. Decide if changes are **user-visible** (table above).
3. Read `CHANGELOG.md` `[Unreleased]`.
4. If user-visible work lacks matching bullets → draft friendly **plain**
   bullets under the right `###` heading; do not commit yet.
5. AskQuestion — **“CHANGELOG check before commit”**:
   - **Approve** — apply/keep bullets; include `CHANGELOG.md` in the commit.
   - **Edit** — user revises; update file; re-ask until Approve/Skip/Cancel.
   - **Skip changelog** — only if user picks this.
   - **Cancel** — stop entirely.

Internal-only (refactor, agent docs, skills, plans): state “CHANGELOG not
required” in one line, then Gate B. No changelog approval unless
`CHANGELOG.md` was edited by mistake.

---

### Gate B — Release

AskQuestion — **“Release this commit?”**:

- **Yes, release** — follow **Release path** below, then continue.
- **No, commit only** — skip version bump / build / publish; commit + push only.
- **Cancel** — stop.

#### Release path (Yes)

1. Read versions from `project.yml`:
   - `MARKETING_VERSION` (semver, e.g. `1.0.0`)
   - `CURRENT_PROJECT_VERSION` (integer build, e.g. `1`)
2. AskQuestion — **“Version to release”**: show current marketing + build, and
   recommended next (default **patch** marketing + **build + 1**). Sparkle
   compares **build number** (`CFBundleVersion`), not marketing version — every
   release **must** bump `CURRENT_PROJECT_VERSION` or installed copies will
   ignore the update. Options: recommended pair + **Other**.
3. Ensure tag free: `git tag -l 'v<version>'` and
   `gh release view v<version>` — if either exists, stop and ask for another
   version.
4. Finalize **only** `CHANGELOG.md` (required for release):
   - Move `[Unreleased]` bullets into `## [X.Y.Z] — YYYY-MM-DD` (today).
   - Add the one-sentence summary under the heading.
   - Drop empty `###` subsections from the new version section.
   - Reset `[Unreleased]` (empty headings OK).
   - Update footer compare/tag links.
   - AskQuestion to approve wording if you drafted/edited the section.
   - **Do not** write `release-notes/X.Y.Z.md` or `.html`.
5. Bump both fields in `project.yml`, then regenerate:

```bash
# edit MARKETING_VERSION and CURRENT_PROJECT_VERSION in project.yml
xcodegen generate
```

6. Continue to build/debug → commit (include `CHANGELOG.md`, `project.yml`,
   regenerated `GhostCursor.xcodeproj` if changed — **not** `release-notes/`).
   Suggested message: `chore(release): vX.Y.Z`.

---

### Step 0 — Build / debug before commit

AskQuestion — **“Would you like to build or debug before committing?”**:

- **Yes, run build** — `swift test --package-path Core` and
  `xcodegen generate && xcodebuild -project GhostCursor.xcodeproj -scheme GhostCursor -configuration Debug build`
  (with `DEVELOPER_DIR` set). Fix failures.
- **Yes, run debug** — run the checks the user expects (often a Debug launch /
  manual smoke); fix failures.
- **Both** — build then debug.
- **skip** — continue.

On a **Yes, release** path, a full `scripts/release.sh` comes **after** push;
this step is still useful for a fast gate before committing.

---

### Step 1–4 — Commit

1. Re-check `git status` / diffs if needed.
2. Stage relevant files (`git add` selectively; never secrets, `.env`, keys,
   `dist/`, `DerivedData/`, `PROJECT_SPEC.md`, `plans/` — those are gitignored
   for the public repo). Do not stage new `release-notes/` for this workflow.
3. Conventional Commits message via HEREDOC:

```bash
git commit -m "$(cat <<'EOF'
type(scope): short summary

Optional body.
EOF
)"
```

4. Verify with `git status`. If hooks fail, fix and create a **new** commit
   (do not amend unless user rules allow).

---

### Step 5 — Push

`publish-release.sh` requires **HEAD to be on `origin/main`** (ancestor check).
Prefer releasing from `main` after a successful push.

```bash
git remote -v
git push -u origin HEAD
```

If on a feature branch and releasing: AskQuestion whether to merge into `main`
first — publish will fail if HEAD is not on `origin/main`.

If no remote: AskQuestion whether to create a GitHub repo (private/public/skip).
Never run `github-create-repo` unless the user explicitly wants a new repo.

If push fails: suggest `git pull --rebase`; do **not** force-push unless asked.
If branch push failed on a release path: **stop** — do not build or publish.

---

### Step 6 — Local release publish (only if Gate B = Yes)

After a successful push with HEAD on `origin/main`:

1. Run the signed build (5–15+ minutes; notarizes app + DMG):

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
./scripts/release.sh
```

2. Publish (notes from CHANGELOG → Sparkle appcast → R2 → GitHub Release + tag):

```bash
./scripts/publish-release.sh
# or: ./scripts/publish-release.sh X.Y.Z
```

`scripts/publish-release.sh` will:

- Compose GitHub Markdown + Sparkle HTML from `CHANGELOG.md` via
  `scripts/changelog-release-notes.sh` (temp/dist only — not committed)
- Validate the stapled DMG
- Confirm HEAD is on `origin/main`
- Seed/generate EdDSA-signed `appcast.xml` via Sparkle `generate_appcast`
- Upload versioned DMG, stable `GhostCursor.dmg`, HTML notes, and `appcast.xml`
  to R2 (`ghostcursor-updates` → `https://ghostcursor.ni.sa`)
- Verify CDN serves the new build
- `gh release create vX.Y.Z` with the DMG + extracted notes (creates/pushes the
  tag targeting `HEAD`)

3. Tell the user:
   - GitHub Release URL (`gh release view vX.Y.Z --json url -q .url`)
   - Appcast: `https://ghostcursor.ni.sa/appcast.xml`
   - Public DMG: `https://ghostcursor.ni.sa/GhostCursor.dmg`

Do **not** separately `git tag` + `git push origin vX.Y.Z` before
`publish-release` — `gh release create` owns the tag. Avoid double-tagging.

---

### Step 7 — Merge into main (optional, commit-only path)

If not on `main`/`master` and this was **commit only**, AskQuestion —
**“Merge this branch into main?”**:

- **Yes, merge into main** — fetch, checkout main, pull, merge, push; stop on
  conflicts.
- **No, keep on current branch** — done.

On a **release** path, merge (if needed) must happen **before** Step 6 so
`publish-release.sh`'s `origin/main` check passes.

---

## Important notes

- Prefer **AskQuestion** for all gates; never guess irreversible choices.
- Never force-push to main/master unless explicitly requested.
- Never commit secrets, `dist/`, or Keychain material.
- `--no-verify` only if the user explicitly requests it.
- GPL-3.0: each GitHub Release must target the commit that built the DMG so
  corresponding source stays available. Do not rewrite Release targets after
  publication.
- Bundle id `sa.ni.GhostCursor` / feed `https://ghostcursor.ni.sa/appcast.xml` —
  do not change without updating `project.yml`, Info.plist properties, and
  AGENTS.md.
- Never mention private planning files (`PROJECT_SPEC.md`, `plans/`) as if they
  ship in the public repo — they are gitignored.

## Error handling

| Situation | Action |
|-----------|--------|
| Nothing to commit | Say so; stop (unless release-only republish — ask first) |
| Push rejected | `git pull --rebase`; do not publish until push succeeds |
| HEAD not on `origin/main` | Merge/push to main first; do not publish |
| `CHANGELOG.md` missing `## [X.Y.Z]` | Finalize changelog; do not invent `release-notes/` |
| `scripts/release.sh` fails | Diagnose notarization/signing from logs; do not publish |
| `publish-release` fails mid-upload | Fix and re-run; script errors if GitHub Release already exists |
| Release / tag already exists | Stop; ask for a new version (+ new build number) |
| Appcast missing EdDSA signature | Sparkle keychain key missing/mismatched — STOP |
| `gh` / `wrangler` missing | Install/auth before retrying publish |
