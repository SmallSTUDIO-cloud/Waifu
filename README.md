# Scarlet Veil

A mobile-first **2D combat prototype** for an original anime action RPG. Fight six rooftop sentinels with sword combos, a timed dodge and an area skill. The concept art and synthesized music/SFX are prototype assets.

## Android test APK

The Android prerelease contains `scarlet-veil-android-test.apk`. Download it from the [GitHub releases page](https://github.com/SmallSTUDIO-cloud/Waifu/releases), open it on an Android 6.0+ device and allow installation from your browser or file manager if prompted. It runs in landscape. Attack, dodge and skill buttons are on the right; move using the left joystick. Tap the music button to mute. Back pauses the fight, returns to the title from a paused screen, or exits from the title.

The APK is an **offline Android WebView wrapper around the 2D prototype**, not the full native 3D game. It is signed with an automatically generated debug key for testing, not production or Play Store distribution. Later debug builds may use a different signing key and require uninstalling the old test app before installation. It has not yet been verified on a physical device.

## Build from source

Requirements: Node.js 20.19+ or 22.12+, Java 17, Gradle 8.9, Android SDK platform 35 and matching build tools. With the Android SDK configured:

```sh
npm ci
npm test
npm run build
mkdir -p android/app/src/main/assets/web
cp -R dist/. android/app/src/main/assets/web/
gradle -p android assembleDebug
```

The test APK will be at `android/app/build/outputs/apk/debug/app-debug.apk`. GitHub Actions builds and publishes an APK artifact on each push; the Android prerelease contains the installable APK. The bundled frontend is compiled as an internal build step, not a separate web release.

For development on a computer, `npm run dev` runs the same prototype. Keyboard controls: **WASD / arrow keys** move, **J / Enter** attacks, **Space / K** dodges, **E** uses a fully charged skill, and **Esc** pauses.

## Scope and roadmap

This is a small vertical slice, **not** a complete gacha game or a 3D character showcase. There are no 3D models, rigging, jiggle physics, character switching, gacha, account backend, or iOS build. The canvas uses capped device pixel ratio, bounded particles, and page-visibility pausing; 3D LOD and frustum culling do not apply to this 2D prototype. See [the plan](docs/PLAN.md) for research, asset provenance and production gates.
