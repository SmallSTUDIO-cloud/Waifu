# Ground Zero — post-apocalyptic tutorial environment

Design authority: `docs/ground_zero_reference.png` (user-provided four-direction
concept: East / West / North / South views of one connected ruined city plaza,
"TUTORIAL WORLD — GROUND ZERO"). The other uploaded sheets (character design,
combat VFX) are **not** in scope for this task and are not used; per standing
rules the Tesla character sheet is never re-added and no sexualized anatomy is
introduced anywhere.

## Phase 0 — audit (recorded before any environment change)

- **Engine**: Godot 4.4.1 stable, `config/features = ["4.4", "GL Compatibility"]`.
  Rendering method **`gl_compatibility`** (desktop + mobile), textures imported
  with `vram_compression/import_etc2_astc=true`. CI runs the same project under
  `xvfb-run ... --rendering-method gl_compatibility --rendering-driver opengl3`.
  Consequence: **no occlusion-culling server and no LightmapGI baking** in the
  compatibility renderer — both are Forward+/Mobile-only. The plan therefore
  relies on frustum culling, aggressive visibility-range LOD/HLOD, MultiMesh
  instancing and a single limited-range shadow-casting sun, and documents this
  honestly instead of switching renderers (project rule: no renderer change
  without a demonstrated reason).
- **Project layout**: single-scene game. `main.tscn` is one `Node3D` with
  `scripts/world.gd`; the whole world (environment, arena, HUD, menu, player,
  enemies, camera) is built at runtime in GDScript. No editor-authored levels.
- **Existing asset inventory** (`native3d/assets/`): `avatar.glb` (temporary CC0
  VRoid test character — kept), `enemy-robot.glb` (CC0 Polygonal Mind robot),
  `quaternius-motion.glb` / `quaternius-combo.glb` (CC0 Quaternius clips),
  `assets/ui/*.png` (in-repo generated glass HUD icons), vendored MIT
  `addons/wigglebone/`. Provenance in `ASSET_LICENSES.md`. No environment art
  exists yet — everything for Ground Zero is generated in-repo (PIL textures +
  procedural GDScript meshes), which keeps licensing clean.
- **Gameplay systems that must keep working unchanged**: player controller
  (`player.gd`, walk/sprint/attack/dodge, position clamped to ±8.5 m),
  WiggleBone hair/skirt physics (`wiggle_physics.gd`), combat + combo VFX
  (`combat_vfx.gd`, `sword_trail.gd`), enemy robots + bolts (`enemy.gd`,
  `enemy_projectile.gd`, also clamped to ±8.5 m), touch camera + glass HUD
  (`world.gd`, `joystick.gd`). Spawn points: player `(0, 0.1, 3)`, four enemies
  around `z ∈ [-5.2, -3.5]` — so the **central plaza within radius ~10 m of the
  origin must stay open and walkable**.
- **Current environment (being replaced)**: `_environment()` (dark night sky,
  one non-shadowed sun, one red omni light) and `_arena()` (20×20 m dark floor,
  grid lines, low walls at ±9.7 m, distant dark boxes with red emissive windows
  at z = −22). It is blockout, not the reference look.
- **Baseline measurement**: CI step "Software-rendered perf report" runs
  `--smoke-play --perf-report` under xvfb/llvmpipe and prints `PERF_REPORT` /
  `PERF` lines (fps, draw calls, primitives, video/static memory, node counts)
  into the run diagnostics and a `Perf report` annotation. **All numbers are
  software-rendered (llvmpipe) CI numbers, not Galaxy M21 device numbers.** Per
  standing rules no APK is built and no prerelease is published in this work, so
  Phase 8's on-device build/test is explicitly out of scope here; the Android
  export preset remains configured for a later, separately approved step.
- **CI**: `.github/workflows/native-3d.yml` imports the project, runs the 9
  headless test scripts (errors fail the run), captures a software-rendered
  frame, captures per-action preview GIFs/stills as annotations, and stores a
  combined `Diagnostics` annotation.

## Plan (phases)

1. Blockout + four fixed view cameras (`--preview-view-east/west/north/south/center`)
   so CI can capture the same four directions as the reference.
2. In-repo texture generation (`tools/gen_env_textures.py` → `assets/env/*.png`).
3. `scripts/ground_zero.gd`: one connected world — plaza, ring road, building
   perimeter with facades/damage, elevated road with a broken gap, comm tower,
   3 text billboards, vehicles, vegetation, rubble, props — with manual 3-tier
   LOD per building + district impostors (HLOD), sector MultiMeshes, visibility
   ranges with hysteresis overlap, one shadow-capped sun + sky + fog.
4. Integrate in `world.gd` (replace `_environment`/`_arena` visuals, keep floor
   collision + all gameplay), add `tests/ground_zero.gd`, extend CI previews
   with the four views + perf report.
5. Iterate on CI screenshots against the reference; tune LOD/lighting from the
   printed PERF numbers.

## Known limitations (honest list, updated as phases complete)

- Compatibility renderer: no occlusion culling, no LightmapGI bake, no
  mesh-LOD-on-import switching for runtime-built meshes → manual LOD tiers.
- No physical-device or emulator APK runs in this branch (standing rule) →
  performance is validated as software-rendered CI numbers + structural metrics
  (draw calls, primitive counts, LOD configuration), not device FPS.
