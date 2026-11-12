# Orrery — Product Requirements Document

| | |
|---|---|
| **Status** | Draft v0.3 |
| **Course** | Computer Graphics (Final Project) |
| **Team** | Sepak Takraw |
| **Engine** | Godot 4.7.2 (standard, GDScript), Compatibility renderer |
| **Platforms** | PC — Windows and Linux (64-bit) |
| **Presentation** | 3D |
| **Duration** | 4 weeks |

---

## 1. Overview

Orrery is an interactive, real-time 3D solar system application. It combines two experiences in one product:

- **Explore** — a guided, accurate tour of the Sun, planets, and major moons, with adjustable scale and time.
- **Sandbox** — a gravity simulator where users place, launch, and remove bodies and observe how orbits respond.

The name refers to the orrery, a mechanical model of the solar system. Orrery brings that idea into an interactive digital form.

## 2. Goals

1. Deliver an interactive computer graphics application that satisfies the course requirements (see §9).
2. Teach core concepts of orbital motion and gravity through direct manipulation rather than text alone.
3. Serve a wide audience, from elementary school students to university students in astronomy and physics, within a single application.
4. Run on modest hardware, since many students do not own high-end devices.
5. Demonstrate a broad set of computer graphics techniques (see §8).

### Non-goals

- Not a scientific-grade ephemeris or mission-planning tool.
- No multiplayer, accounts, or any network functionality.
- No VR support. The team has no VR hardware to develop or verify it.
- No macOS support.
- No procedural generation of exoplanetary systems in the initial release.

## 3. Target Users

| Persona | Needs | Implication |
|---|---|---|
| **Young learner** (elementary – middle school) | Visual, playful, low reading load | Simple controls, large UI, short plain-language facts, voice-over |
| **High school student** | Concepts behind the visuals (orbits, gravity, seasons) | Guided tours, labeled quantities, simple what-if experiments |
| **University student** (astronomy / physics) | Real units, orbital parameters, reproducible behavior | Precise readouts, selectable integrators, adjustable parameters |

To serve all three without overwhelming any of them, the UI exposes **two depth levels**, switchable at any time:

- **Explorer** — simplified labels and descriptions, everyday units, minimal numbers.
- **Scientist** — full numeric readouts (mass, radius, orbital elements, velocity, energy), scientific units, and advanced simulation controls.

## 4. Purpose and Presentation

| Course requirement | Orrery |
|---|---|
| Purpose (min. 1) | Education, information, entertainment |
| Presentation (min. 1) | 3D |
| Platform (min. 1) | PC (Windows, Linux) |

## 5. Functional Requirements

Priority: **P0** = must have, **P1** = should have, **P2** = stretch.

### 5.1 Solar System Simulation

| ID | Requirement | Priority |
|---|---|---|
| F-01 | Render the Sun, eight planets, and Earth's Moon with textured spheres and correct relative axial tilt and rotation | P0 |
| F-02 | Simulate orbital motion from real initial conditions, embedded offline | P0 |
| F-03 | Display orbit trails for every body, with adjustable length | P0 |
| F-04 | Time control: pause, play, reverse, and adjustable speed multiplier | P0 |
| F-05 | Distance and body-size scale toggle (compressed view vs. true scale) | P0 |
| F-06 | Major moons (Galilean moons, Titan) and dwarf planets (Pluto, Ceres) | P1 |
| F-07 | Asteroid belt rendered with instancing | P1 |

### 5.2 Explore Mode

| ID | Requirement | Priority |
|---|---|---|
| F-10 | Free-flight camera with smooth acceleration and speed scaled to distance from nearest body | P0 |
| F-11 | Select any body to focus the camera on it and open an information panel | P0 |
| F-12 | Information panel adapts to the active depth level (Explorer / Scientist) | P0 |
| F-13 | Guided tours with step-by-step camera paths and on-screen narration text | P1 |
| F-14 | Optional labels, orbit lines, and distance/scale reference markers | P1 |
| F-15 | Short quiz mode tied to tour content | P2 |

### 5.3 Sandbox Mode

| ID | Requirement | Priority |
|---|---|---|
| F-20 | Mutual N-body gravity simulation among all active bodies | P0 |
| F-21 | Add a body (choose mass and radius), set position, and launch it with an initial velocity vector | P0 |
| F-22 | Remove, edit, or freeze existing bodies | P0 |
| F-23 | Reset to the default solar system or to a saved preset | P0 |
| F-24 | Collision handling: merge bodies with conservation of momentum | P1 |
| F-25 | Presets (e.g. binary star, extra planet, rogue star flyby) | P1 |
| F-26 | Selectable integrator (Velocity Verlet / RK4) and time step for Scientist level | P1 |
| F-27 | Live readouts of total energy and angular momentum to illustrate numerical drift | P2 |
| F-28 | Maximum body count enforced per quality preset | P0 |

