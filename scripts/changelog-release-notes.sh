#!/usr/bin/env bash
# Extract release notes for a version from CHANGELOG.md (single authored source).
# Usage:
#   changelog-release-notes.sh <version>           # section body (markdown) → stdout
#   changelog-release-notes.sh <version> --summary # one-line summary → stdout
#   changelog-release-notes.sh <version> --html    # Sparkle fragment (HTML) → stdout
set -euo pipefail

VERSION="${1:?usage: changelog-release-notes.sh <version> [--summary|--html]}"
MODE="${2:-}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHANGELOG="${CHANGELOG_FILE:-$ROOT/CHANGELOG.md}"
if [[ ! -f "$CHANGELOG" ]]; then
  echo "ERROR: $CHANGELOG not found" >&2
  exit 1
fi

SECTION_FILE="$(mktemp)"
trap 'rm -f "$SECTION_FILE"' EXIT

# Body only (skip the ## [version] heading). Stop before the next ## [ section.
# Drop Keep-a-Changelog footer link refs that sit after the last version block.
awk -v ver="$VERSION" '
  BEGIN { found=0 }
  /^## \[/ {
    if (found) { exit }
    if ($0 ~ "^## \\[" ver "\\]") { found=1; next }
  }
  found {
    if ($0 ~ /^\[[Uu]nreleased\]:/) { next }
    if ($0 ~ /^\[[0-9]+\.[0-9]+\.[0-9]+\]:/) { next }
    print
  }
' "$CHANGELOG" > "$SECTION_FILE"

# Trim trailing blank lines for emptiness check.
if ! grep -q '[^[:space:]]' "$SECTION_FILE"; then
  echo "ERROR: no changelog section for version $VERSION (expected ## [$VERSION])" >&2
  exit 1
fi

case "$MODE" in
  --summary)
    # First non-empty line that is not a ### heading — the friendly intro blurb.
    awk '
      /^### / { next }
      /^---$/ { next }
      NF { print; exit }
    ' "$SECTION_FILE"
    ;;
  --html)
    # Tight Sparkle fragment: title, summary paragraph, all bullets in one list.
    # Skips ### Keep-a-Changelog headers. Plain markdown only.
    python3 - "$VERSION" "$SECTION_FILE" <<'PY'
import html
import re
import sys

version, path = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().splitlines()

summary_parts: list[str] = []
bullets: list[str] = []
mode = "summary"  # summary | bullet | skip_heading

def flush_summary():
    text = " ".join(summary_parts).strip()
    summary_parts.clear()
    return text

current_bullet: list[str] = []

def flush_bullet():
    if not current_bullet:
        return
    text = " ".join(part.strip() for part in current_bullet).strip()
    current_bullet.clear()
    if text:
        # Strip a leading "- " if somehow present twice
        text = re.sub(r"^-+\s*", "", text)
        bullets.append(text)

for raw in lines:
    line = raw.rstrip()
    if not line.strip():
        if mode == "bullet":
            flush_bullet()
        continue
    if line.startswith("### "):
        flush_bullet()
        mode = "skip_heading"
        continue
    if re.match(r"^-+\s+", line):
        flush_bullet()
        if mode == "summary" and summary_parts:
            pass  # summary already collected
        mode = "bullet"
        current_bullet = [re.sub(r"^-+\s+", "", line)]
        continue
    if mode == "bullet" and current_bullet and (line.startswith("  ") or line.startswith("\t")):
        current_bullet.append(line.strip())
        continue
    if mode in ("summary", "skip_heading") and not line.startswith("#"):
        if mode == "skip_heading":
            # Rare prose under a ### with no bullets — treat as summary only if none yet
            if not summary_parts and not bullets:
                summary_parts.append(line.strip())
                mode = "summary"
            continue
        summary_parts.append(line.strip())

flush_bullet()
summary = flush_summary()

print(f"<h2>GhostCursor {html.escape(version)}</h2>")
if summary:
    print(f"<p>{html.escape(summary)}</p>")
if bullets:
    print("<ul>")
    for item in bullets:
        # Light inline markdown: **bold** and `code`
        escaped = html.escape(item)
        escaped = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", escaped)
        escaped = re.sub(r"`([^`]+)`", r"<code>\1</code>", escaped)
        print(f"  <li>{escaped}</li>")
    print("</ul>")
PY
    ;;
  "")
    # Trim leading/trailing blank lines for a clean GitHub body.
    awk '
      NF { seen=1 }
      seen { print }
    ' "$SECTION_FILE" | awk '
      { lines[NR]=$0 }
      END {
        end=NR
        while (end>0 && lines[end] ~ /^[[:space:]]*$/) end--
        for (i=1; i<=end; i++) print lines[i]
      }
    '
    ;;
  *)
    echo "ERROR: unknown mode '$MODE' (use --summary or --html)" >&2
    exit 1
    ;;
esac
