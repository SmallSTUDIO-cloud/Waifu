extends SceneTree

func _initialize() -> void:
    call_deferred("run_test")

func run_test() -> void:
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var driver = load("res://scripts/authored_motion.gd").new()
    if not driver.setup(scene.player.model_root, scene.player.skeleton):
        printerr("FAIL: authored skeleton mapping incomplete")
        quit(1)
        return
    print("SOURCE CLIPS ", driver.animator.get_animation_list())
    for clip in ["Sword_Idle", "Walk", "Jog_Fwd", "Sword_Attack", "Roll"]:
        if not driver.animator.has_animation(clip):
            printerr("FAIL: missing authored clip ", clip)
            quit(1)
            return
    driver.update(0.1, 0.0, -1.0, -1.0, 0)
    if driver.current != "Sword_Idle":
        printerr("FAIL: idle state")
        quit(1)
        return
    driver.update(0.1, 0.9, -1.0, -1.0, 0)
    if driver.current != "Jog_Fwd":
        printerr("FAIL: jog state")
        quit(1)
        return
    var leg = scene.player.skeleton.find_bone("J_Bip_L_UpperLeg")
    var q = scene.player.skeleton.get_bone_pose_rotation(leg)
    driver.update(0.1, 0.9, -1.0, -1.0, 0)
    var q2 = scene.player.skeleton.get_bone_pose_rotation(leg)
    if absf(q.dot(q2)) > 0.99999:
        printerr("FAIL: authored jog did not animate")
        quit(1)
        return
    driver.update(0.1, 0.0, 0.4, -1.0, 1)
    if driver.current != "Sword_Attack":
        printerr("FAIL: attack state")
        quit(1)
        return
    driver.update(0.1, 0.0, -1.0, 0.4, 1)
    if driver.current != "Roll":
        printerr("FAIL: dodge state")
        quit(1)
        return
    print("PASS authored motion pilot: five clips, 22 mapped bones, state and animated pose")
    quit(0)
