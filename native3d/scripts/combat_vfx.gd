extends Node3D
# Short-lived emissive geometry, with no textures or additional lights.
# The visual count and lifetime are intentionally bounded for mobile.
var lifetime: float = 0.30
var age: float = 0.0
var kind: String = "slash"
var material: StandardMaterial3D
var shape: MeshInstance3D
var spin_direction: float = 1.0
var intensity_stage: int = 1

func setup(effect_kind: String, stage: int = 1) -> void:
    kind = effect_kind
    intensity_stage = clampi(stage, 1, 4)
    spin_direction = -1.0 if stage == 2 else 1.0
    lifetime = 0.42 if kind == "finisher" or kind == "echo" or kind == "cleave" else (0.32 if kind == "slash" or kind == "impact" else 0.30)
    shape = MeshInstance3D.new()
    var mesh = ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    if kind == "slash":
        # Layered tapered crescents: translucent lavender feather, violet body,
        # and a bright white-pink cutting edge, as in the reference.
        var radius = 1.55 + 0.12 * (stage - 1)
        _ring_band(mesh, radius - 0.53, radius - 0.23, -92, 92, Color(0.48, 0.12, 1, 0), Color(0.69, 0.32, 1, 0.42), true)
        _ring_band(mesh, radius - 0.23, radius - 0.09, -92, 92, Color(0.68, 0.25, 1, 0.66), Color(0.93, 0.76, 1, 1.0), true)
        _ring_band(mesh, radius - 0.09, radius, -92, 92, Color(1, 0.95, 1, 1.0), Color(0.65, 0.25, 1, 0), true)
        if stage >= 2:
            _petals(mesh, 8 + stage * 3, radius + 0.15)
        rotation_degrees.x = 38.0 if stage == 1 else (48.0 if stage == 2 else 20.0)
        rotation_degrees.z = -18.0 if stage == 2 else 18.0
    elif kind == "echo":
        _ring_band(mesh, 1.75, 1.88, -115, 115, Color(0.42, 0.12, 1, 0), Color(0.8, 0.52, 1, 0.68), true)
        _ring_band(mesh, 1.88, 1.93, -115, 115, Color(1, 0.94, 1, 0.9), Color(0.56, 0.18, 1, 0), true)
        _petals(mesh, 14, 1.95)
        rotation_degrees.x = 60.0 if stage == 3 else 52.0
        rotation_degrees.z = 24.0 if stage == 3 else -30.0
    elif kind == "finisher":
        _ring_band(mesh, 0.38, 0.60, 0, 360, Color(0.42, 0.08, 1, 0), Color(0.7, 0.35, 1, 0.72), false)
        _ring_band(mesh, 0.60, 0.68, 0, 360, Color(1, 0.9, 1, 0.92), Color(0.5, 0.15, 1, 0), false)
        for i in range(18):
            _ground_shard(mesh, TAU * float(i) / 18.0, 0.70, 0.20 + 0.07 * (i % 3), Color(0.78, 0.5, 1, 0.7))
        _petals(mesh, 12, 0.9)
    elif kind == "cleave":
        _ring_band(mesh, 1.20, 1.58, -55, 55, Color(0.52, 0.15, 1, 0), Color(0.82, 0.55, 1, 0.85), true)
        _ring_band(mesh, 1.58, 1.65, -55, 55, Color(1, 0.96, 1, 0.98), Color(0.58, 0.22, 1, 0), true)
        _petals(mesh, 12, 1.75)
        rotation_degrees.x = 85.0
        rotation_degrees.z = -28.0
    elif kind == "impact":
        for i in range(16):
            var a: float = TAU * float(i) / 16.0
            var dir = Vector3(cos(a), sin(a), 0)
            var side = Vector3(-dir.y, dir.x, 0) * (0.045 if i % 2 == 0 else 0.017)
            var length = 0.35 + 0.14 * (i % 4)
            _triangle(mesh, dir * 0.05 - side, dir * length, dir * 0.05 + side, Color(0.88, 0.6, 1, 0.95))
        _triangle(mesh, Vector3(-0.30, 0, 0), Vector3(0.30, 0, 0), Vector3(0, 0.12, 0), Color(1, 0.95, 1, 0.95))
        _triangle(mesh, Vector3(-0.30, 0, 0), Vector3(0, -0.12, 0), Vector3(0.30, 0, 0), Color(1, 0.95, 1, 0.95))
    else:
        _ring_band(mesh, 0.32, 0.42, 0, 360, Color(0.25, 0.12, 0.42, 0), Color(0.4, 0.26, 0.65, 0.5), false)
        _ring_band(mesh, 0.42, 0.50, 0, 360, Color(0.4, 0.26, 0.65, 0.5), Color(0.2, 0.1, 0.4, 0), false)
    mesh.surface_end()
    shape.mesh = mesh
    material = StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.vertex_color_use_as_albedo = true
    shape.material_override = material
    shape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(shape)

