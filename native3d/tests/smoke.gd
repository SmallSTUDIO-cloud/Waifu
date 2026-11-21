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
    var spring = load("res://scripts/spring.gd").new()
    for i in range(180): spring.step(0.1, 1.0 / 60.0, 30.0, 8.0, 0.16)
    if absf(spring.angle - 0.1) > 0.01:
        printerr("FAIL: spring fails to settle")
        quit(1)
        return
    for i in range(60): spring.step(100.0, 1.0 / 60.0, 30.0, 8.0, 0.16)
    if absf(spring.angle) > 0.161:
        printerr("FAIL: spring exceeds limit")
        quit(1)
        return
    print("PASS native 3D: skeleton, encounter, damage, victory, spring stability")
    quit(0)
