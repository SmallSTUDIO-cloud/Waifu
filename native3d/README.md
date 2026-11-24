# Scarlet Veil native 3D milestone

A Godot 4.4.1 GDScript 3D combat test, independent of the earlier 2D WebView prototype. The player is a rigged third-party CC0 glTF character; the arena, enemy meshes and sword are blockout assets. Move with WASD or the on-screen joystick, attack with J or ATTACK, dodge with Space or DODGE. Four enemies have a chase/windup/attack loop; attacks do real 3D distance and directional checks and the player has dodge invulnerability. Desktop Esc and the pause button open the pause menu.

The character uses retargeted CC0 motion, a procedural fallback and bounded springs on secondary hair and clothing bones. It is an early approximation, **not** a validated cloth or VRM spring-bone system. Animation, camera, AI, content, visuals, audio, optimization and device compatibility are not production-ready. See `ASSET_LICENSES.md` for the temporary model.

To run locally, install Godot 4.4.1 and open this folder as a project. Headless smoke check after importing:

```sh
godot --headless --path native3d --editor --import --quit
godot --headless --path native3d --script res://tests/smoke.gd
```

## Android test status

The `v0.3.1-native3d` debug APK was installed and rendered the actual 3D encounter in an API 30 x86_64 emulator using ANGLE software rendering (CI run 44925419191). This verifies startup and a visible frame, not mobile touch gameplay, sustained frame rate, or compatibility on a physical device. The screenshot showed placeholder visuals and the player taking damage from enemies. A previous emulator configuration using `swiftshader_indirect` produced a blank screen and Godot shader-linking errors; the emulator workflow uses `swangle_indirect` instead. Real Android GPU and device testing remains required, as do production signing and art/animation/physics work.

The current animation pass uses retargeted authored CC0 idle, walk and sword-attack clips, plus an authored sword dash for a fast upright dodge (with the previous jog pose as fallback), with a procedural fallback if mapping fails. The combo now retargets four distinct CC0 authored sword clips; their timing and outfit deformation still require animator review. Sword trails, hit sparks and a dodge ring use short-lived unlit geometry, not large particle textures. These are prototype improvements; they are not authored motion-capture animations. Normal native CI runs validate and render the project without exporting or publishing an APK.

Recent combat iteration adds speed-driven clip selection, directional dodge, buffered combo input, a sampled blade ribbon, layered slash/impact/dodge effects and subtle hit feedback. The blade trail and transient effects have bounded sample counts and lifetimes. CI captures animated previews as well as still frames. This is an early retarget, not final animator-polished or physically grounded motion; better weapon-specific clips, foot locking, visual cleanup, and device profiling are still needed.

Secondary hair, skirt and sleeves use bounded, damped angular springs; anatomy bones are not simulated. Skirt midpoints and tips have approximate swept leg-capsule constraints, not full cloth collision. See `SECONDARY_MOTION.md` for quality modes, validation and limitations. Combo effects build from a single slash to layered crescents and a finisher shockwave, with a cap on simultaneously active transient effects. The sword grip is offset into the hand with curled fingers and a tapered blade. All of this still needs real-device performance and visual testing.

The reference-inspired VFX pass uses violet-white tapered crescents, petal-like shards, a spinning third hit and a heavier fourth-hit cleave; it is an approximation, not a pixel-identical recreation of the reference. Dodge reuses one fading dark skinned afterimage. The walk uses a CC0 formal cycle, while the dodge uses an authored sword dash rather than a roll. Phone profiling and animator cleanup remain necessary.

The deploy and pause menus offer persistent physics (off/reduced/full) and VFX (reduced/full) controls. See `SECONDARY_MOTION.md` for collision limits and `ANDROID_PROFILING.md` for the physical-device protocol. The avatar has no independently rigged ribbon or bow and no anatomy bones are simulated.

### Touch camera

During combat, drag an open part of the screen with one finger to orbit around the character. Pinch with two fingers to zoom in or out. The movement joystick, attack, dodge and pause buttons keep their own touches; movement and dodge direction are relative to the current view. Camera angle and zoom reset when starting a new encounter and remain unchanged when pausing and resuming. Touch behavior still needs physical-device testing.

### Sword and aura
The sword is built in code at runtime (`player.gd::_attach_sword`): leather-wrapped grip with wrap rings, gold pommel and cross-guard, a tapered fullered blade with glowing purple power edges, and an additive hex aura shell that breathes at idle and flares during swings. While walking, the grip tilts the blade outward/down so the swing clears the chest scarf; the pose relaxes back at idle. The swing trail (`sword_trail.gd`) samples the real posed blade.

