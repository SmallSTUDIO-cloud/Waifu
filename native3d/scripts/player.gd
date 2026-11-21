extends CharacterBody3D

signal health_changed(value: int)
signal hit_enemy(enemy: Node3D, damage: int)
signal attack_swing(stage: int)

const AVATAR = preload("res://assets/avatar.glb")
const SPRING = preload("res://scripts/spring.gd")
const SWORD_TRAIL = preload("res://scripts/sword_trail.gd")
const AUTHORED_MOTION = preload("res://scripts/authored_motion.gd")
const SPEED: float = 4.1
const DASH_SPEED: float = 10.0
const ATTACK_DURATION: float = 0.48
const DASH_DURATION: float = 0.28
var control: Vector2 = Vector2.ZERO
var facing: Vector3 = Vector3(0, 0, -1)
var health: int = 100
var energy: float = 0.0
var attack_timer: float = 0.0
var attack_cooldown: float = 0.0
var attack_hit: bool = false
var combo: int = 0
var combo_timeout: float = 0.0
var dash_time: float = 0.0
var dash_cooldown: float = 0.0
var invulnerable: float = 0.0
var model_root: Node3D
var skeleton: Skeleton3D
var bone_rest: Dictionary = {}
var bone_indices: Dictionary = {}
var hair_bones: Array[int] = []
var skirt_bones: Array[int] = []
var body_bones: Array[int] = []
var springs: Dictionary = {}
var previous_motion: Vector3 = Vector3.ZERO
var visual_time: float = 0.0
var speed_ratio: float = 0.0
var enabled: bool = false
var pose_blend: float = 1.0
var gait_phase: float = 0.0
var turn_lean: float = 0.0
var attack_buffered: bool = false
var dash_direction: Vector3 = Vector3.FORWARD
var sword_grip: Node3D
var sword_trail: MeshInstance3D
var motion_driver: RefCounted

func _ready() -> void:
    collision_layer = 2
    collision_mask = 1
    var collider = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = 0.3
    capsule.height = 1.65
    collider.shape = capsule
    collider.position.y = 0.85
    add_child(collider)
    model_root = Node3D.new()
    add_child(model_root)
    var model = AVATAR.instantiate()
    model_root.add_child(model)
    skeleton = _find_skeleton(model)
    if skeleton:
        for i in range(skeleton.get_bone_count()):
            var bone_name: String = skeleton.get_bone_name(i)
            bone_rest[i] = skeleton.get_bone_pose_rotation(i)
            bone_indices[bone_name] = i
            if bone_name.begins_with("HairJoint"):
                hair_bones.append(i)
                springs[i] = SPRING.new()
            elif bone_name.begins_with("J_Sec_") and "Skirt" in bone_name:
                skirt_bones.append(i)
                springs[i] = SPRING.new()
            elif bone_name.begins_with("J_Sec_") and "Bust" in bone_name:
                body_bones.append(i)
                springs[i] = SPRING.new()
        _attach_sword()
        sword_trail = SWORD_TRAIL.new()
        add_child(sword_trail)
        if "--preview-authored" in OS.get_cmdline_user_args():
            var candidate = AUTHORED_MOTION.new()
            if candidate.setup(model_root, skeleton):
                motion_driver = candidate
            else:
                push_error("Authored motion skeleton mapping incomplete")

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node
    for child in node.get_children():
        var found = _find_skeleton(child)
        if found:
            return found
    return null

