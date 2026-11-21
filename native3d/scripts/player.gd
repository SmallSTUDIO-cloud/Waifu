extends CharacterBody3D

signal health_changed(value: int)
signal hit_enemy(enemy: Node3D, damage: int)

const AVATAR = preload("res://assets/avatar.glb")
const SPEED: float = 4.1
const DASH_SPEED: float = 10.0
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
var hair_bones: Array[int] = []
var skirt_bones: Array[int] = []
var body_bones: Array[int] = []
var spring: float = 0.0
var spring_velocity: float = 0.0
var visual_time: float = 0.0
var speed_ratio: float = 0.0
var enabled: bool = false

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
            if bone_name.begins_with("HairJoint"):
                hair_bones.append(i)
            elif bone_name.begins_with("J_Sec_") and "Skirt" in bone_name:
                skirt_bones.append(i)
            elif bone_name.begins_with("J_Sec_") and "Bust" in bone_name:
                body_bones.append(i)
        _attach_sword()

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
    var sword = MeshInstance3D.new()
    var blade = BoxMesh.new()
    blade.size = Vector3(0.045, 0.95, 0.09)
    sword.mesh = blade
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(0.82, 0.88, 0.92)
    material.metallic = 0.7
    material.roughness = 0.25
    material.emission_enabled = true
    material.emission = Color(0.4, 0.015, 0.025)
    sword.material_override = material
    sword.position = Vector3(0.03, -0.48, 0.0) if hand >= 0 else Vector3(0.4, 1.0, 0.0)
    anchor.add_child(sword)

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
    var input_dir = Vector3(control.x, 0.0, control.y)
    input_dir = input_dir.limit_length(1.0)
    if dash_time <= 0.0 and input_dir.length_squared() > 0.01:
        facing = input_dir.normalized()
    var speed = DASH_SPEED if dash_time > 0.0 else SPEED * (0.45 if attack_timer > 0.0 else 1.0)
    var motion = facing if dash_time > 0.0 else input_dir
    velocity.x = motion.x * speed
    velocity.z = motion.z * speed
    velocity.y -= 18.0 * delta
    move_and_slide()
    position.x = clampf(position.x, -8.5, 8.5)
    position.z = clampf(position.z, -8.5, 8.5)
    speed_ratio = lerpf(speed_ratio, minf(motion.length(), 1.0), minf(1.0, delta * 10.0))
    if facing.length_squared() > 0.0:
        var angle = atan2(-facing.x, -facing.z)
        model_root.rotation.y = lerp_angle(model_root.rotation.y, angle, minf(1.0, delta * 14.0))
    if attack_timer > 0.0 and attack_timer < 0.30 and not attack_hit:
        attack_hit = true
        for enemy in get_tree().get_nodes_in_group("enemies"):
            if is_instance_valid(enemy) and enemy.has_method("take_damage"):
                var offset: Vector3 = enemy.global_position - global_position
                if offset.length() < 2.0 and (offset.length() < 0.7 or facing.dot(offset.normalized()) > 0.12):
                    hit_enemy.emit(enemy, 2 if combo == 3 else 1)
                    energy = minf(100.0, energy + 20.0)
    _animate(delta)

func attack() -> void:
    if not enabled or attack_cooldown > 0.0 or dash_time > 0.0:
        return
    combo = combo % 3 + 1
    combo_timeout = 1.1
    attack_timer = 0.42
    attack_cooldown = 0.34
    attack_hit = false

func dodge() -> void:
    if not enabled or dash_cooldown > 0.0:
        return
    dash_time = 0.23
    dash_cooldown = 1.0
    invulnerable = 0.32

func take_damage(amount: int) -> void:
    if not enabled or invulnerable > 0.0:
        return
    health = maxi(0, health - amount)
    invulnerable = 0.6
    health_changed.emit(health)

func _pose(bone_name: String, axis: Vector3, angle: float) -> void:
    var index = skeleton.find_bone(bone_name)
    if index >= 0 and bone_rest.has(index):
        skeleton.set_bone_pose_rotation(index, bone_rest[index] * Quaternion(axis, angle))

func _animate(delta: float) -> void:
    if not skeleton:
        return
    visual_time += delta
    var stride: float = sin(visual_time * 10.0) * speed_ratio
    _pose("J_Bip_L_UpperLeg", Vector3.RIGHT, stride * 0.45)
    _pose("J_Bip_R_UpperLeg", Vector3.RIGHT, -stride * 0.45)
    _pose("J_Bip_L_LowerLeg", Vector3.RIGHT, maxf(0.0, -stride) * 0.35)
    _pose("J_Bip_R_LowerLeg", Vector3.RIGHT, maxf(0.0, stride) * 0.35)
    _pose("J_Bip_L_UpperArm", Vector3.FORWARD, -0.95 + stride * 0.15)
    _pose("J_Bip_R_UpperArm", Vector3.FORWARD, 0.95 - stride * 0.15 - sin((0.42 - attack_timer) * PI / 0.42) * (1.2 if attack_timer > 0.0 else 0.0))
    # Damped secondary motion, bounded for stability. This is not full soft-body physics.
    var target: float = speed_ratio * 0.08 + (0.10 if dash_time > 0.0 else 0.0)
    spring_velocity += ((target - spring) * 30.0 - spring_velocity * 8.0) * delta
    spring = clampf(spring + spring_velocity * delta, -0.16, 0.16)
    for index in hair_bones:
        skeleton.set_bone_pose_rotation(index, bone_rest[index] * Quaternion(Vector3.RIGHT, spring * 0.2))
    for index in skirt_bones:
        skeleton.set_bone_pose_rotation(index, bone_rest[index] * Quaternion(Vector3.RIGHT, spring * 0.12))
    for index in body_bones:
        skeleton.set_bone_pose_rotation(index, bone_rest[index] * Quaternion(Vector3.RIGHT, spring * 0.04))