### 5.4 Application Shell

| ID | Requirement | Priority |
|---|---|---|
| F-30 | Main menu: Explore, Sandbox, Settings, Credits, Quit | P0 |
| F-31 | **Credits screen** listing every team member's name and student ID (NIM), reachable from the main menu | P0 |
| F-32 | Credits also list third-party assets with author and license, and disclose that narration audio is synthesized | P0 |
| F-33 | Settings: resolution/fullscreen, audio volumes, key bindings | P1 |
| F-34 | Pause menu available in both modes | P0 |
| F-35 | Persist user settings locally in the platform's user data directory | P1 |
| F-36 | Graphics quality presets (Low / Medium / High) and a render resolution scale slider | P0 |

### 5.5 Audio and Narration

| ID | Requirement | Priority |
|---|---|---|
| F-40 | Background music with separate volume control and mute | P1 |
| F-41 | Sound effects for UI interaction and sandbox actions (place, launch, merge, remove) | P1 |
| F-42 | Voice-over narration for guided tours, played alongside on-screen text | P1 |
| F-43 | Narration text is always displayed, and voice-over can be disabled independently | P0 |
| F-44 | Separate volume sliders for music, effects, and narration | P1 |

Narration is a narrator voice only. No animated character is planned.

## 6. Non-Functional Requirements

| ID | Requirement |
|---|---|
| N-01 | **Standalone**: a single exported build per platform that runs without installation, with all assets bundled |
| N-02 | **Fully offline**: no network access of any kind at runtime, including speech synthesis |
| N-03 | **Language**: all in-app text, narration, and documentation are in English |
| N-04 | **Cross-platform**: Windows 10/11 (x86_64) and Linux (x86_64, mainstream distributions) with feature parity |
| N-05 | Simulation remains numerically stable at the maximum supported time speed and body count |
| N-06 | Accessibility: scalable UI text, colorblind-safe palette for orbit trails, no flashing effects, captions for all narration |
| N-07 | All third-party assets must have a license permitting inclusion and redistribution |
| N-08 | **Low-spec support** per the targets below |

### 6.1 Hardware Targets _(to be validated on real devices)_

| Tier | Specification | Expectation |
|---|---|---|
| **Minimum** | 64-bit dual-core CPU, 4 GB RAM, integrated GPU supporting OpenGL 3.3, 1280×720 | 30 FPS on **Low** preset |
| **Recommended** | Any laptop from roughly the last 5 years with integrated graphics, 8 GB RAM, 1920×1080 | 60 FPS on **Medium** preset |
| **High** | Dedicated GPU | 60 FPS on **High** preset |

Initial sandbox body caps per preset: Low 32, Medium 64, High 128. These are starting values to be tuned by profiling.

The team's development machines are high-spec, so the minimum tier cannot be validated directly. It is approximated by forcing the application onto integrated graphics where available, lowering the render scale, and limiting CPU cores or memory in a virtual machine. Treat the minimum tier as validated only on a genuinely low-spec device, if one becomes available.

### 6.2 Quality Presets

| Setting | Low | Medium | High |
|---|---|---|---|
| Texture resolution | 1K | 2K | 2K–4K for major bodies |
| Orbit trail length | Short | Medium | Long |
| Bloom / glow | Off | On | On |
| Atmosphere and ring shaders | Simplified | Full | Full |
| Asteroid belt instances | Reduced | Medium | Full |
| Shadows | Off | Planets only | Planets and rings |
| Render scale | Adjustable | Adjustable | Adjustable |

## 7. Technical Approach

### 7.1 Engine, Renderer, and Language

- Godot 4.7.2 with GDScript. Performance-critical paths may move to GDExtension if profiling justifies it.
- **Compatibility renderer** (OpenGL-based) is the single supported renderer. It runs on older integrated GPUs and avoids the Vulkan driver variability seen on Linux. Using one renderer also keeps the test matrix small.
- Custom spatial shaders, instancing, and bloom are expected to work in this renderer. This must be confirmed in M0.

### 7.2 Numerical Precision

Godot's `Vector3` is single-precision by default, which causes jitter at solar-system distances. Strategy:

- Simulation state is held in double-precision values and kept independent from scene nodes.
- Render positions are derived by scaling and re-centering relative to the camera (floating origin).
- Simulation and rendering are separate modules; the renderer only reads simulation state.

### 7.3 Simulation

Two models share the same body data:

