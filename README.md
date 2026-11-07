# Orrery

An interactive 3D solar system for exploration and gravity experiments. Built with Godot 4.7.2 and the Compatibility renderer.

## Structure

| Path | Contents |
|---|---|
| `docs/` | Product requirements, technical docs, final report |
| `godot/` | Godot project |
| `assets/` | Asset license register |

## Requirements

- Godot 4.7.2 (standard build)
- Windows 10/11 or Linux, 64-bit

## Run

1. Open `godot/project.godot` in Godot 4.7.2, or run `godot --path godot` from the repository root.
2. Press F5 to start.

## Export

Export templates for 4.7.2 must be installed. Then, from the repository root:

```
godot --headless --path godot --export-release "Windows" ../builds/windows/Orrery.exe
godot --headless --path godot --export-release "Linux" ../builds/linux/Orrery.x86_64
```

On Linux, mark the exported file as executable with `chmod +x`.

## Controls

| Input | Action |
|---|---|
| W A S D, Q / E | Move, down / up |
| Right mouse + move | Look |
| Mouse wheel | Adjust flight speed |
| Shift | Boost |
| Space or P | Pause |
| R | Reverse time |
| `[` and `]` | Slower and faster time |
| N | Jump to the current date |
| T | Toggle compressed and true scale |
| 1 – 0, Tab | Focus a body, focus the next body |
| F | Release focus into free flight |
| H | Hide the HUD |

## Team

Sepak Takraw — see `docs/PRD.md`, Appendix A.

## Status

Week 1 of 4: core simulation, rendering, and Explore mode foundation. See `docs/PRD.md` for the full plan.
