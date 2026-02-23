#!/usr/bin/env python3
"""
Parakeet Transcriber — local speech-to-text using NVIDIA Parakeet on Apple Silicon.

Usage:
    transcribe.py <audio_file>
    transcribe.py <audio_file> --timestamps
    transcribe.py <audio_file> --json
"""

import sys
import os
import json
import time

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print("Usage: transcribe.py <audio_file> [--timestamps] [--json]")
        print()
        print("Options:")
        print("  --timestamps  Show word-level timestamps")
        print("  --json        Output as JSON")
        sys.exit(0 if sys.argv[1:] == ["--help"] else 1)

    audio_path = sys.argv[1]
    show_timestamps = "--timestamps" in sys.argv
    output_json = "--json" in sys.argv

    if not os.path.isfile(audio_path):
        print(f"Error: file not found: {audio_path}", file=sys.stderr)
        sys.exit(1)

    from parakeet_mlx import from_pretrained

    model_name = "mlx-community/parakeet-tdt-0.6b-v2"
    print(f"Loading model: {model_name}...", file=sys.stderr)
    model = from_pretrained(model_name)

    print(f"Transcribing: {audio_path}...", file=sys.stderr)
    start = time.time()
    result = model.transcribe(audio_path)
    elapsed = time.time() - start

    if output_json:
        output = {
            "file": audio_path,
            "text": result.text,
            "duration_seconds": round(elapsed, 2),
            "model": model_name,
        }
        if show_timestamps and hasattr(result, "segments"):
            output["segments"] = [
                {"text": s.text, "start": s.start, "end": s.end}
                for s in result.segments
            ]
        print(json.dumps(output, indent=2))
    else:
        print(result.text)
        if show_timestamps and hasattr(result, "segments"):
            print()
            for seg in result.segments:
                print(f"[{seg.start:.2f}s - {seg.end:.2f}s] {seg.text}")

    print(f"\nTranscribed in {elapsed:.1f}s", file=sys.stderr)


if __name__ == "__main__":
    main()
