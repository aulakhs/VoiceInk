#!/usr/bin/env bash
#
# VoiceInk installer
#
# Installs everything needed to run VoiceInk on a fresh Mac.
# Idempotent — safe to re-run if something fails halfway through.
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()  { printf "${BLUE}[info]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[ ok ]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[warn]${NC}  %s\n" "$*"; }
fail()  { printf "${RED}[fail]${NC}  %s\n" "$*"; exit 1; }
step()  { printf "\n${BOLD}── %s ──${NC}\n" "$*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$INSTALL_DIR"

# ─── Uninstall ───────────────────────────────────────────────────────────────

if [[ "${1:-}" == "--uninstall" ]]; then
    step "Uninstalling VoiceInk"
    rm -rf "$HOME/Applications/VoiceInk.app" && ok "Removed VoiceInk.app"
    rm -rf "$INSTALL_DIR" && ok "Removed Python environment"
    rm -rf "$HOME/.cache/huggingface/hub/models--mlx-community--parakeet-tdt-0.6b-v2" && ok "Removed cached model"
    info "If you added VoiceInk to Login Items, remove it in System Settings > General > Login Items."
    printf "\n${GREEN}${BOLD}VoiceInk has been removed.${NC}\n\n"
    exit 0
fi

# ─── Pre-flight ──────────────────────────────────────────────────────────────

step "Pre-flight checks"

[[ "$(uname)" == "Darwin" ]] || fail "macOS only. Sorry."

macos_major="$(sw_vers -productVersion | cut -d. -f1)"
(( macos_major >= 14 )) || fail "Requires macOS 14+. You're on $(sw_vers -productVersion)."
ok "macOS $(sw_vers -productVersion)"

[[ "$(uname -m)" == "arm64" ]] || fail "Apple Silicon required. This Mac has $(uname -m)."
ok "Apple Silicon"

# ─── Homebrew ────────────────────────────────────────────────────────────────

step "Homebrew"

if command -v brew &>/dev/null; then
    ok "Already installed"
else
    info "Installing Homebrew (may ask for your password)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
    ok "Installed"
fi

# ─── Python ──────────────────────────────────────────────────────────────────

step "Python 3.13"

if brew list python@3.13 &>/dev/null; then
    ok "Already installed"
else
    info "Installing via Homebrew..."
    brew install python@3.13
    ok "Installed"
fi

PYTHON="$(brew --prefix python@3.13)/bin/python3.13"
[[ -x "$PYTHON" ]] || PYTHON="$(brew --prefix python@3.13)/libexec/bin/python3"
[[ -x "$PYTHON" ]] || fail "Can't find python3.13 after install."
ok "$($PYTHON --version)"

# ─── Virtual environment ────────────────────────────────────────────────────

step "Python virtual environment"

VENV="$INSTALL_DIR/parakeet-env"

if [[ -f "$VENV/bin/python3" ]]; then
    ok "Already exists at $VENV"
else
    info "Creating at $VENV..."
    mkdir -p "$INSTALL_DIR"
    "$PYTHON" -m venv "$VENV"
    ok "Created"
fi

# ─── Parakeet ────────────────────────────────────────────────────────────────

step "parakeet-mlx"

if "$VENV/bin/python3" -c "import parakeet_mlx" &>/dev/null; then
    ok "Already installed"
else
    info "Installing (this takes a few minutes)..."
    "$VENV/bin/pip" install --upgrade pip --quiet
    "$VENV/bin/pip" install parakeet-mlx --quiet
    ok "Installed"
fi

# ─── Transcription script ───────────────────────────────────────────────────

step "transcribe.py"

mkdir -p "$INSTALL_DIR/scripts"

if [[ -f "$SCRIPT_DIR/scripts/transcribe.py" ]]; then
    cp "$SCRIPT_DIR/scripts/transcribe.py" "$INSTALL_DIR/scripts/transcribe.py"
    chmod +x "$INSTALL_DIR/scripts/transcribe.py"
    ok "Installed to ~/.openclaw/scripts/"
elif [[ -f "$INSTALL_DIR/scripts/transcribe.py" ]]; then
    ok "Already in place"
else
    fail "transcribe.py not found in repo or on disk."
fi

# ─── VoiceInk.app ───────────────────────────────────────────────────────────

step "VoiceInk.app"

APP_DEST="$HOME/Applications/VoiceInk.app"
mkdir -p "$HOME/Applications"

install_app() {
    local src="$1"
    [[ -d "$APP_DEST" ]] && rm -rf "$APP_DEST"
    cp -R "$src" "$APP_DEST"
    ok "Installed to ~/Applications/"
}

if [[ -d "$APP_DEST" ]]; then
    ok "Already installed at ~/Applications/"
elif [[ -d "$SCRIPT_DIR/VoiceInk.app" ]]; then
    # App bundle sitting in the repo folder (unzipped manually)
    install_app "$SCRIPT_DIR/VoiceInk.app"
elif [[ -f "$SCRIPT_DIR/VoiceInk.app.zip" ]]; then
    # Zipped app bundle in the repo folder
    info "Unzipping VoiceInk.app.zip..."
    ditto -xk "$SCRIPT_DIR/VoiceInk.app.zip" "$SCRIPT_DIR/_app_tmp"
    install_app "$SCRIPT_DIR/_app_tmp/VoiceInk.app"
    rm -rf "$SCRIPT_DIR/_app_tmp"
else
    printf "\n"
    fail "VoiceInk.app not found. Download VoiceInk.app.zip using the link you were given, place it in this folder, and run this script again."
fi

# ─── Quarantine ──────────────────────────────────────────────────────────────

step "Quarantine cleanup"

xattr -cr "$APP_DEST" 2>/dev/null || true
xattr -cr "$INSTALL_DIR/scripts/transcribe.py" 2>/dev/null || true
ok "Cleared"

# ─── Model download ─────────────────────────────────────────────────────────

step "Parakeet model (~1.2 GB)"

MODEL_DIR="$HOME/.cache/huggingface/hub/models--mlx-community--parakeet-tdt-0.6b-v2"

if [[ -d "$MODEL_DIR" ]]; then
    ok "Already cached"
else
    info "Downloading the model. This is the longest step."
    "$VENV/bin/python3" -c "
from parakeet_mlx import from_pretrained
model = from_pretrained('mlx-community/parakeet-tdt-0.6b-v2')
print('Done.')
"
    ok "Cached at ~/.cache/huggingface/hub/"
fi

# ─── Login Item ──────────────────────────────────────────────────────────────

step "Auto-start (optional)"

printf "\nStart VoiceInk automatically on login? [y/N] "
read -r answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    osascript -e "
        tell application \"System Events\"
            make login item at end with properties {path:\"$APP_DEST\", hidden:false}
        end tell
    " 2>/dev/null && ok "Added to Login Items" \
               || warn "Couldn't add automatically. Do it manually: System Settings > General > Login Items."
else
    info "Skipped"
fi

# ─── Done ────────────────────────────────────────────────────────────────────

step "Done"

printf "\n${GREEN}${BOLD}VoiceInk is ready.${NC}\n"
printf "\n${BOLD}Next steps:${NC}\n"
printf "\n  1. Right-click ~/Applications/VoiceInk.app → Open\n"
printf "     (macOS will warn about an unidentified developer — click Open)\n"
printf "\n  2. Grant these permissions when prompted:\n"
printf "     • Accessibility    → System Settings > Privacy & Security > Accessibility\n"
printf "     • Input Monitoring → System Settings > Privacy & Security > Input Monitoring\n"
printf "     • Microphone       → System Settings > Privacy & Security > Microphone\n"
printf "\n  3. Press Option+A to record. Press Option+A again to stop.\n"
printf "     Text appears wherever your cursor is.\n\n"
