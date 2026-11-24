# 3D asset provenance

`assets/avatar.glb` is an unmodified byte-for-byte copy of VRoid Studio's `HairSample_Female.vrm` (VRM 0 / glTF 2.0), renamed to `.glb` for Godot's glTF importer. This is a **temporary, third-party test character**, not the original Scarlet Veil character. The model embeds `licenseName: CC0` and `title: HairSample_Female` in its VRM metadata.

* Source: https://github.com/madjin/vrm-samples/blob/master/vroid/beta/HairSample_Female.vrm (Git blob `0e5235f9a7972fbcbceb74960479b208c27a8707`).
* Original publisher: pixiv Inc. / VRoid Studio. Official license description lists `HairSample_Female` among CC0 models: https://vroid.pixiv.help/hc/en-us/articles/4402614652569-Do-VRoid-Studio-s-sample-models-come-with-conditions-of-use
* https://creativecommons.org/publicdomain/zero/1.0/

Godot's generic glTF importer does not implement the model's VRM material, humanoid, or spring-bone extensions. The game currently applies a small procedural bone spring as an experiment; it is not a complete VRM physics implementation. Final production assets require original art, optimized geometry, properly authored animations, material review and device profiling.

## Authored motion prototype

`assets/quaternius-motion.glb` derives from Quaternius's **Universal Animation Library (Standard)**, which is [CC0](https://quaternius.com/packs/universalanimationlibrary.html). Source used: `Godot/AnimationLibrary_Godot_Standard.glb` mirrored as `ual1_rigify.glb` in [aether-lang-dev/ae3d](https://github.com/aether-lang-dev/ae3d/tree/main/tests/fixtures/people), original SHA-256 `1b7bf67866360665426bb99e4c71bd619f19b408453c24e30f0c3071601eee5c`. The reduced file retains five motion clips and the source skeleton; unrelated clips, unused tracks and the mannequin mesh were removed. Authored animations by Quaternius. They are retargeted to the separate VRoid character at runtime.

The requested [Samurai Girl](https://sketchfab.com/3d-models/samurai-girl-5a0925bfa4464f6aa33d9dbf53de33f2) by Artical is **not** included: the page says it is not downloadable, its model creator does not own the character design, and it carries a NoAI notice. No permission to use the model or underlying design has been established.

To rebuild the trimmed motion asset, obtain the mirrored source file and verify its SHA-256 above, install `@gltf-transform/core@4.5.1` and `@gltf-transform/functions@4.5.1`, then run `node native3d/tools/reduce-motion.mjs SOURCE.glb OUTPUT.glb` and `python3 native3d/tools/repack-motion.py OUTPUT.glb`. The tiny dummy skinned triangle keeps the source rig importable, and is not rendered.

## Quaternius Universal Animation Library 2 — combo motion

`assets/quaternius-combo.glb` is a trimmed rotation/hip-track subset of Quaternius Universal Animation Library 2 (CC0 1.0): Sword_Dash, Sword_Light_A, Sword_Light_B, Sword_Heavy_B and Sword_Heavy_C. Original pack and license: https://quaternius.com/packs/universalanimationlibrary2.html. Source used: https://github.com/tilakpatell/tilakverse-assets, commit `85064399bbdacc0e8cc50807179490314bc4ff1c`, path `quaternius/universal-animation-library-2/Unreal-Godot/UAL2.glb`, Git blob `e6add803561a0491cd0b8db8b1dc75dc77b3bee1`, SHA-256 `ad3ae049c7d3d4846133b59dba6218fdabebe05d3aec646caef6665f6c540684`. Reduced with `tools/reduce-combo.mjs` and `tools/repack-motion.py`. Original mannequin geometry is replaced by a non-rendered placeholder; character mesh is unchanged. Retargeting and strike timing remain subject to visual and device testing.

## Polygonal Mind trash-polka Robot — enemy robots

`assets/enemy-robot.glb` is a copy of the CC0 1.0 "Robot" model by Polygonal Mind (trash polka project), converted to GLB with `@gltf-transform copy` (no geometry changes). Source: https://github.com/ToxSam/cc0-models-Polygonal-Mind (repository license CC0-1.0), path `projects/trash-polka/Robot.glb`, Git blob `8726a4304c5777d93476d59b9786ed44219c9797`, source SHA-256 `01c8fdf80c6792f70c7167b4408fbbb645e9ab5b41076ad748c1020d1a8699`, shipped GLB SHA-256 `9d2608b1130276ca4de9386de4a7b0294f6fe91c5ff27b8e7cc3c007310f4fc8`. One model is tinted per combat role at runtime; the character mesh is unchanged.

## WiggleBone addon (MIT)
- `native3d/addons/wigglebone/` — detomon/wigglebone v3.0.1 (MIT), https://github.com/detomon/wigglebone — SkeletonModifier3D-based jiggle physics used for hair/skirt/sleeve chains at PHYSICS quality FULL. Runtime files only (editor plugin/gizmos omitted); LICENSE included.
