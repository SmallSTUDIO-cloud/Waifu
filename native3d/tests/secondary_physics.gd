extends SceneTree

func _initialize() -> void:
    call_deferred("run_test")

func fail(message: String) -> void:
    printerr("FAIL secondary: ", message)
    quit(1)

func run_test() -> void:
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var player = scene.player
    var sim = player.secondary_motion
    var kinds = {}
    for joint in sim.joints:
        kinds[joint.kind] = int(kinds.get(joint.kind, 0)) + 1
        if "Bust" in player.skeleton.get_bone_name(joint.bone):
            fail("body anatomy must not be simulated")
            return
    for category in ["hair", "skirt", "sleeve"]:
        if not kinds.has(category):
            fail("missing " + category)
            return
    print("Secondary bone categories ", kinds, " leg capsules ", sim.leg_pairs.size())
    if sim.leg_pairs.size() != 4 or absf(sim._segment_distance(Vector3(1, 0, 0), Vector3.ZERO, Vector3.UP) - 1.0) > 0.0001:
        fail("leg proxy setup or distance")
        return
    sim.reset()
    sim.update(1.0 / 60.0)
    # Drive every category through an identical acceleration, then check
    # response, bound and settling individually rather than as one aggregate.
    for i in range(12):
        player.model_root.position.x += 0.004 * float(i + 1)
        sim.update(1.0 / 60.0)
    var peaks = {}
    for joint in sim.joints:
        var magnitude = maxf(absf(joint.x.angle), absf(joint.z.angle))
        peaks[joint.kind] = maxf(float(peaks.get(joint.kind, 0.0)), magnitude)
        if magnitude > joint.limit + 0.000001 or not is_finite(magnitude):
            fail("unbounded " + joint.kind)
            return
    for category in ["hair", "skirt", "sleeve"]:
        if float(peaks.get(category, 0.0)) < 0.00001:
            fail("no response: " + category)
            return
    for i in range(240): sim.update(1.0 / 60.0)
    for joint in sim.joints:
        if maxf(absf(joint.x.angle), absf(joint.z.angle)) > 0.002:
            fail("failed to settle: " + joint.kind)
            return
    sim.update(1.0) # Stall must not inject unbounded force.
    for joint in sim.joints:
        if not is_finite(joint.x.angle) or absf(joint.x.angle) > joint.limit:
            fail("stall stability")
            return
    # An externally authored local pose must remain the base when physics resets.
    sim.reset()
    var j = sim.joints[0]
    var animated = (j.rest as Quaternion) * Quaternion(Vector3.RIGHT, 0.2)
    player.skeleton.set_bone_pose_rotation(j.bone, animated)
    sim.update(1.0 / 60.0)
    sim.reset()
    if absf(player.skeleton.get_bone_pose_rotation(j.bone).dot(animated)) < 0.99999:
        fail("secondary reset overwrote animated pose")
        return
    # Restore test bone before comparing modes.
    player.skeleton.set_bone_pose_rotation(j.bone, j.rest)
    sim.set_quality(1)
    sim.update(1.0 / 60.0)
    player.model_root.position.x += 0.04
    sim.update(1.0 / 60.0)
    var low_active = 0
    for joint in sim.joints:
        if absf(joint.z.angle) > 0.000001:
            low_active += 1
            if not joint.root:
                fail("low mode simulated non-root joint")
                return
    if low_active == 0 or low_active >= sim.joints.size():
        fail("quality did not reduce work")
        return
    sim.set_quality(0)
    player.model_root.position.x += 0.03
    sim.update(1.0 / 60.0)
    for joint in sim.joints:
        if absf(joint.x.angle) > 0.000001 or absf(joint.z.angle) > 0.000001:
            fail("off mode did not reset springs")
            return
    sim.set_quality(2)
    # Synthetic known geometry: rotating the cloth tip by 45 degrees would
    # enter a vertical capsule at (sqrt(.5), sqrt(.5)); it must be limited.
    var rig = Skeleton3D.new()
    root.add_child(rig)
    for name in ["root", "J_Sec_L_SkirtSide0", "J_Sec_L_SkirtSide0_end", "J_Bip_L_UpperLeg", "J_Bip_L_LowerLeg"]: rig.add_bone(name)
    rig.set_bone_parent(1, 0); rig.set_bone_parent(2, 1); rig.set_bone_parent(3, 0); rig.set_bone_parent(4, 3)
    rig.set_bone_rest(2, Transform3D(Basis.IDENTITY, Vector3(1, 0, 0)))
    rig.set_bone_rest(3, Transform3D(Basis.IDENTITY, Vector3(sqrt(0.5), sqrt(0.5), -0.5)))
    rig.set_bone_rest(4, Transform3D(Basis.IDENTITY, Vector3(0, 0, 1)))
    rig.reset_bone_poses()
    var probe = load("res://scripts/secondary_motion.gd").new()
    probe.setup(rig)
    var cloth = probe.joints[0]
    var base = Quaternion.IDENTITY
    var desired = Quaternion(Vector3.FORWARD, PI / 4.0)
    var constrained = probe._constrain_skirt(cloth, base, desired)
    var tip = probe._tip_position(cloth, constrained, rig.get_bone_global_pose(0))
    var a = rig.get_bone_global_pose(3).origin
    var b = rig.get_bone_global_pose(4).origin
    if probe._segment_distance(tip, a, b) < probe.LEG_RADIUS - 0.001 or absf(constrained.dot(desired)) > 0.99999:
        fail("skirt tip was not constrained against leg proxy")
        return
    rig.queue_free()
    print("PASS secondary categories, bounds, settle, animation ownership, capsule math, quality modes")
    quit(0)
