extends SceneTree

func _initialize() -> void:
    call_deferred("run_test")

func fail(message: String) -> void:
    printerr("FAIL: ", message)
    quit(1)

func active_effects() -> Array[Node]:
    return get_nodes_in_group("combat_effects").filter(func(n): return not n.is_queued_for_deletion())

func run_test() -> void:
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var player = scene.player
    var sim = player.secondary_motion
    var kinds = {}
    for joint in sim.joints: kinds[joint.kind] = true
    for kind in ["hair", "skirt", "sleeve"]:
        if not kinds.has(kind):
            fail("missing secondary category " + kind)
            return
    for joint in sim.joints:
        if "Bust" in player.skeleton.get_bone_name(joint.bone):
            fail("anatomy bone must not be simulated")
            return
    sim.reset()
    sim.update(1.0 / 60.0)
    player.model_root.position.x += 0.08
    sim.update(1.0 / 60.0)
    var moved = false
    for joint in sim.joints:
        if absf(joint.z.angle) > 0.00001: moved = true
        if absf(joint.x.angle) > joint.limit or absf(joint.z.angle) > joint.limit:
            fail("secondary joint outside bound")
            return
    if not moved:
        fail("secondary motion did not react to acceleration")
        return
    for i in range(20): sim.update(1.0 / 15.0)
    sim.update(1.0) # Long stalls must remain bounded.
    for joint in sim.joints:
        if not is_finite(joint.x.angle) or not is_finite(joint.z.angle) or absf(joint.x.angle) > joint.limit or absf(joint.z.angle) > joint.limit:
            fail("secondary motion unstable after a long frame")
            return
    sim.reset()
    for joint in sim.joints:
        if absf(joint.x.angle) > 0.000001 or absf(joint.z.angle) > 0.000001:
            fail("secondary reset")
            return
    var hand = player.skeleton.find_bone("J_Bip_R_Hand")
    var middle = player.skeleton.find_bone("J_Bip_R_Middle1")
    var hand_pos = (player.skeleton.global_transform * player.skeleton.get_bone_global_pose(hand)).origin
    if player.sword_grip.global_position.distance_to(hand_pos) > 0.12:
        fail("sword not attached near right hand")
        return
    if absf(player.skeleton.get_bone_pose_rotation(middle).dot(player.bone_rest[middle])) > 0.99:
        fail("gripping fingers did not curl")
        return
    scene._swing_vfx(1)
    if active_effects().size() != 1:
        fail("first swing effect count")
        return
    scene._swing_vfx(2)
    if active_effects().size() != 3:
        fail("second combo should add a second arc")
        return
    scene._swing_vfx(3)
    if active_effects().size() != 6:
        fail("finisher should add arc, echo and shockwave")
        return
    scene._swing_vfx(4)
    if active_effects().size() != 10:
        fail("fourth hit should add the heavy vertical cleave")
        return
    for i in range(20): scene._swing_vfx(4)
    if active_effects().size() > 12:
        fail("transient VFX budget exceeded")
        return
    print("PASS secondary motion, bounded combo VFX, sword grip")
    quit(0)
