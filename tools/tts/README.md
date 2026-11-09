# Narration Generation

Generates narration audio offline with Kokoro-82M. Generated files are bundled with the game, so the game itself never needs a network connection.

## Requirements

- [uv](https://docs.astral.sh/uv/)
- Internet access on first run only, to download the model files into `models/`

## Usage

From this directory:

```
uv run generate_narration.py
```

On Windows without a local Python, run it inside WSL or Linux with `UV_LINK_MODE=copy` when the repository is on a Windows drive.

| Option | Default | Purpose |
|---|---|---|
| `--script` | `godot/data/narration.json` | Standalone narration entries, each with an `id` and `text` |
| `--tours` | `godot/data/tours.json` | Guided tours. Every step is voiced from `text` and `text_scientist` |
| `--output` | `godot/assets/audio/narration` | Destination for `<id>.ogg` files |
| `--voice` | `af_bella` | Kokoro voice name |
| `--speed` | `1.0` | Speaking speed |
| `--force` | off | Regenerate every entry |

Tour step audio is named `<tour id>_<step number>_<level>.ogg`, where the step number starts at 01 and the level is `explorer` or `scientist`, for example `grand_tour_03_scientist.ogg`. The game derives the same name from the active tour step and depth level.

Only entries whose spoken text, voice, or speed changed are regenerated. Audio files and manifest entries whose id no longer exists are removed. Keep each entry to roughly 100 to 200 tokens for the best prosody.

Before synthesis, units and symbols that Kokoro reads poorly, such as `AU`, `km`, `km/h`, `g/cm3`, `s`, and ratios like `3:2`, are expanded into words. The on-screen captions keep the original text.
