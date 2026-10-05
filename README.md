# Lifeboat

When you unplug a Mac from a monitor, the windows that were on it land on the laptop screen at their old size. They hang off the edges, and Mission Control shrinks everything to tiny thumbnails trying to fit them, so it can't help either.

Lifeboat is a small menu bar app that fixes this.

- **Unplug a monitor** and every window that's off the screen, or too big for it, gets shrunk to fit and moved fully onto the screen.
- **Plug it back in** and each window goes back to where it was on that monitor. Lifeboat keeps a layout for each display setup, so your laptop-only layout comes back too.
- **Press ⌃⌥⌘R** any time to pull stray windows back onto the screen.

Once the windows fit, Mission Control goes back to normal.

## Install

1. Download `Lifeboat-0.1.0.dmg` from the [latest release](https://github.com/iprincemax72-maker/lifeboat/releases/latest).
2. Open the DMG and drag Lifeboat into Applications.
3. Open Lifeboat from Applications. macOS blocks it the first time because Apple hasn't notarized it. Click Done, go to System Settings > Privacy & Security, scroll to the bottom, and click Open Anyway.
4. When Lifeboat asks for Accessibility access, turn it on. That's how it moves other apps' windows.

The lifebuoy in your menu bar means it's running. On first launch it adds itself to your login items so it's there the next time you unplug. You can turn that off in its menu.

## Try it

Drag a window partway off the screen and press ⌃⌥⌘R.

You can test the display handling without unplugging anything. Pick a lower resolution in System Settings > Displays, and Lifeboat shrinks the windows that no longer fit. Switch back, and they return to their old size and spot.

## Menu

| Item | What it does |
| --- | --- |
| Rescue Windows ⌃⌥⌘R | Moves every window that's off the screen back on. |
| Remember Layout per Display Setup | Puts windows back where they were when a display setup returns. On by default. |
| Launch at Login | Starts Lifeboat when you log in. |

## Limits

- macOS only lets apps move windows on the desktop you're looking at. Windows on your other Spaces get fixed the first time you switch to them after a display change.
- Lifeboat moves windows around within a desktop. It can't move them between Spaces.
- Full screen windows are left alone. macOS handles those.
- Saved layouts live in memory, so they reset when Lifeboat quits.
- If you run a tiling window manager like AeroSpace or yabai, you likely don't need Lifeboat, and the two will fight over windows.

## Privacy

Lifeboat reads where windows are and how big they are. It doesn't read what's in them or what they're called, doesn't ask for Screen Recording, and never connects to the internet.

## Build from source

You need macOS 13 or later and the Xcode command line tools. Run `xcode-select --install` if you don't have them.

```sh
git clone https://github.com/iprincemax72-maker/lifeboat.git
cd lifeboat
swift test
./scripts/build.sh
open build/Lifeboat.app
```

Local builds are ad-hoc signed, so macOS sees every rebuild as a new app. If windows stop moving after a rebuild, remove Lifeboat from Privacy & Security > Accessibility and add it again.

`./scripts/release.sh` builds the DMG into `dist/`. Set `SIGN_ID` to a Developer ID identity and `NOTARY_PROFILE` to a `notarytool` keychain profile to sign and notarize it.

## How it works

Lifeboat registers for display changes with CoreGraphics. After a change it waits 1.5 seconds for macOS and apps to finish moving things, then checks every window through the Accessibility API. A window counts as lost when part of it sits outside every screen or under a menu bar. Lost windows get shrunk to the visible area of the screen they overlap most and slid fully onto it.

Every 2 seconds Lifeboat records where each window is, keyed by which displays are connected and how they're arranged. When that same setup comes back, it moves the windows back.

## License

MIT. Made by Ansh Dhakad, who also makes [Drop Notch](https://dropnotch.space).
