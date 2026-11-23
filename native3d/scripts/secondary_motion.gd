extends RefCounted
# Secondary offsets are composed after authored animation; no anatomy bones.
# Angular springs and approximate skirt tip/leg capsule constraints, not cloth.
const SPRING = preload("res://scripts/spring.gd")
const MAX_DT: float = 0.10
const MAX_ACCEL: float = 24.0
const LEG_RADIUS: float = 0.065
# 0 = off, 1 = root chains, 2 = all available secondary joints.
var quality: int = 2
var quality_fade_remaining: float = 0.0
var rig: Skeleton3D
var joints: Array[Dictionary] = []
var leg_pairs: Array = []
var leg_segments: Array = []
var time: float = 0.0

func setup(skeleton: Skeleton3D) -> void:
    rig = skeleton
    joints.clear()
    leg_pairs.clear()
    for side in ["L", "R"]:
        var thigh = rig.find_bone("J_Bip_%s_UpperLeg" % side)
        var knee = rig.find_bone("J_Bip_%s_LowerLeg" % side)
        var foot = rig.find_bone("J_Bip_%s_Foot" % side)
        if thigh >= 0 and knee >= 0: leg_pairs.append([thigh, knee])
        if knee >= 0 and foot >= 0: leg_pairs.append([knee, foot])
    for index in range(rig.get_bone_count()):
        var name = rig.get_bone_name(index)
        if name.ends_with("_end"): continue
        var kind = ""
        if name.begins_with("HairJoint"): kind = "hair"
        elif name.begins_with("J_Sec_") and "Skirt" in name: kind = "skirt"
        elif name.begins_with("J_Sec_") and "Sleeve" in name: kind = "sleeve"
        # Only explicit secondary accessory bones are candidates; this avatar
        # has none. Never infer accessory motion from a body or hair bone.
        elif name.begins_with("J_Sec_") and ("Ribbon" in name or "Bow" in name or "Accessory" in name): kind = "accessory"
        if kind.is_empty(): continue
        var parent = rig.get_bone_parent(index)
        if parent < 0: continue
        var parent_name = rig.get_bone_name(parent)
        var root_joint = not (parent_name.begins_with("HairJoint") or (parent_name.begins_with("J_Sec_") and "Skirt" in parent_name))
        var child = -1
        for c in range(index + 1, rig.get_bone_count()):
            if rig.get_bone_parent(c) == index:
                child = c
                break
        var limit = 0.17 if kind == "hair" else (0.09 if kind == "skirt" else 0.075)
        # Chain depth: roots stay stiff, tips get looser, which gives the
        # whip-like falloff of real hair/cloth instead of a rigid chain.
        var depth = 0
        var walker = parent
        while walker >= 0:
            var walker_name = rig.get_bone_name(walker)
            var same = (walker_name.begins_with("HairJoint") if kind == "hair" else walker_name.begins_with("J_Sec_"))
            if not same: break
            depth += 1
            walker = rig.get_bone_parent(walker)
        var depth_frac = clampf(float(depth) / 4.0, 0.0, 1.0)
        # Stable per-chain variation without random noise or frame-dependent jitter.
        var variation = 0.93 + 0.035 * float(index % 5)
        var stiffness = (28.0 if kind == "hair" else 38.0) * variation * (1.0 - 0.30 * depth_frac)
        var damping = (9.0 if kind == "hair" else 11.0) * variation * (1.0 - 0.18 * depth_frac)
        var base = rig.get_bone_pose_rotation(index)
        joints.append({"bone": index, "parent": parent, "child": child, "kind": kind,
            "root": root_joint, "weight": 1.0, "rest": base, "base": base, "last": base, "limit": limit,
            "stiffness": stiffness, "damping": damping, "variation": variation,
            "x": SPRING.new(), "z": SPRING.new(), "initialized": false,
            "position": Vector3.ZERO, "velocity": Vector3.ZERO, "filtered_accel": Vector3.ZERO,
            "gravity_rest": Vector3.ZERO})

func set_quality(level: int) -> void:
    var next = clampi(level, 0, 2)
    if next == quality: return
    quality = next
    quality_fade_remaining = 0.25

