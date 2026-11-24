extends Node3D
# Ground Zero — one connected post-apocalyptic tutorial plaza matching
# docs/ground_zero_reference.png (East/West/North/South are four views of THIS
# world, captured in CI via --preview-view-*). Built procedurally at runtime;
# all textures are original in-repo art (assets/env/, tools/gen_env_textures.py).
#
# Optimization model (gl_compatibility renderer — no occlusion server, no
# LightmapGI, so we lean on frustum culling + aggressive visibility-range LOD):
#   LOD0  0..34 m   facades + rooftop props + balconies + vehicle detail
#   LOD1  32..70 m  facade box only (2 m hysteresis overlap, fade disabled)
#   LOD2  68..170 m plain silhouette per building (the HLOD step)
#   skyline       4 district MultiMeshes of merged silhouette boxes, 30..260 m
#   grass/rubble  8 octant MultiMesh sectors with distance visibility
# One shadow-capped DirectionalLight3D (max distance 48 m, 2 splits); far LOD
# tiers and all instancing have shadows disabled.

const ENV_TEX := "res://assets/env/"

const LOD0_END := 34.0
const LOD1_END := 70.0
const LOD2_BEGIN := 68.0
const LOD2_END := 170.0
const PROP_END := 46.0
const PROP_FAR_END := 150.0
const PLAZA_RADIUS := 13.0

var buildings: Array = []
var solids: Array = []
var vehicles: Array = []
var billboard_texts: Array = []
var tower: Node3D = null
var elevated_road: Node3D = null
var sun: DirectionalLight3D = null
var env_node: WorldEnvironment = null
var multimesh_sectors := 0

var mats := {}
var _collision: StaticBody3D


func build() -> void:
    seed(20261121)
    _collision = StaticBody3D.new()
    _collision.name = "Collision"
    add_child(_collision)
    _lighting()
    _ground()
    _buildings()
    _elevated()
    _landmarks()
    _vehicles()
    _vegetation()
    _props()
    _skyline()


# ---------------------------------------------------------------- materials

func _mat(key: String) -> StandardMaterial3D:
    if mats.has(key):
        return mats[key]
    var m := StandardMaterial3D.new()
    match key:
        "concrete":
            m.albedo_texture = load(ENV_TEX + "concrete.png")
            m.roughness = 0.92
        "concrete_dark":
            m.albedo_texture = load(ENV_TEX + "concrete.png")
            m.albedo_color = Color(0.52, 0.53, 0.56)
            m.roughness = 0.95
        "asphalt":
            m.albedo_texture = load(ENV_TEX + "asphalt.png")
            m.roughness = 0.98
        "dirt":
            m.albedo_texture = load(ENV_TEX + "dirt.png")
            m.uv1_scale = Vector3(24, 24, 1)
            m.roughness = 1.0
        "metal":
            m.albedo_color = Color(0.55, 0.57, 0.60)
            m.metallic = 0.8
            m.roughness = 0.45
        "metal_dark":
            m.albedo_color = Color(0.22, 0.23, 0.26)
            m.metallic = 0.7
            m.roughness = 0.5
        "tire":
            m.albedo_color = Color(0.08, 0.08, 0.09)
            m.roughness = 1.0
        "glass":
            m.albedo_color = Color(0.10, 0.14, 0.18)
            m.metallic = 0.6
            m.roughness = 0.15
        "windows":
            m.albedo_texture = load(ENV_TEX + "window_strip.png")
            m.roughness = 0.4
        "bark":
            m.albedo_color = Color(0.32, 0.24, 0.16)
            m.roughness = 1.0
        "leaf":
            m.albedo_texture = load(ENV_TEX + "leaf.png")
            m.roughness = 1.0
        "grass":
            m.albedo_texture = load(ENV_TEX + "grass.png")
            m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
            m.alpha_scissor_threshold = 0.45
            m.cull_mode = BaseMaterial3D.CULL_DISABLED
            m.roughness = 1.0
        "rebar":
            m.albedo_color = Color(0.45, 0.28, 0.16)
            m.roughness = 0.7
        "beacon":
            m.albedo_color = Color(1.0, 0.08, 0.08)
            m.emission_enabled = true
            m.emission = Color(1.0, 0.08, 0.08)
            m.emission_energy_multiplier = 3.0
        "lamp":
            m.albedo_color = Color(1.0, 0.85, 0.6)
            m.emission_enabled = true
            m.emission = Color(1.0, 0.85, 0.6)
            m.emission_energy_multiplier = 1.2
    mats[key] = m
    return m


