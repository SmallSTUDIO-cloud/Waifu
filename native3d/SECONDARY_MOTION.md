# Secondary motion: implementation and validation plan

## Scope and inspection

Godot 4.4.1, GL Compatibility, native Android export. The existing CC0 avatar and its skeleton remain unchanged. Inspection of the imported avatar's skeleton found 16 hair joints, 18 skirt joints and 4 sleeve joints (excluding end markers), plus four bust joints which are **not simulated**. The avatar has no independent ribbon, bow or accessory bones; only explicitly named `J_Sec_` accessory joints would be eligible on a compatible future rig. No accessory was invented or attached to the existing model.

## Solver

Each eligible joint uses two reused damped angular spring objects. Per-joint parent translation, velocity, filtered acceleration and gravity direction drive bounded local angular offsets, with small deterministic parameter differences across chains. Solver steps are capped at 1/60 s, long stalls and teleports reset velocity inputs, and damping settles the motion. Secondary rotation is composed after the authored retarget and does not alter its source rig. Hair, skirt and sleeve limits are intentionally small to retain the original silhouette and coverage; bust bones are excluded. The system does not modify base walking, attack or dodge clips and has no separate jump or run gameplay state to test in this prototype.

Skirt child-bone tips are checked against four approximate upper/lower-leg capsules. If an animated rest tip is already inside the proxy it is left alone; otherwise the spring's rotation is limited by binary search before a sampled tip enters a capsule. This is **not mesh collision**: vertices between tips, existing authored-pose penetration, large step crossings and skirt topology may still clip. Reliable cloth/leg collision and outfit coverage require artist-authored collision proxies, skinning review and tests across animations on the final rig.

`secondary_motion/quality` in `project.godot` or `player.secondary_motion.set_quality(level)` accepts 0 (off), 1 (root joints only), 2 (all eligible joints, default). Switching resets spring state. No GUI setting yet. The shadow-dodge's separate reusable avatar instance remains a notable render and memory cost outside this solver.

## Validation

Headless category tests check separate hair/skirt/sleeve acceleration response, bounds, settling, long stalls, animation ownership, leg-proxy math, quality switching and exclusion of bust joints; the combat and authored-retarget tests remain in CI. Software-rendered before/after move, combo and dodge previews permit a qualitative comparison. The visible difference may be subtle at gameplay camera scale; no claim of animator-quality movement or zero clipping is made.

The manual `Native Android emulator smoke` workflow builds a private debug APK from the checked-out commit, starts it in API 30 x86_64 Android with software ANGLE, exercises input and captures an image and Android `gfxinfo` data. It **does not publish an APK**. Emulator software rendering and debug builds cannot establish sustained 60 FPS, GPU cost, real mobile touch behavior or battery/thermal performance. For acceptance, profile the same representative walk/attack/dodge sequence at each quality level on physical low/mid/high Android devices, record build/OS/device/GPU and median/p95/p99 frame times, warm up, run several minutes and inspect clipping and coverage from multiple angles.
