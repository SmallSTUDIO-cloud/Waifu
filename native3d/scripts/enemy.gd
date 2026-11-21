extends CharacterBody3D

signal defeated
signal struck(position: Vector3)

var target: CharacterBody3D
var hp: int = 3
var mode: String = "chase"
var timer: float = 0.5
var stagger: float = 0.0
var body_mesh: MeshInstance3D
var warning: MeshInstance3D
var enabled: bool = false

func _ready() -> void:
    add_to_group("enemies")
    collision_layer = 4
    collision_mask = 1
    var collision = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.5
    collision.shape = capsule
    collision.position.y = 0.8
    add_child(collision)
    body_mesh = _box(Vector3(0, 1.02, 0), Vector3(0.7, 0.75, 0.4), Color(0.16, 0.2, 0.24))
    _box(Vector3(0, 1.58, 0), Vector3(0.42, 0.38, 0.36), Color(0.28, 0.31, 0.34))
    _box(Vector3(0, 1.61, 0.2), Vector3(0.3, 0.06, 0.02), Color(1.0, 0.1, 0.18), true)
    _box(Vector3(-0.22, 0.37, 0), Vector3(0.23, 0.72, 0.28), Color(0.12, 0.15, 0.19))
    _box(Vector3(0.22, 0.37, 0), Vector3(0.23, 0.72, 0.28), Color(0.12, 0.15, 0.19))
    _box(Vector3(-0.5, 1.0, 0), Vector3(0.26, 0.7, 0.28), Color(0.22, 0.25, 0.28))
    _box(Vector3(0.5, 1.0, 0), Vector3(0.26, 0.7, 0.28), Color(0.22, 0.25, 0.28))
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

func _box(pos: Vector3, size: Vector3, color: Color, emissive: bool = false) -> MeshInstance3D:
    var mesh = MeshInstance3D.new()
    var box = BoxMesh.new()
    box.size = size
    mesh.mesh = box
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.55
    material.roughness = 0.5
    if emissive:
        material.emission_enabled = true
        material.emission = color
    mesh.material_override = material
    mesh.position = pos
    add_child(mesh)
    return mesh

func _physics_process(delta: float) -> void:
    if not enabled or not is_instance_valid(target):
        return
    timer -= delta
    stagger = maxf(0.0, stagger - delta)
    var offset: Vector3 = target.global_position - global_position
    offset.y = 0.0
    var distance: float = offset.length()
    velocity.y -= 18.0 * delta
    velocity.x = 0.0
    velocity.z = 0.0
    if distance > 0.05:
        rotation.y = lerp_angle(rotation.y, atan2(offset.x, offset.z), minf(1.0, delta * 8.0))
    if stagger > 0.0:
        warning.visible = false
    elif mode == "chase":
        if distance > 1.3:
            var dir: Vector3 = offset.normalized()
            velocity.x = dir.x * 1.65
            velocity.z = dir.z * 1.65
        elif timer <= 0.0:
            mode = "windup"
            timer = 0.8
            warning.visible = true
    elif mode == "windup" and timer <= 0.0:
        warning.visible = false
        if distance < 1.75 and target.has_method("take_damage"):
            target.take_damage(14)
        mode = "recover"
        timer = 1.0
    elif mode == "recover" and timer <= 0.0:
        mode = "chase"
        timer = 0.25
    move_and_slide()

func take_damage(amount: int) -> void:
    if hp <= 0:
        return
    hp -= amount
    stagger = 0.28
    mode = "chase"
    timer = 0.4
    struck.emit(global_position)
    if hp <= 0:
        remove_from_group("enemies")
        defeated.emit()
        queue_free()