# ---------------------------------------------------------------- helpers

func _box_mesh(size: Vector3) -> BoxMesh:
    var b := BoxMesh.new()
    b.size = size
    return b


func _cyl(top_r: float, bottom_r: float, h: float, seg: int) -> CylinderMesh:
    var c := CylinderMesh.new()
    c.top_radius = top_r
    c.bottom_radius = bottom_r
    c.height = h
    c.radial_segments = seg
    return c


func _sphere(r: float, h: float) -> SphereMesh:
    var s := SphereMesh.new()
    s.radius = r
    s.height = h
    s.radial_segments = 10
    s.rings = 6
    return s


func _mi(mesh: Mesh, parent: Node, pos: Vector3, mat: Material = null, yaw: float = 0.0) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    if mat != null:
        mi.material_override = mat
    mi.position = pos
    mi.rotation.y = yaw
    parent.add_child(mi)
    return mi


func _range(gi: GeometryInstance3D, begin: float, end: float) -> void:
    gi.visibility_range_begin = begin
    gi.visibility_range_end = end
    gi.visibility_range_fade_mode = 0  # DISABLED: cheap, no transparent pop


func _solid(pos: Vector3, size: Vector3, ground: bool = false) -> void:
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    shape.position = pos
    _collision.add_child(shape)
    solids.append({"pos": pos, "size": size, "ground": ground})


func _on_road(p: Vector3) -> bool:
    var r := Vector2(p.x, p.z).length()
    if absf(r - 13.9) < 3.4:
        return true
    if absf(p.x) < 3.2 and absf(p.z) > 13.0:
        return true
    if absf(p.z) < 3.2 and absf(p.x) > 13.0:
        return true
    if p.z > -19.6 and p.z < -12.4 and absf(p.x) < 37.0:
        return true  # elevated road footprint
    return false


# ---------------------------------------------------------------- lighting

func _lighting() -> void:
    var lighting := Node3D.new()
    lighting.name = "Lighting"
    add_child(lighting)
    env_node = WorldEnvironment.new()
    var env := Environment.new()
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.16, 0.42, 0.82)
    sky_mat.sky_horizon_color = Color(0.72, 0.83, 0.95)
    sky_mat.ground_bottom_color = Color(0.30, 0.32, 0.30)
    sky_mat.ground_horizon_color = Color(0.52, 0.55, 0.52)
    sky_mat.sun_angle_max = 25.0
    sky_mat.sun_curve = 0.08
    sky.sky_material = sky_mat
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.55
    env.fog_enabled = true
    env.fog_light_color = Color(0.70, 0.80, 0.93)
    env.fog_light_energy = 0.6
    env.fog_sky_affect = 0.45
    env.fog_aerial_perspective = 0.35
    env.fog_depth_begin = 80.0
    env.fog_depth_end = 260.0
    env.fog_depth_curve = 0.7
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env_node.environment = env
    lighting.add_child(env_node)
    # One sun; shadows capped to the gameplay area (baked/static look comes from
    # sky ambient + fog; the compatibility renderer cannot bake LightmapGI).
    sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50.0, 32.0, 0.0)
    sun.light_color = Color(1.0, 0.95, 0.86)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    sun.directional_shadow_max_distance = 48.0
    lighting.add_child(sun)


# ---------------------------------------------------------------- ground

