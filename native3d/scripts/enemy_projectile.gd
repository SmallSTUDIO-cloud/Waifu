extends Node3D
# Enemy energy bolt. Straight-line, dodgeable projectile with bounded lifetime
# so a missed shot never lingers in the scene.
signal hit_player(position: Vector3)
signal expired(position: Vector3)

const SPEED: float = 8.5
const DAMAGE: int = 10
const LIFE: float = 2.6
const HIT_RADIUS: float = 0.55

var direction: Vector3 = Vector3.FORWARD
var target: Node3D
var life: float = 0.0
var core: MeshInstance3D
var streak: MeshInstance3D

func _ready() -> void:
    add_to_group("enemy_projectiles")
    var core_mesh = SphereMesh.new()
    core_mesh.radius = 0.11
    core_mesh.height = 0.22
    core = MeshInstance3D.new()
    core.mesh = core_mesh
    var core_material = StandardMaterial3D.new()
    core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    core_material.albedo_color = Color(1.0, 0.9, 0.75)
    core_material.emission_enabled = true
    core_material.emission = Color(1.0, 0.35, 0.12)
    core_material.emission_energy_multiplier = 3.2
    core.material_override = core_material
    core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(core)
    var streak_mesh = BoxMesh.new()
    streak_mesh.size = Vector3(0.055, 0.055, 0.55)
    streak = MeshInstance3D.new()
    streak.mesh = streak_mesh
    var streak_material = StandardMaterial3D.new()
    streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    streak_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    streak_material.albedo_color = Color(1.0, 0.28, 0.1, 0.55)
    streak.material_override = streak_material
    streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    streak.position.z = 0.30
    add_child(streak)

func setup(from: Vector3, dir: Vector3, player_target: Node3D) -> void:
    global_position = from
    direction = dir.normalized()
    target = player_target
    if direction.length_squared() > 0.0:
        look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
    life += delta
    if life >= LIFE:
        _finish()
        return
    global_position += direction * SPEED * delta
    if global_position.y < 0.06:
        _finish()
        return
    if is_instance_valid(target):
        var aim_point = target.global_position + Vector3(0, 0.9, 0)
        if global_position.distance_to(aim_point) <= HIT_RADIUS:
            hit_player.emit(global_position)
            call_deferred("queue_free")
            return

func _finish() -> void:
    print("BOLT finish at ", global_position, " life=", life)
    expired.emit(global_position)
    print("BOLT emitted")
    call_deferred("queue_free")
    print("BOLT deferred-free")
