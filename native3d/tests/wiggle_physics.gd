extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL wiggle: ", message)

func run_test() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var player = scene.player
	var w = player.wiggle
	check(w != null and w.modifiers.size() > 0, "no wiggle modifiers created")
	var kinds = {}
	var deepest_hair = -1
	var deepest_depth = -1
	for entry in w.modifiers:
		var bone_name: String = player.skeleton.get_bone_name(entry.bone)
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

	# Acceleration reaction: shove the character sideways; a deep hair bone
	# must deviate from its rest pose, stay inside the swing limit, and settle.
	await process_frame
	var tip_rest = player.skeleton.get_bone_global_pose(deepest_hair).basis
	var max_angle = 0.0
	# Accelerate (not constant velocity): wiggle reacts to acceleration.
	for i in range(8):
		player.model_root.position.x += 0.012 * float(i + 1)
		await process_frame
		await process_frame
	var moved_angle = tip_rest.get_rotation_quaternion().angle_to(player.skeleton.get_bone_global_pose(deepest_hair).basis.get_rotation_quaternion())
	max_angle = moved_angle
	check(moved_angle > 0.02, "hair tip did not react to acceleration (%.4f)" % moved_angle)
	check(moved_angle < deg_to_rad(58.0) + 0.05, "hair tip exceeded swing limit (%.2f deg)" % rad_to_deg(moved_angle))
	for i in range(90):
		await process_frame
	var settled_angle = tip_rest.get_rotation_quaternion().angle_to(player.skeleton.get_bone_global_pose(deepest_hair).basis.get_rotation_quaternion())
	check(settled_angle < max_angle, "hair did not settle after motion")
	check(settled_angle < deg_to_rad(58.0) + 0.05, "hair unbounded after settle")

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