func _ground() -> void:
    var plaza_node := Node3D.new()
    plaza_node.name = "Central_Plaza"
    add_child(plaza_node)
    var outer := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(240, 240)
    outer.mesh = pm
    outer.material_override = _mat("dirt")
    outer.position.y = -0.06
    plaza_node.add_child(outer)
    _range(outer, 0.0, 280.0)
    # plaza disc with cracked concrete + faded circular markings
    var disc := MeshInstance3D.new()
    var cyl := CylinderMesh.new()
    cyl.top_radius = PLAZA_RADIUS
    cyl.bottom_radius = PLAZA_RADIUS
    cyl.height = 0.12
    cyl.radial_segments = 48
    disc.mesh = cyl
    var plm := StandardMaterial3D.new()
    plm.albedo_texture = load(ENV_TEX + "plaza.png")
    plm.roughness = 0.95
    disc.material_override = plm
    plaza_node.add_child(disc)
    _range(disc, 0.0, 260.0)
    # ring road: 16 tangent segments
    var road_mat := _mat("asphalt")
    for i in range(16):
        var a := TAU * float(i) / 16.0
        var seg := _mi(_box_mesh(Vector3(5.6, 0.06, 6.0)), plaza_node, Vector3(sin(a) * 13.9, 0.015, cos(a) * 13.9), road_mat, a)
        _range(seg, 0.0, 200.0)
    # four exit roads
    for d in range(4):
        var a := TAU * float(d) / 4.0
        var road := _mi(_box_mesh(Vector3(6.0, 0.05, 34.0)), plaza_node, Vector3(sin(a) * 31.5, 0.012, cos(a) * 31.5), road_mat, a)
        _range(road, 0.0, 220.0)
    _solid(Vector3(0, -0.5, 0), Vector3(240, 1.0, 240), true)


# ---------------------------------------------------------------- buildings

func _facade_box(size: Vector3, variant: int) -> BoxMesh:
    var box := BoxMesh.new()
    box.size = size
    var fm := StandardMaterial3D.new()
    fm.albedo_texture = load(ENV_TEX + "facade_%s.png" % ["a", "b", "c", "d"][variant])
    # one texture cell = one 4.2 m window bay x one 3 m floor; buildings are
    # square in plan so one uv scale fits all four sides
    fm.uv1_scale = Vector3(size.x / 4.2, size.y / 3.0, 1.0)
    fm.roughness = 0.95
    for si in range(box.get_surface_count()):
        var n: Vector3 = box.surface_get_arrays(si)[Mesh.ARRAY_NORMAL][0]
        box.surface_set_material(si, fm if absf(n.y) < 0.5 else _mat("concrete"))
    return box


func _buildings() -> void:
    var district_names := ["East_District", "West_District", "North_District", "South_District"]
    var district_nodes := {}
    for dname in district_names:
        var dn := Node3D.new()
        dn.name = dname
        add_child(dn)
        district_nodes[dname] = dn
    var n := 0
    var angle := 8.0
    while angle < 360.0 and n < 14:
        var mod90 := fmod(angle, 90.0)
        var near_cardinal := minf(mod90, 90.0 - mod90)
        if near_cardinal > 13.0:  # keep the four road mouths open
            var a := deg_to_rad(angle)
            var r := 19.0 + float(n % 3) * 1.7
            var size := 8.0 + float((n * 5) % 3) * 2.0
            var floors := 3 + (n * 7) % 5
            var variant := n % 4
            var pos := Vector3(sin(a) * r, 0.0, cos(a) * r)
            var dname := "North_District" if pos.z < 0.0 else "South_District"
            if absf(pos.x) > absf(pos.z):
                dname = "East_District" if pos.x > 0.0 else "West_District"
            _building(district_nodes[dname], pos, Vector3(size, floors * 3.0, size), floors, variant, float(n % 3) * 0.33, angle)
            n += 1
        angle += 24.0


