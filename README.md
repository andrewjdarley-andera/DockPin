# DockPin

macOS moves the Dock to your external monitor whenever the cursor touches the bottom of that screen, and has no setting to stop it; DockPin keeps the Dock on your MacBook's built-in display by blocking your cursor from reaching the very bottom of your extra displays

## Setup

**1. Open Terminal.** Press `Command` + `Space`, type `Terminal`, and press `Return`.

**2. Install Apple's developer tools** (this includes git). Paste this line into Terminal and press `Return`:

```bash
xcode-select --install
```

Click **Install** in the window that pops up and wait for it to finish, which takes a few minutes. If Terminal says the tools are already installed, skip to the next step.

**3. Download and install DockPin.** Paste this line into Terminal and press `Return`:

```bash
git clone https://github.com/andrewjdarley-andera/DockPin.git ~/DockPin && ~/DockPin/install.sh
```

**4. Allow DockPin to work.** System Settings opens by itself. Turn on the switch next to **DockPin** under Privacy & Security > Accessibility. Terminal will say "DockPin is running" when it's done. If the switch is already on but Terminal is still waiting, turn it off and then on again.

That's it. DockPin starts by itself every time you turn on your Mac.

## Removing it

Paste this line into Terminal and press `Return`:

```bash
~/DockPin/uninstall.sh
```
