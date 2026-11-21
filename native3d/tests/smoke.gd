extends SceneTree

func _initialize() -> void:
    call_deferred("run_test")

func run_test() -> void:
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    if not scene.player or not scene.player.skeleton or scene.player.skeleton.get_bone_count() < 20:
        printerr("FAIL: rigged avatar skeleton missing")
        quit(1)
        return
    scene.start_game()
    await process_frame
    var enemies = get_nodes_in_group("enemies")
    if enemies.size() != 4:
        printerr("FAIL: expected four enemies")
        quit(1)
        return
    scene.player.invulnerable = 0.0
    scene.player.take_damage(14)
    if scene.player.health != 86:
        printerr("FAIL: player damage")
        quit(1)
        return
    for enemy in enemies:
        enemy.take_damage(10)
    if scene.remaining != 0 or scene.playing:
        printerr("FAIL: victory state")
        quit(1)
        return
    print("PASS native 3D: skeleton, encounter, damage and victory")
    quit(0)
