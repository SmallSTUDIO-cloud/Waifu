# 3D asset provenance

`assets/avatar.glb` is an unmodified byte-for-byte copy of VRoid Studio's `HairSample_Female.vrm` (VRM 0 / glTF 2.0), renamed to `.glb` for Godot's glTF importer. This is a **temporary, third-party test character**, not the original Scarlet Veil character. The model embeds `licenseName: CC0` and `title: HairSample_Female` in its VRM metadata.

* Source: https://github.com/madjin/vrm-samples/blob/master/vroid/beta/HairSample_Female.vrm (Git blob `0e5235f9a7972fbcbceb74960479b208c27a8707`).
* Original publisher: pixiv Inc. / VRoid Studio. Official license description lists `HairSample_Female` among CC0 models: https://vroid.pixiv.help/hc/en-us/articles/4402614652569-Do-VRoid-Studio-s-sample-models-come-with-conditions-of-use
* https://creativecommons.org/publicdomain/zero/1.0/

Godot's generic glTF importer does not implement the model's VRM material, humanoid, or spring-bone extensions. The game currently applies a small procedural bone spring as an experiment; it is not a complete VRM physics implementation. Final production assets require original art, optimized geometry, properly authored animations, material review and device profiling.

## Authored motion prototype

`assets/quaternius-motion.glb` derives from Quaternius's **Universal Animation Library (Standard)**, which is [CC0](https://quaternius.com/packs/universalanimationlibrary.html). Source used: `Godot/AnimationLibrary_Godot_Standard.glb` mirrored as `ual1_rigify.glb` in [aether-lang-dev/ae3d](https://github.com/aether-lang-dev/ae3d/tree/main/tests/fixtures/people), original SHA-256 `1b7bf67866360665426bb99e4c71bd619f19b408453c24e30f0c3071601eee5c`. The reduced file retains five motion clips and the source skeleton; unrelated clips, unused tracks and the mannequin mesh were removed. Authored animations by Quaternius. They are retargeted to the separate VRoid character at runtime.

The requested [Samurai Girl](https://sketchfab.com/3d-models/samurai-girl-5a0925bfa4464f6aa33d9dbf53de33f2) by Artical is **not** included: the page says it is not downloadable, its model creator does not own the character design, and it carries a NoAI notice. No permission to use the model or underlying design has been established.