func _building(parent: Node, pos: Vector3, size: Vector3, floors: int, variant: int, damage: float, angle: float) -> void:
    var node := Node3D.new()
    node.name = "Building_%02d" % buildings.size()
    node.position = pos
    node.rotation.y = deg_to_rad(angle) + PI
    parent.add_child(node)
    var center := Vector3(0, size.y * 0.5, 0)
    # LOD0/LOD1: facade box (side faces get the tiled facade, roof plain concrete)
    var facade := _mi(_facade_box(size, variant), node, center)
    _range(facade, 0.0, LOD1_END)
    # LOD2: plain silhouette (HLOD step for this building)
    var simple := _mi(_box_mesh(size), node, center, _mat("concrete_dark"))
    simple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _range(simple, LOD2_BEGIN, LOD2_END)
    # LOD0-only props
    var props: Array = []
    props.append(_mi(_cyl(0.9, 0.9, 1.6, 10), node, Vector3(size.x * 0.25, size.y + 0.8, size.z * 0.2), _mat("metal")))
    for i in range(2):
        props.append(_mi(_box_mesh(Vector3(0.7, 0.5, 0.7)), node, Vector3(-size.x * 0.3 + i * 0.9, size.y + 0.25, -size.z * 0.25), _mat("metal")))
    if floors >= 5:
        props.append(_mi(_cyl(0.05, 0.08, 3.2, 6), node, Vector3(-size.x * 0.3, size.y + 1.6, size.z * 0.3), _mat("metal")))
    if variant == 1 or variant == 2:
        for f in range(1, floors, 2):
            props.append(_mi(_box_mesh(Vector3(size.x + 0.5, 0.12, 0.9)), node, Vector3(0, f * 3.0 + 0.4, size.z * 0.5 + 0.45), _mat("concrete")))
    if damage > 0.3:
        var slab := _mi(_box_mesh(Vector3(size.x * 0.45, 0.4, size.z * 0.45)), node, Vector3(-size.x * 0.28, size.y - 0.1, -size.z * 0.28), _mat("concrete"))
        slab.rotation.z = 0.35
        slab.rotation.x = -0.2
        props.append(slab)
        for i in range(3):
            props.append(_mi(_cyl(0.03, 0.03, 1.4, 5), node, Vector3(-size.x * 0.3 + i * 0.25, size.y + 0.5, -size.z * 0.3), _mat("rebar")))
    for p in props:
        _range(p, 0.0, LOD0_END)
        p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _solid(pos + center, size + Vector3(0.6, 0.0, 0.6))
    buildings.append({"node": node, "facade": facade, "simple": simple, "props": props, "pos": pos, "size": size})


# ---------------------------------------------------------------- elevated road

func _elevated() -> void:
    elevated_road = Node3D.new()
    elevated_road.name = "Elevated_Ruins"
    add_child(elevated_road)
    var deck_y := 7.2
    var z := -16.0
    var w := 7.0
    var x := -36.0
    while x < 36.0:
        var x1 := x + 6.0
        if not (x1 > -5.0 and x < 7.0):  # broken gap in the deck
            var seg := _mi(_box_mesh(Vector3(6.0, 0.9, w)), elevated_road, Vector3(x + 3.0, deck_y, z), _mat("concrete"))
            _range(seg, 0.0, 95.0)
            if randi() % 3 != 0:
                _range(_mi(_box_mesh(Vector3(6.0, 1.0, 0.15)), elevated_road, Vector3(x + 3.0, deck_y + 0.95, z - w * 0.5 + 0.1), _mat("metal_dark")), 0.0, 60.0)
            if randi() % 3 != 0:
                _range(_mi(_box_mesh(Vector3(6.0, 1.0, 0.15)), elevated_road, Vector3(x + 3.0, deck_y + 0.95, z + w * 0.5 - 0.1), _mat("metal_dark")), 0.0, 60.0)
            _solid(Vector3(x + 3.0, deck_y, z), Vector3(6.0, 0.9, w))
        x = x1
    for px in [-33.0, -27.0, -21.0, -15.0, 11.0, 17.0, 23.0, 29.0, 35.0]:
        var pil := _mi(_cyl(0.8, 1.0, deck_y, 10), elevated_road, Vector3(px, deck_y * 0.5, z), _mat("concrete"))
        _range(pil, 0.0, 95.0)
        _solid(Vector3(px, deck_y * 0.5, z), Vector3(1.8, deck_y, 1.8))
    var lean := _mi(_cyl(0.7, 0.9, 5.0, 8), elevated_road, Vector3(1.0, 2.5, z), _mat("concrete"))
    lean.rotation.z = 0.6
    _range(lean, 0.0, 60.0)
    var e1 := _mi(_box_mesh(Vector3(2.2, 0.8, 5.0)), elevated_road, Vector3(-5.6, deck_y - 0.3, z), _mat("concrete"))
    e1.rotation.z = 0.5
    _range(e1, 0.0, 60.0)
    var e2 := _mi(_box_mesh(Vector3(1.6, 0.8, 4.0)), elevated_road, Vector3(7.5, deck_y - 0.5, z + 1.0), _mat("concrete"))
    e2.rotation.z = -0.7
    e2.rotation.x = 0.3
    _range(e2, 0.0, 60.0)
    var far := _mi(_box_mesh(Vector3(72.0, 0.9, w)), elevated_road, Vector3(0, deck_y, z), _mat("concrete_dark"))
    far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _range(far, 95.0, 260.0)


