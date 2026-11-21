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
    intensity_stage = clampi(stage, 1, 3)
    spin_direction = -1.0 if stage == 2 else 1.0
    lifetime = 0.42 if kind == "finisher" or kind == "echo" else (0.32 if kind == "slash" or kind == "impact" else 0.30)
    shape = MeshInstance3D.new()
    var mesh = ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    if kind == "slash":
        var radius: float = 1.52 if stage == 3 else 1.38
        # Soft feather, warm inner body and a narrow white-hot edge.
        _ring_band(mesh, radius - 0.45, radius - 0.16, -78, 78, Color(1, 0.04, 0.10, 0), Color(1, 0.12, 0.10, 0.55), true)
        _ring_band(mesh, radius - 0.16, radius - 0.05, -78, 78, Color(1, 0.12, 0.10, 0.55), Color(1, 0.72, 0.45, 0.86), true)
        _ring_band(mesh, radius - 0.05, radius, -78, 78, Color(1, 0.90, 0.76, 0.90), Color(1, 0.16, 0.12, 0), true)
        var shards = 7 + (stage - 1) * 4
        for i in range(shards):
            var a = deg_to_rad(lerpf(-70.0, 70.0, float(i) / float(shards - 1)))
            var r = radius + 0.08 + 0.05 * (i % 3)
            _ground_shard(mesh, a, r, 0.22 + 0.05 * (i % 3), Color(1, 0.40, 0.19, 0.75))
        rotation_degrees.x = 35.0 if stage != 3 else -32.0
        rotation_degrees.z = -18.0 if stage == 2 else 18.0
    elif kind == "echo":
        # A wider, separated crescent builds visual intensity on combo hits.
        _ring_band(mesh, 1.55, 1.66, -98, 98, Color(0.85, 0.025, 0.09, 0), Color(1, 0.25, 0.12, 0.72), true)
        _ring_band(mesh, 1.66, 1.70, -98, 98, Color(1, 0.8, 0.55, 0.85), Color(1, 0.12, 0.1, 0), true)
        for i in range(14):
            var angle = deg_to_rad(lerpf(-95.0, 95.0, i / 13.0))
            _ground_shard(mesh, angle, 1.72, 0.22 + (i % 3) * 0.07, Color(1, 0.38, 0.16, 0.75))
        rotation_degrees.x = -18.0 if stage == 3 else 52.0
        rotation_degrees.z = 32.0 if stage == 3 else -30.0
    elif kind == "finisher":
        _ring_band(mesh, 0.46, 0.59, 0, 360, Color(1, 0.05, 0.08, 0), Color(1, 0.35, 0.12, 0.8), false)
        _ring_band(mesh, 0.59, 0.67, 0, 360, Color(1, 0.85, 0.58, 0.9), Color(1, 0.1, 0.08, 0), false)
        for i in range(18):
            _ground_shard(mesh, TAU * float(i) / 18.0, 0.70, 0.28 + 0.07 * (i % 3), Color(1, 0.35, 0.12, 0.8))
    elif kind == "impact":
        # The impact plane faces the camera. Multiple streak lengths keep
        # the silhouette crisp without a costly particle system.
        for i in range(16):
            var a: float = TAU * float(i) / 16.0
            var dir = Vector3(cos(a), sin(a), 0)
            var side = Vector3(-dir.y, dir.x, 0) * (0.025 if i % 2 == 0 else 0.012)
            var length = 0.42 + 0.13 * (i % 4)
            _triangle(mesh, dir * 0.08 - side, dir * length, dir * 0.08 + side, Color(1.0, 0.65, 0.27, 0.92))
        _triangle(mesh, Vector3(-0.28, 0, 0), Vector3(0.28, 0, 0), Vector3(0, 0.10, 0), Color(1, 0.9, 0.7, 0.9))
        _triangle(mesh, Vector3(-0.28, 0, 0), Vector3(0, -0.10, 0), Vector3(0.28, 0, 0), Color(1, 0.9, 0.7, 0.9))
    else:
        _ring_band(mesh, 0.32, 0.42, 0, 360, Color(0.5, 0.75, 1.0, 0), Color(0.7, 0.86, 1.0, 0.62), false)
        _ring_band(mesh, 0.42, 0.50, 0, 360, Color(0.7, 0.86, 1.0, 0.62), Color(0.4, 0.68, 1.0, 0), false)
        for i in range(8):
            _ground_shard(mesh, TAU * float(i) / 8.0, 0.48, 0.19, Color(0.65, 0.85, 1, 0.6))
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
        _vertex(mesh, _point(a, inner), i0)
        _vertex(mesh, _point(a, outer), o0)
        _vertex(mesh, _point(b, inner), i1)
        _vertex(mesh, _point(a, outer), o0)
        _vertex(mesh, _point(b, outer), o1)
        _vertex(mesh, _point(b, inner), i1)

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
    var fade: float = (1.0 - t) * (1.0 - t)
    material.albedo_color = Color(1, 1, 1, fade)
    if kind == "slash":
        shape.rotation.y = spin_direction * lerpf(-0.22, 0.18, t)
        shape.scale = Vector3.ONE * lerpf(0.90, 1.08, t)
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