- **Explore mode** propagates every body analytically along its Keplerian orbit, using published orbital elements and their rates (NASA JPL, valid 1800 AD – 2050 AD), with the Moon modeled around Earth. This is exact at any time speed, supports reversing and jumping in time at no cost, and keeps cost linear in the number of bodies.
- **Sandbox mode** integrates mutual gravity numerically. Bodies start from state vectors derived from the same orbital elements.
  - Fixed-step simulation decoupled from frame rate, with sub-stepping at high time multipliers.
  - Default integrator: Velocity Verlet. RK4 available as an option.
  - Pairwise gravity is O(n²), which is why body count is capped per quality preset.
  - The time step adapts to the shortest dynamical time among body pairs, so close encounters and tight orbits stay stable.
  - Each frame has a fixed CPU budget for simulation. When the requested time speed cannot be met within the budget, the effective speed drops gracefully and the HUD reports that the simulation speed is limited. This keeps the application responsive on low-spec devices (N-05, N-08).
  - Earth and the Moon start as two separate bodies, split about their barycenter, because the published Earth elements describe the barycenter.
  - Orbit trails and launch references use the Hill sphere to choose the body each object orbits.
  - Rendering uses a single linear scale of 1 render unit per 1,000 km, with a minimum angular size so small bodies remain visible, and a distance shell that keeps the depth range bounded.

All orbital and physical data is embedded in `data/bodies.json`, so no network access is needed.

### 7.4 Cross-Platform Notes

- Windows and Linux builds are exported from the same project using Godot export presets.
- Linux filesystems are case-sensitive. All resource paths must match file names exactly and use lowercase `snake_case`.
- User settings are stored under `user://` only. No hard-coded absolute paths.
- Each release is smoke-tested on both platforms before delivery.

### 7.5 Audio Pipeline

- Narration is **pre-generated at development time** with a free, open-source, locally run text-to-speech engine, then bundled as compressed audio files. Nothing is synthesized at runtime, so the application stays fully offline and sounds identical on every platform.
- Engine: **Kokoro-82M** through `kokoro-onnx`. The model weights are Apache-2.0, the wrapper is MIT, and the model was trained on permissively licensed or non-copyrighted audio. It runs on CPU without internet once the model files are downloaded.
- Voice: `af_bella`, the highest-graded American English voice in the published voice list at the time of selection. The voice can be changed with a command-line argument.
- Narration scripts come from `godot/data/narration.json` (standalone clips) and from every guided-tour step in `godot/data/tours.json`, at both depth levels. Audio files are written to `godot/assets/audio/narration/` as OGG Vorbis, named after script IDs (`<tour>_<step>_<explorer|scientist>` for tours). A manifest of content fingerprints makes regeneration incremental and reproducible. Units such as "AU" and "km" are spelled out for speech only; captions keep the original text.
- Generation is run with `uv run generate_narration.py` from `tools/tts/`. Model files and the virtual environment are not committed.
- Music and effects are generated by the team with procedural synthesis in `tools/audio/` (`uv run generate_audio.py`). The generator uses fixed seeds, so its output is reproducible. It uses no third-party samples, so there is nothing to license.

### 7.6 Proposed Module Layout

```
orrery/
├── docs/            Product and technical documentation, final report
├── godot/           Godot project
│   ├── core/        Simulation, orbit models, clock, settings
│   ├── render/      Bodies, trails, shaders, camera
│   ├── ui/          Menus, panels, HUD, credits
│   ├── audio/       Audio manager, buses, playback
│   ├── modes/       Explore and Sandbox mode logic
│   ├── data/        Orbital data, body info, tour and narration scripts
│   └── assets/      Runtime textures, audio, and fonts bundled into the build
├── tools/           Offline scripts, such as narration generation
└── assets/          License register for every bundled third-party asset
```

## 8. Computer Graphics Techniques (Report Material)

| Technique | Where it is used |
|---|---|
| Texture mapping and normal/specular maps | Planet and moon surfaces |
| Lighting model (point light from the Sun, emissive Sun) | Day/night terminator, shading |
| Custom shaders (spatial shader) | Atmosphere scattering, Saturn's rings, Sun surface |
| Alpha blending and transparency sorting | Rings, atmospheres, trails |
| Post-processing (bloom/glow, tone mapping) | Sun glow, overall look |
| Skybox / environment mapping | Starfield and Milky Way |
| GPU instancing | Asteroid belt |
| Dynamic mesh generation | Orbit trails |
| Camera systems and coordinate transforms | Floating origin, focus-and-follow camera |
| Level of detail | Sphere tessellation by distance |
| Quality scaling | Preset-driven shader and asset complexity |

## 9. Course Deliverable Checklist

- [x] Interactive computer graphics application
- [x] Purpose: education, information, entertainment
- [x] Presentation: 3D
- [x] Platform: PC (Windows, Linux)
- [x] Credits screen with names and student IDs, accessible to the user
- [x] Standalone, no internet connection required
- [ ] Technologies documented in the report

