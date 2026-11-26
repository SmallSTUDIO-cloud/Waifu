extends CharacterBody3D

signal health_changed(value: int)
signal hit_enemy(enemy: Node3D, damage: int)
signal attack_swing(stage: int)

const AVATAR = preload("res://assets/avatar.glb")
const SECONDARY = preload("res://scripts/secondary_motion.gd")
const SWORD_TRAIL = preload("res://scripts/sword_trail.gd")
const WIGGLE = preload("res://scripts/wiggle_physics.gd")
const AUTHORED_MOTION = preload("res://scripts/authored_motion.gd")
const SPEED: float = 2.8
const SPRINT_SPEED: float = 5.4
const SPRINT_MIN_STICK: float = 0.86
const SPRINT_MIN_UP: float = -0.55
const DASH_SPEED: float = 10.0
const ATTACK_DURATION: float = 0.58
const DASH_DURATION: float = 0.27
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
var secondary_motion: RefCounted
var wiggle: RefCounted
var physics_quality: int = 2
var visual_time: float = 0.0
var speed_ratio: float = 0.0
var sprint_requested: bool = false
var sprinting: bool = false
var sprint_blend: float = 0.0
var enabled: bool = false
var pose_blend: float = 1.0
var gait_phase: float = 0.0
var gait_rate: float = 0.0
var turn_lean: float = 0.0
var last_horiz: Vector2 = Vector2.ZERO
var accel_lean: float = 0.0
var attack_buffered: bool = false
var dash_direction: Vector3 = Vector3.FORWARD
var sword_grip: Node3D
var grip_base_rotation: Vector3 = Vector3(0, 8, 35)
var aura_material: StandardMaterial3D
var aura_mesh: MeshInstance3D
var sword_trail: MeshInstance3D
var motion_driver: RefCounted
var shadow_root: Node3D
var shadow_skeleton: Skeleton3D
var shadow_material: StandardMaterial3D
var shadow_remaining: float = 0.0
# Enabled only by the opt-in debug profiler marker.
var profile_secondary: bool = false
var profile_secondary_us: int = 0
var profile_secondary_max_us: int = 0
var profile_secondary_steps: int = 0
var profile_shadow_us: int = 0
var profile_shadow_count: int = 0

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
        secondary_motion = SECONDARY.new()
        secondary_motion.setup(skeleton)
        physics_quality = clampi(int(ProjectSettings.get_setting("secondary_motion/quality", 2)), 0, 2)
        secondary_motion.set_quality(physics_quality)
        # Real jiggle physics (WiggleBone addon) drives hair/skirt/sleeve at FULL.
        wiggle = WIGGLE.new()
        wiggle.setup(skeleton)
        wiggle.set_active(physics_quality == 2)
        _attach_sword()
        # Profiling can disable the entire shadow instance, allowing a device
        # comparison of both memory and rendering costs. Normal builds keep it.
        var shadow_enabled = not OS.is_debug_build() or bool(ProjectSettings.get_setting("secondary_motion/profile_shadow_enabled", true))
        if shadow_enabled: _create_dodge_shadow()
        sword_trail = SWORD_TRAIL.new()
        add_child(sword_trail)
        var candidate = AUTHORED_MOTION.new()
        if candidate.setup(model_root, skeleton):
            motion_driver = candidate
            # Settle into the ready pose immediately, including on the menu.
            for i in range(25):
                motion_driver.update(1.0 / 60.0, 0.0, -1.0, -1.0, 0)
        else:
            if candidate.source: candidate.source.queue_free()
            push_warning("Authored motion unavailable; using procedural fallback")


func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node
    for child in node.get_children():
        var found = _find_skeleton(child)
        if found:
            return found
    return null

