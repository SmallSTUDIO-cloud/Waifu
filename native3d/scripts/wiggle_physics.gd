extends RefCounted
# Real jiggle physics for hair, skirt, sleeve and chest-scarf (Bust) chains,
# using the vendored MIT WiggleBone addon (detomon/wigglebone,
# addons/wigglebone). The addon is a SkeletonModifier3D that models each bone
# as a point mass on a spring and reacts to ACCELERATION plus the external
# force (wind/breeze), not raw velocity: while running at constant speed the
# player.gd gait wind keeps the strands flowing, and on starts, stops, turns
# and dodges the acceleration swings them; they droop under gravity when
# idle. Body (J_Bip_*) bones are never touched. At PHYSICS quality 2 (FULL)
# the wiggle modifiers drive these chains and the cheaper angular springs in
# secondary_motion.gd stand down.
const WiggleMod = preload("res://addons/wigglebone/wiggle_rotation_modifier_3d.gd")
const WiggleProps = preload("res://addons/wigglebone/wiggle_rotation_properties_3d.gd")

var skeleton: Skeleton3D
var modifiers: Array[Dictionary] = []
var active: bool = false
var wind: Vector3 = Vector3.ZERO

func setup(skel: Skeleton3D) -> void:
	skeleton = skel
	clear()
	for index in range(skeleton.get_bone_count()):
		var name = skeleton.get_bone_name(index)
		if name.ends_with("_end"):
			continue
		var kind = ""
		if name.begins_with("HairJoint"):
			kind = "hair"
		elif name.begins_with("J_Sec_") and ("Skirt" in name or "Sleeve" in name):
			kind = "cloth"
		elif name.begins_with("J_Sec_") and "Bust" in name:
			kind = "scarf"
		# J_Bip_* body bones are deliberately never simulated.
		if kind.is_empty():
			continue
		var depth = _chain_depth(index, kind)
		_add_bone(index, kind, depth)

func _chain_depth(index: int, kind: String) -> int:
	var depth = 0
	var walker = skeleton.get_bone_parent(index)
	while walker >= 0:
		var walker_name = skeleton.get_bone_name(walker)
		var same = walker_name.begins_with("HairJoint") if kind == "hair" else (walker_name.begins_with("J_Sec_") and ("Skirt" in walker_name or "Sleeve" in walker_name or "Bust" in walker_name))
		if not same:
			break
		depth += 1
		walker = skeleton.get_bone_parent(walker)
	return depth

func _add_bone(index: int, kind: String, depth: int) -> void:
	var mod = WiggleMod.new()
	mod.bone_name = skeleton.get_bone_name(index)
	var p = WiggleProps.new()
	var df = clampf(float(depth) / 4.0, 0.0, 1.0)
	# The addon integrates the spring analytically (undamped) and then decays
	# angular velocity by exp(-angular_damp * dt), so the damping ratio is
	# zeta = angular_damp / (TAU * spring_freq). We therefore derive damping
	# FROM the frequency to hit a target zeta instead of picking two
	# independent numbers: hair stays underdamped and flowing, cloth is
	# closer to critically damped so panels don't flap forever.
	# Roots are stiffer and settle faster; tips get lower freq AND lower damp
	# (whip/follow-through). A small deterministic per-bone variation keeps
	# strands from moving in perfect lockstep.
	var wobble = 0.96 + 0.04 * float(index % 4)
	if kind == "hair":
		# Soft and flowing: low spring freq, clearly underdamped so tips whip
		# and trail, moderate gravity droop, generous swing span.
		var freq = 2.9 * (1.0 - 0.30 * df) * wobble
		p.spring_freq = freq
		p.angular_damp = 1.15 * freq # zeta ~= 0.18, flowing follow-through
		p.gravity = Vector3(0, -2.6, 0) # gentle idle droop
		p.swing_span = deg_to_rad(50.0) # keep strands off the face/scarf
		p.linear_scale = 360.0 # reaction to walking/dashing
		p.force_scale = 230.0 # strong breeze/wind response while running
	else:
		var freq = 4.2 * (1.0 - 0.30 * df) * wobble
		p.spring_freq = freq
		p.angular_damp = 3.2 * freq # zeta ~= 0.51, cloth settles fast
		p.gravity = Vector3(0, -7.0, 0) # visible skirt sag
		p.swing_span = deg_to_rad(32.0) # panels stay close to the legs
		p.linear_scale = 460.0
		p.force_scale = 190.0
		if kind == "scarf":
			# Chest scarf panels: soft, a little underdamped so they flutter,
			# with enough span to visibly lift and puff backward while running,
			# but still never clip the chest or the sword arm.
			var sfreq = 3.8 * (1.0 - 0.25 * df) * wobble
			p.spring_freq = sfreq
			p.angular_damp = 2.65 * sfreq # zeta ~= 0.42, lively flutter
			p.gravity = Vector3(0, -5.5, 0)
			p.swing_span = deg_to_rad(30.0)
			p.linear_scale = 430.0
			p.force_scale = 260.0
	mod.properties = p
	mod.influence = 0.0
	# SkeletonModifier3D runs in child order, so parents must be added first;
	# iterating bone indices ascending guarantees that for these chains.
	skeleton.add_child(mod)
	modifiers.append({"mod": mod, "kind": kind, "bone": index, "depth": depth})

func set_active(value: bool) -> void:
	active = value
	for entry in modifiers:
		entry.mod.influence = 1.0 if value else 0.0

func set_wind(value: Vector3) -> void:
	wind = value
	for entry in modifiers:
		entry.mod.force_global = value

func reset_all() -> void:
	for entry in modifiers:
		if entry.mod.has_method("reset"):
			entry.mod.reset()

func clear() -> void:
	for entry in modifiers:
		if is_instance_valid(entry.mod):
			entry.mod.queue_free()
	modifiers.clear()
