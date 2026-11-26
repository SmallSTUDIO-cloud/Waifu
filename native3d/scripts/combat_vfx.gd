extends Node3D
# Short-lived emissive geometry with no textures and no additional lights.
# Scarlet Veil combat identity: layered crimson bands with a white-hot core.
# The visual count and lifetime are intentionally bounded for mobile.
# Kinds: slash (normal), echo (combo follow-up), finisher (shockwave),
# cleave (heavy/charged arc), impact (hit sparks), dash (bloodline streaks),
# veil (Scarlet Veil skill rings), bloom (Crimson Bloom ultimate petals).
const DEEP := Color(0.474, 0.0, 0.094)      # #790018
const SCARLET := Color(1.0, 0.090, 0.267)     # #FF1744
const BRIGHT := Color(1.0, 0.216, 0.365)      # #FF365D
const HILITE := Color(1.0, 0.510, 0.584)      # #FF8295
const CORE := Color(1.0, 0.941, 0.949)        # #FFF0F2
var lifetime: float = 0.30
var age: float = 0.0
var kind: String = "slash"
var material: StandardMaterial3D
var shape: MeshInstance3D
var spin_direction: float = 1.0
var intensity_stage: int = 1
var effect_quality: int = 1

func setup(effect_kind: String, stage: int = 1, quality: int = 1) -> void:
    effect_quality = clampi(quality, 0, 1)
    kind = effect_kind
    intensity_stage = clampi(stage, 1, 4)
    spin_direction = -1.0 if stage == 2 else 1.0
    lifetime = 1.25 if kind == "bloom" else (0.90 if kind == "veil" else (0.42 if kind == "finisher" or kind == "echo" or kind == "cleave" else (0.22 if kind == "dash" else (0.32 if kind == "slash" or kind == "impact" else 0.30))))
    shape = MeshInstance3D.new()
    var mesh = ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    if kind == "slash":
        # Layered tapered crescents: deep crimson feather, scarlet body, bright
        # mid band and a white-hot cutting edge.
        var radius = 1.55 + 0.12 * (stage - 1)
        var arc = 138.0 if stage == 3 else (105.0 if stage == 4 else 92.0)
        if effect_quality == 1:
            _ring_band(mesh, radius - 0.78, radius - 0.52, -arc, arc, DEEP * Color(1, 1, 1, 0), SCARLET * Color(1, 1, 1, 0.26), true)
            _ring_band(mesh, radius, radius + 0.30, -arc, arc, HILITE * Color(1, 1, 1, 0.34), DEEP * Color(1, 1, 1, 0), true)
        _ring_band(mesh, radius - 0.53, radius - 0.23, -arc, arc, SCARLET * Color(1, 1, 1, 0), BRIGHT * Color(1, 1, 1, 0.45), true)
        _ring_band(mesh, radius - 0.23, radius - 0.09, -arc, arc, BRIGHT * Color(1, 1, 1, 0.66), HILITE * Color(1, 1, 1, 1.0), true)
        _ring_band(mesh, radius - 0.09, radius, -arc, arc, CORE * Color(1, 1, 1, 1.0), BRIGHT * Color(1, 1, 1, 0), true)
        if stage >= 2 and effect_quality == 1:
            _petals(mesh, 8 + stage * 3, radius + 0.15, SCARLET, HILITE)
        rotation_degrees.x = 38.0 if stage == 1 else (48.0 if stage == 2 else 20.0)
        rotation_degrees.z = -18.0 if stage == 2 else 18.0
    elif kind == "echo":
        _ring_band(mesh, 1.75, 1.88, -115, 115, DEEP * Color(1, 1, 1, 0), HILITE * Color(1, 1, 1, 0.68), true)
        _ring_band(mesh, 1.88, 1.93, -115, 115, CORE * Color(1, 1, 1, 0.9), SCARLET * Color(1, 1, 1, 0), true)
        if effect_quality == 1: _petals(mesh, 14, 1.95, BRIGHT, CORE)
        rotation_degrees.x = 60.0 if stage == 3 else 52.0
        rotation_degrees.z = 24.0 if stage == 3 else -30.0
    elif kind == "finisher":
        _ring_band(mesh, 0.38, 0.60, 0, 360, DEEP * Color(1, 1, 1, 0), BRIGHT * Color(1, 1, 1, 0.72), false)
        _ring_band(mesh, 0.60, 0.68, 0, 360, CORE * Color(1, 1, 1, 0.92), SCARLET * Color(1, 1, 1, 0), false)
        for i in range(18):
            _ground_shard(mesh, TAU * float(i) / 18.0, 0.70, 0.20 + 0.07 * (i % 3), HILITE * Color(1, 1, 1, 0.7))
        if effect_quality == 1: _petals(mesh, 12, 0.9, BRIGHT, CORE)
    elif kind == "cleave":
        # Charged attack release: wide, bright crimson arc in front of the hero.
        _ring_band(mesh, 1.20, 1.58, -55, 55, SCARLET * Color(1, 1, 1, 0), HILITE * Color(1, 1, 1, 0.85), true)
        _ring_band(mesh, 1.58, 1.65, -55, 55, CORE * Color(1, 1, 1, 0.98), BRIGHT * Color(1, 1, 1, 0), true)
        if effect_quality == 1:
            _petals(mesh, 12, 1.75, BRIGHT, CORE)
            _ring_band(mesh, 1.02, 1.16, -55, 55, DEEP * Color(1, 1, 1, 0.5), DEEP * Color(1, 1, 1, 0), true)
        rotation_degrees.x = 85.0
        rotation_degrees.z = -28.0
    elif kind == "impact":
        for i in range(16):
            var a: float = TAU * float(i) / 16.0
            var dir = Vector3(cos(a), sin(a), 0)
            var side = Vector3(-dir.y, dir.x, 0) * (0.045 if i % 2 == 0 else 0.017)
            var length = 0.35 + 0.14 * (i % 4)
            _triangle(mesh, dir * 0.05 - side, dir * length, dir * 0.05 + side, HILITE * Color(1, 1, 1, 0.95))
        _triangle(mesh, Vector3(-0.30, 0, 0), Vector3(0.30, 0, 0), Vector3(0, 0.12, 0), CORE * Color(1, 1, 1, 0.95))
        _triangle(mesh, Vector3(-0.30, 0, 0), Vector3(0, -0.12, 0), Vector3(0.30, 0, 0), CORE * Color(1, 1, 1, 0.95))
    elif kind == "dash":
        # Bloodline trail: sharp streaks along local -Z (the dash direction).
        for i in range(5):
            var off = (float(i) - 2.0) * 0.05
            var len = 0.9 + 0.25 * (i % 2)
            _triangle(mesh, Vector3(-0.030 + off, 0, 0.05), Vector3(0.030 + off, 0, 0.05), Vector3(off * 0.5, 0, -len), SCARLET * Color(1, 1, 1, 0.85))
        _ring_band(mesh, 0.30, 0.42, 0, 360, DEEP * Color(1, 1, 1, 0), BRIGHT * Color(1, 1, 1, 0.5), false)
        if effect_quality == 1: _petals(mesh, 6, 0.5, BRIGHT, HILITE)
        rotation_degrees.x = 90.0
    elif kind == "veil":
        # Scarlet Veil skill: rune-like segmented rings + orbiting streaks.
        for ring_i in range(2):
            var r = 1.15 + 0.55 * ring_i
            for seg in range(12):
                var a0 = TAU * seg / 12.0 + ring_i * 0.26
                _ring_band(mesh, r, r + 0.06, rad_to_deg(a0), rad_to_deg(a0 + TAU / 12.0 * 0.62),
                    SCARLET * Color(1, 1, 1, 0.55 if ring_i == 0 else 0.3), HILITE * Color(1, 1, 1, 0.0), false)
        _ring_band(mesh, 0.30, 0.40, 0, 360, CORE * Color(1, 1, 1, 0.85), SCARLET * Color(1, 1, 1, 0), false)
        if effect_quality == 1:
            _petals(mesh, 8, 1.45, BRIGHT, CORE)
        rotation_degrees.x = 90.0
    elif kind == "bloom":
        # CRIMSON BLOOM ultimate: petal-shaped energy segments forming a flower,
        # plus an expanding ring and a white-hot core flash.
        for i in range(8):
            var angle = TAU * float(i) / 8.0
            var r = 1.15
            var center = _point(angle, r)
            var tangent = Vector3(cos(angle), 0, sin(angle))
            var radial = _point(angle, 1.0)
            var width = 0.16
            var length = 0.85
            var col = SCARLET * Color(1, 1, 1, 0.9)
            var light = HILITE * Color(1, 1, 1, 0.95)
            var tip = center + radial * length + Vector3.UP * 0.18
            var tail = center - radial * length * 0.45
            var left = center - tangent * width
            var right = center + tangent * width
            for pair in [[tail, left], [left, tip], [tip, right], [right, tail]]:
                _vertex(mesh, center, light)
                _vertex(mesh, pair[0], col)
                _vertex(mesh, pair[1], col)
        _ring_band(mesh, 0.25, 2.4, 0, 360, CORE * Color(1, 1, 1, 0.9), DEEP * Color(1, 1, 1, 0), false)
        if effect_quality == 1:
            for i in range(10):
                _ground_shard(mesh, TAU * float(i) / 10.0, 2.2, 0.35, BRIGHT * Color(1, 1, 1, 0.8))
        rotation_degrees.x = 90.0
    else:
        _ring_band(mesh, 0.32, 0.42, 0, 360, DEEP * Color(1, 1, 1, 0), BRIGHT * Color(1, 1, 1, 0.5), false)
        _ring_band(mesh, 0.42, 0.50, 0, 360, BRIGHT * Color(1, 1, 1, 0.5), DEEP * Color(1, 1, 1, 0), false)
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
    if effect_quality == 1 and kind in ["slash", "impact", "dash", "veil", "bloom"]:
        _add_particles()

