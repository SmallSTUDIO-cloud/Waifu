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
    scene.player.attack()
    scene.player.dodge()
    scene.player.take_damage(14)
    if scene.player.health != 86:
        printerr("FAIL: dodge invulnerability")
        quit(1)
        return
    if not scene.player.attack_timer == 0.0:
        printerr("FAIL: dodge did not cancel attack")
        quit(1)
        return
    scene.player.dash_time = 0.0
    enemies[0].global_position = scene.player.global_position + Vector3(0, 0, -1.0)
    scene.player.facing = Vector3(0, 0, -1)
    scene.player.attack()
    for i in range(20): await physics_frame
    var saw_effect = false
    var impact_in_front = false
    for child in scene.get_children():
        if child.get_script() == load("res://scripts/combat_vfx.gd"):
            saw_effect = true
            if child.kind == "impact":
                var center = enemies[0].global_position + Vector3(0, 1, 0)
                impact_in_front = (child.global_position - center).dot((scene.camera.global_position - center).normalized()) > 0.3
    if not impact_in_front:
        printerr("FAIL: impact is missing or hidden inside the target")
        quit(1)
        return
    if not saw_effect:
        printerr("FAIL: attack impact effect missing")
        quit(1)
        return
    if enemies[0].hp >= 3:
        printerr("FAIL: attack did not hit nearby enemy")
        quit(1)
        return
    var visual = load("res://scripts/combat_vfx.gd").new()
    visual.setup("dodge")
    root.add_child(visual)
    if visual.shape.mesh.get_surface_count() != 1:
        printerr("FAIL: dodge visual geometry missing")
        quit(1)
        return
    visual._process(1.0)
    if not visual.is_queued_for_deletion():
        printerr("FAIL: transient effect did not clean up")
        quit(1)
        return
    # Verify the actual weapon ribbon samples, stays bounded and ages out.
    var trail = scene.player.sword_trail
    var grip = scene.player.sword_grip
    trail.clear_trail()
    for i in range(20):
        trail.update_trail(1.0 / 60.0, grip, true)
    if trail.samples.size() > trail.MAX_SAMPLES or trail.mesh.get_surface_count() != 1:
        printerr("FAIL: blade trail is missing or unbounded")
        quit(1)
        return
    trail.update_trail(1.0, grip, false)
    if not trail.samples.is_empty() or trail.mesh.get_surface_count() != 0:
        printerr("FAIL: blade trail did not expire")
        quit(1)
        return
    # Input buffering should advance a combo after cooldown, not double-hit early.
    scene.player.attack_cooldown = 0.08
    var previous_combo = scene.player.combo
    if not scene.player.attack() or not scene.player.attack_buffered:
        printerr("FAIL: attack was not buffered")
        quit(1)
        return
    for i in range(8): await physics_frame
    if scene.player.combo != previous_combo % 4 + 1 or scene.player.attack_buffered:
        printerr("FAIL: buffered combo did not advance")
        quit(1)
        return
    scene.player.dash_cooldown = 0.0
    scene.player.control = Vector2(1, 0)
    scene.player.dodge()
    if scene.player.dash_direction.dot(Vector3.RIGHT) < 0.99 or scene.player.attack_buffered:
        printerr("FAIL: dodge direction or buffered attack cancellation")
        quit(1)
        return
    # A speed-driven gait must advance while moving and stop when idle.
    scene.player.speed_ratio = 1.0
    var phase = scene.player.gait_phase
    scene.player._animate(0.1)
    if is_equal_approx(phase, scene.player.gait_phase):
        printerr("FAIL: gait phase did not advance")
        quit(1)
        return
    scene.player.speed_ratio = 0.0
    phase = scene.player.gait_phase
    scene.player._animate(0.1)
    if not is_equal_approx(phase, scene.player.gait_phase):
        printerr("FAIL: idle gait kept advancing")
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
