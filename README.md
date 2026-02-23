# VoiceInk

Local speech-to-text for macOS, built on [NVIDIA Parakeet](https://huggingface.co/mlx-community/parakeet-tdt-0.6b-v2) and Apple's [MLX](https://github.com/ml-explore/mlx) framework. Runs entirely on-device — no API keys, no cloud, no subscriptions.

## Why

If you're paying for a speech-to-text service — OpenAI Whisper API, Google Cloud Speech, Deepgram, or anything else — you probably don't need to. Parakeet-TDT 0.6B runs locally on any Apple Silicon Mac, transcribes faster than real-time, and the quality is genuinely good for English.

VoiceInk wraps it into a menu bar app with a global hotkey. Press `Option+A`, talk, press `Option+A` again — transcribed text appears wherever your cursor is. That's the whole workflow.

## How it works

VoiceInk lives in your menu bar. When you trigger the hotkey, it records from your mic and hands the audio to a local Python script (`transcribe.py`) that runs Parakeet through MLX — Apple's ML framework built for M-series silicon. The result gets pasted at your cursor.

Everything stays on your machine. The model (~1.2 GB) downloads once during setup and gets cached locally. After that, the entire pipeline works offline.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (M1, M2, M3, M4 — any variant)
- A microphone (MacBooks have one built-in; Mac Mini / Studio / Pro need an external mic)
- ~2 GB of disk space
- Internet for initial setup only

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/aulakhs/VoiceInk.git
cd VoiceInk
```

### 2. Download VoiceInk.app

Download `VoiceInk.app.zip` from [Google Drive](https://drive.google.com/drive/folders/1LDkdDo17kormaopA4nwYk7_1yg2K7LDQ?usp=drive_link) and drop it into the `VoiceInk` folder you just cloned.

> The app binary isn't in this repo because it's a compiled macOS bundle — not the kind of thing that belongs in Git.

### 3. Run the setup script

```bash
bash setup.sh
```

This handles everything: Homebrew, Python 3.13, a virtual environment, the Parakeet speech engine, file placement, quarantine cleanup, and model download. Takes about 5–15 minutes depending on your connection.

The script is idempotent — run it again if something fails. It picks up where it left off.

### 4. First launch

The app isn't signed with an Apple Developer certificate ($99/year — not worth it for a personal tool), so macOS will block a normal double-click. To get around Gatekeeper:

1. Open Finder and go to `~/Applications`
2. **Right-click** VoiceInk.app and click **Open**
3. macOS will warn you about an unidentified developer — click **Open**

This is a one-time thing. After the first launch, it opens normally.

### 5. Grant permissions

VoiceInk needs three permissions to function. macOS prompts for each on first launch — grant them all.

| Permission | What it's for | Where to enable |
|---|---|---|
| Accessibility | Pasting transcribed text at your cursor | System Settings > Privacy & Security > Accessibility |
| Input Monitoring | Detecting the `Option+A` hotkey globally | System Settings > Privacy & Security > Input Monitoring |
| Microphone | Recording audio | System Settings > Privacy & Security > Microphone |

Toggle VoiceInk **on** for each one. If you don't get a prompt, add it manually from the locations above.

Restart VoiceInk after granting all three (quit from the menu bar, then reopen).

## Usage

1. Put your cursor wherever you want text to appear — a document, a text field, a chat window, anything
2. Press **`Option + A`** to start recording
3. Speak
4. Press **`Option + A`** again to stop
5. Wait a beat — transcribed text appears at your cursor

A small floating pill shows the current state:

| Pill state | Meaning |
|---|---|
| Red / pulsing | Recording — speak now |
| Processing | Transcribing your audio |
| Done | Text has been pasted |
| Error | Something went wrong — usually a permissions issue |

### Output modes

| Mode | What it does |
|---|---|
| Smart | Pastes with punctuation and formatting |
| Paste | Pastes the raw transcription |
| Paste + Enter | Pastes and presses Enter — useful in Spotlight, chat apps, terminal |

## Disk footprint

| Component | Size | Location |
|---|---|---|
| VoiceInk.app | ~5 MB | `~/Applications/` |
| Python environment | ~600 MB | `~/.openclaw/parakeet-env/` |
| Parakeet model | ~1.2 GB | `~/.cache/huggingface/hub/` |
| **Total** | **~1.8 GB** | |

## Limitations

- English only — Parakeet is an English-language model
- Apple Silicon only — MLX doesn't run on Intel Macs
- Not signed — requires the right-click bypass on first launch
- Longer recordings take proportionally longer to transcribe
- First transcription after a reboot is slower (~5s) while the model loads into memory; after that it's fast

## Troubleshooting

| Problem | Fix |
|---|---|
| macOS says the app "can't be opened" | Right-click > Open — see [First launch](#4-first-launch) |
| `Option+A` doesn't do anything | Grant Input Monitoring, restart VoiceInk |
| Records but text doesn't appear | Grant Accessibility, restart VoiceInk |
| No audio detected | Grant Microphone. If you're on a Mac Mini/Studio/Pro, connect an external mic |
| First transcription is slow | Normal after a reboot — the model needs to load into memory (~5s) |
| App quits immediately on launch | Run it from Terminal to see the error: `~/Applications/VoiceInk.app/Contents/MacOS/VoiceInk` |
| `setup.sh` fails partway through | Check your internet and run it again. It skips steps that already succeeded |

## Uninstall

```bash
# App
rm -rf ~/Applications/VoiceInk.app

# Python environment and scripts
rm -rf ~/.openclaw

# Cached ML model (~1.2 GB)
rm -rf ~/.cache/huggingface/hub/models--mlx-community--parakeet-tdt-0.6b-v2
```

If you added VoiceInk to Login Items: System Settings > General > Login Items > remove it.
