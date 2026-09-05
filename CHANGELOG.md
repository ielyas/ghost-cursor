# Changelog

All notable changes to GhostCursor are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Edit this file only. Publish extracts the `## [X.Y.Z]` section for GitHub
Release notes and converts it to HTML for Sparkle — do not hand-write
`release-notes/`. Keep bullets plain (no tables, nested lists, or raw HTML).

## [Unreleased]

## [1.2.0] — 2026-09-05

GhostCursor now keeps itself up to date instead of waiting for you to check.

### Changed

- GhostCursor now checks for updates automatically, about once a day,
  instead of only when you ask. It still asks before installing anything —
  you can turn automatic checks off, or let updates install themselves
  without asking, in Settings › About.

## [1.1.0] — 2026-09-05

Adds a shorter hide delay for people who want the cursor gone almost immediately.

### Added

- A 0.5 second hide delay option.

## [1.0.1] — 2026-07-31

Verifies the in-app update path; no behavior changes from 1.0.0.

### Changed

- README includes the app icon, settings screenshots, and a link to the changelog.

## [1.0.0] — 2026-07-31

First public release.

### Added

- Idle auto-hide with configurable delay (1–60 seconds) and instant reveal on
  mouse movement
- Global keyboard shortcut to toggle auto-hide
- Launch at login
- Menu bar icon that reflects on/off state
- Settings › General, Shortcut, and About
- User-initiated update checks via Sparkle (no background polling)
- Developer ID signed and notarized distribution

[Unreleased]: https://github.com/ielyas/ghost-cursor/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/ielyas/ghost-cursor/releases/tag/v1.2.0
[1.1.0]: https://github.com/ielyas/ghost-cursor/releases/tag/v1.1.0
[1.0.1]: https://github.com/ielyas/ghost-cursor/releases/tag/v1.0.1
[1.0.0]: https://github.com/ielyas/ghost-cursor/releases/tag/v1.0.0