func _create_dodge_shadow() -> void:
    # Reuse one skinned silhouette rather than allocating copies each dodge.
    shadow_root = Node3D.new()
    get_parent().add_child.call_deferred(shadow_root)
    var avatar = AVATAR.instantiate()
    shadow_root.add_child(avatar)
    shadow_skeleton = _find_skeleton(avatar)
    shadow_material = StandardMaterial3D.new()
    shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    shadow_material.albedo_color = Color(0.025, 0.015, 0.055, 0.75)
    shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _shadow_meshes(avatar)
    shadow_root.visible = false

func _shadow_meshes(node: Node) -> void:
    if node is MeshInstance3D:
        node.material_override = shadow_material
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for child in node.get_children():
        _shadow_meshes(child)

func _show_dodge_shadow() -> void:
    if not shadow_root or not shadow_root.is_inside_tree() or not shadow_skeleton:
        return
    var shadow_started = Time.get_ticks_usec() if profile_secondary else 0
    shadow_root.global_transform = model_root.global_transform
    for i in range(mini(skeleton.get_bone_count(), shadow_skeleton.get_bone_count())):
        shadow_skeleton.set_bone_pose_position(i, skeleton.get_bone_pose_position(i))
        shadow_skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i))
        shadow_skeleton.set_bone_pose_scale(i, skeleton.get_bone_pose_scale(i))
    shadow_remaining = 0.30
    shadow_material.albedo_color.a = 0.75
    shadow_root.visible = true
    if profile_secondary:
        profile_shadow_us += Time.get_ticks_usec() - shadow_started
        profile_shadow_count += 1

func set_physics_quality(level: int) -> void:
    physics_quality = clampi(level, 0, 2)
    secondary_motion.set_quality(physics_quality)
    if wiggle:
        wiggle.set_active(physics_quality == 2)

func reset_secondary() -> void:
    if secondary_motion:
        secondary_motion.reset()
    if wiggle:
        wiggle.reset_all()

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
    # The grip node sits at the hand origin; the blade extends along -Y.
    var grip = Node3D.new()
    sword_grip = grip
    anchor.add_child(grip)
    if hand < 0:
        grip.position = Vector3(0.4, 1.0, 0.0)
    if hand >= 0:
        grip.position = Vector3(0.038, 0.0, -0.005)
    grip_base_rotation = Vector3(0, 8, 35)
    grip.rotation_degrees = grip_base_rotation
    _pose_gripping_fingers()
    # Grip: leather-wrapped cylinder with wrap rings and a pommel.
    _sword_cylinder(grip, Vector3(0, 0.0, 0), 0.017, 0.12, Color(0.23, 0.11, 0.10), 0.35, 0.85)
    _sword_cylinder(grip, Vector3(0, 0.034, 0), 0.0195, 0.012, Color(0.12, 0.06, 0.05), 0.30, 0.90)
    _sword_cylinder(grip, Vector3(0, -0.034, 0), 0.0195, 0.012, Color(0.12, 0.06, 0.05), 0.30, 0.90)
    _sword_sphere(grip, Vector3(0, 0.078, 0), 0.024, Color(0.55, 0.42, 0.18), 0.9, 0.25)
    # Cross-guard: a wide gold bar with a center boss.
    _sword_piece(grip, Vector3(0, 0.062, 0), Vector3(0.15, 0.020, 0.032), Color(0.62, 0.47, 0.20), 0.9, 0.30)
    _sword_piece(grip, Vector3(0, 0.062, 0), Vector3(0.05, 0.028, 0.05), Color(0.70, 0.54, 0.24), 0.9, 0.30)
    _make_blade(grip)
    # Aura: an additive hex shell hugging the blade, pulsed in _animate.
    var aura = MeshInstance3D.new()
    var aura_shape = CylinderMesh.new()
    aura_shape.top_radius = 0.055
    aura_shape.bottom_radius = 0.028
    aura_shape.height = 0.98
    aura_shape.radial_segments = 6
    aura.mesh = aura_shape
    aura.position = Vector3(0, -0.44, 0)
    aura_material = StandardMaterial3D.new()
    aura_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    aura_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    aura_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    aura_material.albedo_color = Color(0.55, 0.25, 1.0, 0.10)
    aura_material.emission_enabled = true
    aura_material.emission = Color(0.45, 0.15, 1.0)
    aura_material.emission_energy_multiplier = 0.6
    aura.material_override = aura_material
    aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    aura_mesh = aura
    grip.add_child(aura)

