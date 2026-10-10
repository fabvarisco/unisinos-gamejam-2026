# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Godot 4.5 game** (GDScript) for Unisinos Game Jam 2026. The GDD is in [GDD-console-quebrado.md](GDD-console-quebrado.md) — read it first for design intent.

Entry point: `scenes/main.tscn`. Viewport: 1280×720, Forward Plus renderer.

## Running

Open in Godot 4.5+ editor and press F5 (or use **Project > Run**). There is no CLI build step or test suite.

## Architecture

The game has two distinct rendering layers composed together:

**3D layer** — the physical console (`scenes/console.tscn`, driven by `scripts/console.gd`). A `Node3D` that owns the voxel-style handheld console mesh, all 3D interaction logic, and a `SubViewport` whose texture is mapped onto the console's screen mesh (`scripts/screen.gd`).

**2D layer** — runs *inside* the `SubViewport`. Contains the game-select menu (`minigames/gameSelect/`) and the platformer minigame (`minigames/platform/`). The platformer's `process_mode` is toggled between `DISABLED` and `INHERIT` at runtime so it only runs when the screen is active.

### Input model

The player character (`playerPlatform.gd`) **never reads `Input` directly**. It exposes:
- `move_axis: Vector2` — set by `console.gd` based on wire/short state
- `try_jump()` — called by `console.gd` when jump is triggered

`console.gd` is the single owner of all input decisions. It checks each pad against two sources before acting:
- `_wire.is_live("PadName")` — wire is fully plugged into this pad
- `_shorted.has("PadName")` — pad was burned via screwdriver

### Pad names

All pads on the console back are named `PadDpad`, `PadA`, `PadB`, `PadStart`. Code that references pads uses these string names — the wire, screwdriver, and console scripts all key on them.

### Wire simulation (`scripts/wire.gd`)

Verlet-integration rope with `point_count` nodes. The tip snaps to a `Pad*` child of `Console/Back` when released within `snap_distance`. `is_live(pad_name)` returns true only when fully snapped. Blocked pads (burned) are tracked in `blocked_pads` and excluded from snap candidates.

### Battery system (`scripts/battery.gd`)

Each battery is a `MeshInstance3D` with a dynamic `StaticBody3D` hitbox. Signals `removed`/`inserted` are wired to `console.gd._refresh_energy()`, which counts installed batteries and drives the energy label (0%, 50%, 100%).

### Burn/short mechanic

Placing the screwdriver (`scripts/screwdriver.gd`) onto a pad and pressing the corresponding button triggers `_burn(pad_name)` in `console.gd`. This:
1. Adds the pad to `_shorted`
2. Calls `_wire.block_pad(pad_name)` so the wire cannot plug there
3. Overrides the hole material to `_burned`
4. Applies a red overlay to the button mesh
5. Spawns a `CPUParticles3D` spark burst

Removing the screwdriver via `_try_grab_screwdriver` calls `_clear_short`, reversing steps 1–4.

### Transitions

Both the 3D console layer and the 2D platformer reuse the same pixel-dissolve shader (`shaders/pixel_transition.gdshader`). Transitions snapshot current and next frames as `ImageTexture`, then tween the `progress` shader parameter.

## File layout

```
scenes/       main.tscn, console.tscn
scripts/      console.gd, wire.gd, battery.gd, screen.gd, screwdriver.gd, view.gd, dpad_button.gd
minigames/
  platform/   platformMinigame.gd/tscn, playerPlatform.gd, levelPlatform.gd, monsterPlatform.gd
  gameSelect/ gameSelect.gd/tscn
shaders/      pixel_transition.gdshader, fade.gdshader, platform/chromaPlatform.gdshader
Assets/       platformer/monochrome_tilemap.png
```
