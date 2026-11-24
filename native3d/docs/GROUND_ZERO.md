# Ground Zero — post-apocalyptic tutorial environment (delivery report)

Design authority: `docs/ground_zero_reference.png` (user-provided four-direction
concept: East / West / North / South views of **one connected** ruined city
plaza, "TUTORIAL WORLD — GROUND ZERO"). The other uploaded sheets (a character
design and a combat-VFX sheet) are out of scope here and were not used; per
standing rules the Tesla character sheet is never re-added and no sexualized
anatomy appears anywhere in the project.

## What was built

One connected 3D world, built procedurally at runtime by
`scripts/ground_zero.gd` (instantiated by `world.gd::_ready`, replacing the old
night blockout `_environment()`/`_arena()`):

- **Central plaza** — 26 m diameter cracked-concrete disc with faded circular
  ground markings (generated `assets/env/plaza.png`), ring road (16 merged
  segments) + 4 exit roads, kept fully open: the gameplay clamp (±8.5 m) and a
  test-enforced "no solid within 9 m of center" rule keep combat space clear.
- **Surrounding architecture** — 12 perimeter buildings (square modular blocks,
  8–12 m footprint, 3–7 floors, 4 facade texture variants with windows,
  balconies, grime, damage holes and exposed rebar), rooftop water tanks / AC
  units / antennas, tilted collapse slabs on damaged ones. Plus a 28-box
  distant skyline.
- **Elevated road** (`Elevated_Ruins`) — spans the north side at 7.2 m with a
  broken gap, leaning broken pillar, jagged deck edges, partial railings and 9
  pillars; one merged far-LOD slab.
- **Landmarks** — lattice communication tower with platforms, dish and red
  beacon (south side, centred in the North view); abandoned bus + 4 cars;
  three readable emissive billboards: **CLAUDE FOREVER** (west side, faces the
  East view), **HUMANITY WAS HERE...** (east side, faces the West view),
  **CLAUDE AI CONTROLS THE WORLD** (north side, faces the South view).
- **Vegetation/props** — 8 trees (trunk + merged foliage, 2 LOD tiers), 10
  bushes, grass in 8 octant MultiMesh sectors (~1280 instances, alpha-scissored
  blade texture), rubble in 8 octant MultiMesh sectors, 6 merged big rubble
  clusters, 8 streetlights, 6 jersey barriers.
- **Scene organization** — `GroundZero` root with `Lighting`, `Central_Plaza`,
  `East/West/North/South_District`, `Elevated_Ruins`, `Landmarks`,
  `Static_Vehicles`, `Vegetation`, `Props`, `LOD_Proxies`, `Collision`.

## LOD / HLOD implementation (aggressive, from the start)

Manual visibility-range tiers on every `GeometryInstance3D` (fade mode
DISABLED — cheap, no transparent popping; 2 m hysteresis overlap between tiers
so nothing flickers at the boundary):

| tier | range | content |
|---|---|---|
| LOD0 | 0–34 m | facade boxes + merged props/balconies + vehicle detail + tree detail |
| LOD1 | 32–70 m | facade box only |
| LOD2 | 68–170 m | merged per-district silhouette boxes (HLOD) |
| skyline | 30–260 m | 4 district MultiMeshes of merged boxes (impostors) |
| grass | 0–55 m per octant sector | MultiMesh, shadows off |
| rubble | 0–70 m per octant sector | MultiMesh |
| props/vehicles | 0–46 m (far simple box to 150 m) | merged meshes |

Same-material static geometry is merged into single meshes (roads, deck,
railings, pillars, tower lattice, props per building, barriers, streetlights,
rubble clusters, district LOD2 boxes), which cut mesh instances from 359 → 151
and nodes from 586 → 378. MultiMesh sectors are spatially divided (8 octants +
4 skyline districts) so frustum culling still works per sector. Shadow casting
is disabled on all far tiers, grass, rubble and merged props.

## Lighting / shadow engineering (mobile)

- One `DirectionalLight3D` sun (warm afternoon, from the south-east), shadows
  **enabled but capped**: `directional_shadow_max_distance = 48`, 2 parallel
  splits, atlas sizes capped in `project.godot` (directional 2048, positional
  1024). No OmniLight/SpotLight anywhere (test-enforced).
