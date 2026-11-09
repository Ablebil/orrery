# Orrery

An interactive 3D solar system for exploration and gravity experiments. Built with Godot 4.7.2 and the Compatibility renderer.

## Modes

- **Explore**: fly through the solar system, select any body to read about it, and follow guided tours. Information is shown at two depth levels: Explorer for plain language and Scientist for full numeric data. Planets have atmosphere glow, Earth has a cloud layer, and an instanced asteroid belt orbits between Mars and Jupiter.
- **Sandbox**: an N-body gravity simulator. Place bodies, launch them with a drag, then edit, freeze, or remove them and watch the orbits respond. Bodies that collide merge, and the merge conserves momentum. Load a preset (solar system, binary star, extra planet, rogue star flyby), or save a snapshot and restore it later. At Scientist level you can choose the integrator (Velocity Verlet or RK4) and the time step.

Background music and sound effects play in both modes. Music, effects, and narration each have a volume slider in the settings panel, and music can be muted.

## Structure

| Path | Contents |
|---|---|
| `docs/` | Product requirements, technical docs, final report |
| `godot/` | Godot project |
| `tools/` | Offline tooling: narration (`tts/`), music and sound effects (`audio/`) |
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

### Both modes

| Input | Action |
|---|---|
| W A S D, Q / E | Move, down / up |
| Right mouse + move | Look |
| Mouse wheel | Adjust flight speed |
| Shift | Boost |
| Space or P | Pause |
| R | Reverse time |
| `[` and `]` | Slower and faster time |
| L, O, G | Toggle labels, orbit lines, and distance rings |
| M | Switch between Explorer and Scientist levels |
| 1 – 0 | Focus a body |
| F | Release focus into free flight |
| F1 / F2 | Open Explore / open Sandbox |
| F3 | Show or hide the controls help |
| H | Hide the HUD |

### Explore

| Input | Action |
|---|---|
| Left click | Select a body and show its information |
| Double click | Fly to a body |
| Tab | Focus the next body |
| T | Toggle compressed and true scale |
| N | Jump to the current date |
| Left / Right, Enter | Previous / next tour step |
| Esc | Exit a tour, close a menu, or clear the selection |

### Sandbox

| Input | Action |
|---|---|
| Place body, then click and drag on the orbital plane | Place a body and set its launch velocity |
| Left click | Select a body |
| Delete or Backspace | Remove the selected body |
| Esc | Cancel placement or clear the selection |

## Team

Sepak Takraw — see `docs/PRD.md`, Appendix A.

## Status

Weeks 1 to 3 of 4 are complete:

- Core simulation and rendering.
- Explore mode: information panels, depth levels, labels, distance rings, guided tours, atmosphere and cloud shaders, a quality-tiered ring shader, and the asteroid belt.
- Sandbox: N-body engine with placement, launch, edit, and remove; collision merging; presets and snapshots; selectable integrator and time step; body caps per quality preset.
- Audio: audio manager with music, sound effects, and separate volume controls.

See `docs/PRD.md` for the full plan.
