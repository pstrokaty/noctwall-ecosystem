#!/usr/bin/env bash
set -euo pipefail

WITH_AI=0
for arg in "$@"; do
    case "$arg" in
        --with-ai) WITH_AI=1 ;;
        -h|--help)
            echo "Usage: ./install.sh [--with-ai]"
            echo "  --with-ai   Also install local BiRefNet dependencies (rembg, onnxruntime, opencv) for perfil outline transitions"
            exit 0
            ;;
    esac
done

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_BIN="$HOME/.local/bin"
VENV_DIR="$HOME/.local/share/noctwall/venv"
SYSTEMD_USER_DIR="$CONFIG_DIR/systemd/user"

echo "[1/5] Linking NoctWall core and plugins..."
mkdir -p "$CONFIG_DIR" "$LOCAL_BIN" "$SYSTEMD_USER_DIR" "$HOME/Pictures/Wallpapers"

ln -sfn "$REPO_DIR/noctwall" "$CONFIG_DIR/noctwall"
ln -sfn "../../noctwall-openrgb" "$REPO_DIR/noctwall/plugins/noctwall-openrgb"
ln -sfn "../../noctwall-studio" "$REPO_DIR/noctwall/plugins/noctwall-studio"

chmod +x "$REPO_DIR/noctwall/bin/noctwall-fx"
chmod +x "$REPO_DIR/noctwall/scripts/"*.sh
chmod +x "$REPO_DIR/noctwall-openrgb/bin/noctwall-openrgb-sync"

ln -sfn "$REPO_DIR/noctwall/bin/noctwall-fx" "$LOCAL_BIN/noctwall-fx"
ln -sfn "$REPO_DIR/noctwall/scripts/backend-get.sh" "$LOCAL_BIN/noctwall-backend-get"
ln -sfn "$REPO_DIR/noctwall/scripts/backend-set.sh" "$LOCAL_BIN/noctwall-backend-set"
ln -sfn "$REPO_DIR/noctwall-openrgb/bin/noctwall-openrgb-sync" "$LOCAL_BIN/noctwall-openrgb-sync"

echo "[2/5] Initializing default configuration..."
if [ ! -f "$REPO_DIR/noctwall/config.json" ]; then
    cp "$REPO_DIR/noctwall/config.default.json" "$REPO_DIR/noctwall/config.json"
fi

echo "[3/5] Setting up Python virtual environment..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi
"$VENV_DIR/bin/pip" install --quiet --upgrade pip pillow numpy scipy

if [ "$WITH_AI" -eq 1 ]; then
    echo "      Installing local AI segmentation runtime (rembg + onnxruntime + opencv)..."
    "$VENV_DIR/bin/pip" install --quiet rembg onnxruntime opencv-python-headless
fi

echo "[4/5] Installing systemd user unit..."
cat > "$SYSTEMD_USER_DIR/noctwall.service" <<EOF
[Unit]
Description=NoctWall Shader Transitions, Wallpaper Picker & Plugins
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
Environment="PATH=%h/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/bin"
ExecStart=/usr/bin/qs -p %h/.config/noctwall
Restart=on-failure
RestartSec=1

[Install]
WantedBy=graphical-session.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now noctwall.service

echo "[5/5] Done! Bind IPC commands in your compositor:"
echo "  Toggle picker:   qs -p ~/.config/noctwall ipc call picker toggle"
echo "  Next wallpaper:  qs -p ~/.config/noctwall ipc call picker next"
echo "  Prev wallpaper:  qs -p ~/.config/noctwall ipc call picker prev"
echo "  Random wall:     ~/.config/noctwall/scripts/random-wallpaper.sh"
if [ "$WITH_AI" -eq 0 ]; then
    echo ""
    echo "Tip: Run ./install.sh --with-ai to enable offline BiRefNet silhouette outline transitions (perfil)."
fi