func _attach_sword() -> void:
    var hand = skeleton.find_bone("J_Bip_R_Hand")
    var anchor: Node3D
    if hand >= 0:
        var attachment = BoneAttachment3D.new()
        attachment.bone_name = "J_Bip_R_Hand"
        skeleton.add_child(attachment)
        anchor = attachment
    else:
        anchor = model_root
    # The grip is at the hand origin. Separate pieces give a readable sword
    # silhouette while keeping the model cheap enough for a mobile prototype.
    var grip = Node3D.new()
    sword_grip = grip
    anchor.add_child(grip)
    if hand < 0:
        grip.position = Vector3(0.4, 1.0, 0.0)
    grip.rotation_degrees = Vector3(0, 8, 65)
    _sword_piece(grip, Vector3(0, 0.055, 0), Vector3(0.045, 0.17, 0.045), Color(0.14, 0.065, 0.08), 0.2)
    _sword_piece(grip, Vector3(0, -0.045, 0), Vector3(0.19, 0.035, 0.09), Color(0.42, 0.25, 0.19), 0.8)
    _sword_piece(grip, Vector3(0, -0.48, 0), Vector3(0.065, 0.85, 0.035), Color(0.74, 0.82, 0.88), 0.85)
    _sword_piece(grip, Vector3(0, -0.48, -0.019), Vector3(0.012, 0.8, 0.009), Color(0.8, 0.055, 0.1), 0.3, true)

func _sword_piece(parent: Node3D, pos: Vector3, size: Vector3, color: Color, metal: float, glow: bool = false) -> void:
    var piece = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = size
    piece.mesh = mesh
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metal
    material.roughness = 0.3
    if glow:
        material.emission_enabled = true
        material.emission = color
    piece.material_override = material
    piece.position = pos
    parent.add_child(piece)

func _physics_process(delta: float) -> void:
    if not enabled:
        return
    attack_timer = maxf(0.0, attack_timer - delta)
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    combo_timeout = maxf(0.0, combo_timeout - delta)
    dash_time = maxf(0.0, dash_time - delta)
    dash_cooldown = maxf(0.0, dash_cooldown - delta)
    invulnerable = maxf(0.0, invulnerable - delta)
    if combo_timeout <= 0.0:
        combo = 0
    if attack_buffered and attack_cooldown <= 0.0 and dash_time <= 0.0:
        attack_buffered = false
        attack()
    var input_dir = Vector3(control.x, 0.0, control.y)
    input_dir = input_dir.limit_length(1.0)
    if dash_time <= 0.0 and input_dir.length_squared() > 0.01:
        facing = input_dir.normalized()
    var speed = DASH_SPEED if dash_time > 0.0 else SPEED * (0.45 if attack_timer > 0.0 else 1.0)
    var motion = dash_direction if dash_time > 0.0 else input_dir
    var target_velocity = motion * speed
    var acceleration: float = 42.0 if dash_time > 0.0 else (21.0 if input_dir.length_squared() > 0.01 else 28.0)
    var horizontal = Vector2(velocity.x, velocity.z).move_toward(Vector2(target_velocity.x, target_velocity.z), acceleration * delta)
    velocity.x = horizontal.x
    velocity.z = horizontal.y
    velocity.y -= 18.0 * delta
    move_and_slide()
    position.x = clampf(position.x, -8.5, 8.5)
    position.z = clampf(position.z, -8.5, 8.5)
    var target_ratio: float = 0.0 if dash_time > 0.0 else clampf(Vector2(velocity.x, velocity.z).length() / SPEED, 0.0, 1.0)
    speed_ratio = lerpf(speed_ratio, target_ratio, 1.0 - exp(-delta * 9.0))
    if facing.length_squared() > 0.0:
        var angle = atan2(-facing.x, -facing.z)
        var angle_error: float = wrapf(angle - model_root.rotation.y, -PI, PI)
        turn_lean = lerpf(turn_lean, clampf(-angle_error * 0.18, -0.18, 0.18) * speed_ratio, 1.0 - exp(-delta * 8.0))
        model_root.rotation.y = lerp_angle(model_root.rotation.y, angle, 1.0 - exp(-delta * 12.0))
    if attack_timer > 0.0 and attack_timer <= ATTACK_DURATION - 0.16 and not attack_hit:
        attack_hit = true
        attack_swing.emit(combo)
        for enemy in get_tree().get_nodes_in_group("enemies"):
            if is_instance_valid(enemy) and enemy.has_method("take_damage"):
                var offset: Vector3 = enemy.global_position - global_position
                if offset.length() < 2.0 and (offset.length() < 0.7 or facing.dot(offset.normalized()) > 0.12):
                    hit_enemy.emit(enemy, 2 if combo == 3 else 1)
                    energy = minf(100.0, energy + 20.0)
    _animate(delta)
    if sword_trail:
        var progress = 1.0 - attack_timer / ATTACK_DURATION
        sword_trail.update_trail(delta, sword_grip, attack_timer > 0.0 and progress >= 0.26 and progress <= 0.84)