# ---------------------------------------------------------------- landmarks

func _billboard(parent: Node, pos: Vector3, yaw: float, tex_name: String, text: String, size: Vector3) -> void:
    var node := Node3D.new()
    node.name = "Billboard_" + text.split(" ")[0]
    node.position = pos
    node.rotation.y = yaw
    parent.add_child(node)
    var tex: Texture2D = load(ENV_TEX + tex_name)
    var panel := BoxMesh.new()
    panel.size = size
    var bm := StandardMaterial3D.new()
    bm.albedo_texture = tex
    bm.emission_enabled = true
    bm.emission_texture = tex
    bm.emission_energy_multiplier = 0.55
    bm.roughness = 0.8
    for si in range(panel.get_surface_count()):
        var n: Vector3 = panel.surface_get_arrays(si)[Mesh.ARRAY_NORMAL][0]
        panel.surface_set_material(si, bm if n.z > 0.5 else _mat("metal_dark"))
    var p := _mi(panel, node, Vector3.ZERO)
    _range(p, 0.0, 200.0)
    for sx in [-1.0, 1.0]:
        var pole := _mi(_cyl(0.12, 0.12, pos.y, 8), node, Vector3(sx * size.x * 0.35, -pos.y * 0.5, -0.4), _mat("metal_dark"))
        _range(pole, 0.0, 120.0)
    _solid(Vector3(pos.x, pos.y * 0.5, pos.z), Vector3(size.x * 0.9, pos.y, 0.8))
    billboard_texts.append(text)


func _landmarks() -> void:
    var lm := Node3D.new()
    lm.name = "Landmarks"
    add_child(lm)
    # communication tower, south of the plaza (centred in the North view)
    tower = Node3D.new()
    tower.name = "CommTower"
    tower.position = Vector3(6.0, 0.0, 22.0)
    lm.add_child(tower)
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            _range(_mi(_box_mesh(Vector3(0.22, 24.0, 0.22)), tower, Vector3(sx * 1.4, 12.0, sz * 1.4), _mat("metal")), 0.0, 90.0)
    for h in [4.0, 8.0, 12.0, 16.0, 20.0]:
        for s in [-1.0, 1.0]:
            var b1 := _mi(_box_mesh(Vector3(0.08, 4.2, 0.08)), tower, Vector3(s * 1.4, h + 2.0, 0), _mat("metal"))
            b1.rotation.z = 0.7 * s
            _range(b1, 0.0, 90.0)
            var b2 := _mi(_box_mesh(Vector3(0.08, 4.2, 0.08)), tower, Vector3(0, h + 2.0, s * 1.4), _mat("metal"))
            b2.rotation.x = 0.7 * s
            _range(b2, 0.0, 90.0)
    for py in [10.0, 20.0]:
        _range(_mi(_cyl(2.4, 2.4, 0.25, 12), tower, Vector3(0, py, 0), _mat("metal")), 0.0, 90.0)
    _range(_mi(_cyl(0.07, 0.1, 6.0, 6), tower, Vector3(0, 27.0, 0), _mat("metal")), 0.0, 90.0)
    var dish := _mi(_sphere(1.1, 0.4), tower, Vector3(0, 20.0, 1.6), _mat("metal"))
    dish.rotation.x = -0.6
    _range(dish, 0.0, 90.0)
    _range(_mi(_sphere(0.22, 0.22), tower, Vector3(0, 30.2, 0), _mat("beacon")), 0.0, 200.0)
    var ts := _mi(_cyl(1.6, 2.2, 24.0, 10), tower, Vector3(0, 12.0, 0), _mat("concrete_dark"))
    ts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _range(ts, 90.0, 260.0)
    _solid(Vector3(6.0, 12.0, 22.0), Vector3(3.4, 24.0, 3.4))
    # the three readable billboards, oriented for their reference views:
    # East view (camera at +X) sees the west facade -> CLAUDE FOREVER
    _billboard(lm, Vector3(-23.0, 8.0, 8.0), PI / 2.0, "billboard_forever.png", "CLAUDE FOREVER", Vector3(9.0, 4.5, 0.3))
    # West view (camera at -X) sees the east facade -> HUMANITY WAS HERE...
    _billboard(lm, Vector3(23.0, 9.0, -6.0), -PI / 2.0, "billboard_humanity.png", "HUMANITY WAS HERE...", Vector3(9.0, 4.5, 0.3))
    # South view (camera at +Z) sees the north facade -> CLAUDE AI CONTROLS THE WORLD
    _billboard(lm, Vector3(2.0, 10.0, -23.0), 0.0, "billboard_controls.png", "CLAUDE AI CONTROLS THE WORLD", Vector3(10.0, 5.0, 0.3))


