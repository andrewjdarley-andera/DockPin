# DockPin

Keep the macOS Dock on your built-in display. Always.

With an external monitor connected, macOS moves the Dock to whichever display
you push the cursor against the bottom of. There is no setting to turn that
off. DockPin is a tiny background helper that makes it impossible to trigger:
the Dock stays on your MacBook's screen and never jumps to the monitor.

## Install

Tested on macOS 26. Requires the Xcode Command Line Tools
(`xcode-select --install`).

```bash
git clone https://github.com/andrewjdarley-andera/DockPin.git
cd DockPin
./install.sh
```

The script builds DockPin from source, installs it to `~/Applications`, sets
it to start at login, and opens the Accessibility settings pane. Turn on
**DockPin** there and you're done; the script confirms once it is working.

If the Dock is on your external display at that moment, push the cursor
against the bottom of the built-in display once to bring it back.

## Uninstall

```bash
./uninstall.sh
```

This stops DockPin and removes the app, its login item, its log, and its
Accessibility entry.

## How it works

macOS moves the Dock when the cursor presses against the bottom edge of a
display. DockPin listens to mouse movement and holds the cursor two pixels
above the bottom edge of every external display, so that edge is never
reached. Sideways movement is untouched, so you can still slide along the
bottom of the screen.

- If another display is arranged directly below the external one, the cursor
  can still cross into it.
- With the lid closed (no built-in display active) DockPin does nothing, so
  the Dock works normally on the external display.
- Display changes (plugging in, unplugging, rearranging) are picked up
  automatically.

It has no Dock icon, no menu bar item, and no network access. The whole thing
is one file: [Sources/main.swift](Sources/main.swift).

## Good to know

- **Accessibility access** is required because DockPin has to see and adjust
  mouse movement. It reads nothing else.
- **The bottom two pixel rows** of external displays can't be reached by the
  cursor. Change `margin` in `Sources/main.swift` to adjust.
- **Re-running `install.sh`** (for example after pulling an update) rebuilds
  the app, and macOS will ask you to grant Accessibility access again. This
  is because the app is signed locally rather than with a developer
  certificate.
- **Logs** are written to `~/Library/Logs/DockPin.log`.
- If the Dock is positioned on the left or right of the screen, macOS doesn't
  move it this way and you don't need DockPin.

## License

[MIT](LICENSE)
