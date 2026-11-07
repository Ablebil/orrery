import argparse
import hashlib
import json
import sys
import urllib.request
from pathlib import Path

import soundfile
from kokoro_onnx import Kokoro

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
MODEL_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx"
VOICES_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"
DEFAULT_VOICE = "af_bella"
DEFAULT_SPEED = 1.0
LANGUAGE = "en-us"
MANIFEST_NAME = "manifest.json"


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate narration audio files from a script file.")
    parser.add_argument("--script", type=Path, default=REPOSITORY_ROOT / "godot/data/narration.json")
    parser.add_argument("--output", type=Path, default=REPOSITORY_ROOT / "godot/assets/audio/narration")
    parser.add_argument("--models", type=Path, default=Path(__file__).resolve().parent / "models")
    parser.add_argument("--voice", default=DEFAULT_VOICE)
    parser.add_argument("--speed", type=float, default=DEFAULT_SPEED)
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def ensure_models(directory: Path) -> tuple[Path, Path]:
    directory.mkdir(parents=True, exist_ok=True)
    model_path = directory / "kokoro-v1.0.onnx"
    voices_path = directory / "voices-v1.0.bin"
    for url, target in ((MODEL_URL, model_path), (VOICES_URL, voices_path)):
        if not target.exists():
            print(f"Downloading {target.name}")
            urllib.request.urlretrieve(url, target)
    return model_path, voices_path


def fingerprint(text: str, voice: str, speed: float) -> str:
    return hashlib.sha256(f"{voice}|{speed}|{text}".encode("utf-8")).hexdigest()


def load_manifest(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    arguments = parse_arguments()
    entries = json.loads(arguments.script.read_text(encoding="utf-8"))
    arguments.output.mkdir(parents=True, exist_ok=True)
    manifest_path = arguments.output / MANIFEST_NAME
    manifest = load_manifest(manifest_path)
    pending = []
    for entry in entries:
        digest = fingerprint(entry["text"], arguments.voice, arguments.speed)
        target = arguments.output / f"{entry['id']}.ogg"
        if arguments.force or manifest.get(entry["id"]) != digest or not target.exists():
            pending.append((entry, digest, target))
    if not pending:
        print("Narration is up to date")
        return 0
    model_path, voices_path = ensure_models(arguments.models)
    engine = Kokoro(str(model_path), str(voices_path))
    for entry, digest, target in pending:
        samples, sample_rate = engine.create(entry["text"], voice=arguments.voice, speed=arguments.speed, lang=LANGUAGE)
        soundfile.write(target, samples, sample_rate, format="OGG", subtype="VORBIS")
        manifest[entry["id"]] = digest
        print(f"Generated {target.name} ({len(samples) / sample_rate:.1f}s)")
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