func _add_particles() -> void:
    # Tiny one-shot CPU burst parented to this effect, so cleanup is automatic
    # and the transient effect budget/group counts are untouched.
    var count := 14 if kind == "bloom" else (10 if kind == "veil" else 8)
    var p := CPUParticles3D.new()
    p.one_shot = true
    p.explosiveness = 0.92
    p.amount = count
    p.lifetime = 0.38
    p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    p.emission_sphere_radius = 0.35 if kind != "bloom" else 1.2
    p.direction = Vector3.UP
    p.spread = 65.0
    p.initial_velocity_min = 1.2
    p.initial_velocity_max = 2.6
    p.gravity = Vector3(0, -1.5, 0)
    p.damping_min = 1.5
    p.damping_max = 3.0
    var m := SphereMesh.new()
    m.radius = 0.014
    m.height = 0.028
    m.radial_segments = 6
    m.rings = 3
    p.mesh = m
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    mat.albedo_color = BRIGHT
    mat.emission_enabled = true
    mat.emission = SCARLET
    mat.emission_energy_multiplier = 2.0
    p.material_override = mat
    add_child(p)
    p.emitting = true

func _point(angle: float, radius: float) -> Vector3:
    return Vector3(sin(angle) * radius, 0, -cos(angle) * radius)