func _pose_gripping_fingers() -> void:
    # VRoid fingers are unanimated by the motion source. Curl them around the
    # handle instead of leaving the hand in the imported open T-pose.
    for finger in ["Index", "Middle", "Ring", "Little"]:
        for part in range(1, 4):
            var bone = skeleton.find_bone("J_Bip_R_%s%d" % [finger, part])
            if bone >= 0:
                var curl = 0.70 if part == 1 else 0.82
                skeleton.set_bone_pose_rotation(bone, bone_rest[bone] * Quaternion(Vector3.FORWARD, curl))
    for part in range(1, 4):
        var bone = skeleton.find_bone("J_Bip_R_Thumb%d" % part)
        if bone >= 0:
            skeleton.set_bone_pose_rotation(bone, bone_rest[bone] * Quaternion.from_euler(Vector3(0, -0.28, -0.35)))

func _make_blade(parent: Node3D) -> void:
    # A tapered prism with a raised center fuller reads as a real blade at
    # close range while staying cheap enough for a mobile prototype.
    var outline = [Vector2(-0.034, 0.05), Vector2(0.034, 0.05),
        Vector2(0.030, -0.69), Vector2(0.005, -0.88), Vector2(-0.026, -0.78)]
    var surface = SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for side in [-1.0, 1.0]:
        for i in range(1, outline.size() - 1):
            var order = [0, i + 1, i] if side < 0 else [0, i, i + 1]
            for index in order:
                var point: Vector2 = outline[index]
                surface.add_vertex(Vector3(point.x, point.y, side * 0.011))
    for i in range(outline.size()):
        var a: Vector2 = outline[i]
        var b: Vector2 = outline[(i + 1) % outline.size()]
        var v0 = Vector3(a.x, a.y, -0.011); var v1 = Vector3(b.x, b.y, -0.011)
        var v2 = Vector3(a.x, a.y, 0.011); var v3 = Vector3(b.x, b.y, 0.011)
        for vertex in [v0, v1, v2, v1, v3, v2]: surface.add_vertex(vertex)
    surface.generate_normals()
    var blade = MeshInstance3D.new()
    blade.mesh = surface.commit()
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(0.74, 0.82, 0.88)
    material.metallic = 0.82
    material.roughness = 0.25
    blade.material_override = material
    parent.add_child(blade)
    # Center fuller ridge.
    _sword_piece(parent, Vector3(0, -0.40, 0.012), Vector3(0.010, 0.78, 0.004), Color(0.42, 0.48, 0.55), 0.85, 0.35)
    # Glowing power edges along both sides of the blade.
    _sword_piece(parent, Vector3(0.028, -0.40, 0.0125), Vector3(0.005, 0.80, 0.003), Color(0.58, 0.25, 1.0), 0.3, true)
    _sword_piece(parent, Vector3(-0.028, -0.40, 0.0125), Vector3(0.005, 0.80, 0.003), Color(0.58, 0.25, 1.0), 0.3, true)

func _sword_cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, metal: float, rough: float) -> void:
    var piece = MeshInstance3D.new()
    var mesh = CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius * 1.12
    mesh.height = height
    mesh.radial_segments = 10
    piece.mesh = mesh
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metal
    material.roughness = rough
    piece.material_override = material
    piece.position = pos
    parent.add_child(piece)

