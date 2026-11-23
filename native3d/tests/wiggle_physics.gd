extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL wiggle: ", message)

func _swing_of(w, bone_idx: int, skeleton: Skeleton3D) -> float:
	for entry in w.modifiers:
		if entry.bone == bone_idx:
			var pose_dir = (skeleton.get_bone_global_pose_no_override(bone_idx).basis * Vector3.UP).normalized()
			return entry.mod._global_direction.angle_to(pose_dir)
	return -1.0

func run_test() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var player = scene.player
	var w = player.wiggle
	var skeleton = player.skeleton
	check(w != null and w.modifiers.size() > 0, "no wiggle modifiers created")
	var kinds = {}
	var deepest_hair = -1
	var deepest_depth = -1
	for entry in w.modifiers:
		var bone_name: String = skeleton.get_bone_name(entry.bone)
		kinds[entry.kind] = true
		check("Bust" not in bone_name and not bone_name.begins_with("J_Bip_"), "anatomy bone wiggled: " + bone_name)
		if entry.kind == "hair" and entry.depth > deepest_depth:
			deepest_depth = entry.depth
			deepest_hair = entry.bone
	check(kinds.has("hair"), "no hair wiggle chain")
	check(kinds.has("cloth"), "no skirt/sleeve wiggle chain")
	check(w.active, "wiggle not active at default FULL quality")
	for entry in w.modifiers:
		check(entry.mod.influence == 1.0, "modifier influence not 1 at FULL")

	# Acceleration reaction: shove the character with growing steps; a deep
	# hair bone must swing away from its animated pose, stay inside the swing
	# limit, and settle back once the motion stops.
	var rest_swing = _swing_of(w, deepest_hair, skeleton)
	check(rest_swing < 0.02, "hair not at rest before motion (%.3f)" % rest_swing)
	var max_swing = 0.0
	for i in range(8):
		player.model_root.position.x += 0.012 * float(i + 1)
		await process_frame
		await process_frame
		max_swing = maxf(max_swing, _swing_of(w, deepest_hair, skeleton))
	check(max_swing > 0.02, "hair tip did not react to acceleration (%.4f)" % max_swing)
	check(max_swing < deg_to_rad(58.0) + 0.05, "hair tip exceeded swing limit (%.2f deg)" % rad_to_deg(max_swing))
	for i in range(120):
		await process_frame
	var settled = _swing_of(w, deepest_hair, skeleton)
	check(settled < max_swing, "hair did not settle after motion (%.4f vs %.4f)" % [settled, max_swing])
	check(settled < deg_to_rad(58.0) + 0.05, "hair unbounded after settle")

	# Quality routing: FULL drives wiggle, REDUCED/OFF hand back to springs.
	player.set_physics_quality(1)
	check(not w.active and player.secondary_motion.quality == 1, "quality 1 did not disable wiggle")
	for entry in w.modifiers:
		check(entry.mod.influence == 0.0, "influence not 0 at REDUCED")
	player.set_physics_quality(2)
	check(w.active, "quality 2 did not re-enable wiggle")
	player.reset_secondary()

	scene.queue_free()
	if failures == 0:
		print("PASS wiggle physics: addon chains, accel reaction, swing limit, settle, quality routing")
	quit(1 if failures else 0)
