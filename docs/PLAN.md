# Scarlet Veil — vertical slice plan

## Goal
Validate whether a mobile player can read an enemy wind-up, close distance, chain sword strikes and dodge on a compact screen. This repository started empty; this is a browser-playable 2D combat prototype, not a completed 3D action RPG.

## Sequence
1. Establish an original visual direction and character concept, using the supplied images only as stylistic references.
2. Build one responsive rooftop encounter with touch and keyboard input, telegraphed opponents, combo attacks, dodge invulnerability, a charged skill, victory and defeat.
3. Add responsive feedback, synthesized placeholder sound and an original looping motif; pause when the page is hidden.
4. Build, test core logic and inspect desktop/mobile screenshots. Keep performance bounded by a capped pixel ratio and bounded effects.
5. Package a reproducible static web build and document what is and isn't production-ready.

## Design research
Genshin Impact's combat emphasizes combining elements; Punishing: Gray Raven centers on quick dodges, character switching and colored signal skills. This prototype borrows the broad lessons of readable action and timed evasion, not their characters, assets, exact combat systems or economy. Sources: https://genshin.gg/elements/ and https://cosm-game.com/games/punishing-gray-raven/.

## Production gates after the prototype
* Author and review original rigged 3D characters, facial animation, outfits and physically plausible secondary motion in a DCC. No character model, skinning or jiggle physics is included here.
* Build the full 3D camera, animation state machines, collision, progression, team switching, original story and ethical, transparent gacha economy; none are represented by the prototype as complete systems.
* Establish Android/iOS native packaging, device-specific frame-time budgets, GPU profiling, actual LODs and frustum/occlusion culling. The present 2D canvas does not need 3D LOD or frustum culling.
* Replace synthesized placeholder sounds and concept images with approved production assets, verify rights, optimize and test on actual mobile devices, and run accessibility, security and store-compliance reviews.

## Art provenance
`public/art/veil-keyart.png`, `public/art/arena.png` and `art-source/fighter-source.png` were generated for this prototype. `fighter.png` is a green-screen extraction from the source. The supplied reference images are not distributed. These are concept/prototype assets and require art-direction and rights review before commercial release.

## Verification and open issues
* Ran the unit tests and production build. In headless Chromium, inspected the title and battle at desktop and landscape phone sizes, tested attacks/energy, pause/resume and the portrait rotation prompt.
* The first screenshot exposed a green fringe on the extracted fighter; the alpha key and green spill were corrected. Portrait combat is intentionally paused behind a rotate prompt rather than distorted.
* The battle character is a static cutout with lightweight motion, and the enemies are procedural placeholder shapes. The synthesized motif and cues are placeholders, not a produced theme song or recorded character voices. There is no jump or jump/idle voice audio.
* No physical-device performance, touch ergonomics, store compliance, visual-art approval or long-session playtest has yet been performed. No frame-rate guarantee is made.

## Android test packaging
The Android package is a debug-signed WebView wrapper around the same 2D prototype, with bundled assets served from an intercepted local HTTPS origin and other network requests blocked. It is not a native 3D game. GitHub Actions compiles the assets and APK. A physical Android device and Play Store signing/compliance review are still required; this test APK is not a production release.