func reset() -> void:
    if not rig: return
    for joint in joints:
        # Do not erase a newly-authored pose that changed after our last output.
        var pose = rig.get_bone_pose_rotation(joint.bone)
        if absf(pose.dot(joint.last)) > 0.999999:
            rig.set_bone_pose_rotation(joint.bone, joint.base)
        joint.initialized = false
        joint.velocity = Vector3.ZERO
        joint.filtered_accel = Vector3.ZERO
        joint.x.angle = 0.0; joint.x.velocity = 0.0
        joint.z.angle = 0.0; joint.z.velocity = 0.0
        joint.base = rig.get_bone_pose_rotation(joint.bone)
        joint.last = joint.base
        joint.weight = 1.0 if quality == 2 or (quality == 1 and joint.root) else 0.0

func _segment_distance(point: Vector3, a: Vector3, b: Vector3) -> float:
    var ab = b - a
    var t = clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
    return point.distance_to(a + ab * t)

func _cache_leg_segments() -> void:
    leg_segments.clear()
    for pair in leg_pairs:
        leg_segments.append([rig.get_bone_global_pose(pair[0]).origin, rig.get_bone_global_pose(pair[1]).origin])

func _skirt_point(joint: Dictionary, pose: Quaternion, parent_pose: Transform3D, fraction: float) -> Vector3:
    return parent_pose * (rig.get_bone_pose_position(joint.bone) + Basis(pose) * rig.get_bone_pose_position(joint.child) * fraction)

func _tip_position(joint: Dictionary, pose: Quaternion, parent_pose: Transform3D) -> Vector3:
    return _skirt_point(joint, pose, parent_pose, 1.0)

func _constrain_skirt(joint: Dictionary, base: Quaternion, proposed: Quaternion) -> Quaternion:
    if joint.child < 0 or leg_pairs.is_empty(): return proposed
    if leg_segments.is_empty(): _cache_leg_segments()
    var parent_pose = rig.get_bone_global_pose(joint.parent)
    var angle = base.angle_to(proposed)
    var length = rig.get_bone_pose_position(joint.child).length()
    var fraction = 1.0
    var base_middle = _skirt_point(joint, base, parent_pose, 0.55)
    var base_tip = _skirt_point(joint, base, parent_pose, 1.0)
    # Frobenius norm bounds the basis operator norm even if inherited
    # non-uniform scale introduces shear; max column scale alone does not.
    var basis = parent_pose.basis
    var scale_bound = sqrt(basis.x.length_squared() + basis.y.length_squared() + basis.z.length_squared())
    # Guard two points per chain segment. Conservative rotation sweeps catch a tip
    # passing through a capsule even when both end poses are outside.
    for segment in leg_segments:
        var a: Vector3 = segment[0]
        var b: Vector3 = segment[1]
        for along in [0.55, 1.0]:
            var base_point = base_middle if along < 1.0 else base_tip
            var initial = _segment_distance(base_point, a, b)
            if initial < LEG_RADIUS: continue # Authored pose already intersects.
            var max_travel = 2.0 * length * along * sin(minf(angle, PI) * 0.5)
            if initial > LEG_RADIUS + max_travel: continue
            # Distance to a capsule is 1-Lipschitz. Bound the point's arc
            # speed so each advance remains on the safe side even for a narrow
            # crossing between fixed samples. If the iteration cap is reached,
            # keep the last proven-safe pose rather than jumping through it.
            var speed_bound = maxf(length * along * angle * scale_bound, 0.000001)
            var safe = 0.0
            for _i in range(20):
                var point = _skirt_point(joint, base.slerp(proposed, safe), parent_pose, along)
                var gap = _segment_distance(point, a, b) - LEG_RADIUS
                if gap <= 0.0001:
                    fraction = minf(fraction, safe)
                    break
                var advance = gap / speed_bound
                if safe + advance >= fraction:
                    safe = fraction
                    break
                safe += advance * 0.95
            fraction = minf(fraction, safe)
    return base.slerp(proposed, fraction)

