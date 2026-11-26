# Master animation audit — technical diagnosis

Branch `arena/175fcd9f-waifu`. This is the section-2 audit of the existing
architecture: model, rig, animation ownership, physics ownership, coordinate
conventions and the exact root causes of the reported problems. Everything
below was verified by reading the code, parsing `assets/avatar.glb` directly
(pure-Python GLB parse) and by headless CI measurements — no bone direction
was ever guessed or blindly reversed.

## 1. Hero model and skeleton

- `native3d/assets/avatar.glb`: VRoid-style heroine, rest pose is a **T-pose**.
  Parsed directly: every `J_Bip_*` bone's *global* rest basis is the identity,
  so for every body bone **local +Z = world +Z (character's left/abduction)**,
  **local +X = world +X**, **local +Y = bone's long axis (down the limb)**.
  The character model faces **-Z** (Godot forward for this avatar), right hand
  at +X. Consequence: the original sprint bug (arms stuck sideways) was arms
  written with z≈0 in a T-pose rest = arms out along ±Z; the fix adducts them
  to z≈±1.05 (down along the body).
- Bone families:
  - `J_Bip_*` — body. Written **only** by the animation layers
    (`authored_motion.gd` retarget + `player.gd` `_pose`/`_sprint_pose`).
  - `HairJoint*` — hair chains. Owned **only** by WiggleBone.
  - `J_Sec_*Skirt*`, `J_Sec_*Sleeve*` — cloth chains. Owned only by WiggleBone.
  - `J_Sec_*Bust*` — chest scarf chain. Owned only by WiggleBone.
  - `*_end` leaf bones are skipped by physics.
- No bone is written by two systems (asserted by `tests/sprint_cycle.gd` and
  `tests/secondary_vfx.gd`), so animation and physics never fight.

## 2. Locomotion architecture

- `player.gd` is a `CharacterBody3D`. Movement is **fully code-driven**
  (`velocity` + `move_and_slide()`); there is **no root motion** and none was
  added. `facing` = last non-zero input direction; `model_root.rotation.y`
  lerps toward `atan2(-facing.x, -facing.z)` (rate 12/s) with a `turn_lean`
  roll on sharp turns.
- Speeds: walk 2.8 m/s, sprint 5.4 m/s, dodge dash 10 m/s; acceleration 21–42
  m/s² via `move_toward`, so real acceleration exists to feed physics.
- Animation sources:
  - `authored_motion.gd` retargets Quaternius clips (`Sword_Idle`,
    `Walk_Formal`, `Jog_Fwd`, combo attacks, `Sword_Dash`) onto the VRoid rig
    using **global rest orientations** and an explicit **180° facing
    correction** (source mannequin faces +Z, avatar faces -Z). Idle/walk/dash/
    combat come from here, blended with `slerp` at 14–26/s (no snapping).
  - `player.gd` `_sprint_pose(phase)` layers a procedural phase-based run
    cycle over the authored walk via `sprint_blend` (rate 10/s): thigh swing,
    knee flex hardest mid-swing / near-straight at contact, foot plant, arms
    pumping opposite the legs with bent elbows (z≈±1.05 adducted), pelvis
    yaw/roll, chest counter-rotation, level head.
  - Gait cadence is **velocity-driven**: `gait_rate = max(speed_ratio*9.5,
    clamp(horiz_speed*3.05, 0, 18))`, so stride frequency matches actual ground
    speed (sprint cycles ~1.7× walk; measured walk 9.5 vs sprint 16.5 rad/s).
    This is what removed the "gliding" look — the old cadence saturated at
    walk speed while sprinting.

## 3. Secondary-motion architecture (hair / scarf / cloth)

- `wiggle_physics.gd` wraps the vendored MIT **WiggleBone** addon
  (`addons/wigglebone/wiggle_rotation_modifier_3d.gd`) on every hair/cloth/scarf
  bone at FULL quality. `secondary_motion.gd` (cheap angular springs + skirt
  leg-collision constraint) is the REDUCED fallback.
- Addon model (read from source, L95–175): each bone is a point mass;
  `force = (force_global + gravity) * force_scale - global_velocity *
  linear_scale`; torque `angular_acceleration = _global_direction.cross(force)`;
  the bone direction integrates that torque, then an **analytic undamped
  spring** pulls it back to the animated pose and velocity decays by
  `exp(-angular_damp*dt)`. So damping ratio is `zeta = angular_damp /
  (TAU*spring_freq)` — our config derives damping from frequency to hit target
  zetas (hair ≈0.18 underdamped/whippy, scarf ≈0.42 fluttery, cloth ≈0.51).
- **Root cause of the "hair blows forward" bug**: the torque deflects the
  chain *along the force vector* (measured empirically: with `force_global`
  along `+facing`, the deepest hair tip's `_global_direction.dot(facing)` was
  **+0.633** — CI run 45743924686). Therefore the wind force must be
  `-facing` (backward). Commit `a9daaa7` restored that, strengthened the breeze
  (`5.5*speed + 18*sprint`) and cut up-lift so hair doesn't cover the face.
  `tests/wiggle_physics.gd` now asserts `dot(facing) < 0` for the deepest hair
  AND scarf bone while sprinting, so the sign can never silently regress.
- Wind is **velocity/facing-aware**, not a hard-coded world direction:
  `back = -facing` (or `-velocity.normalized()` while moving — see this
  branch's update), plus a small up-lift and a stride-frequency lateral sway
  (`right*sin(gait_phase)`) so cloth keeps fluttering at *constant* speed (the
  springs alone are acceleration-driven and would go still at steady state).
  Acceleration/deceleration/turns come from the addon's `linear_scale` term
  (real bone acceleration) — hair lags on starts and swings forward on stops,
  which `tests/secondary_inertia.gd` asserts.

## 4. Sword and hand

- Sword is attached with a `BoneAttachment3D` on `J_Bip_R_Hand`; the grip node
  sits at the hand origin, blade along -Y. Fingers are curled around the
  handle (`_pose_gripping_fingers`). Attachment cannot slide or float.
- While moving, the grip tilts outward/down (+30° z at walk, +12° more at
  sprint) so the blade clears scarf/sleeve/legs; this branch adds a small
  inertia wobble (pitch from forward acceleration, yaw from turn lean).
- Combat uses the authored combo clips through the same retarget, so attack
  poses and the sword arc stay coordinated.

## 5. Performance (Galaxy M21 / Mali-G72 target)

- One skeleton, no extra bones, no cloth sim: WiggleBone integrates ~44 spring
  bones per physics frame (a handful of vector ops each), `secondary_motion`
  runs only at REDUCED quality and substeps at ≤1/60 s with `MAX_DT=0.1`.
- Quality setting (0/1/2) is honored: FULL = WiggleBone, REDUCED = root chains
  only via springs, OFF = none; `player.set_physics_quality` routes live.
- No per-frame allocations in the hot path; CI publishes a software-rendered
  perf report annotation every run (draw calls, frame time) for before/after
  comparison.

## 6. Problem → cause → fix map

| Reported problem | Root cause (verified) | Fix |
|---|---|---|
| Sprint looks stiff/exaggerated | static pose overlay, arms spread z≈0 in T-pose rest, cadence saturated at walk | phase-based `_sprint_pose`, arms adducted z≈±1.05, velocity-driven gait (`746e390`, `bd711ce`) |
| Gliding over the floor | gait_rate capped by speed_ratio which saturates at walk speed | `gait_rate` from real horizontal speed (`746e390`) |
| Hair/scarf blow FORWARD while running | wind force along +facing; addon deflects chains along the force (measured dot=+0.633) | wind = `-facing`, stronger breeze, less lift (`a9daaa7`) + regression test |
| Scarf not fabric-like | scarf used cloth tuning (overdamped, stiff) | dedicated scarf tuning: freq 3.8, zeta≈0.42, span 30°, force_scale 260 (`dea9abb`) |
| Sword feels disconnected | rigid grip, clipped scarf while running | BoneAttachment grip, curled fingers, outward tilt while moving + inertia wobble (this branch) |
| No weight/momentum | flat root height, upright torso | 2-per-stride CoM bob, sprint lean, accel/decel lean from real acceleration (this branch) |

## 7. Master rework round 2 (commits ee8a8ee..52aeda2)

Changes in `player.gd` / `world.gd` / CI, all verified by the green run
`45752760018` @ `52aeda2` (10/10 headless suites):

- **Velocity-aware wind**: the cloth/hair breeze now opposes the *actual
  horizontal velocity* while moving (`-velocity.normalized()`), falling back to
  `-facing` — backward and strafing runs trail correctly, and sharp turns re-
  trail along the new direction. Breeze strengthened to `7*speed + 26*sprint`
  so the deeper torso lean cannot let the hair equilibrium drift forward.
- **Momentum lean**: `accel_lean` is measured from real velocity change
  (clamped ±30 m/s²) and adds forward lean on acceleration / slight backward
  lean on deceleration, on top of the sprint lean (-0.16 -> -0.20).
- **Sprint biomechanics**: bigger arm pump (0.46 -> 0.50 rad), deeper hip
  pitch (0.30 -> 0.34), spine pitch coupled to the stride, and a new
  `J_Bip_C_UpperChest` counter-rotation so the shoulder line opposes the pelvis.
  `tests/sprint_cycle.gd` still asserts: arms adducted down, elbows bent
  0.95-1.50 rad, arm/leg opposition, seamless loop, J_Bip-only writes.
- **Sword inertia**: the grip gets a small pitch wobble from `accel_lean` and a
  yaw wobble from `turn_lean` on top of the existing move tilt — the blade now
  lags the hand slightly instead of being rigid; attachment unchanged
  (BoneAttachment3D on `J_Bip_R_Hand`).
- **New test `tests/secondary_inertia.gd`** (measured @ 52aeda2):
  accel from idle -> hair tip whips to dot=-0.99 then settles at -0.13
  (follow-through overshoot, trails backward); stop -> swings forward to
  dot=+0.96 past rest (+0.26) then settles (swing 0.027 rad, no freeze);
  90° turn while sprinting -> hair -0.32 / scarf -0.55 relative to the NEW
  facing (re-trails correctly); scarf trails at steady sprint (-0.21).
- **CI**: headless tests now run in a loop with per-test exit codes and log
  tails in the Diagnostics annotation (one failure no longer hides the rest);
  new `sprint-three-quarter` capture (front-right 3/4 view); preview steps
  split so the 10-annotation/step cap no longer drops `sprint-decel`.
- **Captures** (check-run annotations of run 45752760018, kept in
  `previews/`): `new-sprint-front/side/rear/three-quarter.gif`,
  `new-sprint-accel.gif`, `new-sprint-decel.gif`, `new-authored-sprint.gif`,
  plus `old-authored-sprint.gif` (pre-rework `5b1f953`) and the stacked
  `comparison-sprint.gif` (before top / after bottom).
