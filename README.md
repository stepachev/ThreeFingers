# ThreeFingers

Tiny native macOS app (~100 lines of Swift) for three-finger trackpad gestures in the browser. No UI, no settings, no dependencies.

| Gesture | Action |
|---|---|
| Three-finger **tap** | Middle click (open link in new tab) — everywhere |
| Three fingers **down** | Close tab (⌘W) — browsers only |
| Three fingers **left / right** | Previous / next tab (⌘⇧[ / ⌘⇧]) — browsers only; keep sliding to step through tabs |

Browsers: Yab, Chrome, Safari, Arc, Firefox (edit `browsers` in `main.swift`).

## Install

```sh
./build.sh        # builds /Applications/ThreeFingers.app
open /Applications/ThreeFingers.app
```

Then allow it in **System Settings → Privacy & Security → Accessibility**. After every rebuild the permission has to be granted again (ad-hoc signature changes).

Free the three-finger swipes from macOS (moves Spaces / Mission Control to four fingers):

```sh
for d in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
  defaults write $d TrackpadThreeFingerHorizSwipeGesture -int 0
  defaults write $d TrackpadThreeFingerVertSwipeGesture -int 0
  defaults write $d TrackpadFourFingerHorizSwipeGesture -int 2
  defaults write $d TrackpadFourFingerVertSwipeGesture -int 2
done
```
Log out and back in if it doesn't apply.

Start at login: System Settings → General → Login Items → add ThreeFingers.

Uses Apple's private `MultitouchSupport` framework.

## License

MIT