# ---------------------------------------------------------------- vehicles

func _car(parent: Node, pos: Vector3, yaw: float, color: Color) -> void:
    var node := Node3D.new()
    node.name = "Car_%d" % vehicles.size()
    node.position = pos
    node.rotation.y = yaw
    parent.add_child(node)
    var body_mat := StandardMaterial3D.new()
    body_mat.albedo_color = color
    body_mat.metallic = 0.35
    body_mat.roughness = 0.6
    var body := _mi(_box_mesh(Vector3(4.2, 1.0, 1.9)), node, Vector3(0, 0.75, 0), body_mat)
    var cab := _mi(_box_mesh(Vector3(2.1, 0.65, 1.7)), node, Vector3(-0.2, 1.5, 0), _mat("glass"))
    _range(body, 0.0, PROP_END)
    _range(cab, 0.0, PROP_END)
    for wx in [-1.4, 1.4]:
        for wz in [-0.85, 0.85]:
            var wheel := _mi(_cyl(0.34, 0.34, 0.24, 10), node, Vector3(wx, 0.34, wz), _mat("tire"))
            wheel.rotation.x = PI / 2.0
            _range(wheel, 0.0, PROP_END)
    var simple := _mi(_box_mesh(Vector3(4.3, 1.9, 2.0)), node, Vector3(0, 0.95, 0), body_mat)
    simple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _range(simple, PROP_END - 2.0, PROP_FAR_END)
    _solid(pos + Vector3(0, 0.9, 0), Vector3(4.3, 1.9, 2.0))
    vehicles.append(node)


func _bus(parent: Node, pos: Vector3, yaw: float) -> void:
    var node := Node3D.new()
    node.name = "Bus"
    node.position = pos
    node.rotation.y = yaw
    parent.add_child(node)
    var body_mat := StandardMaterial3D.new()
    body_mat.albedo_color = Color(0.72, 0.68, 0.55)
    body_mat.metallic = 0.3
    body_mat.roughness = 0.65
    var body := _mi(_box_mesh(Vector3(10.5, 2.4, 2.8)), node, Vector3(0, 1.45, 0), body_mat)
    var band := _mi(_box_mesh(Vector3(10.2, 0.9, 2.82)), node, Vector3(0, 1.95, 0), _mat("windows"))
    _range(body, 0.0, PROP_END)
    _range(band, 0.0, PROP_END)
    for wx in [-4.2, -1.4, 1.4, 4.2]:
        for wz in [-1.3, 1.3]:
            var wheel := _mi(_cyl(0.42, 0.42, 0.3, 10), node, Vector3(wx, 0.42, wz), _mat("tire"))
            wheel.rotation.x = PI / 2.0
            _range(wheel, 0.0, PROP_END)
    var simple := _mi(_box_mesh(Vector3(10.6, 2.9, 2.9)), node, Vector3(0, 1.45, 0), body_mat)
    simple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _range(simple, PROP_END - 2.0, PROP_FAR_END)
    _solid(pos + Vector3(0, 1.4, 0), Vector3(10.6, 2.9, 2.9))
    vehicles.append(node)