func _sword_sphere(parent: Node3D, pos: Vector3, radius: float, color: Color, metal: float, rough: float) -> void:
    var piece = MeshInstance3D.new()
    var mesh = SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 10
    mesh.rings = 6
    piece.mesh = mesh
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metal
    material.roughness = rough
    piece.material_override = material
    piece.position = pos
    parent.add_child(piece)

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
    if shadow_remaining > 0.0:
        shadow_remaining = maxf(0.0, shadow_remaining - delta)
        shadow_material.albedo_color.a = 0.75 * shadow_remaining / 0.30
        if shadow_remaining <= 0.0: shadow_root.visible = false
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
    sprinting = sprint_requested and dash_time <= 0.0 and attack_timer <= 0.0
    var speed = DASH_SPEED if dash_time > 0.0 else (SPRINT_SPEED if sprinting else SPEED * (0.45 if attack_timer > 0.0 else 1.0))
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
    if attack_timer > 0.0 and attack_timer <= ATTACK_DURATION * 0.60 and not attack_hit:
        attack_hit = true
        attack_swing.emit(combo)
        for enemy in get_tree().get_nodes_in_group("enemies"):
            if is_instance_valid(enemy) and enemy.has_method("take_damage"):
                var offset: Vector3 = enemy.global_position - global_position
                if offset.length() < 2.0 and (offset.length() < 0.7 or facing.dot(offset.normalized()) > 0.12):
                    hit_enemy.emit(enemy, 2 if combo == 4 else 1)
                    energy = minf(100.0, energy + 20.0)
    # Forward acceleration measured from real velocity change; feeds the
    # accel/decel body lean and the sword inertia wobble (momentum reads).
    var horiz_now := Vector2(velocity.x, velocity.z)
    var accel_f := 0.0
    if delta > 0.0:
        accel_f = clampf((horiz_now - last_horiz).dot(Vector2(facing.x, facing.z)) / delta, -30.0, 30.0)
    last_horiz = horiz_now
    accel_lean = lerpf(accel_lean, clampf(accel_f * 0.006, -0.08, 0.12), 1.0 - exp(-delta * 6.0))
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
    combo = combo % 4 + 1
    combo_timeout = 1.1
    attack_timer = ATTACK_DURATION
    attack_cooldown = 0.50
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
    _show_dodge_shadow()
    dash_time = DASH_DURATION
    dash_cooldown = 1.0
    invulnerable = DASH_DURATION
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

func _pose_sprint(bone_name: String, angles: Vector3) -> void:
    # Sprint pose layers on top of the authored walk: slerp toward it by
    # sprint_blend so it fades in/out instead of snapping.
    var index: int = bone_indices.get(bone_name, -1)
    if index >= 0 and bone_rest.has(index):
        var target: Quaternion = bone_rest[index] * Quaternion.from_euler(angles)
        skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index).slerp(target, sprint_blend))