func attack() -> bool:
    if not enabled or dash_time > 0.0:
        return false
    if attack_cooldown > 0.0:
        if attack_cooldown <= 0.16:
            attack_buffered = true
            return true
        return false
    combo = combo % 3 + 1
    combo_timeout = 1.1
    attack_timer = ATTACK_DURATION
    attack_cooldown = 0.40
    attack_hit = false
    return true

func dodge() -> bool:
    if not enabled or dash_cooldown > 0.0:
        return false
    # Dodge cancels the current attack, including its pending hit.
    attack_timer = 0.0
    attack_buffered = false
    if sword_trail: sword_trail.clear_trail()
    attack_hit = true
    attack_cooldown = 0.0
    var requested = Vector3(control.x, 0, control.y)
    dash_direction = requested.normalized() if requested.length_squared() > 0.01 else facing
    facing = dash_direction
    dash_time = DASH_DURATION
    dash_cooldown = 1.0
    invulnerable = 0.32
    return true

func take_damage(amount: int) -> void:
    if not enabled or invulnerable > 0.0:
        return
    health = maxi(0, health - amount)
    invulnerable = 0.6
    health_changed.emit(health)

# All rotations are additive to the imported bone poses; no animation files
# are baked into the temporary avatar. Blending prevents state transitions from
# snapping while the attack timeline keeps wind-up, strike and recovery distinct.
func _pose(bone_name: String, angles: Vector3) -> void:
    var index: int = bone_indices.get(bone_name, -1)
    if index >= 0 and bone_rest.has(index):
        var target: Quaternion = bone_rest[index] * Quaternion.from_euler(angles)
        skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index).slerp(target, pose_blend))

func _attack_pose() -> float:
    if attack_timer <= 0.0:
        return 0.0
    var t = 1.0 - attack_timer / ATTACK_DURATION
    if t < 0.30:
        return -smoothstep(0.0, 0.30, t) * 0.65
    if t < 0.62:
        return lerpf(-0.65, 1.0, smoothstep(0.30, 0.62, t))
    return 1.0 - smoothstep(0.62, 1.0, t)

