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
	if kind == "hair":
		# Light strands: soft spring, moderate damping so they keep swaying,
		# gentle gravity droop, wide swing limit; tips looser than roots.
		p.spring_freq = 3.2 * (1.0 - 0.25 * df)
		p.angular_damp = 3.2 + 2.6 * df
		p.gravity = Vector3(0, -3.0, 0)
		p.swing_span = deg_to_rad(58.0)
		p.linear_scale = 320.0
		p.force_scale = 150.0
	else:
		# Cloth (skirt/dress panels, sleeves): heavier, stiffer, slower sway,
		# stronger gravity sag, tighter swing limit.
		p.spring_freq = 4.2 * (1.0 - 0.30 * df)
		p.angular_damp = 5.5 + 2.8 * df
		p.gravity = Vector3(0, -7.5, 0)
		p.swing_span = deg_to_rad(40.0)
		p.linear_scale = 400.0
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

func reset_all() -> void:
	for entry in modifiers:
		if entry.mod.has_method("reset"):
			entry.mod.reset()

func clear() -> void:
	for entry in modifiers:
		if is_instance_valid(entry.mod):
			entry.mod.queue_free()
	modifiers.clear()
