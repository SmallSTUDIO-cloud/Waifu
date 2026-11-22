# Physical Android validation protocol (not yet performed)

The automated Android job is a debug x86_64 emulator using ANGLE/SwiftShader. It is not a real-device baseline, and the last recorded emulator numbers are not evidence of 60 FPS on an Android GPU. A physical Android handset and its details are required; no phone is attached to the CI runner. The goal is 16.67 ms/frame on devices capable of 60 Hz, not a promise on every device.

## Prepare a private profiling build

1. On a machine with Godot **4.4.1**, Android SDK/export templates, Java 17 and a connected physical Android device, make a private debug export of this project. Do **not** publish it. Record commit, build type, device model, OS, GPU, refresh rate, resolution, power mode and ambient conditions.
2. Temporarily enable `secondary_motion/profile_debug=true` in a local export copy of `project.godot`; set `profile_warmup=30.0` and `profile_duration=180.0`. This logger is debug-only. Install the private build on the device using local `adb install -r <local-debug.apk>`.
3. For each physics tier **OFF, REDUCED, FULL** and each VFX tier, use the menu controls and restart the encounter. Execute a repeatable 3-minute sequence of walking, stopping, turns, attacks and dodges. Keep the device awake, set brightness and note thermal state. Run at least three trials per tier on the same device, including cooldown periods.
4. Capture `adb logcat -s godot:I | grep SECONDARY_PROFILE` after the sample, plus `adb shell dumpsys meminfo com.smallstudio.scarletveil3d` and `adb shell dumpsys thermalservice` at the start and end. Godot reports wall-frame p50/p95/p99, spring-update CPU time, dark-shadow pose-capture CPU time and Godot static memory. Static memory excludes important native, GPU and OS allocations; use Android meminfo/profilers for actual process memory.
5. Use Android GPU Inspector, Perfetto or an equivalent on-device profiler to capture CPU, GPU and frame timelines. For the dodge shadow specifically, compare controlled private builds with `secondary_motion/profile_shadow_enabled=true` and `false` using the same sequence; the off build does not instantiate the shadow avatar (this switch is debug-only), the built-in timing reports only the pose-copy CPU cost, not mesh memory, rendering cost or GPU time. Record median/p95 and thermal throttling for both. VSync may cap visible headroom; document whether profiling is capped.
6. Film the front, side and rear of the character through walk, stop, attack and dodge. Check dress coverage and visible clipping at normal speed and frame-by-frame. Mark any failed poses with timestamps. Neither bone proxies nor automated tests establish whole-mesh collision safety.

Record all results in a separate device report, including failure cases and whether the 16.67 ms/frame target was met. Do not infer sustained device FPS from emulator or debug-only measurements. Running and jumping are not currently implemented in gameplay; do not mark them as verified.

## Emulator-only comparison (2026-11-22)

Run `44980064667`, debug build, API 30 x86_64, 640×320, ANGLE/SwiftShader; one short scripted trial per tier, 2-second warmup and 10-second total profile window. The table shows measured Godot wall-frame p50/p95 and mean secondary-update CPU cost, not GPU timings:

| Physics tier | p50 frame | p95 frame | Mean secondary update |
| --- | ---: | ---: | ---: |
| Off | 57.31 ms | 104.73 ms | 7.9 µs |
| Reduced | 56.83 ms | 99.54 ms | 460.4 µs |
| Full | 58.93 ms | 118.42 ms | 738.5 µs |

One shadow pose-copy sample per tier was 84, 67 and 68 µs respectively; this does not measure shadow GPU time or duplicated mesh memory. Godot static memory read 33.5 MiB for each, excluding other allocations. These single, short software-rendered debug trials are noisy and not physical-phone or thermal data; they cannot establish the 60 FPS target or a statistically reliable before/after performance comparison. Full mesh coverage and clipping remain unverified on-device. No APK was published.
