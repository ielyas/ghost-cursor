# GhostCursor

A tiny macOS menu bar app that hides the mouse cursor when you stop moving it, and
brings it back the instant you do.

- **No permissions.** No Accessibility prompt, no Input Monitoring prompt, nothing.
- **No network.** Not a single outbound connection, ever.
- **No data.** GhostCursor reads only *how long ago* a mouse event happened. It
  cannot see what you type, even in principle.

Requires macOS 14 or later.

## Recover a stuck cursor

This is the one thing worth knowing before you use it.

**Quit GhostCursor.** macOS restores the cursor as soon as the app's connection to
the window server closes — including when the app crashes or is force-killed.

If you cannot reach the menu bar icon, open Terminal and run:

```sh
pkill -x GhostCursor
```

If you cannot reach Terminal either, log out with **Control-Option-Command-Q**, then
press Return.

A script that "shows the cursor" **will not work**. Cursor hiding is reference
counted per process connection, so only GhostCursor — or its termination — can undo
GhostCursor's hide.

## Using it

Click the menu bar icon for the on/off switch and the delay. The icon is slashed
when auto-hide is on.

| Setting | Where | Notes |
|---|---|---|
| Auto-hide on/off | Menu, Settings › General, or your shortcut | On by default |
| Delay before hiding | Menu, or the slider in Settings › General | 1, 2, 3, 5, 10, 15, 30 or 60 seconds; 3 by default |
| Global shortcut | Settings › Shortcut | Toggles auto-hide from anywhere; unassigned by default |
| Launch at login | Settings › General | On by default |

The cursor never hides while a mouse button is held, so drags and selections are
safe. It also reveals itself on display sleep, wake, screen lock and display
changes, and stays visible until you move the mouse again.

## Building from source

```sh
brew install xcodegen
xcodegen generate
open GhostCursor.xcodeproj
```

Then build and run the `GhostCursor` scheme. The logic tests live in a local Swift
package:

```sh
swift test --package-path Core
```

There are no third-party dependencies, and there never will be.

## Reporting a bug

GhostCursor has no telemetry, so a log helps. Reproduce the problem, then run:

```sh
log show --last 10m --predicate 'subsystem == "sa.ni.GhostCursor"' --info --debug --style compact
```

Attach the output to an issue at
<https://github.com/ielyas/ghost-cursor/issues>, along with your macOS version.

## How it works, and the catch

Hiding the cursor from a background app is not possible with public API alone.
GhostCursor calls one private CoreGraphics function, `CGSSetConnectionProperty`,
to grant itself background cursor control, and resolves it at runtime with `dlsym`
rather than linking it. If a future macOS removes that function, the app notices at
launch, disables hiding, and tells you — instead of failing to start.

The consequence is deliberate and permanent: **GhostCursor can never be distributed
through the Mac App Store.** Only App Store review rejects private API use;
notarization does not.

Idle detection uses `CGEventSource.secondsSinceLastEventType`, a public API that
needs no entitlement, polled on an adaptive timer — 250 ms while visible, 60 Hz
while hidden. That polling choice is what avoids the Accessibility permission an
event tap would require.
