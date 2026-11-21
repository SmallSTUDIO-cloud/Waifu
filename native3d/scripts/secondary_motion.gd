extends RefCounted
# Small, bounded angular springs driven by animated parent acceleration.
# This is an approximation, not VRM spring-bone or soft-body simulation.
const SPRING = preload("res://scripts/spring.gd")
const MAX_DT = 0.10
const MAX_ACCEL = 28.0
var rig: Skeleton3D
var joints: Array[Dictionary] = []

func setup(skeleton: Skeleton3D) -> void:
    rig = skeleton
    for index in range(rig.get_bone_count()):
        var name = rig.get_bone_name(index)
        if name.ends_with("_end"): continue
        var kind = ""
        if name.begins_with("HairJoint"): kind = "hair"
        elif name.begins_with("J_Sec_") and "Skirt" in name: kind = "skirt"
        elif name.begins_with("J_Sec_") and "Sleeve" in name: kind = "sleeve"
        elif name.begins_with("J_Sec_") and "Bust" in name: kind = "body"
        if kind.is_empty(): continue
        var parent = rig.get_bone_parent(index)
        if parent < 0: continue
        var limit = 0.16 if kind == "hair" else (0.09 if kind == "skirt" else (0.08 if kind == "sleeve" else 0.025))
        var stiffness = 30.0 if kind == "hair" else (42.0 if kind == "body" else 36.0)
        var damping = 8.0 if kind == "hair" else 10.0
        joints.append({"bone": index, "parent": parent, "kind": kind,
            "rest": rig.get_bone_pose_rotation(index), "limit": limit,
            "stiffness": stiffness, "damping": damping, "x": SPRING.new(), "z": SPRING.new(),
            "initialized": false, "position": Vector3.ZERO, "velocity": Vector3.ZERO})

func reset() -> void:
    for joint in joints:
        joint.initialized = false
        joint.velocity = Vector3.ZERO
        joint.x.angle = 0.0; joint.x.velocity = 0.0
        joint.z.angle = 0.0; joint.z.velocity = 0.0
        rig.set_bone_pose_rotation(joint.bone, joint.rest)

func update(delta: float) -> void:
    if delta <= 0.0 or not rig: return
    var sample_dt = clampf(delta, 0.001, MAX_DT)
    for joint in joints:
        var parent_pose: Transform3D = rig.global_transform * rig.get_bone_global_pose(joint.parent)
        var position = parent_pose.origin
        var parent_velocity = Vector3.ZERO
        var acceleration = Vector3.ZERO
        if joint.initialized and position.distance_to(joint.position) < 0.75:
            parent_velocity = ((position - joint.position) / sample_dt).limit_length(12.0)
            acceleration = ((parent_velocity - joint.velocity) / sample_dt).limit_length(MAX_ACCEL)
        joint.initialized = true
        joint.position = position
        joint.velocity = parent_velocity
        var local_accel = parent_pose.basis.orthonormalized().inverse() * acceleration
        var limit: float = joint.limit
        var sensitivity: float = 0.006 if joint.kind == "hair" else (0.003 if joint.kind == "body" else 0.004)
        var target_x = clampf(-local_accel.z * sensitivity - local_accel.y * sensitivity * 0.25, -limit, limit)
        var target_z = clampf(local_accel.x * sensitivity, -limit, limit)
        # Substep at <= 60 Hz to avoid unstable or frame-rate-dependent leaps.
        var remaining = minf(delta, MAX_DT)
        while remaining > 0.000001:
            var step_dt = minf(remaining, 1.0 / 60.0)
            joint.x.step(target_x, step_dt, joint.stiffness, joint.damping, limit)
            joint.z.step(target_z, step_dt, joint.stiffness, joint.damping, limit)
            remaining -= step_dt
        var offset = Quaternion(Vector3.RIGHT, joint.x.angle) * Quaternion(Vector3.FORWARD, joint.z.angle)
        rig.set_bone_pose_rotation(joint.bone, (joint.rest as Quaternion) * offset)