func _sprint_pose(phase: float) -> void:
    # Grounded anime sprint: one full stride per TAU of `phase`, left foot
    # plants at phase 0. The avatar rests in a T-pose, so local Z is the
    # abduction axis: the sprint pose adducts the upper arms DOWN along the
    # body (z ~ +/-1.05) and pumps them fore/aft on X with bent elbows.
    # Thighs swing about the hip; the knee flexes hardest
    # mid-swing and is near-straight at contact; arms pump in opposition to
    # the legs with bent elbows along a compact path; pelvis yaws/rolls
    # slightly while the chest counter-rotates and the head stays level.
    # Only J_Bip_* body bones are written here — WiggleBone owns the
    # HairJoint*/J_Sec_* hair/skirt/sleeve chains, so no double animation.
    var s := sin(phase)
    var c := cos(phase)
    var thigh := 0.75 * c
    var knee_l := 0.12 + 1.55 * pow(maxf(0.0, -s), 1.4)
    var knee_r := 0.12 + 1.55 * pow(maxf(0.0, s), 1.4)
    var foot_l := 0.55 * pow(maxf(0.0, -s), 1.2)
    var foot_r := 0.55 * pow(maxf(0.0, s), 1.2)
    _pose_sprint("J_Bip_L_UpperLeg", Vector3(thigh, 0, -0.05))
    _pose_sprint("J_Bip_R_UpperLeg", Vector3(-thigh, 0, 0.05))
    _pose_sprint("J_Bip_L_LowerLeg", Vector3(-knee_l, 0, 0))
    _pose_sprint("J_Bip_R_LowerLeg", Vector3(-knee_r, 0, 0))
    _pose_sprint("J_Bip_L_Foot", Vector3(foot_l, 0, 0))
    _pose_sprint("J_Bip_R_Foot", Vector3(foot_r, 0, 0))
    var arm := 0.50 * c
    _pose_sprint("J_Bip_L_UpperArm", Vector3(0.10 - arm, 0, 1.10 + 0.05 * s))
    _pose_sprint("J_Bip_R_UpperArm", Vector3(0.10 + arm, 0, -1.05 - 0.05 * s))
    _pose_sprint("J_Bip_L_LowerArm", Vector3(1.25 + 0.10 * s, 0, 0.15))
    _pose_sprint("J_Bip_R_LowerArm", Vector3(1.25 - 0.10 * s, 0, -0.15))
    _pose_sprint("J_Bip_C_Hips", Vector3(0.34, -0.12 * c, 0.07 * s))
    _pose_sprint("J_Bip_C_Spine", Vector3(-0.22 + 0.04 * s, 0.06 * s, 0))
    _pose_sprint("J_Bip_C_Chest", Vector3(-0.16, 0.10 * c, 0))
    _pose_sprint("J_Bip_C_UpperChest", Vector3(-0.10, -0.08 * c, 0.0))
    _pose_sprint("J_Bip_C_Head", Vector3(0.12, -0.06 * c, 0.03 * s))


