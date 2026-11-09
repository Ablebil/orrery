# Music and Effects Generation

Generates the background music and sound effects offline by procedural synthesis. No samples, models, or third-party recordings are used, so every generated file is team-owned. Generated files are bundled with the game.

## Requirements

- [uv](https://docs.astral.sh/uv/)
- Internet access on first run only, to install `numpy` and `soundfile` into the virtual environment

## Usage

From this directory:

```
uv run generate_audio.py
```

On Windows without a local Python, run it inside WSL or Linux with `UV_LINK_MODE=copy` when the repository is on a Windows drive.

| Option | Default | Purpose |
|---|---|---|
| `--output` | `godot/assets/audio` | Destination root; files are written to `music/` and `effects/` below it |

## Output

| File | Content |
|---|---|
| `music/space_ambient.ogg` | 96 s stereo ambient loop: detuned pad chords, sub drone, high shimmer, sparse FM bells, synthetic reverb. Normalized to -16 LUFS with peaks at or below -1 dBFS |
| `effects/click.ogg` | Soft UI tick |
| `effects/place.ogg` | Rising blip when a body is placed |
| `effects/launch.ogg` | Rising whoosh when a body is launched |
| `effects/merge.ogg` | Low thump and noise burst when bodies collide |
| `effects/remove.ogg` | Descending blip when a body is removed |

Effects are mono with peaks at -3 dBFS. All files are 44.1 kHz OGG Vorbis.

Every random choice uses a fixed seed, so each run produces the same audio. The music is rendered on a circular timeline: notes and reverb tails that run past the end are folded back into the start, which makes the loop seamless. The game enables looping at runtime, so the import settings do not need to be changed.
