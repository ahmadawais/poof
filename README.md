<p align="center"><img src=".github/hero.png" width="860" alt="Poof: your cursor vanishes when idle. Touch the mouse, it's back."></p>

# Poof

Hide your Mac's cursor. It vanishes after a few seconds of not moving and comes back the moment you touch the
mouse or trackpad. Optionally, turn on **⌃⌥K** to make it go *poof* right now.

## Features

- **Hide when idle**: after 3 s without moving or clicking (1–60 s, slider). Moving or clicking brings it back.
- **⌃⌥K** (suggested, off by default: no global shortcut until you turn it on): hide now, or show again.
  *Show when moved* (on) lets movement bring it back too; turn it off and only ⌃⌥K does, even through clicks and
  app switches.
- No menu bar icon by default (turn it on in Settings). Open Poof from Spotlight to reach Settings; they also open
  once on first launch. Launch at login.

## Private by construction

- App Sandbox with **no** entitlements: the kernel blocks all network access, and Poof can't read your files.
- **No permissions**: no Accessibility, no Input Monitoring, no Screen Recording. It only reads where the pointer
  is and when the mouse last clicked. The shortcut uses Carbon `RegisterEventHotKey`, which needs no permission.
- Stores only its settings. ~500 KB, no dependencies, 0% CPU while idle.

How it hides: a background app's `CGDisplayHideCursor` is ignored by macOS unless its WindowServer connection sets
the private `SetsCursorInBackground` property, the same trick other cursor hiders use.

## Install

No Xcode, no Apple Developer account, no certificate: Poof asks for no permissions, so there's no grant to keep
and an ad-hoc signature made on your Mac is all it needs. Two ways, same result.

**1. Download the release:**

```bash
curl -fsSL https://raw.githubusercontent.com/ahmadawais/poof/main/scripts/get.sh | bash
```

[`get.sh`](scripts/get.sh) downloads the latest [release](https://github.com/ahmadawais/poof/releases), checks its
SHA-256 sums, signs it on your Mac and installs it to `/Applications`. Run it again to update. With the
[GitHub CLI](https://cli.github.com) signed in it also checks the build provenance: proof the zip was built by
this repo's [release workflow](.github/workflows/release.yml) from the tagged commit
(`gh attestation verify Poof.zip --repo ahmadawais/poof`). Prefer reading first? Download `get.sh`, read it,
then `bash get.sh`.

**2. Build from source** (Command Line Tools: `xcode-select --install`):

```bash
git clone https://github.com/ahmadawais/poof.git && cd poof
./scripts/install.sh   # builds, copies to /Applications, launches
./scripts/test.sh      # Swift Testing suite
```

Either way it's never quarantined, so Gatekeeper doesn't block it.

## License

MIT © Ahmad Awais
