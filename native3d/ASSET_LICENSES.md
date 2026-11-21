# 3D asset provenance

`assets/avatar.glb` is an unmodified byte-for-byte copy of VRoid Studio's `HairSample_Female.vrm` (VRM 0 / glTF 2.0), renamed to `.glb` for Godot's glTF importer. This is a **temporary, third-party test character**, not the original Scarlet Veil character. The model embeds `licenseName: CC0` and `title: HairSample_Female` in its VRM metadata.

* Source: https://github.com/madjin/vrm-samples/blob/master/vroid/beta/HairSample_Female.vrm (Git blob `0e5235f9a7972fbcbceb74960479b208c27a8707`).
* Original publisher: pixiv Inc. / VRoid Studio. Official license description lists `HairSample_Female` among CC0 models: https://vroid.pixiv.help/hc/en-us/articles/4402614652569-Do-VRoid-Studio-s-sample-models-come-with-conditions-of-use
* https://creativecommons.org/publicdomain/zero/1.0/

Godot's generic glTF importer does not implement the model's VRM material, humanoid, or spring-bone extensions. The game currently applies a small procedural bone spring as an experiment; it is not a complete VRM physics implementation. Final production assets require original art, optimized geometry, properly authored animations, material review and device profiling.
