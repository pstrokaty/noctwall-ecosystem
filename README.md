# NoctWall Ecosystem

A modular Wayland wallpaper transition engine, 3D skewed carousel picker, and plugin ecosystem built with **Quickshell**, **GLSL shaders**, and **OpenRGB**.

## Architecture

```text
noctwall-ecosystem/
├── noctwall/               # Core Quickshell daemon (WallpaperFx + WallpaperPicker + Plugin API)
│   ├── shaders/            # GLSL fragment shaders & compiled .qsb binaries
│   ├── scripts/            # Thumbnail generator & wallpaper switching helpers
│   ├── bin/noctwall-fx     # Dijkstra/outline transition mask generator & cache warmer
│   └── plugins/            # Symlinked plugin slots (PluginWorker, BottomSlot, StageOverlay)
├── noctwall-openrgb/       # 5-zone keyboard RGB sync plugin (Logitech G213 / OpenRGB)
└── noctwall-studio/        # Live in-UI geometry, shader & plugin configurator drawer
```

## Features

- **GLSL Shader Transitions (`WallpaperFx`):** Smooth GPU-accelerated `contagio` and `perfil` transitions driven by precomputed outline/distance maps.
- **3D Perspective Carousel (`WallpaperPicker`):** Skewed parallelogram cards with dynamic accent extraction, ambient glow, mouse wheel / keyboard navigation, and instant IPC control.
- **NoctWall Studio (`noctwall-studio`):** Built-in live tuner accessible from the bottom-right corner of the picker (`studio`) to adjust card geometry, 3D perspective, transition timings, glow intensity, active plugins, and wallpaper directories with instant persistence to `config.json`.
- **NoctWall OpenRGB (`noctwall-openrgb`):** Extracts 5-zone palettes from the active wallpaper (Accent & Glow, Dominant Spread, Complementary, Analogous, Full Material, or Custom user profiles) with live Saturation and Brightness sliders and asynchronous `openrgb` synchronization.

## Requirements

- **Wayland compositor** with `wlr-layer-shell` support (tested on **Hyprland**)
- **Quickshell** (`qs`)
- **Python 3** (`pillow`, `numpy`, `scipy` — installed automatically into an isolated venv by `install.sh`)
- **ImageMagick** (`magick`) or `ffmpeg` for fast thumbnail generation
- **OpenRGB** (`openrgb` CLI, optional — required only for `noctwall-openrgb`)

## Installation

```bash
git clone https://github.com/pstrokaty/noctwall-ecosystem.git
cd noctwall-ecosystem
./install.sh
```

## Hyprland Keybind Examples

```lua
-- Toggle interactive wallpaper carousel
qs -p ~/.config/noctwall ipc call picker toggle

-- Cycle previous / next wallpaper immediately
qs -p ~/.config/noctwall ipc call picker prev
qs -p ~/.config/noctwall ipc call picker next

-- Pick a random wallpaper from configured randomSubdir
~/.config/noctwall/scripts/random-wallpaper.sh
```

## Plugin API

Plugins live in their own directories and are enabled via `plugins.enabled` in `noctwall/config.json`. Each plugin declares supported UI/background slots in `plugin.json`:

- `PluginWorker.qml` — headless background worker reacting to `wallpaperPreviewed`, `wallpaperApplied`, and `keyAction` signals.
- `BottomSlot.qml` — per-card interactive dock mounted directly beneath each carousel card.
- `StageOverlay.qml` — full-stage overlay layer for drawers, modals, and floating controls.

## License

**GPL-3.0** — see [LICENSE](LICENSE) for the full license text.

## Credits

- Core shader transition concepts and initial wallpaper picker foundation derived from **pocket-dots** (GPL-3.0).