func _vehicles() -> void:
    var sv := Node3D.new()
    sv.name = "Static_Vehicles"
    add_child(sv)
    _car(sv, Vector3(-11.5, 0.0, 5.5), 0.5, Color(0.82, 0.83, 0.85))
    _car(sv, Vector3(12.0, 0.0, -8.5), -2.4, Color(0.55, 0.30, 0.16))
    _car(sv, Vector3(8.5, 0.0, 11.5), 2.8, Color(0.25, 0.38, 0.55))
    _car(sv, Vector3(-6.0, 0.0, -11.0), 0.15, Color(0.45, 0.46, 0.44))
    _bus(sv, Vector3(-15.0, 0.0, -12.5), 0.5)


# ---------------------------------------------------------------- vegetation

func _cross_quad() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var hw := 0.22
    var h := 0.55
    var quads := [
        [Vector3(-hw, 0, 0), Vector3(hw, 0, 0), Vector3(hw, h, 0), Vector3(-hw, h, 0)],
        [Vector3(0, 0, -hw), Vector3(0, 0, hw), Vector3(0, h, hw), Vector3(0, h, -hw)],
    ]
    var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
    for q in quads:
        for i in [0, 1, 2, 0, 2, 3]:
            st.set_uv(uvs[i])
            st.add_vertex(q[i])
    st.generate_normals()
    return st.commit()


func _tree(parent: Node, pos: Vector3) -> void:
    var node := Node3D.new()
    node.name = "Tree"
    node.position = pos
    parent.add_child(node)
    var trunk := _mi(_cyl(0.22, 0.32, 3.0, 7), node, Vector3(0, 1.5, 0), _mat("bark"))
    var f1 := _mi(_sphere(1.7, 1.3), node, Vector3(0, 3.6, 0), _mat("leaf"))
    var f2 := _mi(_sphere(1.1, 0.9), node, Vector3(0.8, 4.6, 0.3), _mat("leaf"))
    for m in [trunk, f1, f2]:
        _range(m, 0.0, 45.0)
    var simple := _mi(_sphere(2.3, 1.8), node, Vector3(0, 3.4, 0), _mat("leaf"))
    simple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _range(simple, 43.0, 100.0)
    _solid(pos + Vector3(0, 1.5, 0), Vector3(0.7, 3.0, 0.7))


func _vegetation() -> void:
    var veg := Node3D.new()
    veg.name = "Vegetation"
    add_child(veg)
    var tree_spots := [
        Vector3(-16.5, 0, 3.0), Vector3(17.0, 0, 9.5), Vector3(-9.0, 0, -17.0),
        Vector3(10.5, 0, -17.5), Vector3(-18.0, 0, -9.0), Vector3(16.5, 0, -4.0),
        Vector3(0.0, 0, 18.5), Vector3(-13.0, 0, 14.0),
    ]
    for tp in tree_spots:
        _tree(veg, tp)
    # grass: 8 octant MultiMesh sectors (spatially divided so frustum culling works)
    var quad := _cross_quad()
    for s in range(8):
        var xforms: Array = []
        for i in range(120):
            var a := TAU * (float(s) + randf()) / 8.0
            var r := 10.5 + randf() * 55.0
            var p := Vector3(sin(a) * r, 0.02, cos(a) * r)
            if _on_road(p) or Vector2(p.x, p.z).length() < 10.0:
                continue
            var sc := 0.6 + randf() * 0.9
            xforms.append(Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3(sc, sc, sc)), p))
        if xforms.is_empty():
            continue
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = quad
        mm.instance_count = xforms.size()
        for i in range(xforms.size()):
            mm.set_instance_transform(i, xforms[i])
        var mmi := MultiMeshInstance3D.new()
        mmi.multimesh = mm
        mmi.material_override = _mat("grass")
        mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        _range(mmi, 0.0, 55.0)
        veg.add_child(mmi)
        multimesh_sectors += 1
    # bushes
    for i in range(10):
        var a := TAU * float(i) / 10.0 + 0.4
        var r := 14.5 + randf() * 30.0
        var p := Vector3(sin(a) * r, 0, cos(a) * r)
        if _on_road(p):
            continue
        var bush := _mi(_sphere(0.8 + randf() * 0.5, 0.6 + randf() * 0.4), veg, p + Vector3(0, 0.35, 0), _mat("leaf"))
        _range(bush, 0.0, 60.0)


# ---------------------------------------------------------------- props

