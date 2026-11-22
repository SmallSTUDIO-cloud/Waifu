extends RefCounted
# Retarget authored rotations using each rig's GLOBAL rest orientation. Both
# skeletons share an ancestor, and each target local pose is reconstructed from
# the already-posed target parent. No motion-source mesh is rendered.
const SOURCE = preload("res://assets/quaternius-motion.glb")
const COMBO_SOURCE = preload("res://assets/quaternius-combo.glb")
const COMBO_CLIPS = ["Sword_Light_A", "Sword_Light_B", "Sword_Heavy_B", "Sword_Heavy_C"]
const COMBO_NAMES = ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r", "thigh_l", "calf_l", "foot_l", "ball_l", "thigh_r", "calf_r", "foot_r", "ball_r"]
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
var source_hips: int = -1
var target_hips: int = -1
var target_hips_rest_position: Vector3
var valid: bool = false
var combo_source: Node3D
var combo_rig: Skeleton3D
var combo_animator: AnimationPlayer
var combo_mapped: Array[Dictionary] = []
# Evaluated via deterministic preview flags before enabling either by default.
var candidate_formal_walk: bool = false
var candidate_sword_dash: bool = false

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
    # The authored sword-idle's first and last poses match, but its source
    # name lacks Godot's loop suffix, so the importer treats it as a one-shot.
    if animator.has_animation("Sword_Idle"):
        animator.get_animation("Sword_Idle").loop_mode = Animation.LOOP_LINEAR
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
    combo_source = COMBO_SOURCE.instantiate()
    combo_source.visible = false
    parent.add_child(combo_source)
    combo_rig = _find(combo_source, "Skeleton3D") as Skeleton3D
    combo_animator = _find(combo_source, "AnimationPlayer") as AnimationPlayer
    if combo_rig and combo_animator:
        combo_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
        var targets = BONE_MAP.keys()
        for i in range(targets.size()):
            var target_index = target_rig.find_bone(targets[i])
            var source_index = combo_rig.find_bone(COMBO_NAMES[i])
            if target_index >= 0 and source_index >= 0:
                combo_mapped.append({"target": target_index, "source": source_index,
                    "src_rest": combo_rig.get_bone_global_rest(source_index).basis.get_rotation_quaternion(),
                    "dst_rest": target_rig.get_bone_global_rest(target_index).basis.get_rotation_quaternion()})
        combo_mapped.sort_custom(func(a, b): return a.target < b.target)
    source_hips = source_rig.find_bone("DEF-hips")
    target_hips = target_rig.find_bone("J_Bip_C_Hips")
    if target_hips >= 0: target_hips_rest_position = target_rig.get_bone_pose_position(target_hips)
    valid = mapped.size() == BONE_MAP.size() and source_hips >= 0 and target_hips >= 0
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
    var use_combo = attack_progress >= 0.0 and dash_progress < 0.0 and combo_mapped.size() == BONE_MAP.size() and combo_animator != null
    if use_combo:
        use_combo = combo_animator.has_animation(COMBO_CLIPS[clampi(combo - 1, 0, 3)])
    var use_authored_dash = dash_progress >= 0.0 and candidate_sword_dash and combo_animator != null and combo_mapped.size() == BONE_MAP.size() and combo_animator.has_animation("Sword_Dash")
    if dash_progress >= 0.0:
        desired = "Sword_Dash" if use_authored_dash else "Jog_Fwd"
    elif attack_progress >= 0.0:
        desired = COMBO_CLIPS[clampi(combo - 1, 0, 3)] if use_combo else "Sword_Attack"
    elif speed > (0.07 if current in ["Walk", "Walk_Formal"] else 0.16):
        desired = "Walk_Formal" if candidate_formal_walk and animator.has_animation("Walk_Formal") else "Walk"
    var use_second_rig = use_combo or use_authored_dash
    var active_animator = combo_animator if use_second_rig else animator
    var active_rig = combo_rig if use_second_rig else source_rig
    var active_mapped = combo_mapped if use_second_rig else mapped
    if desired != current or (attack_progress >= 0.0 and current_combo != combo):
        var sync_gait = not use_second_rig and current in ["Walk", "Walk_Formal", "Jog_Fwd"] and desired in ["Walk", "Walk_Formal", "Jog_Fwd"]
        var phase = animator.current_animation_position / maxf(animator.current_animation_length, 0.001) if sync_gait else 0.0
        current = desired
        current_combo = combo
        active_animator.play(desired)
        if sync_gait:
            active_animator.seek(phase * active_animator.get_animation(desired).length, true)
    if attack_progress >= 0.0 and dash_progress < 0.0:
        active_animator.seek(clampf(attack_progress, 0.0, 1.0) * active_animator.current_animation_length, true)
    elif dash_progress >= 0.0:
        if use_authored_dash:
            active_animator.seek((0.06 + 0.38 * clampf(dash_progress, 0.0, 1.0)) * active_animator.current_animation_length, true)
        else:
            animator.seek((0.10 + 0.25 * clampf(dash_progress, 0.0, 1.0)) * animator.current_animation_length, true)
    else:
        var rate = 1.0 if desired == "Sword_Idle" else clampf(speed * 1.10, 0.55, 1.1)
        animator.advance(delta * rate)
    # The UAL mannequin faces +Z with its right side at -X; VRoid faces -Z
    # with its right side at +X. Account for that 180-degree facing difference.
    var source_to_target: Quaternion = Quaternion(Vector3.UP, PI) * (target_rig.global_basis.inverse() * active_rig.global_basis).get_rotation_quaternion()
    var source_height = source_rig.get_bone_global_pose(source_hips).origin.y - source_rig.get_bone_global_rest(source_hips).origin.y
    var pelvis_offset = clampf(source_height, -0.6, 0.12) if desired == "Roll" else 0.0
    var pelvis_position = target_rig.get_bone_pose_position(target_hips)
    target_rig.set_bone_pose_position(target_hips, pelvis_position.lerp(target_hips_rest_position + Vector3.UP * pelvis_offset, 1.0 - exp(-delta * 22.0)))
    var blend = 1.0 - exp(-delta * (26.0 if attack_progress >= 0.0 or dash_progress >= 0.0 else 14.0))
    for item in active_mapped:
        var source_pose = active_rig.get_bone_global_pose(item.source).basis.get_rotation_quaternion()
        var change: Quaternion = source_pose * (item.src_rest as Quaternion).inverse()
        var desired_global: Quaternion = source_to_target * change * source_to_target.inverse() * item.dst_rest
        var parent_index = target_rig.get_bone_parent(item.target)
        var parent_rotation: Quaternion = Quaternion.IDENTITY
        if parent_index >= 0:
            parent_rotation = target_rig.get_bone_global_pose(parent_index).basis.get_rotation_quaternion()
        var local: Quaternion = parent_rotation.inverse() * desired_global
        var old = target_rig.get_bone_pose_rotation(item.target)
        target_rig.set_bone_pose_rotation(item.target, old.slerp(local.normalized(), blend))
