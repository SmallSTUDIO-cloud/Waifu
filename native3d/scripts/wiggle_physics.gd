extends RefCounted
# Real jiggle physics for hair, skirt and sleeve chains, using the vendored
# MIT WiggleBone addon (detomon/wigglebone, addons/wigglebone). The addon is a
# SkeletonModifier3D that models each bone as a point mass on a spring and
# reacts to ACCELERATION, not velocity: while walking at constant speed the
# hair does not permanently lag behind; it swings on starts, stops, turns and
# dodges, and droops under gravity when idle. Anatomy (bust) bones are never
# touched. At PHYSICS quality 2 (FULL) the wiggle modifiers drive these chains
# and the cheaper angular springs in secondary_motion.gd stand down.
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
		# J_Sec_*Bust* and all body bones are deliberately never simulated.
		if kind.is_empty():
			continue
		var depth = _chain_depth(index, kind)
		_add_bone(index, kind, depth)

func _chain_depth(index: int, kind: String) -> int:
	var depth = 0
	var walker = skeleton.get_bone_parent(index)
	while walker >= 0:
		var walker_name = skeleton.get_bone_name(walker)
		var same = walker_name.begins_with("HairJoint") if kind == "hair" else (walker_name.begins_with("J_Sec_") and ("Skirt" in walker_name or "Sleeve" in walker_name))
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
		var freq = 3.4 * (1.0 - 0.28 * df) * wobble
		p.spring_freq = freq
		p.angular_damp = 1.4 * freq # zeta ~= 0.22, lively but settles
		p.gravity = Vector3(0, -2.2, 0) # gentle idle droop
		p.swing_span = deg_to_rad(45.0) # keep strands off the face/scarf
		p.linear_scale = 340.0 # reaction to walking/dashing
		p.force_scale = 160.0
	else:
		var freq = 4.6 * (1.0 - 0.30 * df) * wobble
		p.spring_freq = freq
		p.angular_damp = 3.1 * freq # zeta ~= 0.49, cloth settles fast
		p.gravity = Vector3(0, -6.5, 0) # visible skirt sag
		p.swing_span = deg_to_rad(30.0) # panels stay close to the legs
		p.linear_scale = 430.0
		p.force_scale = 170.0
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
