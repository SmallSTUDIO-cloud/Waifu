# Scarlet Veil native 3D milestone

A Godot 4.4.1 GDScript 3D combat test, independent of the earlier 2D WebView prototype. The player is a rigged third-party CC0 glTF character; the arena, enemy meshes and sword are blockout assets. Move with WASD or the on-screen joystick, attack with J or ATTACK, dodge with Space or DODGE. Four enemies have a chase/windup/attack loop; attacks do real 3D distance and directional checks and the player has dodge invulnerability. Desktop Esc and the pause button open the pause menu.

The character currently has procedural skeletal limb poses plus a bounded damped spring applied to some secondary bones. It is an early approximation, **not** a validated realistic jiggle or VRM spring-bone system. Animation, camera, AI, content, visuals, audio, optimization and device compatibility are not production-ready. See `ASSET_LICENSES.md` for the temporary model.

To run locally, install Godot 4.4.1 and open this folder as a project. Headless smoke check after importing:

```sh
godot --headless --path native3d --editor --import --quit
godot --headless --path native3d --script res://tests/smoke.gd
```

## Android test status

The `v0.3.1-native3d` debug APK was installed and rendered the actual 3D encounter in an API 30 x86_64 emulator using ANGLE software rendering (CI run 44925419191). This verifies startup and a visible frame, not mobile touch gameplay, sustained frame rate, or compatibility on a physical device. The screenshot showed placeholder visuals and the player taking damage from enemies. A previous emulator configuration using `swiftshader_indirect` produced a blank screen and Godot shader-linking errors; the emulator workflow uses `swangle_indirect` instead. Real Android GPU and device testing remains required, as do production signing and art/animation/physics work.
