# Production roadmap: Scarlet Veil

## Target and current state
Target: a polished, landscape-first Android action RPG with attractive original characters, responsive sword combat and a sustainable content pipeline. Current implementation: an offline, 2D WebView vertical slice. This is not a complete 3D gacha game and is not ready for a commercial launch.

## This iteration: reliable first-session loop
1. Make startup explicit and resilient: preload the assets actually required, show progress and offer retry on failure.
2. Give the player a usable home screen, mission briefing, persistent audio/accessibility settings, pause/resume and meaningful victory history.
3. Protect mobile controls and simulation from interrupted touches, orientation changes, lifecycle transitions, double animation loops and aspect-ratio distortion.
4. Verify save boundaries and core combat logic with unit tests; inspect multiple simulated mobile viewports; build a debug APK in CI. Do not claim physical-device certification.

## Subsequent gates
- Choose a native 3D engine and target device tier; prototype camera, movement, sword hit detection and animation before migrating content.
- Establish original character concept approval, high/low mesh and rig production, animation, materials, secondary-motion constraints, texture budgets and device LOD validation.
- Develop enemy roster, encounters, skill-driven combat, level streaming and content tools. Benchmark CPU/GPU frame times and thermal behavior on representative Android devices.
- Implement account, persistence, live-ops and gacha only after economy design, disclosed odds, privacy, fraud/security, regional age/rating and payment-compliance reviews. No purchase or gacha system is implemented now.
- Commission or license final music, effects and voice; finish localization, accessibility, QA automation, Android signing and store certification.
