#!/usr/bin/env bash
# Publish an already-built, notarized release: appcast -> R2 -> GitHub Release.
# Run scripts/release.sh first.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_FILE="${GHOSTCURSOR_RELEASE_ENV:-$HOME/.ghostcursor-release-env}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. See README ## Releasing." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

BUCKET="${CLOUDFLARE_R2_BUCKET:-ghostcursor-updates}"
BASE_URL="${UPDATE_BASE_URL:-https://ghostcursor.ni.sa}"
REPO_URL="https://github.com/ielyas/ghost-cursor"

# Cloudflare credentials are optional: wrangler falls back to its own logged-in
# session, which is how this machine is set up.
export CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
export CLOUDFLARE_ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-}"

command -v wrangler >/dev/null || { echo "ERROR: wrangler not found" >&2; exit 1; }
command -v gh >/dev/null || { echo "ERROR: gh not found" >&2; exit 1; }

VERSION="${1:-$(awk -F'"' '/^[[:space:]]*MARKETING_VERSION:/ {print $2; exit}' project.yml)}"
BUILD="$(awk -F'"' '/^[[:space:]]*CURRENT_PROJECT_VERSION:/ {print $2; exit}' project.yml)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: bad version '$VERSION'" >&2; exit 1; }

TAG="v$VERSION"
DMG="dist/GhostCursor-$VERSION.dmg"
[[ -f "$DMG" ]] || { echo "ERROR: $DMG not found. Run scripts/release.sh first." >&2; exit 1; }

echo "==> Confirm the artifact is notarized"
xcrun stapler validate "$DMG"

echo "==> Confirm HEAD is pushed (a release must point at a public commit)"
git fetch --quiet origin
git merge-base --is-ancestor HEAD origin/main \
  || { echo "ERROR: HEAD is not on origin/main. Push first." >&2; exit 1; }

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "ERROR: GitHub Release $TAG already exists." >&2
  exit 1
fi

# Resolve Sparkle's tools from whichever DerivedData last resolved the package.
GEN=""
for candidate in \
  dist/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast \
  DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast
do
  [[ -x "$candidate" ]] && { GEN="$candidate"; break; }
done
[[ -n "$GEN" ]] || { echo "ERROR: generate_appcast not found. Build once, then retry." >&2; exit 1; }

FEED_DIR="dist/appcast"
mkdir -p "$FEED_DIR"
cp -f "$DMG" "$FEED_DIR/"

# Sparkle picks up release notes from a file whose name matches the archive.
if [[ -f "release-notes/$VERSION.html" ]]; then
  cp -f "release-notes/$VERSION.html" "$FEED_DIR/GhostCursor-$VERSION.html"
fi

# Seed from the live feed so previously published entries survive. A 404 on the
# very first release is expected.
if curl -fsSL "$BASE_URL/appcast.xml" -o "$FEED_DIR/appcast.xml"; then
  echo "==> Seeded from the published appcast"
else
  echo "==> No published appcast yet; generating a new one"
  rm -f "$FEED_DIR/appcast.xml"
fi

echo "==> Generate and sign the appcast"
"$GEN" --download-url-prefix "$BASE_URL/" --link "$REPO_URL" "$FEED_DIR"

APPCAST="$FEED_DIR/appcast.xml"
# generate_appcast writes <sparkle:version>N</sparkle:version> as an element, but
# reads the older enclosure-attribute form too; match either.
grep -Eq "sparkle:version(=\"|>)$BUILD(\"|<)" "$APPCAST" \
  || { echo "ERROR: appcast has no entry for build $BUILD" >&2; exit 1; }
grep -q "$BASE_URL/GhostCursor-$VERSION.dmg" "$APPCAST" \
  || { echo "ERROR: appcast enclosure URL is wrong" >&2; exit 1; }
grep -q "sparkle:edSignature" "$APPCAST" \
  || { echo "ERROR: appcast is not EdDSA-signed" >&2; exit 1; }

# Versioned object first, stable alias second, feed last: the feed must never
# name an object that is not there yet.
echo "==> Upload to R2 ($BUCKET)"
wrangler r2 object put "$BUCKET/GhostCursor-$VERSION.dmg" --file="$DMG" \
  --content-type="application/x-apple-diskimage" \
  --cache-control="public, max-age=31536000, immutable" --remote
wrangler r2 object put "$BUCKET/GhostCursor.dmg" --file="$DMG" \
  --content-type="application/x-apple-diskimage" \
  --cache-control="public, max-age=60, must-revalidate" --remote
if [[ -f "$FEED_DIR/GhostCursor-$VERSION.html" ]]; then
  wrangler r2 object put "$BUCKET/GhostCursor-$VERSION.html" \
    --file="$FEED_DIR/GhostCursor-$VERSION.html" \
    --content-type="text/html; charset=utf-8" \
    --cache-control="public, max-age=300" --remote
fi
wrangler r2 object put "$BUCKET/appcast.xml" --file="$APPCAST" \
  --content-type="application/xml; charset=utf-8" \
  --cache-control="no-cache, must-revalidate" --remote

echo "==> Verify what the CDN actually serves"
curl -fsS "$BASE_URL/appcast.xml" | grep -Eq "sparkle:version(=\"|>)$BUILD(\"|<)" \
  || { echo "ERROR: published appcast does not advertise build $BUILD" >&2; exit 1; }
LOCAL_SIZE="$(stat -f %z "$DMG")"
REMOTE_SIZE="$(curl -fsSLI "$BASE_URL/GhostCursor-$VERSION.dmg" \
  | awk 'tolower($1) == "content-length:" {print $2+0}' | tail -1)"
[[ "$LOCAL_SIZE" == "$REMOTE_SIZE" ]] \
  || { echo "ERROR: published DMG size $REMOTE_SIZE != local $LOCAL_SIZE" >&2; exit 1; }

echo "==> Create GitHub Release $TAG"
NOTES_ARG=(--generate-notes)
[[ -f "release-notes/$VERSION.md" ]] && NOTES_ARG=(--notes-file "release-notes/$VERSION.md")
gh release create "$TAG" \
  --title "GhostCursor $VERSION" \
  --target "$(git rev-parse HEAD)" \
  "${NOTES_ARG[@]}" \
  "$DMG"

echo ""
echo "Published $TAG."
echo "  Appcast:  $BASE_URL/appcast.xml"
echo "  Download: $BASE_URL/GhostCursor.dmg"
echo "  Release:  $(gh release view "$TAG" --json url -q .url)"