- Sky: `ProceduralSkyMaterial` in a `Sky` background + sky-sourced ambient;
  depth fog (begin 80 m, end 260 m) + aerial perspective for the distant
  skyline; ACES tonemap.
- **Honest renderer limitation**: the project renders with `gl_compatibility`
  (standing rule: no renderer change without a demonstrated reason), which has
  **no occlusion-culling server and no LightmapGI baking**. So instead of baked
  lightmaps we use sky ambient + distance fog + capped dynamic shadows, and
  instead of occlusion culling we rely on frustum culling + the LOD/visibility
  system above. This is documented rather than worked around by switching
  renderers.
- Billboard/sign faces use emission materials (no extra shadow-casting lights).

## Textures / assets

All environment art is **original, generated in-repo** by
`tools/gen_env_textures.py` (seeded, deterministic) into `assets/env/`
(15 POT PNGs, 128–1024 px: 4 facade cells, concrete, plaza, asphalt, dirt,
3 billboards, 2 signs, grass, leaf, window strip). Imported with the project's
ETC2/ASTC VRAM compression. No external or commercial models were extracted;
existing gameplay assets (avatar/enemy/Quaternius GLBs, UI icons, WiggleBone
addon) are untouched — provenance in `ASSET_LICENSES.md`.

## CI verification (all software-rendered under xvfb/llvmpipe — NOT device numbers)

- `tests/ground_zero.gd` (new, in the required test list) asserts: sector
  structure, ≥12 buildings with LOD ranges on every tier, district HLOD meshes,
  open plaza (no solid near center), the 3 billboard texts, tower, elevated
  road, ≥5 vehicles, ≥16 MultiMesh sectors, sun shadow cap ≤ 60 m, sky
  background, fog, zero point/spot lights, and **gameplay integration**: 4
  enemies spawn, the player moves, attacks and dodges inside the plaza.
- Full suite: 9/9 PASS (all pre-existing gameplay tests unchanged and green).
- Four fixed view cameras `--preview-view-east/west/north/south/center` render
  the same world from the four reference directions; CI stores stills + GIFs as
  run annotations (previews were split into 4 workflow steps because GitHub
  processes max 10 warning annotations per step).
- Perf instrumentation (`--perf-report`) prints `PERF` lines into diagnostics:
  baseline blockout arena vs Ground Zero (software-rendered 1280×720):

  | scene | draw calls | primitives | objects | video mem | nodes |
  |---|---|---|---|---|---|
  | old arena (smoke-play) | 334 | 27,898 | 400 | 74.4 MB | 214 |
  | Ground Zero, gameplay cam | ~662 | ~96,000 | ~728 | ~85 MB | 378 |
  | Ground Zero, plaza overview | ~416 | ~57,000 | ~421 | ~85 MB | 378 |

  The overview view (what the four reference shots use) sits at ~416 draw calls
  after LOD/visibility culling; the close gameplay camera sees more LOD0 props.
  These are llvmpipe software-rendering numbers only.

## Gameplay preservation

Player (walk/sprint/attack/dodge), WiggleBone hair/skirt physics, combat VFX,
enemy robots + bolts, touch camera and glass HUD are untouched and all their
tests still pass. Only `world.gd` changed, minimally: it instantiates
`GroundZero`, adds the five `--preview-view-*` cameras and a `--perf-report`
hook, and the menu copy now says GROUND ZERO. Player/enemy position clamps
(±8.5 m) are unchanged and the plaza is open around them.

## Known limitations / not done (honest)

- **No APK build, no prerelease, no emulator run in this branch** (standing
  rule), so Phase 8's "build for Galaxy M21 and test on device" is explicitly
  **not performed**. There are therefore **no physical-device FPS claims**; the
  30 FPS target remains unverified on hardware. All performance figures above
  are software-rendered CI numbers plus structural metrics (draw calls,
  primitives, LOD configuration, memory).
- `gl_compatibility` has no occlusion culling / LightmapGI (see above);
  if the renderer is ever moved to Mobile/Forward+, bake LightmapGI and add
  occlusion occluders for building walls to cut the overview further.
- Buildings are modular textured boxes with procedural damage, not unique
  hand-modeled meshes; interiors are intentionally absent.
- LOD transitions are hard swaps with hysteresis (no alpha dither), which can
  pop at exactly the boundary on close inspection; tuned ranges are documented
  above and can be adjusted per device after real profiling.
