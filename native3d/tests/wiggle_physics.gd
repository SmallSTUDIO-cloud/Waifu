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
	# Idle hair droops under gravity but stays inside the swing limit.
	var rest_swing = _swing_of(w, deepest_hair, skeleton)
	check(rest_swing < deg_to_rad(45.0), "idle hair exceeds swing limit (%.2f deg)" % rad_to_deg(rest_swing))
	var max_swing = 0.0
	for i in range(8):
		player.model_root.position.x += 0.012 * float(i + 1)
		await process_frame
		await process_frame
		max_swing = maxf(max_swing, _swing_of(w, deepest_hair, skeleton))
	check(max_swing > 0.02, "hair tip did not react to acceleration (%.4f)" % max_swing)
	check(max_swing < deg_to_rad(45.0) + 0.05, "hair tip exceeded swing limit (%.2f deg)" % rad_to_deg(max_swing))
	for i in range(120):
		await process_frame
	var settled = _swing_of(w, deepest_hair, skeleton)
	check(settled < max_swing, "hair did not settle after motion (%.4f vs %.4f)" % [settled, max_swing])
	check(settled < deg_to_rad(45.0) + 0.05, "hair unbounded after settle")

	# Tuning invariants: damping is derived from frequency via a damping
	# ratio; hair must be underdamped, cloth near-critical; tips looser than roots.
	var hair_root = null
	var hair_tip = null
	var cloth_root = null
	for entry in w.modifiers:
		var zeta = entry.mod.properties.angular_damp / (TAU * maxf(entry.mod.properties.spring_freq, 0.001))
		if entry.kind == "hair":
			check(zeta < 0.35, "hair zeta too high (%.2f)" % zeta)
			if hair_root == null or entry.depth == 0: hair_root = entry
			if hair_tip == null or entry.depth > hair_tip.depth: hair_tip = entry
		elif entry.kind == "cloth":
			check(zeta > 0.35, "cloth zeta too low (%.2f)" % zeta)
			if cloth_root == null or entry.depth == 0: cloth_root = entry
	check(hair_root != null and hair_tip != null and hair_tip.mod.properties.spring_freq < hair_root.mod.properties.spring_freq, "hair tips not looser than roots")
	check(cloth_root != null and cloth_root.mod.properties.angular_damp > 8.0, "cloth root damping not in cloth range")

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
