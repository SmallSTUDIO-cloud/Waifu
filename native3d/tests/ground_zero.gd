extends SceneTree

var failures: int = 0

func _initialize() -> void:
    call_deferred("run_test")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        printerr("FAIL ground zero: ", message)

func run_test() -> void:
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var gz = scene.get_node_or_null("GroundZero")
    check(gz != null, "GroundZero root missing")
    if gz == null:
        quit(1)
        return

    # Scene organization into spatial sectors.
    for name in ["Lighting", "Central_Plaza", "East_District", "West_District", "North_District",
            "South_District", "Elevated_Ruins", "Landmarks", "Static_Vehicles", "Vegetation",
            "Props", "LOD_Proxies", "Collision"]:
        check(gz.get_node_or_null(name) != null, "sector missing: " + name)

    # Perimeter buildings with three LOD tiers each.
    check(gz.buildings.size() >= 12, "too few perimeter buildings: %d" % gz.buildings.size())
    for b in gz.buildings:
        check(b.facade.visibility_range_end >= 60.0, "facade LOD1 range missing")
        check(b.simple.visibility_range_begin >= 60.0 and b.simple.visibility_range_end > b.simple.visibility_range_begin, "LOD2 silhouette range missing")
        for p in b.props:
            check(p.visibility_range_end <= 40.0, "prop LOD0 range missing")

    # Central plaza must stay open and walkable (gameplay clamp is ±8.5 m).
    for s in gz.solids:
        if s.ground:
            continue
        var d: float = Vector2(s.pos.x, s.pos.z).length()
        var half: float = Vector2(s.size.x, s.size.z).length() * 0.5
        check(d - half > 9.0, "solid too close to plaza center at %s (d=%.1f half=%.1f)" % [str(s.pos), d, half])

    # Landmarks from the reference.
    var texts: Array = gz.billboard_texts.duplicate()
    texts.sort()
    var want: Array = ["CLAUDE AI CONTROLS THE WORLD", "CLAUDE FOREVER", "HUMANITY WAS HERE..."]
    want.sort()
    check(texts == want, "billboard set wrong: %s" % str(texts))
    check(gz.tower != null and gz.tower.get_child_count() > 10, "comm tower missing")
    check(gz.elevated_road != null and gz.elevated_road.get_child_count() > 10, "elevated road missing")
    check(gz.vehicles.size() >= 5, "abandoned vehicles missing: %d" % gz.vehicles.size())
    check(gz.multimesh_sectors >= 16, "instancing sectors missing: %d" % gz.multimesh_sectors)

    # Mobile lighting config: one shadow-capped sun, sky background, distance fog.
    check(gz.sun != null and gz.sun.shadow_enabled, "sun shadows missing")
    check(gz.sun.directional_shadow_max_distance <= 60.0, "sun shadow distance too far: %.1f" % gz.sun.directional_shadow_max_distance)
    var env: Environment = gz.env_node.environment
    check(env.background_mode == Environment.BG_SKY, "sky background missing")
    check(env.fog_enabled, "distance fog missing")
    var omnis := 0
    var stack: Array = [gz]
    while not stack.is_empty():
        var n: Node = stack.pop_back()
        if n is OmniLight3D or n is SpotLight3D:
            omnis += 1
        for c in n.get_children():
            stack.append(c)
    check(omnis == 0, "extra point/spot lights present: %d" % omnis)

    # Gameplay integration: existing systems still work inside Ground Zero.
    scene.start_game()
    await process_frame
    var enemies = get_nodes_in_group("enemies")
    check(enemies.size() == 4, "expected four enemies, got %d" % enemies.size())
    scene.player.control = Vector2(0, -1)
    var p0: Vector3 = scene.player.position
    for i in range(30):
        await physics_frame
    check(scene.player.position.distance_to(p0) > 0.5, "player cannot move inside plaza")
    check(scene.player.position.y < 1.0 and scene.player.position.y > -0.5, "player floating or sunk: y=%.2f" % scene.player.position.y)
    scene.player.attack()
    check(scene.player.attack_timer > 0.0, "attack broken in new environment")
    scene.player.dash_cooldown = 0.0
    scene.player.dodge()
    check(scene.player.dash_time > 0.0, "dodge broken in new environment")

    # Structural perf counters for the diagnostics log (software-rendered only).
    var mesh_instances := 0
    var mm := 0
    stack = [scene]
    while not stack.is_empty():
        var n: Node = stack.pop_back()
        if n is MeshInstance3D:
            mesh_instances += 1
        if n is MultiMeshInstance3D:
            mm += 1
        for c in n.get_children():
            stack.append(c)
    print("GZ_PERF buildings=%d solids=%d vehicles=%d multimesh_sectors=%d nodes=%d mesh_instances=%d multimesh=%d" % [
        gz.buildings.size(), gz.solids.size(), gz.vehicles.size(), gz.multimesh_sectors,
        int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), mesh_instances, mm])

    if failures == 0:
        print("PASS ground zero: layout, LOD tiers, landmarks, lighting, instancing, gameplay integration")
    quit(0 if failures == 0 else 1)
