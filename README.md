# omarchy-wallpaper-engine

> Simple integration of Omarchy with the official Wallpaper Engine.

Use your **[Wallpaper Engine](https://store.steampowered.com/app/431960/Wallpaper_Engine/)** wallpapers (the animated *scene* and *video* ones from the Steam Workshop) as **live wallpapers on [Omarchy](https://omarchy.org/)**.

Omarchy 4 draws its wallpaper through its Quickshell shell, which only understands static images. This project renders your Wallpaper Engine content on the Hyprland background layer with [`linux-wallpaperengine`](https://github.com/Almamu/linux-wallpaperengine) and gets Omarchy's own background out of the way, so the animation shows through — and survives theme switches and reboots.

https://github.com/Almamu/linux-wallpaperengine does the actual rendering; this repo is the Omarchy glue around it.

---

## Requirements

- An **Omarchy** system (Hyprland + Quickshell shell).
- **Wallpaper Engine** installed via Steam, with some wallpapers subscribed (they live in `~/.local/share/Steam/steamapps/workshop/content/431960/`).
- An AUR helper (`yay` or `paru`) to install `linux-wallpaperengine-git`.

## Install

```bash
git clone https://github.com/<you>/omarchy-wallpaper-engine.git
cd omarchy-wallpaper-engine
./install.sh
```

The installer:
1. installs `linux-wallpaperengine-git` from the AUR (skip with `--no-deps`),
2. links the `omarchy-we` CLI into `~/.local/bin`,
3. creates a transparent placeholder so Omarchy's background stops covering the live one,
4. adds an autostart entry to `~/.config/hypr/autostart.lua`,
5. installs an Omarchy `theme-set` hook so the live wallpaper is restored after theme switches.

## Usage

```bash
omarchy-we list          # list your wallpapers: #  type  title  id
omarchy-we set 3         # set by list number
omarchy-we set 2555206224 # ...or by Steam Workshop id
omarchy-we set "goku"    # ...or by title substring
omarchy-we menu          # graphical picker (walker/fuzzel/wofi/rofi)
omarchy-we next          # cycle to the next wallpaper
omarchy-we random        # random wallpaper
omarchy-we current       # show what's set and whether it's running
omarchy-we stop          # stop the live wallpaper, restore a normal background
```

Your choice is saved to `~/.local/state/omarchy-we/current` and re-applied on every login.

### Optional: a keybinding

Add to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + W", "Wallpaper picker", "omarchy-we menu")
```

### Tuning

Environment variables (set them before `omarchy-we`, e.g. in the autostart line):

| Variable | Default | Meaning |
|----------|---------|---------|
| `OMARCHY_WE_SCALING` | `fill` | `stretch` \| `fit` \| `fill` \| `default` |
| `OMARCHY_WE_FPS` | *(unset)* | cap the frame rate (e.g. `30`) to save battery |

## How it works

- `linux-wallpaperengine --screen-root <output> --scaling fill --silent <workshop-folder>` renders the wallpaper on the Hyprland **background** layer.
- Omarchy's Quickshell background is a fullscreen **opaque** surface on the same layer, so it would hide the live one. We point Omarchy's current background at a **transparent** PNG (`~/.config/omarchy/backgrounds/transparent.png`) — nothing in `/usr/share/omarchy` is ever modified — and relaunch the live wallpaper on top.
- The `theme-set` hook reapplies this after a theme change (which otherwise resets the background and restarts the shell).

## Notes & limits

- **Scene** and **video** wallpapers work. **Web** (HTML/JS) wallpapers may not render — `linux-wallpaperengine`'s web support is limited.
- Live wallpapers use the GPU continuously. On a laptop/iGPU, cap the frame rate (`OMARCHY_WE_FPS=30`) or use `omarchy-we stop` on battery.
- Audio is muted by default (`--silent`).
- Multi-monitor: the wallpaper is applied to the focused/first monitor. Run one `linux-wallpaperengine` per output for per-screen wallpapers.

## Uninstall

```bash
./uninstall.sh          # removes CLI, hook, autostart, state; restores a normal background
yay -R linux-wallpaperengine-git   # optional: remove the renderer too
```

## Credits

- [Almamu/linux-wallpaperengine](https://github.com/Almamu/linux-wallpaperengine) — the renderer doing all the heavy lifting.
- [Omarchy](https://omarchy.org/) by DHH.