func _point(angle: float, radius: float) -> Vector3:
    return Vector3(sin(angle) * radius, 0, -cos(angle) * radius)

func _ring_band(mesh: ImmediateMesh, inner: float, outer: float, start: float, end: float, inner_color: Color, outer_color: Color, taper: bool) -> void:
    const SEGMENTS = 32
    for i in range(SEGMENTS):
        var p0 = float(i) / SEGMENTS
        var p1 = float(i + 1) / SEGMENTS
        var a = deg_to_rad(lerpf(start, end, p0))
        var b = deg_to_rad(lerpf(start, end, p1))
        var fade0 = pow(sin(PI * p0), 0.6) if taper else 1.0
        var fade1 = pow(sin(PI * p1), 0.6) if taper else 1.0
        var i0 = inner_color; i0.a *= fade0
        var o0 = outer_color; o0.a *= fade0
        var i1 = inner_color; i1.a *= fade1
        var o1 = outer_color; o1.a *= fade1
        _vertex(mesh, _point(a, lerpf(outer, inner, fade0) if taper else inner), i0)
        _vertex(mesh, _point(a, outer), o0)
        _vertex(mesh, _point(b, lerpf(outer, inner, fade1) if taper else inner), i1)
        _vertex(mesh, _point(a, outer), o0)
        _vertex(mesh, _point(b, outer), o1)
        _vertex(mesh, _point(b, lerpf(outer, inner, fade1) if taper else inner), i1)

func _petals(mesh: ImmediateMesh, count: int, radius: float) -> void:
    # Deterministic diamond-shaped petals; geometry stays bounded on mobile.
    for i in range(count):
        var angle = TAU * float(i) / float(count) + 0.2 * (i % 3)
        var r = radius * (0.65 + 0.15 * (i % 3))
        var center = _point(angle, r) + Vector3.UP * (0.06 + 0.08 * (i % 4))
        var tangent = Vector3(cos(angle), 0, sin(angle))
        var radial = _point(angle, 1.0)
        var width = 0.035 + 0.008 * (i % 3)
        var length = width * 2.2
        var col = Color(0.92, 0.74, 1.0, 0.85)
        _triangle(mesh, center - tangent * width, center + radial * length, center + tangent * width, col)
        _triangle(mesh, center + tangent * width, center - radial * length, center - tangent * width, col)

func _ground_shard(mesh: ImmediateMesh, angle: float, radius: float, length: float, color: Color) -> void:
    var tip = _point(angle, radius + length)
    var center = _point(angle, radius)
    var side = Vector3(cos(angle), 0, sin(angle)) * 0.025
    _triangle(mesh, center - side, tip, center + side, color)

func _triangle(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
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
    var fade: float = (1.0 - t) * (1.0 - 0.35 * t)
    material.albedo_color = Color(1, 1, 1, fade)
    if kind == "slash":
        shape.rotation.y = spin_direction * lerpf(-0.22, 0.18, t)
        shape.scale = Vector3.ONE * lerpf(0.90, 1.08, t)
    elif kind == "cleave":
        shape.scale = Vector3.ONE * lerpf(0.75, 1.25, t)
    elif kind == "echo":
        shape.rotation.y = spin_direction * lerpf(0.30, -0.12, t)
        shape.scale = Vector3.ONE * lerpf(0.86, 1.18, t)
    elif kind == "finisher":
        shape.rotation.y = t * 0.25
        shape.scale = Vector3.ONE * lerpf(0.6, 3.2, t)
    elif kind == "impact":
        shape.scale = Vector3.ONE * lerpf(0.55, 1.25 + 0.12 * (intensity_stage - 1), t)
    else:
        shape.scale = Vector3.ONE * lerpf(0.7, 2.0, t)
