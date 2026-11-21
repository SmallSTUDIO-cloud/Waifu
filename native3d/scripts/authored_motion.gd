extends RefCounted
# Retarget authored rotations using each rig's GLOBAL rest orientation. Both
# skeletons share an ancestor, and each target local pose is reconstructed from
# the already-posed target parent. No motion-source mesh is rendered.
const SOURCE = preload("res://assets/quaternius-motion.glb")
const BONE_MAP = {
    "J_Bip_C_Hips": "DEF-hips",
    "J_Bip_C_Spine": "DEF-spine.001",
    "J_Bip_C_Chest": "DEF-spine.002",
    "J_Bip_C_UpperChest": "DEF-spine.003",
    "J_Bip_C_Neck": "DEF-neck", "J_Bip_C_Head": "DEF-head",
    "J_Bip_L_Shoulder": "DEF-shoulder.L", "J_Bip_L_UpperArm": "DEF-upper_arm.L",
    "J_Bip_L_LowerArm": "DEF-forearm.L", "J_Bip_L_Hand": "DEF-hand.L",
    "J_Bip_R_Shoulder": "DEF-shoulder.R", "J_Bip_R_UpperArm": "DEF-upper_arm.R",
    "J_Bip_R_LowerArm": "DEF-forearm.R", "J_Bip_R_Hand": "DEF-hand.R",
    "J_Bip_L_UpperLeg": "DEF-thigh.L", "J_Bip_L_LowerLeg": "DEF-shin.L",
    "J_Bip_L_Foot": "DEF-foot.L", "J_Bip_L_ToeBase": "DEF-toe.L",
    "J_Bip_R_UpperLeg": "DEF-thigh.R", "J_Bip_R_LowerLeg": "DEF-shin.R",
    "J_Bip_R_Foot": "DEF-foot.R", "J_Bip_R_ToeBase": "DEF-toe.R",
}
var source: Node3D
var source_rig: Skeleton3D
var target_rig: Skeleton3D
var animator: AnimationPlayer
var mapped: Array[Dictionary] = []
var current: String = ""
var current_combo: int = 0
var valid: bool = false

func setup(parent: Node3D, target: Skeleton3D) -> bool:
    target_rig = target
    source = SOURCE.instantiate()
    source.visible = false
    parent.add_child(source)
    source_rig = _find(source, "Skeleton3D") as Skeleton3D
    animator = _find(source, "AnimationPlayer") as AnimationPlayer
    if not source_rig or not animator:
        return false
    animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    # A parent-first iteration is essential when reconstructing local rotations.
    for index in range(target_rig.get_bone_count()):
        var target_name = target_rig.get_bone_name(index)
        if not BONE_MAP.has(target_name):
            continue
        var src = source_rig.find_bone(BONE_MAP[target_name])
        if src < 0:
            continue
        mapped.append({"target": index, "source": src,
            "src_rest": source_rig.get_bone_global_rest(src).basis.get_rotation_quaternion(),
            "dst_rest": target_rig.get_bone_global_rest(index).basis.get_rotation_quaternion()})
    valid = mapped.size() == BONE_MAP.size()
    return valid

func _find(node: Node, type: String) -> Node:
    if node.is_class(type): return node
    for child in node.get_children():
        var found = _find(child, type)
        if found: return found
    return null

func update(delta: float, speed: float, attack_progress: float, dash_progress: float, combo: int) -> void:
    if not valid: return
    var desired = "Sword_Idle"
    if dash_progress >= 0.0: desired = "Roll"
    elif attack_progress >= 0.0: desired = "Sword_Attack"
    elif speed > 0.62: desired = "Jog_Fwd_Loop"
    elif speed > 0.10: desired = "Walk_Loop"
    if desired != current or (desired == "Sword_Attack" and current_combo != combo):
        current = desired
        current_combo = combo
        animator.play(desired)
    if desired == "Sword_Attack":
        animator.seek(clampf(attack_progress, 0.0, 1.0) * animator.current_animation_length, true)
    elif desired == "Roll":
        animator.seek(clampf(dash_progress, 0.0, 1.0) * animator.current_animation_length, true)
    else:
        var rate = 1.0 if desired == "Sword_Idle" else clampf(speed * 1.35, 0.55, 1.3)
        animator.advance(delta * rate)
    var source_to_target: Quaternion = (target_rig.global_basis.inverse() * source_rig.global_basis).get_rotation_quaternion()
    var blend = 1.0 - exp(-delta * (26.0 if attack_progress >= 0.0 or dash_progress >= 0.0 else 14.0))
    for item in mapped:
        var source_pose = source_rig.get_bone_global_pose(item.source).basis.get_rotation_quaternion()
        var change: Quaternion = source_pose * (item.src_rest as Quaternion).inverse()
        var desired_global: Quaternion = source_to_target * change * source_to_target.inverse() * item.dst_rest
        var parent_index = target_rig.get_bone_parent(item.target)
        var parent_rotation: Quaternion = Quaternion.IDENTITY
        if parent_index >= 0:
            parent_rotation = target_rig.get_bone_global_pose(parent_index).basis.get_rotation_quaternion()
        var local: Quaternion = parent_rotation.inverse() * desired_global
        var old = target_rig.get_bone_pose_rotation(item.target)
        target_rig.set_bone_pose_rotation(item.target, old.slerp(local.normalized(), blend))
