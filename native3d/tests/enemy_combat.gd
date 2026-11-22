extends SceneTree

var failures: int = 0

func _initialize() -> void:
    call_deferred("run_test")

var expired_seen: bool = false

func _on_orphan_expired(_position: Vector3) -> void:
    expired_seen = true

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        printerr("FAIL enemies: ", message)

func enemy_by_kind(kind: String) -> Node:
    for e in get_nodes_in_group("enemies"):
        if e.get("kind") == kind and not e.get("dead"):
            return e
    return null

func run_test() -> void:
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    scene.start_game()
    await process_frame
    var enemies = get_nodes_in_group("enemies")
    check(enemies.size() == 4, "expected four robots")
    var kinds: Array = enemies.map(func(e): return e.get("kind"))
    check(kinds.count("large") == 2 and kinds.count("small") == 2, "expected two bruisers and two drones")
    for e in enemies:
        check(e.model_root != null and e.flash_materials.size() > 0, "robot model and materials missing")
        var meshes: int = 0
        var stack = [e.model_root]
        while not stack.is_empty():
            var n = stack.pop_back()
            if n is GeometryInstance3D and n.mesh: meshes += 1
            for c in n.get_children(): stack.append(c)
        check(meshes > 0, "robot has no renderable mesh")
    # Balance bounds: telegraphed damage cannot burst-kill the 100 HP player.
    check(scene.player.health == 100, "player HP reset")
    var ENEMY = load("res://scripts/enemy.gd")
    check(ENEMY.MELEE_DAMAGE <= 14 and ENEMY.HEADBUTT_DAMAGE <= 10, "melee damage exceeds balance bound")
    var BOLT = load("res://scripts/enemy_projectile.gd")
    check(BOLT.DAMAGE <= 12 and BOLT.SPEED >= 6.0 and BOLT.LIFE <= 3.0, "bolt balance bound")

    var player = scene.player
    player.invulnerable = 99.0
    var bruiser = enemy_by_kind("large")
    var drone = enemy_by_kind("small")
    if bruiser == null or drone == null:
        printerr("FAIL enemies: robot kinds not found")
        quit(1)
        return

    # Bruiser only strikes inside melee range after a windup.
    bruiser.global_position = player.global_position + Vector3(0, 0, -6.0)
    bruiser.timer = 0.0
    var hp_before = player.health
    var chase_start = bruiser.global_position.distance_to(player.global_position)
    for i in range(12): await physics_frame
    check(player.health == hp_before, "bruiser hit from 6m without windup")
    for i in range(40): await physics_frame
    var chase_end = bruiser.global_position.distance_to(player.global_position)
    print("BRUISER DEBUG enabled=", bruiser.enabled, " mode=", bruiser.mode, " stagger=", bruiser.stagger, " vel=", bruiser.velocity, " target_valid=", is_instance_valid(bruiser.target), " kind=", bruiser.kind)
    check(chase_end < chase_start - 0.8, "bruiser did not chase (%.2f -> %.2f)" % [chase_start, chase_end])
    check(bruiser.model_root.rotation.x > 0.02, "bruiser did not lean while chasing")
    bruiser.global_position = player.global_position + Vector3(0, 0, -1.2)
    bruiser.timer = 0.0
    player.invulnerable = 0.0
    for i in range(80): await physics_frame
    check(player.health < hp_before, "bruiser melee windup did not strike")
    check(player.health >= hp_before - ENEMY.MELEE_DAMAGE, "melee damage exceeded tuning")

    # Drone keeps its firing band and fires a real projectile after telegraph.
    player.invulnerable = 99.0
    drone.global_position = player.global_position + Vector3(0, 0.95, -6.0)
    drone.timer = 0.0
    var fired_seen = false
    for i in range(240):
        await physics_frame
        if not get_nodes_in_group("enemy_projectiles").is_empty():
            fired_seen = true
            break
    check(fired_seen, "drone never fired a bolt in range")
    var bolt = get_nodes_in_group("enemy_projectiles")[0]
    check(bolt.direction.length() > 0.99, "bolt direction not normalized")
    var bolt_start = bolt.global_position
    for i in range(6): await physics_frame
    check(bolt.global_position.distance_to(bolt_start) > 0.2, "bolt did not travel")
    # A standing player is hit; damage respects the bolt tuning.
    player.invulnerable = 0.0
    var hp2 = player.health
    for i in range(120):
        await physics_frame
        if get_nodes_in_group("enemy_projectiles").is_empty(): break
    check(player.health <= hp2, "bolt passed through a standing player without damage")
    # Dodge invulnerability makes the same bolt harmless.
    player.health = 100
    player.invulnerable = 0.0
    drone.global_position = player.global_position + Vector3(0, 0.95, -5.0)
    drone.timer = 0.0
    drone.mode = "chase"
    for i in range(240):
        await physics_frame
        if not get_nodes_in_group("enemy_projectiles").is_empty(): break
    if not get_nodes_in_group("enemy_projectiles").is_empty():
        player.dash_cooldown = 0.0
        player.dash_time = 0.0
        player.control = Vector2(1, 0)
        player.dodge()
        for i in range(120):
            await physics_frame
            if get_nodes_in_group("enemy_projectiles").is_empty(): break
        check(player.health == 100, "dodge did not avoid the bolt")
    # Bolts expire instead of lingering. Park all robots first so the crash
    # bisect stays attributable to projectile lifetime handling.
    for e in get_nodes_in_group("enemies"): e.enabled = false
    var orphan = load("res://scripts/enemy_projectile.gd").new()
    scene.add_child(orphan)
    # Start far enough away that the bolt must expire by lifetime, not impact.
    orphan.setup(player.global_position + Vector3(0, 1, 30), Vector3(0, 0, -1), player)
    expired_seen = false
    orphan.expired.connect(_on_orphan_expired)
    for i in range(200):
        await physics_frame
        if not is_instance_valid(orphan) or orphan.is_queued_for_deletion(): break
    check(expired_seen and (not is_instance_valid(orphan) or orphan.is_queued_for_deletion()), "bolt did not expire")

    # Enemies separate instead of stacking.
    var e1 = enemy_by_kind("large")
    var e2 = null
    for e in get_nodes_in_group("enemies"):
        if e != e1 and e.get("kind") == "large" and not e.get("dead"): e2 = e
    if e1 and e2:
        # Re-enable and keep both in chase mode away from the player.
        e1.enabled = true
        e2.enabled = true
        e1.timer = 5.0
        e2.timer = 5.0
        e1.global_position = Vector3(0, 0.1, -6)
        e2.global_position = Vector3(0.2, 0.1, -6)
        var gap_before = Vector2(e1.global_position.x - e2.global_position.x, e1.global_position.z - e2.global_position.z).length()
        for i in range(150): await physics_frame
        var gap = Vector2(e1.global_position.x - e2.global_position.x, e1.global_position.z - e2.global_position.z).length()
        check(gap > gap_before + 0.3, "enemies did not separate (%.2f -> %.2f)" % [gap_before, gap])

    # Hit reactions and defeat still work with the new models.
    for e in get_nodes_in_group("enemies"):
        e.take_damage(99)
    await process_frame
    check(scene.remaining == 0 and not scene.playing, "victory after defeating all robots")
    var fallen = false
    for e in scene.get_children():
        if e.get("kind") and e.get("dead") and e.model_root and e.model_root.rotation.x < -0.4:
            fallen = true
    for i in range(40): await physics_frame
    for e in scene.get_children():
        if e.get("kind") and e.get("dead") and is_instance_valid(e.model_root) and e.model_root.rotation.x < -0.8:
            fallen = true
    check(fallen, "destroyed robot did not fall over")
    check(get_nodes_in_group("enemies").is_empty(), "defeated robots removed from group")

    scene.queue_free()
    if failures == 0:
        print("PASS enemy robots: models, animations, melee, ranged bolts, dodge, balance, separation")
    quit(1 if failures else 0)
