extends SceneTree

# Sprint rework invariants:
#  1. gait cadence follows actual ground speed (sprint strides faster than
#     walk instead of saturating at walk cadence -> no foot sliding),
#  2. the sprint pose writes only J_Bip_* body bones (WiggleBone owns the
#     hair/skirt/sleeve chains, so no double animation),
#  3. arms stay compact (no spread) with bent elbows and pump opposite to
#     the legs, and the stride loops seamlessly.

func _fail(msg: String) -> void:
    printerr("FAIL sprint cycle: ", msg)
    quit(1)

func _bone_euler(player: Node, bone: int) -> Vector3:
    var rest: Quaternion = player.bone_rest[bone]
    var pose: Quaternion = player.skeleton.get_bone_pose_rotation(bone)
    return (rest.inverse() * pose).get_euler()

func _find_bone(skeleton: Skeleton3D, needle: String) -> int:
    for i in range(skeleton.get_bone_count()):
        if needle in skeleton.get_bone_name(i):
            return i
    return -1

func _initialize() -> void:
    call_deferred("run_test")

func run_test() -> void:
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var player = scene.player
    if not player.skeleton:
        _fail("no skeleton")
        return

    # 1. Cadence follows real velocity: sprinting at SPRINT_SPEED must cycle
    # the stride clearly faster than walking at SPEED (no saturation).
    player.speed_ratio = 1.0
    player.velocity = Vector3(0, 0, -player.SPEED)
    player._animate(1.0 / 60.0)
    var walk_rate: float = player.gait_rate
    player.velocity = Vector3(0, 0, -player.SPRINT_SPEED)
    player._animate(1.0 / 60.0)
    var sprint_rate: float = player.gait_rate
    print("GAIT walk_rate=", walk_rate, " sprint_rate=", sprint_rate)
    if sprint_rate < walk_rate * 1.3:
        _fail("sprint cadence does not scale with speed (gliding)")
        return
    player.velocity = Vector3.ZERO
    player.speed_ratio = 0.0
    var phase: float = player.gait_phase
    player._animate(1.0 / 60.0)
    if player.gait_rate != 0.0 or player.gait_phase != phase:
        _fail("idle gait kept advancing")
        return

    # 2. Bone ownership: hair/skirt/sleeve poses must be untouched by the
    # sprint pose layer.
    var hair = _find_bone(player.skeleton, "HairJoint")
    var skirt = _find_bone(player.skeleton, "J_Sec_")
    var scarf = _find_bone(player.skeleton, "Bust")
    if hair < 0 or skirt < 0 or scarf < 0:
        _fail("hair/cloth/scarf bones not found")
        return
    var hair_before: Quaternion = player.skeleton.get_bone_pose_rotation(hair)
    var skirt_before: Quaternion = player.skeleton.get_bone_pose_rotation(skirt)
    var scarf_before: Quaternion = player.skeleton.get_bone_pose_rotation(scarf)
    player.sprint_blend = 1.0
    for step in range(24):
        player._sprint_pose(TAU * step / 24.0)
    if absf(player.skeleton.get_bone_pose_rotation(hair).dot(hair_before)) < 0.999999:
        _fail("sprint pose wrote to a hair bone (double animation)")
        return
    if absf(player.skeleton.get_bone_pose_rotation(skirt).dot(skirt_before)) < 0.999999:
        _fail("sprint pose wrote to a cloth bone (double animation)")
        return
    if absf(player.skeleton.get_bone_pose_rotation(scarf).dot(scarf_before)) < 0.999999:
        _fail("sprint pose wrote to a scarf bone (double animation)")
        return

    # 3. Pose quality across one full stride.
    var arm_l = player.bone_indices["J_Bip_L_UpperArm"]
    var arm_r = player.bone_indices["J_Bip_R_UpperArm"]
    var elbow_l = player.bone_indices["J_Bip_L_LowerArm"]
    var elbow_r = player.bone_indices["J_Bip_R_LowerArm"]
    var leg_l = player.bone_indices["J_Bip_L_UpperLeg"]
    var leg_r = player.bone_indices["J_Bip_R_UpperLeg"]
    var saw_opposition := false
    var phases := []
    for step in range(25):
        var ph: float = TAU * step / 24.0
        player._sprint_pose(ph)
        phases.append(ph)
        var a_l: Vector3 = _bone_euler(player, arm_l)
        var a_r: Vector3 = _bone_euler(player, arm_r)
        var e_l: Vector3 = _bone_euler(player, elbow_l)
        var e_r: Vector3 = _bone_euler(player, elbow_r)
        var l_l: Vector3 = _bone_euler(player, leg_l)
        var l_r: Vector3 = _bone_euler(player, leg_r)
        # Arms compact: no wide z spread like the old pose (±0.30).
        if absf(a_l.z) > 0.15 or absf(a_r.z) > 0.15:
            _fail("sprint arm spread too wide: z=" + str(a_l.z) + "/" + str(a_r.z))
            return
        # Elbows bent (roughly 60-80 degrees) the whole cycle.
        if e_l.x < 0.85 or e_l.x > 1.45 or e_r.x < 0.85 or e_r.x > 1.45:
            _fail("sprint elbow not bent: " + str(e_l.x) + "/" + str(e_r.x))
            return
        # Opposite arm/leg coordination.
        var arm_swing := a_l.x - a_r.x
        var leg_swing := l_l.x - l_r.x
        if absf(arm_swing) > 0.15 and absf(leg_swing) > 0.15:
            if arm_swing * leg_swing > 0.0:
                _fail("arm and leg swing on the same side at phase " + str(ph))
                return
            saw_opposition = true
    if not saw_opposition:
        _fail("no arm/leg opposition observed in the stride")
        return
    # Seamless loop: phase 0 and phase TAU must be the same pose.
    player._sprint_pose(0.0)
    var q0: Quaternion = player.skeleton.get_bone_pose_rotation(leg_l)
    player._sprint_pose(TAU)
    var q1: Quaternion = player.skeleton.get_bone_pose_rotation(leg_l)
    if absf(q0.dot(q1)) < 0.999999:
        _fail("sprint cycle does not loop seamlessly")
        return
    print("PASS sprint cycle: velocity-driven cadence, clean bone ownership, compact opposite arm pump, bent elbows, seamless loop")
    quit(0)
