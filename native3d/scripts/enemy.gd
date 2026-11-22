extends CharacterBody3D
# Rigged CC0 Quaternius space-kit robots. "large" is a melee bruiser,
# "small" is a hovering drone with a long-range energy bolt.
signal defeated
signal struck(position: Vector3)
signal fired(from: Vector3, direction: Vector3)

# One CC0 robot model, tinted per combat role. It has no skeleton, so pose
# comes from bounded procedural lean, recoil and a fall-over death.
const MODEL_ROBOT = preload("res://assets/enemy-robot.glb")

# Balance-tuned combat constants: telegraphed, dodgeable, and bounded so a
# full encounter cannot burst the 100 HP player faster than they can react.
const LARGE_SPEED: float = 1.55
const LARGE_HP: int = 5
const LARGE_HEIGHT: float = 2.05
const MELEE_DAMAGE: int = 12
const MELEE_RANGE: float = 2.15
const MELEE_WINDUP: float = 0.75
const MELEE_RECOVER: float = 1.15
const SMALL_SPEED: float = 2.3
const SMALL_HP: int = 3
const SMALL_HEIGHT: float = 1.45
const HOVER_HEIGHT: float = 0.95
const BOLT_WINDUP: float = 0.65
const BOLT_RECOVER: float = 1.5
const RANGE_MIN: float = 4.2
const RANGE_MAX: float = 8.5
const HEADBUTT_DAMAGE: int = 8
const HEADBUTT_RANGE: float = 1.9
const HEADBUTT_WINDUP: float = 0.35
const SEPARATION: float = 1.25

var kind: String = "large"
var target: CharacterBody3D
var hp: int = LARGE_HP
var mode: String = "chase"
var timer: float = 0.5
var stagger: float = 0.0
var flash: float = 0.0
var enabled: bool = false
var dead: bool = false
var aim_height: float = 1.15
var model_root: Node3D
var animator: AnimationPlayer
var flash_materials: Array[BaseMaterial3D] = []
var warning: MeshInstance3D
var sight: MeshInstance3D
var hover_phase: float = 0.0
var current_anim: String = ""
var anim_time: float = 0.0

func _ready() -> void:
    add_to_group("enemies")
    hover_phase = randf() * TAU
    _build_model()
    _build_collision()
    _build_telegraphs()
    if kind == "small":
        hp = SMALL_HP
        aim_height = 1.55
    else:
        hp = LARGE_HP
        aim_height = 1.15

func _build_model() -> void:
    model_root = Node3D.new()
    add_child(model_root)
    var model = MODEL_ROBOT.instantiate()
    model_root.add_child(model)
    # Normalize the imported model to a known height with its feet at y=0.
    var bounds = _model_aabb(model)
    var target_height = SMALL_HEIGHT if kind == "small" else LARGE_HEIGHT
    var scale_factor = target_height / maxf(bounds.size.y, 0.001)
    model.scale = Vector3.ONE * scale_factor
    model.position.y = -bounds.position.y * scale_factor
    _collect(model)
    _add_visor(bounds, scale_factor)

func _add_visor(bounds: AABB, scale_factor: float) -> void:
    # Glowing hostile eye strip on the face side (+Z), scaled with the model.
    var visor = MeshInstance3D.new()
    var strip = BoxMesh.new()
    var final = AABB(bounds.position * scale_factor + Vector3(0, -bounds.position.y * scale_factor, 0), bounds.size * scale_factor)
    strip.size = Vector3(final.size.x * 0.42, final.size.y * 0.075, 0.035)
    visor.mesh = strip
    var visor_material = StandardMaterial3D.new()
    visor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    visor_material.albedo_color = Color(1, 0.12, 0.16)
    visor_material.emission_enabled = true
    visor_material.emission = Color(1, 0.1, 0.12)
    visor_material.emission_energy_multiplier = 2.6
    visor.material_override = visor_material
    visor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    visor.position = Vector3(final.get_center().x, final.position.y + final.size.y * 0.80, final.position.z + final.size.z - 0.02)
    model_root.add_child(visor)

func _model_aabb(root: Node) -> AABB:
    var result := AABB(Vector3.ZERO, Vector3.ZERO)
    var first := true
    var stack: Array = [[root, Transform3D.IDENTITY]]
    while not stack.is_empty():
        var pair: Array = stack.pop_back()
        var node: Node = pair[0]
        var node_xform := Transform3D.IDENTITY
        if node is Node3D:
            node_xform = node.transform
        var xform: Transform3D = pair[1] * node_xform
        if node is GeometryInstance3D and node.mesh:
            var local = node.get_aabb()
            for corner in [
                local.position,
                local.position + Vector3(local.size.x, 0, 0),
                local.position + Vector3(0, local.size.y, 0),
                local.position + Vector3(0, 0, local.size.z),
                local.position + Vector3(local.size.x, local.size.y, 0),
                local.position + Vector3(local.size.x, 0, local.size.z),
                local.position + Vector3(0, local.size.y, local.size.z),
                local.position + local.size,
            ]:
                var p = xform * corner
                if first:
                    result = AABB(p, Vector3.ZERO)
                    first = false
                else:
                    result = result.expand(p)
        for child in node.get_children():
            stack.append([child, xform])
    return result

