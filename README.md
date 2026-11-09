# Orrery

An interactive 3D solar system for exploration and gravity experiments. Built with Godot 4.7.2 and the Compatibility renderer.

## Modes

- **Explore**: fly through the solar system, select any body to read about it, and follow guided tours. Information is shown at two depth levels: Explorer for plain language and Scientist for full numeric data. Planets have atmosphere glow, Earth has a cloud layer, and an instanced asteroid belt orbits between Mars and Jupiter.
- **Sandbox**: an N-body gravity simulator. Place bodies, launch them with a drag, then edit, freeze, or remove them and watch the orbits respond. Bodies that collide merge, and the merge conserves momentum. Load a preset (solar system, binary star, extra planet, rogue star flyby), or save a snapshot and restore it later. At Scientist level you can choose the integrator (Velocity Verlet or RK4) and the time step.

The application opens on a main menu with Explore, Sandbox, Settings, Credits, and Quit. Settings covers window mode and resolution, graphics preset, render scale, orbit trail length, audio volumes, music mute, voice-over, and key bindings, and it is saved between sessions. Guided tours have synthesized voice-over at both depth levels. Captions are always shown, and the voice can be turned off separately. Esc opens a pause menu in both modes.

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

1. Open `godot/project.godot` in Godot 4.7.2 and press F5, or run `godot --path godot` from the repository root.
2. The main menu opens first.

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
| Space or P | Pause or resume time |
| R | Reverse time |
| `[` and `]` | Slower and faster time |
| L, O, G | Toggle labels, orbit lines, and distance rings |
| M | Switch between Explorer and Scientist levels |
| 1 – 0 | Focus a body |
| F | Release focus into free flight |
| F1 / F2 | Open Explore / open Sandbox |
| F3 | Show or hide the controls help |
| H | Hide the HUD |
| Esc | Open the pause menu when nothing else is open or selected |

Every key can be rebound in Settings → Controls.

### Explore

| Input | Action |
|---|---|
| Left click | Select a body and show its information |
| Double click | Fly to a body |
| Tab | Focus the next body |
| T | Toggle compressed and true scale |
| N | Jump to the current date |
| Left / Right, Enter | Previous / next tour step |
| Esc | Exit a tour, close the tour menu, clear the selection, then open the pause menu |

### Sandbox

| Input | Action |
|---|---|
| Place body, then click and drag on the orbital plane | Place a body and set its launch velocity |
| Left click | Select a body |
| Delete or Backspace | Remove the selected body |
| Esc | Cancel placement, clear the selection, then open the pause menu |

## Team

Sepak Takraw — see `docs/PRD.md`, Appendix A.

## Status

All four weeks are complete. Every P0 item is done, as are the P1 items except F-06 (additional moons and dwarf planets); the P2 items F-15 (quiz) and F-27 (energy readouts) are not done. Linux and Windows release builds export as single files. The Windows build has been checked under Wine but not yet on native Windows.

`docs/report.md` is the draft final report: architecture, graphics techniques, verification results, and screenshots. See `docs/PRD.md` for the full plan.
