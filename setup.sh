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

VENV="$HOME/.openclaw/parakeet-env"

if [[ -f "$VENV/bin/python3" ]]; then
    ok "Already exists at $VENV"
else
    info "Creating at $VENV..."
    mkdir -p "$HOME/.openclaw"
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

mkdir -p "$HOME/.openclaw/scripts"

if [[ -f "$SCRIPT_DIR/scripts/transcribe.py" ]]; then
    cp "$SCRIPT_DIR/scripts/transcribe.py" "$HOME/.openclaw/scripts/transcribe.py"
    chmod +x "$HOME/.openclaw/scripts/transcribe.py"
    ok "Installed to ~/.openclaw/scripts/"
elif [[ -f "$HOME/.openclaw/scripts/transcribe.py" ]]; then
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
xattr -cr "$HOME/.openclaw/scripts/transcribe.py" 2>/dev/null || true
ok "Cleared"

# ─── Model download ─────────────────────────────────────────────────────────

step "Parakeet model (~1.2 GB)"

MODEL_DIR="$HOME/.cache/huggingface/hub/models--mlx-community--parakeet-tdt-0.6b-v2"

if [[ -d "$MODEL_DIR" ]]; then
    ok "Already cached"
else
    info "Downloading — this is the longest step. Go grab a coffee."
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

cat <<EOF

${GREEN}${BOLD}VoiceInk is ready.${NC}

${BOLD}Next steps:${NC}

  1. Right-click ~/Applications/VoiceInk.app → Open
     (macOS will warn about an unidentified developer — click Open)

  2. Grant these permissions when prompted:
     • Accessibility    → System Settings > Privacy & Security > Accessibility
     • Input Monitoring → System Settings > Privacy & Security > Input Monitoring
     • Microphone       → System Settings > Privacy & Security > Microphone

  3. Press Option+A to record. Press Option+A again to stop.
     Text appears wherever your cursor is.

EOF