func _collect(node: Node) -> void:
    if node is AnimationPlayer and animator == null:
        animator = node
    if node is GeometryInstance3D and node.mesh:
        # Duplicate materials per enemy so hit flashes do not leak between
        # instances sharing the imported atlas material.
        var source = node.material_override
        if source == null and node.mesh.get_surface_count() > 0:
            source = node.mesh.surface_get_material(0)
        if source is BaseMaterial3D:
            var material: BaseMaterial3D = source.duplicate()
            # Role tints: the bruiser is darker gunmetal, the drone cooler blue.
            if kind == "small":
                material.albedo_color = Color(0.62, 0.68, 0.78)
            else:
                material.albedo_color = Color(0.42, 0.42, 0.48)
            material.metallic = 0.65
            material.roughness = 0.38
            node.material_override = material
            flash_materials.append(material)
    for child in node.get_children():
        _collect(child)

func _build_collision() -> void:
    collision_layer = 4
    collision_mask = 1
    var collision = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = 0.34 if kind == "small" else 0.45
    capsule.height = 1.25 if kind == "small" else 1.75
    collision.shape = capsule
    collision.position.y = (0.72 + HOVER_HEIGHT) if kind == "small" else 0.88
    add_child(collision)

func _build_telegraphs() -> void:
    warning = MeshInstance3D.new()
    var ring = CylinderMesh.new()
    ring.top_radius = 0.95
    ring.bottom_radius = 0.95
    ring.height = 0.015
    warning.mesh = ring
    var warning_material = StandardMaterial3D.new()
    warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    warning_material.albedo_color = Color(1.0, 0.06, 0.12, 0.4)
    warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    warning.material_override = warning_material
    warning.position.y = 0.025
    warning.visible = false
    add_child(warning)
    # Thin red sight line shown while the drone charges a bolt.
    sight = MeshInstance3D.new()
    var beam = BoxMesh.new()
    beam.size = Vector3(0.035, 0.035, 1.0)
    sight.mesh = beam
    var sight_material = StandardMaterial3D.new()
    sight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    sight_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    sight_material.albedo_color = Color(1.0, 0.08, 0.14, 0.55)
    sight.material_override = sight_material
    sight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    sight.visible = false
    add_child(sight)

func _play(_name: String) -> void:
    # The robot model is static; pose feedback comes from lean/recoil below.
    return

func _muzzle() -> Vector3:
    return global_position + Vector3(0, aim_height, 0) + Vector3(sin(rotation.y), 0, cos(rotation.y)) * 0.45

func _process(delta: float) -> void:
    if dead and model_root:
        # Fall over backwards when destroyed.
        model_root.rotation.x = lerpf(model_root.rotation.x, -1.35, 1.0 - exp(-delta * 5.0))

func _physics_process(delta: float) -> void:
    if not enabled or dead or not is_instance_valid(target):
        return
    timer -= delta
    stagger = maxf(0.0, stagger - delta)
    flash = maxf(0.0, flash - delta)
    anim_time += delta
    for material in flash_materials:
        if flash > 0.0:
            material.emission_enabled = true
            material.emission = Color(1.0, 0.22, 0.12)
            material.emission_energy_multiplier = (flash / 0.12) * 3.0
        else:
            material.emission_enabled = false
    var offset: Vector3 = target.global_position - global_position
    offset.y = 0.0
    var distance: float = offset.length()
    if distance > 0.05:
        rotation.y = lerp_angle(rotation.y, atan2(offset.x, offset.z), minf(1.0, delta * 8.0))
    # Gentle separation keeps robots from stacking into one target.
    for other in get_tree().get_nodes_in_group("enemies"):
        if other == self or not is_instance_valid(other) or other.get("dead"):
            continue
        var apart: Vector3 = global_position - other.global_position
        apart.y = 0.0
        var apart_distance: float = apart.length()
        if apart_distance < SEPARATION and apart_distance > 0.001:
            offset += apart.normalized() * (SEPARATION - apart_distance) * 0.8
    var move_dir := Vector3.ZERO
    if stagger <= 0.0:
        if kind == "small":
            move_dir = _process_drone(delta, offset, distance)
        else:
            move_dir = _process_bruiser(delta, offset, distance)
    else:
        warning.visible = false
        sight.visible = false
    var speed = SMALL_SPEED if kind == "small" else LARGE_SPEED
    if move_dir.length_squared() > 0.01:
        var dir = move_dir.normalized()
        velocity.x = dir.x * speed
        velocity.z = dir.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
    if kind == "small":
        # Hovering drone: hold altitude with a small bob, no gravity.
        position.y = HOVER_HEIGHT + sin(anim_time * 2.1 + hover_phase) * 0.05
        position.x += velocity.x * delta
        position.z += velocity.z * delta
        model_root.position.y = sin(anim_time * 2.1 + hover_phase) * 0.05
    else:
        velocity.y -= 18.0 * delta
        move_and_slide()
    if not dead:
        # Lean into movement so the static model still reads as alive.
        var lean = 0.16 if move_dir.length_squared() > 0.01 else 0.0
        if kind == "small": lean *= 0.45
        if stagger > 0.0: lean = -0.20
        model_root.rotation.x = lerpf(model_root.rotation.x, lean, 1.0 - exp(-delta * 8.0))
        model_root.rotation.z = lerpf(model_root.rotation.z, clampf(-velocity.x * 0.03, -0.1, 0.1), 1.0 - exp(-delta * 6.0))
    position.x = clampf(position.x, -8.5, 8.5)
    position.z = clampf(position.z, -8.5, 8.5)
    rotation.x = lerpf(rotation.x, -0.16 if stagger > 0.0 else 0.0, 1.0 - exp(-delta * 14.0))

