extends Node3D
# Lightweight transient geometry: no textures, lights, particles, or per-frame mesh rebuilds.
var lifetime: float = 0.30
var age: float = 0.0
var kind: String = "slash"
var material: StandardMaterial3D
var shape: MeshInstance3D

func setup(effect_kind: String, stage: int = 1) -> void:
    kind = effect_kind
    lifetime = 0.32 if kind == "slash" else (0.35 if kind == "impact" else 0.28)
    shape = MeshInstance3D.new()
    var mesh = ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    if kind == "slash":
        # A feathered crescent: transparent edges and a hot inner streak.
        var radius: float = 1.5 if stage == 3 else 1.32
        var direction: float = -1.0 if stage == 2 else 1.0
        for i in range(30):
            var a = deg_to_rad(-76.0 + float(i) * 152.0 / 30.0) * direction
            var b = deg_to_rad(-76.0 + float(i + 1) * 152.0 / 30.0) * direction
            var fade_a = pow(sin(PI * float(i) / 30.0), 0.7)
            var fade_b = pow(sin(PI * float(i + 1) / 30.0), 0.7)
            _arc_quad(mesh, a, b, radius - 0.32, radius - 0.10, Color(1, 0.07, 0.12, 0), Color(1, 0.25, 0.27, fade_a * 0.7), fade_b)
            _arc_quad(mesh, a, b, radius - 0.10, radius, Color(1, 0.85, 0.78, fade_a), Color(1, 0.18, 0.15, 0), fade_b)
        rotation_degrees.x = 35.0 if stage != 3 else -32.0
        rotation_degrees.z = -18.0 if stage == 2 else 18.0
    elif kind == "impact":
        for i in range(10):
            var a: float = TAU * float(i) / 10.0
            var dir = Vector3(cos(a), sin(a), 0)
            var normal = Vector3(-dir.y, dir.x, 0) * 0.035
            _tri(mesh, dir * 0.06 - normal, dir * (0.35 + 0.10 * (i % 3)), dir * 0.06 + normal, Color(1.0, 0.7, 0.4, 0.9))
    else:
        for i in range(24):
            var a = TAU * float(i) / 24.0
            var b = TAU * float(i + 1) / 24.0
            _arc_quad(mesh, a, b, 0.35, 0.42, Color(0.55, 0.8, 1.0, 0.5), Color(0.55, 0.8, 1.0, 0), 1.0)
    mesh.surface_end()
    shape.mesh = mesh
    material = StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.vertex_color_use_as_albedo = true
    material.no_depth_test = false
    shape.material_override = material
    add_child(shape)

func _point(angle: float, radius: float) -> Vector3:
    return Vector3(sin(angle) * radius, 0, -cos(angle) * radius)

func _arc_quad(mesh: ImmediateMesh, a: float, b: float, inner: float, outer: float, c0: Color, c1: Color, end_fade: float) -> void:
    var end0 = c0
    var end1 = c1
    if c0.a > 0.0: end0.a = end_fade
    if c1.a > 0.0: end1.a = end_fade * 0.7
    _vertex(mesh, _point(a, inner), c0)
    _vertex(mesh, _point(a, outer), c1)
    _vertex(mesh, _point(b, inner), end0)
    _vertex(mesh, _point(a, outer), c1)
    _vertex(mesh, _point(b, outer), end1)
    _vertex(mesh, _point(b, inner), end0)

func _tri(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
    _vertex(mesh, a, color)
    _vertex(mesh, b, Color(color.r, color.g, color.b, 0.0))
    _vertex(mesh, c, color)

func _vertex(mesh: ImmediateMesh, vertex: Vector3, color: Color) -> void:
    mesh.surface_set_color(color)
    mesh.surface_add_vertex(vertex)

func _process(delta: float) -> void:
    age += delta
    var t = clampf(age / lifetime, 0.0, 1.0)
    if t >= 1.0:
        queue_free()
        return
    material.albedo_color = Color(1, 1, 1, 1.0 - t)
    if kind == "slash":
        shape.rotation.y = lerpf(-0.20, 0.18, t)
        shape.scale = Vector3.ONE * lerpf(0.87, 1.12, t)
    elif kind == "impact":
        shape.scale = Vector3.ONE * lerpf(0.55, 1.2, t)
    else:
        shape.scale = Vector3.ONE * lerpf(0.8, 2.2, t)