func _props() -> void:
    var props := Node3D.new()
    props.name = "Props"
    add_child(props)
    # rubble: 8 octant MultiMesh sectors of random concrete slabs
    for s in range(8):
        var xforms: Array = []
        for i in range(14):
            var a := TAU * (float(s) + randf()) / 8.0
            var r := 11.0 + randf() * 45.0
            var p := Vector3(sin(a) * r, 0.12, cos(a) * r)
            if _on_road(p) or Vector2(p.x, p.z).length() < 10.5:
                continue
            var sc := Vector3(0.4 + randf(), 0.3 + randf() * 0.6, 0.4 + randf())
            xforms.append(Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(sc), p))
        if xforms.is_empty():
            continue
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = _box_mesh(Vector3.ONE)
        mm.instance_count = xforms.size()
        for i in range(xforms.size()):
            mm.set_instance_transform(i, xforms[i])
        var mmi := MultiMeshInstance3D.new()
        mmi.multimesh = mm
        mmi.material_override = _mat("concrete")
        mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        _range(mmi, 0.0, 70.0)
        props.add_child(mmi)
        multimesh_sectors += 1
    # big rubble clusters near the building line
    for i in range(6):
        var a := TAU * float(i) / 6.0 + 0.3
        var p := Vector3(sin(a) * 20.5, 0.5, cos(a) * 20.5)
        var c := _mi(_box_mesh(Vector3(2.4, 1.0, 1.8)), props, p, _mat("concrete"))
        c.rotation.y = randf() * TAU
        c.rotation.z = randf() * 0.3
        _range(c, 0.0, 80.0)
        _solid(p + Vector3(0, 0.4, 0), Vector3(2.4, 1.2, 1.8))
    # streetlights around the ring road
    for i in range(8):
        var a := TAU * (float(i) + 0.5) / 8.0
        var p := Vector3(sin(a) * 16.6, 0, cos(a) * 16.6)
        var inward := Vector3(-sin(a), 0, -cos(a))
        var pole := _mi(_cyl(0.09, 0.12, 5.6, 6), props, p + Vector3(0, 2.8, 0), _mat("metal_dark"))
        var arm := _mi(_box_mesh(Vector3(1.6, 0.08, 0.08)), props, p + Vector3(0, 5.5, 0) + inward * 0.7, _mat("metal_dark"))
        arm.rotation.y = a
        var head := _mi(_box_mesh(Vector3(0.5, 0.12, 0.25)), props, p + Vector3(0, 5.45, 0) + inward * 1.4, _mat("lamp"))
        for m in [pole, arm, head]:
            _range(m, 0.0, PROP_END)
    # jersey barriers
    for i in range(6):
        var a := TAU * float(i) / 6.0 + 0.5
        var p := Vector3(sin(a) * 16.9, 0.4, cos(a) * 16.9)
        var b := _mi(_box_mesh(Vector3(2.0, 0.8, 0.45)), props, p, _mat("concrete"), a + PI / 2.0)
        _range(b, 0.0, PROP_END)
        _solid(p, Vector3(2.0, 0.8, 0.45))


# ---------------------------------------------------------------- skyline HLOD

func _skyline() -> void:
    var proxies := Node3D.new()
    proxies.name = "LOD_Proxies"
    add_child(proxies)
    # distant ruined city: per-district MultiMesh of merged silhouette boxes
    for d in range(4):
        var xforms: Array = []
        for i in range(7):
            var a := TAU * (float(d) + 0.15 + 0.7 * float(i) / 6.0) / 4.0
            var r := 46.0 + randf() * 34.0
            var h := 12.0 + randf() * 26.0
            var w := 7.0 + randf() * 8.0
            var p := Vector3(sin(a) * r, h * 0.5 - 0.2, cos(a) * r)
            xforms.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3(w, h, w)), p))
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = _box_mesh(Vector3.ONE)
        mm.instance_count = xforms.size()
        for i in range(xforms.size()):
            mm.set_instance_transform(i, xforms[i])
        var mmi := MultiMeshInstance3D.new()
        mmi.multimesh = mm
        mmi.material_override = _mat("concrete_dark")
        mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        _range(mmi, 30.0, 260.0)
        proxies.add_child(mmi)
        multimesh_sectors += 1
