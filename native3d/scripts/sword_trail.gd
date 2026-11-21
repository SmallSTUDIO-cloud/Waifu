extends MeshInstance3D
# Sample the actual blade after bone posing. A small, time-bounded ribbon follows
# the weapon instead of placing a static effect in front of the character.
const MAX_SAMPLES: int = 12
const SAMPLE_LIFE: float = 0.14
var samples: Array[Dictionary] = []
var ribbon: ImmediateMesh

func _ready() -> void:
    ribbon = ImmediateMesh.new()
    mesh = ribbon
    var mat = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.vertex_color_use_as_albedo = true
    material_override = mat
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func update_trail(delta: float, grip: Node3D, active: bool) -> void:
    for sample in samples:
        sample.age += delta
    while not samples.is_empty() and samples[0].age >= SAMPLE_LIFE:
        samples.pop_front()
    if active and is_instance_valid(grip):
        samples.append({"base": grip.to_global(Vector3(0, -0.10, 0)), "tip": grip.to_global(Vector3(0, -0.90, 0)), "age": 0.0})
        while samples.size() > MAX_SAMPLES:
            samples.pop_front()
    ribbon.clear_surfaces()
    if samples.size() < 2:
        return
    ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(samples.size() - 1):
        var a: Dictionary = samples[i]
        var b: Dictionary = samples[i + 1]
        var alpha_a: float = 0.56 * (1.0 - clampf(a.age / SAMPLE_LIFE, 0.0, 1.0))
        var alpha_b: float = 0.56 * (1.0 - clampf(b.age / SAMPLE_LIFE, 0.0, 1.0))
        var a_base = to_local(a.base)
        var a_tip = to_local(a.tip)
        var b_base = to_local(b.base)
        var b_tip = to_local(b.tip)
        _vertex(a_base, Color(1.0, 0.09, 0.14, 0.0))
        _vertex(a_tip, Color(1.0, 0.68, 0.45, alpha_a))
        _vertex(b_base, Color(1.0, 0.09, 0.14, 0.0))
        _vertex(a_tip, Color(1.0, 0.68, 0.45, alpha_a))
        _vertex(b_tip, Color(1.0, 0.68, 0.45, alpha_b))
        _vertex(b_base, Color(1.0, 0.09, 0.14, 0.0))
    ribbon.surface_end()

func clear_trail() -> void:
    samples.clear()
    if ribbon:
        ribbon.clear_surfaces()

func _vertex(point: Vector3, color: Color) -> void:
    ribbon.surface_set_color(color)
    ribbon.surface_add_vertex(point)