func update(delta: float) -> void:
    if delta <= 0.0 or not rig or (quality == 0 and quality_fade_remaining <= 0.0): return
    time += delta
    var sample_dt = clampf(delta, 0.001, MAX_DT)
    if quality > 0 or quality_fade_remaining > 0.0: _cache_leg_segments()
    quality_fade_remaining = maxf(0.0, quality_fade_remaining - delta)
    for joint in joints:
        var target_weight = 1.0 if quality == 2 or (quality == 1 and joint.root) else 0.0
        joint.weight = move_toward(float(joint.weight), target_weight, delta * 4.0)
        if joint.weight <= 0.0:
            var last_pose = rig.get_bone_pose_rotation(joint.bone)
            if absf(last_pose.dot(joint.last)) > 0.999999: rig.set_bone_pose_rotation(joint.bone, joint.base)
            joint.last = rig.get_bone_pose_rotation(joint.bone)
            joint.x.angle = 0.0; joint.x.velocity = 0.0
            joint.z.angle = 0.0; joint.z.velocity = 0.0
            joint.initialized = false
            continue
        var current = rig.get_bone_pose_rotation(joint.bone)
        # Remove our last result only if it is still present; an animation
        # writing this bone in the meantime is treated as the new base pose.
        var base: Quaternion = joint.base if absf(current.dot(joint.last)) > 0.999999 else current
        joint.base = base
        var parent_pose: Transform3D = rig.global_transform * rig.get_bone_global_pose(joint.parent)
        var position = parent_pose.origin
        var parent_velocity = Vector3.ZERO
        var acceleration = Vector3.ZERO
        var gravity_local = parent_pose.basis.orthonormalized().inverse() * Vector3.DOWN
        if joint.initialized and position.distance_to(joint.position) < 0.75 and delta <= MAX_DT:
            parent_velocity = ((position - joint.position) / sample_dt).limit_length(10.0)
            acceleration = ((parent_velocity - joint.velocity) / sample_dt).limit_length(MAX_ACCEL)
        else:
            joint.filtered_accel = Vector3.ZERO
            joint.gravity_rest = gravity_local
        joint.initialized = true
        joint.position = position
        joint.velocity = parent_velocity
        joint.filtered_accel = (joint.filtered_accel as Vector3).lerp(acceleration, 1.0 - exp(-sample_dt * 16.0))
        var inverse_basis = parent_pose.basis.orthonormalized().inverse()
        var local_accel = inverse_basis * (joint.filtered_accel as Vector3)
        var local_velocity = inverse_basis * parent_velocity
        var gravity_change: Vector3 = gravity_local - joint.gravity_rest
        var limit: float = joint.limit
        var sensitivity: float = (0.006 if joint.kind == "hair" else 0.0035) * joint.variation
        var target_x = clampf(-local_accel.z * sensitivity - local_velocity.z * 0.009 - local_accel.y * sensitivity * 0.15 + gravity_change.z * 0.025, -limit, limit)
        var target_z = clampf(local_accel.x * sensitivity + local_velocity.x * 0.009 - gravity_change.x * 0.025, -limit, limit)
        var remaining = minf(delta, MAX_DT)
        while remaining > 0.000001:
            var step_dt = minf(remaining, 1.0 / 60.0)
            joint.x.step(target_x, step_dt, joint.stiffness, joint.damping, limit)
            joint.z.step(target_z, step_dt, joint.stiffness, joint.damping, limit)
            remaining -= step_dt
        var offset = Quaternion(Vector3.RIGHT, joint.x.angle) * Quaternion(Vector3.FORWARD, joint.z.angle)
        # A faint idle sway keeps hair roots alive even when standing still.
        # Applied after the spring so the simulated state can still settle.
        if joint.kind == "hair" and joint.root:
            offset = offset * Quaternion(Vector3.RIGHT, sin(time * 1.9 + float(joint.bone % 7) * 0.9) * 0.012)
        var result = base * Quaternion.IDENTITY.slerp(offset, float(joint.weight))
        if joint.kind == "skirt": result = _constrain_skirt(joint, base, result)
        joint.last = result.normalized()
        rig.set_bone_pose_rotation(joint.bone, joint.last)
