#!/usr/bin/env bash
# Build a Developer ID signed, notarized GhostCursor release and package it as a
# DMG. Reads the version from project.yml so there is one source of truth.
#
# Prerequisites: ~/.ghostcursor-release-env (mode 600), a Developer ID
# Application certificate, and Xcode. Publishing is a separate script.
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

for var in APPLE_ID APPLE_PASSWORD APPLE_TEAM_ID APPLE_SIGNING_IDENTITY; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: $var is not set (sourced from $ENV_FILE)" >&2
    exit 1
  fi
done

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "ERROR: DEVELOPER_DIR does not exist: $DEVELOPER_DIR" >&2
  exit 1
fi

VERSION="$(awk -F'"' '/^[[:space:]]*MARKETING_VERSION:/ {print $2; exit}' project.yml)"
BUILD="$(awk -F'"' '/^[[:space:]]*CURRENT_PROJECT_VERSION:/ {print $2; exit}' project.yml)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: bad MARKETING_VERSION '$VERSION'" >&2; exit 1; }
[[ "$BUILD" =~ ^[0-9]+$ ]] || { echo "ERROR: bad CURRENT_PROJECT_VERSION '$BUILD'" >&2; exit 1; }

echo "==> GhostCursor $VERSION (build $BUILD)"

DIST="$ROOT/dist"
ARCHIVE="$DIST/GhostCursor.xcarchive"
EXPORT_DIR="$DIST/export"
APP="$EXPORT_DIR/GhostCursor.app"
DMG="$DIST/GhostCursor-$VERSION.dmg"
APP_ZIP="$DIST/GhostCursor-$VERSION-notarize.zip"

rm -rf "$ARCHIVE" "$EXPORT_DIR" "$DMG" "$APP_ZIP"
mkdir -p "$DIST"

echo "==> Logic tests"
swift test --package-path Core

echo "==> Regenerate the project from project.yml"
xcodegen generate

echo "==> Archive (Release)"
xcodebuild -project GhostCursor.xcodeproj -scheme GhostCursor -configuration Release \
  -archivePath "$ARCHIVE" -derivedDataPath "$DIST/DerivedData" archive

echo "==> Export with Developer ID"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist scripts/ExportOptions.plist -exportPath "$EXPORT_DIR"

echo "==> Verify the signature before spending notarization time on it"
EXPECT_NOTARIZED=0 "$ROOT/scripts/verify-release-bundle.sh" "$APP"

# Notarize the app itself, not only the DMG, so the installed copy carries its
# own stapled ticket and Gatekeeper is satisfied even offline.
echo "==> Notarize the app (this waits on Apple; minutes, not seconds)"
/usr/bin/ditto -c -k --keepParent "$APP" "$APP_ZIP"
xcrun notarytool submit "$APP_ZIP" \
  --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_PASSWORD" --wait
xcrun stapler staple "$APP"
rm -f "$APP_ZIP"

echo "==> Build the DMG"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
/bin/cp -R "$APP" "$STAGING/GhostCursor.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "GhostCursor" -srcfolder "$STAGING" -ov -format UDZO -fs HFS+ "$DMG"

echo "==> Notarize and staple the DMG"
xcrun notarytool submit "$DMG" \
  --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_PASSWORD" --wait
xcrun stapler staple "$DMG"

echo "==> Final verification"
"$ROOT/scripts/verify-release-bundle.sh" "$APP" "$DMG"

echo ""
echo "Release build complete."
echo "  App: $APP"
echo "  DMG: $DMG"
echo "  Next: scripts/publish-release.sh"
