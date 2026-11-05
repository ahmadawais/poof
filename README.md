# Poof

Hide your Mac's cursor. It vanishes after a few seconds of not moving and comes back the moment you touch the
mouse or trackpad. Or press **⌃⌥K** to make it go *poof* right now.

## Features

- **Hide when idle**: after 3 s without moving or clicking (1–60 s, slider). Moving or clicking brings it back.
- **⌃⌥K**: hide now, or show again. *Show when moved* (on by default) lets movement bring it back too; turn it off
  and only ⌃⌥K does, even through clicks and app switches.
- Menu bar icon (optional; open Poof from Spotlight to reach Settings when hidden). Launch at login.

## Private by construction

- App Sandbox with **no** entitlements: the kernel blocks all network access, and Poof can't read your files.
- **No permissions**: no Accessibility, no Input Monitoring, no Screen Recording. It only reads where the pointer
  is and when the mouse last clicked. The shortcut uses Carbon `RegisterEventHotKey`, which needs no permission.
- Stores only its settings. ~500 KB, no dependencies, 0% CPU while idle.

How it hides: a background app's `CGDisplayHideCursor` is ignored by macOS unless its WindowServer connection sets
the private `SetsCursorInBackground` property, the same trick other cursor hiders use.

## Install

Needs macOS 14+ and the Command Line Tools (`xcode-select --install`). No Xcode.

```bash
git clone https://github.com/ahmadawais/poof.git && cd poof
./scripts/install.sh   # builds, copies to /Applications, launches
./scripts/test.sh      # Swift Testing suite
```

No Apple Developer account or certificate needed: the build is ad-hoc signed on your Mac, and since Poof asks for
no permissions there is no grant to lose when you rebuild. Built locally, it isn't quarantined, so Gatekeeper
doesn't block it either. (`SIGN_ID="Developer ID Application: …" ./scripts/build.sh` if you want to sign it.)

## License

MIT © Ahmad Awais
