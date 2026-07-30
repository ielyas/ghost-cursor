#!/usr/bin/env bash
# Verify a Release-built GhostCursor.app (and optionally its DMG) is signed the
# way notarization and the private WindowServer call both require.
#
# Set EXPECT_NOTARIZED=0 to run this before notarization, when the Gatekeeper
# and stapling checks cannot pass yet.
set -euo pipefail

APP="${1:?usage: verify-release-bundle.sh <GhostCursor.app> [GhostCursor.dmg]}"
DMG="${2:-}"
TEAM_ID="M8A3G95883"
EXPECT_NOTARIZED="${EXPECT_NOTARIZED:-1}"

fail() { echo "ERROR: $*" >&2; exit 1; }

echo "==> codesign --verify on $APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Developer ID team and Hardened Runtime on the app"
codesign -dvv "$APP" 2>&1 | grep -q "TeamIdentifier=$TEAM_ID" \
  || fail "app is not signed by team $TEAM_ID (ad-hoc or wrong certificate)"
codesign -d --verbose=4 "$APP" 2>&1 | grep -Eq 'flags=.*runtime' \
  || fail "Hardened Runtime is not enabled on the app"

echo "==> Sparkle's nested code is signed the same way"
FW="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for nested in \
  "$APP/Contents/Frameworks/Sparkle.framework" \
  "$FW/Updater.app" \
  "$FW/Autoupdate" \
  "$FW/XPCServices/Installer.xpc" \
  "$FW/XPCServices/Downloader.xpc"
do
  [[ -e "$nested" ]] || fail "missing nested component: $nested"
  codesign -dvv "$nested" 2>&1 | grep -q "TeamIdentifier=$TEAM_ID" \
    || fail "$nested is not signed by team $TEAM_ID"
done

# App Sandbox breaks the private CGSSetConnectionProperty call the whole app
# depends on, and the only reason it is off is that no entitlements file exists.
echo "==> App Sandbox is absent"
if codesign -d --entitlements - "$APP" 2>&1 | grep -q "app-sandbox"; then
  fail "app-sandbox entitlement is present"
fi

if [[ "$EXPECT_NOTARIZED" == "1" ]]; then
  echo "==> Notarization ticket is stapled to the app"
  xcrun stapler validate "$APP"

  echo "==> Gatekeeper accepts the app"
  spctl --assess --type execute --verbose=4 "$APP"
fi

if [[ -n "$DMG" ]]; then
  echo "==> Notarization ticket is stapled to the DMG"
  xcrun stapler validate "$DMG"

  echo "==> Gatekeeper accepts the DMG"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG"
fi

echo "==> All release-bundle checks passed"