func _ring_band(mesh: ImmediateMesh, inner: float, outer: float, start: float, end: float, inner_color: Color, outer_color: Color, taper: bool) -> void:
    const SEGMENTS = 48
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

func _petals(mesh: ImmediateMesh, count: int, radius: float, col: Color = SCARLET, light: Color = CORE) -> void:
    # Deterministic diamond-shaped petals; geometry stays bounded on mobile.
    for i in range(count):
        var angle = TAU * float(i) / float(count) + 0.2 * (i % 3)
        var r = radius * (0.65 + 0.15 * (i % 3))
        var center = _point(angle, r) + Vector3.UP * (0.06 + 0.08 * (i % 4))
        var tangent = Vector3(cos(angle), 0, sin(angle))
        var radial = _point(angle, 1.0)
        var width = 0.035 + 0.008 * (i % 3)
        var length = width * 2.2
        var tip = center + radial * length
        var tail = center - radial * length * 0.65
        var left = center - tangent * width
        var right = center + tangent * width
        var upper_left = center + radial * length * 0.45 - tangent * width * 0.8
        var upper_right = center + radial * length * 0.45 + tangent * width * 0.8
        for pair in [[tail, left], [left, upper_left], [upper_left, tip], [tip, upper_right], [upper_right, right], [right, tail]]:
            _vertex(mesh, center, light)
            _vertex(mesh, pair[0], col)
            _vertex(mesh, pair[1], col)

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
    elif kind == "dash":
        shape.scale = Vector3(1.0, 1.0, lerpf(1.4, 0.4, t))
        shape.rotation.y = -0.4 * t
    elif kind == "veil":
        shape.rotation.y = lerpf(0.9, -0.9, t)
        shape.scale = Vector3.ONE * lerpf(0.8, 1.25, t)
    elif kind == "bloom":
        shape.rotation.y = t * 0.6
        shape.scale = Vector3.ONE * lerpf(0.45, 1.6, t)
    else:
        shape.scale = Vector3.ONE * lerpf(0.7, 2.0, t)
