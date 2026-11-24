# Sprint animation rework

Branch `arena/175fcd9f-waifu`, commits `746e390` + `6f94981` + `7bfbe93` (+ follow-ups).
All changes are in `native3d/scripts/player.gd`, `native3d/scripts/world.gd`,
`native3d/tests/sprint_cycle.gd`, `.github/workflows/native-3d.yml`.

## Root causes found (inspection)

- Movement is code-driven (`CharacterBody3D.velocity` + `move_and_slide`, no root
  motion). The old gait advanced at `speed_ratio * 12.5`, but `speed_ratio`
  saturates at `SPEED` (2.8 m/s) while sprint runs at 5.4 m/s, so the stride
  cycled at walk cadence during a sprint -> feet slid over the ground ("gliding").
- `_sprint_pose` was a static exaggerated overlay: arms spread to z +/-0.30 rad
  with elbows locked at 1.30, hips pitched 0.34 with almost no gait coupling,
  legs a pure sinusoid with no contact/push-off/airborne phases, root lean 0.26
  plus chest pitch stacked on top.

## What changed

`player.gd`:
- `gait_rate = maxf(speed_ratio * 9.5, clampf(horiz_speed * 3.05, 0, 18))` —
  cadence follows real ground speed, so sprint strides cycle ~1.7x faster than
  walk (measured: walk_rate 9.5, sprint_rate 16.47 rad/s at 5.4 m/s) and stop at
  idle. Still no root motion; animation follows velocity.
- `_sprint_pose(phase)` rebuilt as a phase-based run cycle (left foot plants at
  phase 0): thigh swing `0.72*cos`, knee flex `0.14 + 1.5*max(0,-sin)^1.4`
  (hardest mid-swing, near-straight at contact), foot plant, arms pump
  opposite the legs (`0.5*cos`) with bent elbows (~1.15 rad) and compact path
  (|z| <= 0.10), pelvis yaw/roll `0.05*sin` + counter-pitch, spine/chest
  counter-rotation, head level. Writes only `J_Bip_*` bones — WiggleBone owns
  HairJoint*/J_Sec_* chains, so no double animation (asserted in tests).
- Root lean reduced -0.26 -> -0.16 and a two-per-stride CoM bob
  (`0.05 * (0.5 - 0.5*cos(2*phase)) * sprint_blend`) added for weight.
- Sword grip tilts +12 deg more outward while sprinting (keeps the blade clear
  of the scarf/sleeve during the arm pump).
- The no-motion-driver fallback branch layers the same `_sprint_pose`.

`world.gd` (CI capture only): new preview modes `--preview-sprint-front|side|rear`
(fixed angle cameras on the sprinting hero), `--preview-sprint-accel`
(walk 1.2 s -> full sprint) and `--preview-sprint-decel` (sprint -> stick release),
with HUD/enemies hidden so the transitions are readable.

`tests/sprint_cycle.gd` (new, wired into CI): asserts cadence scales with speed
and stops at idle, sprint pose leaves hair/cloth bones untouched, arm z stays
compact, elbows stay bent, arm swing opposes leg swing, and phase 0 == phase TAU
(seamless loop).

## Verification (CI run 45386279280 @ 7bfbe93, exit 0)

- 10/10 suites PASS, including the new `PASS sprint cycle: velocity-driven
  cadence, clean bone ownership, compact opposite arm pump, bent elbows,
  seamless loop` (`GAIT walk_rate=9.5 sprint_rate=16.47`).
- Perf unchanged: draw_calls 416 (overview) / 662 (gameplay cam), same as
  pre-rework; animation cost is a handful of slerps per frame. All numbers are
  llvmpipe software-rendered CI values, NOT device measurements (no APK built).
- Preview GIFs `sprint-front/side/rear/accel/decel` (annotations of that run,
  saved under `previews/r453862-*`) show a grounded stride from all angles and
  smooth walk->sprint and sprint->idle blends; before/after comparison:
  `previews/before-Animation-authored-sprint.gif` (spread-arm T-pose glide)
  vs `previews/r453862-Animation-sprint-*.gif`.

## Preserved

Hero model/skeleton/attachments, wiggle physics ownership (hair/skirt/sleeve),
sword grip attachment, combat/dodge animations, enemies, HUD, code-driven
movement controller and clamps, quality routing. Mobile-friendly: same rig,
no new layers, no root motion, a few extra slerps only while sprinting.