## 10. Assets and Licensing

- Surface textures: Solar System Scope (CC BY 4.0) for the Sun, planets, Moon, rings, and sky. USGS Astrogeology global mosaics from NASA missions (public domain) for the Galilean moons, Titan, Ceres, and Pluto, prepared by `tools/textures`.
- Music and sound effects: use only assets whose license permits redistribution inside an application. Record attribution requirements.
- Narration: record the TTS engine, voice model, and the voice model's license.
- Every asset is recorded in `assets/LICENSES.md` with source URL, author, license, and date retrieved.
- All records are surfaced in the in-app credits (F-32).

## 11. Timeline

The project runs for a fixed **4 weeks**. The plan is expressed in weeks, not calendar dates.

| Week | Focus | Scope | Exit criteria |
|---|---|---|---|
| **1** | Foundation and core simulation | Project setup, Compatibility renderer validation, precision strategy, full planet set, orbit trails, time controls, scale toggle, quality preset framework, TTS engine and voice selection, first Linux export | F-01 to F-05 and F-36 complete. Stable orbits with no jitter. Bloom and a custom shader confirmed on Compatibility. Linux build launches |
| **2** | Explore mode and sandbox foundation | Body selection, info panels, depth levels, labels, tour framework with text narration, N-body engine, add / launch / remove bodies | F-10 to F-14 and F-20 to F-23 complete |
| **3** | Sandbox completion, visuals, audio base | Collisions, presets, body caps, integrator choice, atmosphere and ring shaders, skybox, asteroid belt, audio manager, music, sound effects | F-24 to F-26, F-28, F-40, F-41, F-44 complete. Visual targets met on all presets |
| **4** | Voice-over, shell, and release | Voice-over generation and integration, main menu, settings, credits, final exports for Windows and Linux, offline test, low-spec approximation test, final report | All P0 items done. P1 items done where schedule allows. Builds verified on Windows and Linux |

The final report is written alongside development. Technique notes, screenshots, and asset records are captured as each feature lands, not left to week 4.

### 11.1 Scope Cut Order

If the schedule slips, features are cut in this order, first to last. P0 items are never cut.

1. F-15 Quiz mode
2. F-27 Energy and angular momentum readouts
3. F-07 Asteroid belt
4. F-06 Additional moons and dwarf planets
5. F-26 Selectable integrator
6. F-25 Sandbox presets
7. F-42 Voice-over (text narration remains)
8. F-24 Collision merging

## 12. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Floating-point jitter at large distances | Visual artifacts | Double-precision simulation and floating origin from M0 |
| N-body instability at high time speed | Wrong or exploding orbits | Sub-stepping, Verlet, energy monitoring |
| Scope too large for 4 weeks | Incomplete product | Strict P0/P1/P2 prioritization, the cut order in §11.1, and Sandbox built on the week 1 core |
| Mixed Godot versions in the team | Project corruption | Everyone pins Godot 4.7.2 |
| Linux regressions go unnoticed | Broken Linux release | Export a Linux build in week 1 and re-test on the team's Linux laptop at the end of every week |
| Compatibility renderer lacks a needed feature | Visual targets not met | Validate shaders and post-processing in week 1 before committing to designs |
| Low-spec target cannot be verified on real hardware | Unknown performance on weak devices | Preset system from week 1, and approximate low-spec conditions as described in §6.1 |
| TTS voice license forbids redistribution | Cannot ship narration | Verify license before generating; record in `LICENSES.md` |
| Build size grows from textures and audio | Hard to distribute | Compressed textures and OGG audio, track size each milestone |
| Asset license issues | Disqualification risk | Track every asset in `LICENSES.md` from the first import |

## 13. Engineering Conventions

- Source code contains no explanatory comments. Clarity comes from naming and structure.
- A comment is permitted only when it is professional and necessary, such as a non-obvious constraint, a units note, or a reference to a source of an algorithm or constant.
- Comments never narrate what the code does line by line.
- All identifiers, UI strings, commit messages, and documentation are in English.
- File and folder names inside the Godot project use lowercase `snake_case`.

## 14. Open Questions

1. ~~Music and sound effect sources.~~ Resolved: team-generated procedural audio (§7.5).
2. Demo format and report structure required by the course.

## Appendix A — Credits

**Team Sepak Takraw**

| Name | Student ID (NIM) | Role |
|---|---|---|
| Muhamad Fahry Pratama Putra | 245150207111046 | Team Lead |
| Muhammad Atha Tsaqif | 245150201111002 | Member |
| Muhammad Hafizh Faiqunnabil | 245150201111031 | Member |
| Alexander William Sinjaya | 245150200111044 | Member |