func _animate(delta: float) -> void:
    if not skeleton:
        return
    visual_time += delta
    pose_blend = 1.0 - exp(-delta * 18.0)
    sprint_blend = lerpf(sprint_blend, 1.0 if sprinting else 0.0, 1.0 - exp(-delta * 10.0))
    # Phase follows actual ground speed, so a slow stick deflection doesn't
    # produce a fast running cycle while the character barely moves, and a
    # sprint (which exceeds SPEED) cycles the stride proportionally faster
    # instead of gliding over the floor. Movement stays code-driven (no root
    # motion), so the animation must match velocity, never the reverse.
    var horiz := Vector2(velocity.x, velocity.z).length()
    gait_rate = maxf(speed_ratio * 9.5, clampf(horiz * 3.05, 0.0, 18.0))
    gait_phase = fposmod(gait_phase + delta * gait_rate, TAU)
    if motion_driver:
        var attack_progress = 1.0 - attack_timer / ATTACK_DURATION if attack_timer > 0.0 else -1.0
        var dash_progress = 1.0 - dash_time / DASH_DURATION if dash_time > 0.0 else -1.0
        motion_driver.update(delta, speed_ratio, attack_progress, dash_progress, combo)
        var dash_weight = sin(PI * dash_progress) if dash_progress >= 0.0 else 0.0
        model_root.rotation.x = lerpf(model_root.rotation.x, -0.22 * dash_weight - 0.20 * sprint_blend - accel_lean, pose_blend)
        model_root.rotation.z = lerpf(model_root.rotation.z, turn_lean * 0.5, pose_blend)
        # Two vertical CoM bobs per stride (one per footfall) so the center of
        # mass reads as weight, not gliding.
        var bob_target := 0.05 * (0.5 - 0.5 * cos(2.0 * gait_phase)) * sprint_blend
        model_root.position.y = lerpf(model_root.position.y, bob_target, pose_blend)
        if sprint_blend > 0.01:
            _sprint_pose(gait_phase)
    # Wind: blow hair/scarf/skirt/sleeves backward while moving. A steady
    # breeze scaled by real speed plus a stride-frequency lateral sway keeps
    # the cloth flowing at CONSTANT run speed (the springs are
    # acceleration-driven, so without this they would only react to
    # starts/stops); sprinting adds a strong backward wind.
    if wiggle:
        var wind_target = Vector3.ZERO
        if facing.length_squared() > 0.0:
            # Wind force points BACKWARD (-facing): the wiggle spring torque deflects
            # chain tips along the force, so -facing makes hair/scarf/skirt trail
            # behind the runner (asserted by the wind-direction test in
            # tests/wiggle_physics.gd). Small lift + stride-frequency sway keep the
            # cloth fluttering at constant speed.
            # Oppose the ACTUAL movement direction while moving (backward and
            # strafing runs trail correctly too), facing as fallback.
            var back = Vector3(-facing.x, 0, -facing.z).normalized()
            var hv = Vector2(velocity.x, velocity.z)
            if hv.length() > 0.6:
                back = Vector3(-hv.x, 0, -hv.y).normalized()
            var right = Vector3(back.z, 0, -back.x)
            var moving = speed_ratio
            var breeze = 5.5 * moving + 18.0 * sprint_blend
            var sway = 2.6 * moving + 5.0 * sprint_blend
            wind_target = back * breeze + Vector3(0, 0.15 * moving + 0.25 * sprint_blend, 0) + right * sin(gait_phase) * sway
        wiggle.set_wind(wiggle.wind.lerp(wind_target, 1.0 - exp(-delta * 6.0)))
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
        model_root.rotation.x = lerpf(model_root.rotation.x, -0.42 * dash - 0.08 * run - accel_lean * 0.8, pose_blend)
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
        _pose("J_Bip_R_UpperArm", Vector3(-0.32 * swing if combo == 4 else -0.10 * swing, -0.30 - stride * 0.12 + swing * 1.15 * side, -1.08 + arm_raise * (1.20 if combo == 4 else 0.95)))
        _pose("J_Bip_R_LowerArm", Vector3(0, 0.25 + swing * 0.70 * side, -0.38 - 0.25 * dash - 0.15 * arm_raise))
        _pose("J_Bip_R_Hand", Vector3(0.10, -0.15 + swing * 0.30 * side, 0.12))
        if sprint_blend > 0.01:
            _sprint_pose(gait_phase)
    # While moving, tilt the blade outward and slightly down so the swing
    # carries it clear of the chest scarf instead of through it.
    if sword_grip:
        var walk = speed_ratio
        # Blade tilts clear of scarf/sleeve/legs while moving, plus a small
        # inertia wobble: pitch follows forward acceleration, yaw turn lean.
        var grip_target = Vector3(grip_base_rotation.x - 6.0 * walk - accel_lean * 45.0, grip_base_rotation.y + 4.0 * walk + turn_lean * 25.0, grip_base_rotation.z + 30.0 * walk + 12.0 * sprint_blend)
        sword_grip.rotation_degrees = sword_grip.rotation_degrees.lerp(grip_target, 1.0 - exp(-delta * 14.0))
    # Aura breathes at idle and flares during the swing.
    if aura_material and aura_mesh:
        var atk = 1.0 - attack_timer / ATTACK_DURATION if attack_timer > 0.0 else -1.0
        var flare = 0.18 * sin(PI * clampf(atk, 0.0, 1.0)) if atk >= 0.0 else 0.0
        var pulse = 0.03 * sin(visual_time * 6.0)
        aura_material.albedo_color.a = 0.10 + pulse + flare
        aura_mesh.scale = Vector3(1.0 + 0.05 * sin(visual_time * 6.0) + 0.35 * flare, 1.0, 1.0 + 0.05 * sin(visual_time * 6.0) + 0.35 * flare)
    if secondary_motion and physics_quality < 2:
        if profile_secondary:
            var started = Time.get_ticks_usec()
            secondary_motion.update(delta)
            var elapsed = Time.get_ticks_usec() - started
            profile_secondary_us += elapsed
            profile_secondary_max_us = maxi(profile_secondary_max_us, elapsed)
            profile_secondary_steps += 1
        else:
            secondary_motion.update(delta)
