extends RefCounted
# Secondary offsets are composed after authored animation; no anatomy bones.
# Angular springs and approximate skirt tip/leg capsule constraints, not cloth.
const SPRING = preload("res://scripts/spring.gd")
const MAX_DT: float = 0.10
const MAX_ACCEL: float = 24.0
const LEG_RADIUS: float = 0.065
# 0 = off, 1 = root chains, 2 = all available secondary joints.
var quality: int = 2
var rig: Skeleton3D
var joints: Array[Dictionary] = []
var leg_pairs: Array = []

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
        # Stable per-chain variation without random noise or frame-dependent jitter.
        var variation = 0.93 + 0.035 * float(index % 5)
        var stiffness = (28.0 if kind == "hair" else 38.0) * variation
        var damping = (9.0 if kind == "hair" else 11.0) * variation
        var base = rig.get_bone_pose_rotation(index)
        joints.append({"bone": index, "parent": parent, "child": child, "kind": kind,
            "root": root_joint, "rest": base, "base": base, "last": base, "limit": limit,
            "stiffness": stiffness, "damping": damping, "variation": variation,
            "x": SPRING.new(), "z": SPRING.new(), "initialized": false,
            "position": Vector3.ZERO, "velocity": Vector3.ZERO, "filtered_accel": Vector3.ZERO,
            "gravity_rest": Vector3.ZERO})

func set_quality(level: int) -> void:
    var next = clampi(level, 0, 2)
    if next == quality: return
    reset()
    quality = next

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

func _segment_distance(point: Vector3, a: Vector3, b: Vector3) -> float:
    var ab = b - a
    var t = clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
    return point.distance_to(a + ab * t)

func _tip_position(joint: Dictionary, pose: Quaternion, parent_pose: Transform3D) -> Vector3:
    var child: int = joint.child
    return parent_pose * (rig.get_bone_pose_position(joint.bone) + Basis(pose) * rig.get_bone_pose_position(child))

func _constrain_skirt(joint: Dictionary, base: Quaternion, proposed: Quaternion) -> Quaternion:
    if joint.child < 0 or leg_pairs.is_empty(): return proposed
    var parent_pose = rig.get_bone_global_pose(joint.parent)
    var base_tip = _tip_position(joint, base, parent_pose)
    var proposed_tip = _tip_position(joint, proposed, parent_pose)
    var fraction = 1.0
    for pair in leg_pairs:
        var a: Vector3 = rig.get_bone_global_pose(pair[0]).origin
        var b: Vector3 = rig.get_bone_global_pose(pair[1]).origin
        # If the authored pose already penetrates the proxy, do not force the
        # garment away from its design. This cannot fix underlying skinning.
        if _segment_distance(base_tip, a, b) < LEG_RADIUS: continue
        if _segment_distance(proposed_tip, a, b) >= LEG_RADIUS: continue
        var lo = 0.0
        var hi = fraction
        for _i in range(6):
            var mid = (lo + hi) * 0.5
            var tip = _tip_position(joint, base.slerp(proposed, mid), parent_pose)
            if _segment_distance(tip, a, b) >= LEG_RADIUS: lo = mid
            else: hi = mid
        fraction = minf(fraction, lo)
    return base.slerp(proposed, fraction)

func update(delta: float) -> void:
    if delta <= 0.0 or not rig or quality == 0: return
    var sample_dt = clampf(delta, 0.001, MAX_DT)
    for joint in joints:
        if quality == 1 and not joint.root: continue
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
        var result = base * offset
        if joint.kind == "skirt": result = _constrain_skirt(joint, base, result)
        joint.last = result.normalized()
        rig.set_bone_pose_rotation(joint.bone, joint.last)
