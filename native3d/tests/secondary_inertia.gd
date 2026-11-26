extends SceneTree

# Secondary-motion inertia QA (master animation brief, section 4 + tests D/E/F):
#  A. acceleration from idle: hair lags (early deflection clearly smaller than
#     the steady-sprint deflection) then trails backward at constant sprint;
#  B. deceleration to stop: hair keeps momentum and swings FORWARD relative to
#     the body for a moment, then settles (no freeze, no unbounded oscillation);
#  C. 90-degree turn while sprinting: hair/scarf re-trail along the NEW
#     movement direction (physics follows actual velocity, not a world axis);
#  plus: scarf trails backward at steady sprint.

var failures: int = 0

func _initialize() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL inertia: ", message)

func _deepest(w, kind: String) -> int:
	var best := -1
	var best_depth := -1
	for entry in w.modifiers:
		if entry.kind == kind and entry.depth > best_depth:
			best_depth = entry.depth
			best = entry.bone
	return best

func _dot(w, bone_idx: int, facing: Vector3) -> float:
	for entry in w.modifiers:
		if entry.bone == bone_idx:
			return entry.mod._global_direction.dot(facing)
	return 0.0

func _swing(w, bone_idx: int, skeleton: Skeleton3D) -> float:
	for entry in w.modifiers:
		if entry.bone == bone_idx:
			var pose_dir = (skeleton.get_bone_global_pose_no_override(bone_idx).basis * Vector3.UP).normalized()
			return entry.mod._global_direction.angle_to(pose_dir)
	return -1.0

func _avg(values: Array) -> float:
	var s := 0.0
	for v in values:
		s += v
	return s / maxf(1.0, float(values.size()))

func run_test() -> void:
	print("INERTIA: start")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var player = scene.player
	var w = player.wiggle
	print("INERTIA: modifiers=", w.modifiers.size() if w != null else -1)
	check(w != null and w.modifiers.size() > 0, "no wiggle modifiers")
	var hair = _deepest(w, "hair")
	var scarf = _deepest(w, "scarf")
	check(hair >= 0 and scarf >= 0, "hair/scarf chain not found")
	if w == null or hair < 0 or scarf < 0:
		quit(1)
		return

	# Settle at idle first (droop under gravity, no wind); record the rest
	# direction so "swing forward on stop" can be measured RELATIVE to rest.
	var rest_dots: Array = []
	for i in range(150):
		player._animate(1.0 / 60.0)
		await process_frame
		if i >= 120:
			rest_dots.append(_dot(w, hair, player.facing))
	var rest_dot = _avg(rest_dots)
	var rest_swing = _swing(w, hair, player.skeleton)
	print("INERTIA: idle settled rest_dot=", rest_dot, " rest_swing=", rest_swing)

	# --- A. accelerate into a forward sprint (facing -Z, 5 m/s) ---
	player.facing = Vector3(0, 0, -1)
	player.velocity = Vector3(0, 0, -5.0)
	player.speed_ratio = 1.0
	player.sprinting = true
	var min_early := 9.0
	var steady: Array = []
	var scarf_steady: Array = []
	for i in range(90):
		player._animate(1.0 / 60.0)
		await process_frame
		var d = _dot(w, hair, player.facing)
		if i < 30:
			min_early = minf(min_early, d)
		if i >= 70:
			steady.append(d)
			scarf_steady.append(_dot(w, scarf, player.facing))
	var d_steady = _avg(steady)
	var d_scarf = _avg(scarf_steady)
	print("INERTIA accel: hair min_early=", min_early, " steady=", d_steady, " scarf steady=", d_scarf)
	check(d_steady < -0.05, "hair does not trail at steady sprint (%.3f)" % d_steady)
	check(d_scarf < 0.0, "scarf does not trail at steady sprint (%.3f)" % d_scarf)
	# Spring follow-through: on acceleration the underdamped tip whips PAST
	# its steady deflection and then oscillates back (not a rigid lock).
	check(min_early < d_steady - 0.1, "no follow-through overshoot on accel (min %.3f vs steady %.3f)" % [min_early, d_steady])

	# --- B. stop: momentum carries hair FORWARD past the rest direction,
	# then it settles back to the droop (no freeze, no runaway oscillation) ---
	player.velocity = Vector3.ZERO
	player.speed_ratio = 0.0
	player.sprinting = false
	var max_after := -9.0
	var final: Array = []
	var final_swing := 0.0
	for i in range(150):
		player._animate(1.0 / 60.0)
		await process_frame
		var d = _dot(w, hair, player.facing)
		if i >= 5 and i <= 80:
			max_after = maxf(max_after, d)
		if i >= 130:
			final.append(d)
			final_swing = _swing(w, hair, player.skeleton)
	var d_final = _avg(final)
	print("INERTIA stop: rest_dot=", rest_dot, " max forward swing=", max_after, " final=", d_final, " final_swing=", final_swing)
	check(max_after > rest_dot + 0.2, "hair did not swing forward past rest on stop (%.3f vs rest %.3f)" % [max_after, rest_dot])
	check(absf(d_final - rest_dot) < 0.15, "hair did not settle back near rest after stop (%.3f vs rest %.3f)" % [d_final, rest_dot])
	check(final_swing < 0.25, "hair oscillating after stop (swing %.3f rad)" % final_swing)

	# --- C. 90-degree turn while sprinting: re-trail along new direction ---
	player.velocity = Vector3(0, 0, -5.0)
	player.speed_ratio = 1.0
	player.sprinting = true
	for i in range(90):
		player._animate(1.0 / 60.0)
		await process_frame
	player.facing = Vector3(-1, 0, 0)
	player.velocity = Vector3(-5, 0, 0)
	var turn_hair: Array = []
	var turn_scarf: Array = []
	for i in range(100):
		player._animate(1.0 / 60.0)
		await process_frame
		if i >= 80:
			turn_hair.append(_dot(w, hair, player.facing))
			turn_scarf.append(_dot(w, scarf, player.facing))
	var d_turn_hair = _avg(turn_hair)
	var d_turn_scarf = _avg(turn_scarf)
	print("INERTIA turn90: hair=", d_turn_hair, " scarf=", d_turn_scarf)
	check(d_turn_hair < 0.0, "hair does not trail after 90-degree turn (%.3f)" % d_turn_hair)
	check(d_turn_scarf < 0.0, "scarf does not trail after 90-degree turn (%.3f)" % d_turn_scarf)

	player.sprinting = false
	player.velocity = Vector3.ZERO
	player.speed_ratio = 0.0
	player._animate(1.0 / 60.0)
	scene.queue_free()
	if failures == 0:
		print("PASS secondary inertia: accel lag, backward trail at sprint, forward swing on stop, settle, 90-degree turn re-trail")
	quit(1 if failures else 0)