func _animate(delta: float) -> void:
    if not skeleton:
        return
    visual_time += delta
    pose_blend = 1.0 - exp(-delta * 18.0)
    # Phase follows actual ground speed, so a slow stick deflection doesn't
    # produce a fast running cycle while the character barely moves.
    gait_phase = fposmod(gait_phase + delta * speed_ratio * 9.5, TAU)
    if motion_driver:
        var attack_progress = 1.0 - attack_timer / ATTACK_DURATION if attack_timer > 0.0 else -1.0
        var dash_progress = 1.0 - dash_time / DASH_DURATION if dash_time > 0.0 else -1.0
        motion_driver.update(delta, speed_ratio, attack_progress, dash_progress, combo)
    else:
        var gait: float = sin(gait_phase)
        var stride: float = gait * speed_ratio
        var lift_l: float = pow(maxf(0.0, -gait), 1.3) * speed_ratio
        var lift_r: float = pow(maxf(0.0, gait), 1.3) * speed_ratio
        var swing: float = _attack_pose()
        var side: float = -1.0 if combo == 2 else 1.0
        var arm_raise: float = clampf(absf(swing) * 1.3, 0.0, 1.0)
        var dash: float = sin(PI * (1.0 - dash_time / DASH_DURATION)) if dash_time > 0.0 else 0.0
        var run: float = speed_ratio * (1.0 - dash * 0.5)
        model_root.position.y = 0.018 * (1.0 - cos(gait_phase * 2.0)) * run - 0.19 * dash
        model_root.rotation.x = lerpf(model_root.rotation.x, -0.42 * dash - 0.08 * run, pose_blend)
        model_root.rotation.z = lerpf(model_root.rotation.z, turn_lean, pose_blend)
        _pose("J_Bip_C_Hips", Vector3(0.08 * run + 0.34 * dash, swing * 0.20 * side + stride * 0.075, stride * 0.05))
        _pose("J_Bip_C_Spine", Vector3(-0.10 * run + 0.20 * dash - arm_raise * 0.08, -swing * 0.45 * side, -stride * 0.025 - swing * 0.08))
        _pose("J_Bip_C_Chest", Vector3(0.025 * sin(visual_time * 2.2) * (1.0 - run), -swing * 0.28 * side - stride * 0.08, 0.08 * dash))
        _pose("J_Bip_C_Head", Vector3(-0.12 * dash, swing * 0.12 * side, 0.0))
        _pose("J_Bip_L_UpperLeg", Vector3(stride * 0.62 - 0.65 * dash, 0, -0.04))
        _pose("J_Bip_R_UpperLeg", Vector3(-stride * 0.62 + 0.40 * dash, 0, 0.04))
        _pose("J_Bip_L_LowerLeg", Vector3(-lift_l * 0.70 - 0.75 * dash, 0, 0))
        _pose("J_Bip_R_LowerLeg", Vector3(-lift_r * 0.70 - 0.35 * dash, 0, 0))
        _pose("J_Bip_L_Foot", Vector3(lift_l * 0.35 + 0.15 * dash, 0, 0))
        _pose("J_Bip_R_Foot", Vector3(lift_r * 0.35 + 0.15 * dash, 0, 0))
        _pose("J_Bip_L_UpperArm", Vector3(-0.08 - dash * 0.30, stride * 0.36 - 0.35 * dash - swing * 0.20 * side, 1.12))
        _pose("J_Bip_L_LowerArm", Vector3(0, -0.20, 0.30 + 0.35 * dash))
        # Shoulder, elbow and wrist all contribute to the sword arc.
        _pose("J_Bip_R_UpperArm", Vector3(-0.32 * swing if combo == 3 else -0.10 * swing, -0.30 - stride * 0.12 + swing * 1.15 * side, -1.08 + arm_raise * (1.20 if combo == 3 else 0.95)))
        _pose("J_Bip_R_LowerArm", Vector3(0, 0.25 + swing * 0.70 * side, -0.38 - 0.25 * dash - 0.15 * arm_raise))
        _pose("J_Bip_R_Hand", Vector3(0.10, -0.15 + swing * 0.30 * side, 0.12))
    # Procedural spring on the imported secondary bones. Motion lags acceleration
    # and settles with damping; limits prevent instability at low mobile frame rates.
    var current_motion: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
    var acceleration: Vector3 = (current_motion - previous_motion).limit_length(8.0)
    previous_motion = current_motion
    var lag: float = clampf(speed_ratio * 0.09 + acceleration.length() * 0.009, 0.0, 0.18)
    for index in hair_bones:
        var hair_angle: float = springs[index].step(lag * 0.5, delta, 26.0, 7.0, 0.16)
        skeleton.set_bone_pose_rotation(index, bone_rest[index] * Quaternion(Vector3.RIGHT, hair_angle))
    for index in skirt_bones:
        var cloth_angle: float = springs[index].step(lag * 0.3, delta, 34.0, 9.0, 0.12)
        skeleton.set_bone_pose_rotation(index, bone_rest[index] * Quaternion(Vector3.RIGHT, cloth_angle))
    for index in body_bones:
        var body_angle: float = springs[index].step(lag * 0.08, delta, 45.0, 11.0, 0.035)
        skeleton.set_bone_pose_rotation(index, bone_rest[index] * Quaternion(Vector3.RIGHT, body_angle))