### Real jiggle physics (WiggleBone addon)
At PHYSICS quality **FULL**, hair, skirt/dress and sleeve chains are driven by the vendored MIT [WiggleBone](https://github.com/detomon/wigglebone) addon (`addons/wigglebone/`, wired up in `scripts/wiggle_physics.gd`). It models each bone as a spring point-mass that reacts to **acceleration**, so while walking at constant speed the hair doesn't lag behind — it swings on starts, stops, turns and dodges, and droops under gravity when idle. Tuning follows the addon's damping model (`angular_damp` is an exponential velocity decay, so the damping ratio is `zeta = angular_damp / (TAU * spring_freq)`): hair is underdamped (~0.22, flows and settles), cloth near-critical (~0.49, no endless flapping); roots are stiffer and settle faster while tips get lower frequency AND lower damping for whip/follow-through; swing limits (hair 45°, cloth 30°) keep strands off the face and panels off the legs; a small deterministic per-bone frequency wobble avoids lockstep motion. Bust/anatomy bones are never simulated (test-enforced). REDUCED/OFF fall back to the angular springs in `secondary_motion.gd` (cheaper) or disable entirely, so the cost stays mobile-friendly. Covered by `tests/wiggle_physics.gd`.

### Secondary physics
Hair, skirt and sleeve chains are driven by angular springs after authored animation (`secondary_motion.gd`), with per-chain depth falloff (stiff roots, whip-like tips), skirt tips constrained against leg capsules, a faint post-spring idle sway, and quality tiers 0/1/2 for mobile. Solver cost stays bounded (substeps capped at 60 Hz, acceleration clamped) and is profiled on the emulator via `SECONDARY_PROFILE`.

### HUD controls
Combat HUD buttons are round, glass-style and icon-only (sword = attack, chevrons = dodge, bars = pause; textures in `assets/ui/`, generated in-repo). The joystick is glass too. Touch input is routed centrally in `world.gd::_input`: each finger gets an explicit owner (HUD button, joystick, or camera), so the joystick and the attack/dodge buttons work at the same time. Covered by `tests/touch_camera.gd`.

### Ground Zero tutorial environment

The night blockout arena was replaced by **Ground Zero**, a sunny post-apocalyptic
plaza built procedurally at runtime by `scripts/ground_zero.gd` from the
four-direction concept in `docs/ground_zero_reference.png` (all four views are
one connected world). It has a 26 m open plaza with faded circular markings, a
ring road, 12 modular damaged buildings with facade textures (generated in-repo
by `tools/gen_env_textures.py` into `assets/env/`), a broken elevated road, a
lattice comm tower, three readable billboards ("CLAUDE FOREVER", "HUMANITY WAS
HERE...", "CLAUDE AI CONTROLS THE WORLD"), abandoned cars and a bus, trees,
grass and rubble. Aggressive LOD: per-building visibility-range tiers
(0–34 / 32–70 / 68–170 m) with merged per-district HLOD silhouettes, district
skyline impostor MultiMeshes, octant-sector grass/rubble MultiMeshes, merged
same-material static meshes, one shadow-capped sun (48 m, 2 splits, atlas sizes
capped in `project.godot`), procedural sky + distance fog. Note the
`gl_compatibility` renderer has no occlusion culling or LightmapGI baking, so
culling relies on frustum + visibility ranges. `tests/ground_zero.gd` validates
layout, LOD tiers, landmarks, lighting, instancing, an open plaza and gameplay
integration; CI captures the four reference views via `--preview-view-*` and a
software-rendered perf report via `--perf-report`. See `docs/GROUND_ZERO.md` for
the full LOD/lighting report and honest limitations — **no APK was built and no
device FPS is claimed** (standing rule); all perf numbers are llvmpipe
software-rendered CI metrics.

### Enemy robots

Encounters spawn four CC0 Polygonal Mind robots (one model, role tints): two dark **bruisers** that chase and telegraphed melee-slam (12 damage, red ground ring), and two hovering **gun drones** that hold a 4–8 m band, show a red sight line while charging, and fire dodgeable energy bolts (10 damage, 8.5 m/s). Drones headbutt (8 damage) if you get too close. Robots separate so they do not stack, flash and recoil when hit, and fall over when destroyed. Balance constants are bounded in `enemy.gd`/`enemy_projectile.gd` and covered by `tests/enemy_combat.gd`. Physical-device gameplay feel still needs on-device testing.

