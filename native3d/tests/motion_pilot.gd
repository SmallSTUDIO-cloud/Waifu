extends SceneTree

func _initialize() -> void:
    call_deferred("run_test")

func run_test() -> void:
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var driver = scene.player.motion_driver
    if not driver or not driver.valid:
        printerr("FAIL: authored skeleton mapping incomplete")
        quit(1)
        return
    # Test the previous authored fallback separately from the new defaults.
    driver.use_formal_walk = false
    driver.use_sword_dash = false
    print("SOURCE CLIPS ", driver.animator.get_animation_list())
    for clip in ["Sword_Idle", "Walk", "Jog_Fwd", "Sword_Attack", "Roll"]:
        if not driver.animator.has_animation(clip):
            printerr("FAIL: missing authored clip ", clip)
            quit(1)
            return
    for clip in ["Sword_Idle", "Walk", "Jog_Fwd"]:
        if driver.animator.get_animation(clip).loop_mode == Animation.LOOP_NONE:
            printerr("FAIL: locomotion clip does not loop: ", clip)
            quit(1)
            return
    driver.update(0.1, 0.0, -1.0, -1.0, 0)
    if driver.current != "Sword_Idle":
        printerr("FAIL: idle state")
        quit(1)
        return
    driver.update(0.1, 0.9, -1.0, -1.0, 0)
    if driver.current != "Walk":
        printerr("FAIL: walk state")
        quit(1)
        return
    var leg = scene.player.skeleton.find_bone("J_Bip_L_UpperLeg")
    var q = scene.player.skeleton.get_bone_pose_rotation(leg)
    driver.update(0.1, 0.9, -1.0, -1.0, 0)
    var q2 = scene.player.skeleton.get_bone_pose_rotation(leg)
    if absf(q.dot(q2)) > 0.99999:
        printerr("FAIL: authored walk did not animate")
        quit(1)
        return
    # After blending, the anatomical upper arm and leg directions should match
    # the authored rig after its 180-degree facing correction. This catches the
    # common failure where local bone quaternions lift both arms over the head.
    for i in range(60): driver.update(1.0 / 60.0, 0.9, -1.0, -1.0, 0)
    var facing_flip = Basis(Vector3.UP, PI)
    for pair in [["DEF-upper_arm.R", "DEF-forearm.R", "J_Bip_R_UpperArm", "J_Bip_R_LowerArm"], ["DEF-thigh.R", "DEF-shin.R", "J_Bip_R_UpperLeg", "J_Bip_R_LowerLeg"]]:
        var a = driver.source_rig.find_bone(pair[0]); var b = driver.source_rig.find_bone(pair[1])
        var c = scene.player.skeleton.find_bone(pair[2]); var d = scene.player.skeleton.find_bone(pair[3])
        var source_dir = (driver.source_rig.get_bone_global_pose(b).origin - driver.source_rig.get_bone_global_pose(a).origin).normalized()
        var target_dir = (scene.player.skeleton.get_bone_global_pose(d).origin - scene.player.skeleton.get_bone_global_pose(c).origin).normalized()
        if (facing_flip * source_dir).dot(target_dir) < 0.75:
            printerr("FAIL: anatomical retarget direction: ", pair)
            quit(1)
            return
    driver.update(0.02, 0.10, -1.0, -1.0, 0)
    if driver.current != "Walk":
        printerr("FAIL: walk hysteresis")
        quit(1)
        return
    driver.update(0.1, 0.0, 0.4, -1.0, 1)
    if driver.current != "Sword_Light_A":
        printerr("FAIL: attack state")
        quit(1)
        return
    if driver.combo_mapped.size() != 22:
        printerr("FAIL: combo rig mapping")
        quit(1)
        return
    for stage in range(1, 5):
        driver.update(0.1, 0.0, 0.4, -1.0, stage)
        if driver.current != driver.COMBO_CLIPS[stage - 1]:
            printerr("FAIL: distinct combo stage ", stage)
            quit(1)
            return
    driver.update(0.1, 0.0, -1.0, 0.4, 1)
    if driver.current != "Jog_Fwd":
        printerr("FAIL: dodge state")
        quit(1)
        return
    driver.use_formal_walk = true
    driver.update(0.1, 0.9, -1.0, -1.0, 1)
    if driver.current != "Walk_Formal":
        printerr("FAIL: formal walk")
        quit(1)
        return
    driver.use_sword_dash = true
    driver.update(0.1, 0.0, -1.0, 0.4, 1)
    if driver.current != "Sword_Dash":
        printerr("FAIL: authored dash")
        quit(1)
        return
    print("PASS authored motion pilot: authored clips, 22 mapped bones, state and animated pose")
    quit(0)
