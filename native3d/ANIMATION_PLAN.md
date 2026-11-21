# Animation iteration: research and acceptance plan

The earlier sine-wave rig animation is a blockout, not a substitute for authored motion. This pass tests a small, CC0 Quaternius clip set on the existing CC0 VRoid test model; the requested Artical/D-pin model is not included. Artical says on the model page that the work is not downloadable and they do not own the character design. It is also marked NoAI. Permission and a legitimately supplied model are needed before using it.

## Principles to apply

1. Design the silhouette and timing around contact, weight absorption, passing and push-off. Feet should appear planted during support; shoulders and pelvis counter-rotate. Keep the gait cycle aligned with actual travel speed. A small idle breath should not look like a constant bounce.
2. Anticipation, a readable strike, and follow-through/recovery must correspond to the gameplay hit window. Player input, facing and weapon grip need to stay consistent through a dodge or combo transition.
3. Use authored, retargeted animation as the base rather than stacking procedural bone rotations over it. Map both humanoid skeletons and reconcile their rest orientations; don't copy identically named local rotations blindly. Keep secondary springs as a separate layer.
4. Inspect looping motion from gameplay and close cameras, both in-place and moving. Check feet, hand/sword contact, clipping, pose transitions, action timing and silhouette. Visual review is not a substitute for physical-device testing or an animator's polish.

References: [Godot 4.4 skeleton retargeting](https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/retargeting_3d_skeletons.html), [Godot AnimationTree](https://docs.godotengine.org/en/4.4/tutorials/animation/animation_tree.html), [walk cycle contact/weight/counter-rotation](https://mocaponline.com/blogs/mocap-news/walk-cycle-animation), and [Quaternius Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html).

## Delivery / limitations

Pilot clips and retargeting on the current avatar, verify mapping and animation state changes in tests, and capture moving previews for review before replacing the old motion. Do not release an APK. The requested model needs rights and files; the current placeholder's dress and long sleeves may obscure motion. A final result needs art direction, authored sword-specific clips, foot-lock cleanup, and phone performance testing.
