# Scarlet Veil

A mobile-first **2D browser combat prototype** for an original anime action RPG. Fight six rooftop sentinels with sword combos, a timed dodge and an area skill. The generated concept art and synthesized music/SFX are placeholders, not production game assets.

## Run

Requires Node.js 20.19+ or 22.12+.

```sh
npm ci
npm run dev
```

Open the local URL printed by Vite. On mobile, use the joystick and action buttons; landscape is recommended. On desktop, use **WASD / arrow keys** to move, **J / Enter** to attack, **Space / K** to dodge, **E** to use a fully charged skill, and **Esc** to pause. Audio starts after the first interaction and can be muted in the HUD.

```sh
npm test
npm run build
npm run preview
```

The static build is produced in `dist/`; serve it from the root of an HTTP server. CI builds and uploads this folder as an artifact.

## Scope and roadmap

This is a small vertical slice, **not** a complete gacha game, a native mobile app, or a 3D character showcase. There are no 3D models, rigging, jiggle physics, character switching, gacha, account backend, or native Android/iOS builds. The canvas uses capped device pixel ratio, bounded particles, and page-visibility pausing; 3D LOD and frustum culling do not apply to this 2D prototype. See [the plan](docs/PLAN.md) for research, asset provenance and production gates.