func _process_bruiser(delta: float, offset: Vector3, distance: float) -> Vector3:
    if stagger > 0.0:
        return Vector3.ZERO
    if mode == "chase":
        _play("Walk")
        if distance <= 1.55 and timer <= 0.0:
            mode = "windup"
            timer = MELEE_WINDUP
            warning.visible = true
            _play("Punch")
            return Vector3.ZERO
        return offset
    elif mode == "windup" and timer <= 0.0:
        warning.visible = false
        if distance < MELEE_RANGE and target.has_method("take_damage"):
            target.take_damage(MELEE_DAMAGE)
        mode = "recover"
        timer = MELEE_RECOVER
        return Vector3.ZERO
    elif mode == "recover" and timer <= 0.0:
        mode = "chase"
        timer = 0.3
    return Vector3.ZERO

func _process_drone(delta: float, offset: Vector3, distance: float) -> Vector3:
    if stagger > 0.0:
        return Vector3.ZERO
    var to_target = offset.normalized() if offset.length() > 0.01 else Vector3.ZERO
    if mode == "chase":
        _play("Flying_Idle")
        # Hold the preferred firing band instead of hugging the player.
        var move = offset
        if distance > RANGE_MAX:
            move = to_target * (distance - RANGE_MAX + 0.8)
        elif distance < RANGE_MIN:
            move = -to_target * (RANGE_MIN - distance + 0.6)
        else:
            move = Vector3(-to_target.z, 0, to_target.x) * 0.55
        if distance < HEADBUTT_RANGE - 0.4 and timer <= 0.0:
            mode = "headbutt"
            timer = HEADBUTT_WINDUP
            _play("Headbutt")
            return Vector3.ZERO
        elif RANGE_MIN <= distance and distance <= RANGE_MAX and timer <= 0.0:
            mode = "ranged"
            timer = BOLT_WINDUP
            _play("Punch")
            return Vector3.ZERO
        return move
    elif mode == "ranged":
        # Track the player during the telegraph so the bolt needs a dodge.
        _aim_sight()
        if timer <= 0.0:
            sight.visible = false
            var muzzle = _muzzle()
            var aim_point = target.global_position + Vector3(0, 0.9, 0)
            fired.emit(muzzle, (aim_point - muzzle).normalized())
            mode = "recover"
            timer = BOLT_RECOVER
    elif mode == "headbutt" and timer <= 0.0:
        if distance < HEADBUTT_RANGE and target.has_method("take_damage"):
            target.take_damage(HEADBUTT_DAMAGE)
        mode = "recover"
        timer = 0.9
    elif mode == "recover" and timer <= 0.0:
        mode = "chase"
        timer = 0.25
    return Vector3.ZERO

func _aim_sight() -> void:
    if not is_instance_valid(target):
        sight.visible = false
        return
    sight.visible = true
    var muzzle = _muzzle()
    var aim_point = target.global_position + Vector3(0, 0.9, 0)
    var beam = aim_point - muzzle
    sight.global_position = (muzzle + aim_point) * 0.5
    sight.look_at(aim_point, Vector3.UP)
    sight.scale = Vector3(1, 1, beam.length())

func take_damage(amount: int) -> void:
    if dead or hp <= 0:
        return
    hp -= amount
    stagger = 0.28
    flash = 0.12
    struck.emit(global_position)
    if hp <= 0:
        dead = true
        enabled = false
        remove_from_group("enemies")
        collision_layer = 0
        warning.visible = false
        sight.visible = false
        velocity = Vector3.ZERO
        defeated.emit()
        _play("Death")
        var cleanup = get_tree().create_timer(1.4)
        cleanup.timeout.connect(queue_free)
    else:
        # Getting hit interrupts a windup; the attack is not free.
        mode = "chase"
        timer = 0.4
        warning.visible = false
        sight.visible = false
        _play("HitReact")
