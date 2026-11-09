import argparse
import hashlib
import json
import re
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
TOUR_LEVELS = (("explorer", "text"), ("scientist", "text_scientist"))
SPEECH_REPLACEMENTS = (
    (re.compile(r"(\d+)\.0+\b"), r"\1"),
    (re.compile(r"(?<![\d.,])1\s*AU\b"), "1 astronomical unit"),
    (re.compile(r"(\d)\s*AU\b"), r"\1 astronomical units"),
    (re.compile(r"(\d)\s*km/h\b"), r"\1 kilometers per hour"),
    (re.compile(r"(\d)\s*km\b"), r"\1 kilometers"),
    (re.compile(r"(\d)\s*g/cm3\b"), r"\1 grams per cubic centimeter"),
    (re.compile(r"(\d)\s+s\b"), r"\1 seconds"),
    (re.compile(r"\b(\d+):(\d+)\b"), r"\1 to \2"),
    (re.compile(r"\bbarycenter\b"), "bary center"),
)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate narration audio files from the narration and tour scripts.")
    parser.add_argument("--script", type=Path, default=REPOSITORY_ROOT / "godot/data/narration.json")
    parser.add_argument("--tours", type=Path, default=REPOSITORY_ROOT / "godot/data/tours.json")
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


def tour_narration_id(tour_id: str, step_index: int, level: str) -> str:
    return f"{tour_id}_{step_index + 1:02d}_{level}"


def collect_entries(script_path: Path, tours_path: Path) -> dict[str, str]:
    entries: dict[str, str] = {}

    def add(entry_id: str, text: str) -> None:
        if entry_id in entries:
            raise SystemExit(f"Duplicate narration id: {entry_id}")
        entries[entry_id] = text

    for entry in json.loads(script_path.read_text(encoding="utf-8")):
        add(entry["id"], entry["text"])
    for tour in json.loads(tours_path.read_text(encoding="utf-8")):
        for index, step in enumerate(tour["steps"]):
            for level, key in TOUR_LEVELS:
                if key in step:
                    add(tour_narration_id(tour["id"], index, level), step[key])
    return entries


def speech_text(text: str) -> str:
    for pattern, replacement in SPEECH_REPLACEMENTS:
        text = pattern.sub(replacement, text)
    return text


def fingerprint(text: str, voice: str, speed: float) -> str:
    return hashlib.sha256(f"{voice}|{speed}|{text}".encode("utf-8")).hexdigest()


def load_manifest(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def prune(output: Path, manifest: dict[str, str], entries: dict[str, str]) -> bool:
    changed = False
    for entry_id in [entry_id for entry_id in manifest if entry_id not in entries]:
        del manifest[entry_id]
        changed = True
    for audio in output.glob("*.ogg"):
        if audio.stem not in entries:
            audio.unlink()
            audio.with_name(audio.name + ".import").unlink(missing_ok=True)
            print(f"Removed {audio.name}")
            changed = True
    return changed


def main() -> int:
    arguments = parse_arguments()
    entries = collect_entries(arguments.script, arguments.tours)
    arguments.output.mkdir(parents=True, exist_ok=True)
    manifest_path = arguments.output / MANIFEST_NAME
    manifest = load_manifest(manifest_path)
    changed = prune(arguments.output, manifest, entries)
    pending = []
    for entry_id, text in entries.items():
        spoken = speech_text(text)
        digest = fingerprint(spoken, arguments.voice, arguments.speed)
        target = arguments.output / f"{entry_id}.ogg"
        if arguments.force or manifest.get(entry_id) != digest or not target.exists():
            pending.append((entry_id, spoken, digest, target))
    if pending:
        model_path, voices_path = ensure_models(arguments.models)
        engine = Kokoro(str(model_path), str(voices_path))
        for entry_id, spoken, digest, target in pending:
            samples, sample_rate = engine.create(spoken, voice=arguments.voice, speed=arguments.speed, lang=LANGUAGE)
            soundfile.write(target, samples, sample_rate, format="OGG", subtype="VORBIS")
            manifest[entry_id] = digest
            print(f"Generated {target.name} ({len(samples) / sample_rate:.1f}s)")
    if not pending and not changed:
        print("Narration is up to date")
        return 0
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
