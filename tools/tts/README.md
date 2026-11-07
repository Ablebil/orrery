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
| `--script` | `godot/data/narration.json` | Narration entries, each with an `id` and `text` |
| `--output` | `godot/assets/audio/narration` | Destination for `<id>.ogg` files |
| `--voice` | `af_bella` | Kokoro voice name |
| `--speed` | `1.0` | Speaking speed |
| `--force` | off | Regenerate every entry |

Only entries whose text, voice, or speed changed are regenerated. Keep each entry to roughly 100 to 200 tokens for the best prosody.
