extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const JOYSTICK_SCRIPT = preload("res://scripts/joystick.gd")
const COMBAT_VFX = preload("res://scripts/combat_vfx.gd")
const SETTINGS = preload("res://scripts/settings.gd")
var player: CharacterBody3D
var camera: Camera3D
var joystick: Control
var hud: Control
var menu: Control
var health_label: Label
var count_label: Label
var tip_label: Label
var timer: float = 0.0
var playing: bool = false
var remaining: int = 0
var preview_mode: String = ""
var preview_action_started: bool = false
var review_camera: String = ""
var review_attack: bool = false
var review_dodge: bool = false
var camera_kick: float = 0.0
var profile_enabled: bool = false
var profile_time: float = 0.0
var profile_last_us: int = 0
var profile_frames: Array[float] = []
var profile_reported: bool = false
var profile_warmup: float = 2.0
var profile_duration: float = 10.0
var quality_settings: RefCounted
var menu_action: Button
var physics_button: Button
var effects_button: Button

func _ready() -> void:
    _environment()
    _arena()
    player = PLAYER_SCRIPT.new()
    add_child(player)
    profile_enabled = OS.is_debug_build() and bool(ProjectSettings.get_setting("secondary_motion/profile_debug", false))
    profile_warmup = maxf(0.0, float(ProjectSettings.get_setting("secondary_motion/profile_warmup", 2.0)))
    profile_duration = maxf(profile_warmup + 1.0, float(ProjectSettings.get_setting("secondary_motion/profile_duration", 10.0)))
    player.profile_secondary = profile_enabled
    player.position = Vector3(0, 0.1, 3)
    player.health_changed.connect(_on_health)
    player.hit_enemy.connect(_hit_enemy)
    player.attack_swing.connect(_swing_vfx)
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 47.0
    camera.position = Vector3(0, 4.0, 7.0)
    add_child(camera)
    camera.look_at(Vector3(0, 1, 0))
    quality_settings = SETTINGS.new()
    quality_settings.load_settings()
    player.secondary_motion.set_quality(quality_settings.physics)
    _ui()
    _update_camera(1.0)
    var args = OS.get_cmdline_user_args()
    if player.motion_driver:
        player.motion_driver.use_formal_walk = not "--legacy-walk" in args
        player.motion_driver.use_sword_dash = not "--legacy-dash" in args
    if "--smoke-play" in args or "--preview-move" in args or "--preview-attack" in args or "--preview-dodge" in args or "--preview-combo" in args or "--preview-impact" in args or "--preview-grip" in args:
        start_game()
    for side in ["front", "side", "rear"]:
        if "--preview-review-" + side in args:
            review_camera = side
            preview_mode = "review"
            start_game()
            hud.visible = false
            player.invulnerable = 99.0
            for enemy in get_tree().get_nodes_in_group("enemies"):
                enemy.enabled = false
                enemy.visible = false
    if "--preview-settings" in args:
        start_game()
        call_deferred("_pause")
    if "--preview-move" in args: preview_mode = "move"
    if "--preview-attack" in args: preview_mode = "attack"
    if "--preview-dodge" in args: preview_mode = "dodge"
    if "--preview-combo" in args: preview_mode = "combo"
    if "--preview-grip" in args:
        preview_mode = "grip"
        hud.visible = false
        for enemy in get_tree().get_nodes_in_group("enemies"):
            enemy.enabled = false
            enemy.visible = false
    if "--preview-impact" in args:
        preview_mode = "impact"
        var enemies = get_tree().get_nodes_in_group("enemies")
        for enemy in enemies: enemy.enabled = false
        if not enemies.is_empty(): enemies[0].global_position = player.global_position + Vector3(0.55, 0, -1.5)

func _environment() -> void:
    var env_node = WorldEnvironment.new()
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.025, 0.045, 0.07)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.40, 0.48, 0.56)
    env.ambient_light_energy = 0.9
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env_node.environment = env
    add_child(env_node)
    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.light_color = Color(0.75, 0.83, 1.0)
    sun.light_energy = 1.0
    sun.shadow_enabled = false
    add_child(sun)
    var red = OmniLight3D.new()
    red.position = Vector3(-5, 3, -5)
    red.light_color = Color(1.0, 0.1, 0.16)
    red.light_energy = 2.0
    red.omni_range = 12.0
    add_child(red)

func _material(color: Color, metal: float = 0.0, glow: bool = false) -> StandardMaterial3D:
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metal
    material.roughness = 0.65
    if glow:
        material.emission_enabled = true
        material.emission = color
    return material

func _box(pos: Vector3, size: Vector3, color: Color, metal: float = 0.0, glow: bool = false) -> MeshInstance3D:
    var mesh = MeshInstance3D.new()
    var box = BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.material_override = _material(color, metal, glow)
    mesh.position = pos
    add_child(mesh)
    return mesh

func _arena() -> void:
    var floor_body = StaticBody3D.new()
    var shape = CollisionShape3D.new()
    var box = BoxShape3D.new()
    box.size = Vector3(20, 0.3, 20)
    shape.shape = box
    shape.position.y = -0.15
    floor_body.add_child(shape)
    add_child(floor_body)
    _box(Vector3(0, -0.16, 0), Vector3(20, 0.3, 20), Color(0.09, 0.13, 0.17), 0.65)
    for i in range(-4, 5):
        _box(Vector3(i * 2, 0.006, 0), Vector3(0.025, 0.012, 19.8), Color(0.24, 0.29, 0.32), 0.4)
        _box(Vector3(0, 0.007, i * 2), Vector3(19.8, 0.012, 0.025), Color(0.24, 0.29, 0.32), 0.4)
    for side in [-1, 1]:
        _box(Vector3(side * 9.7, 0.8, 0), Vector3(0.13, 0.12, 20), Color(0.35, 0.39, 0.42))
        _box(Vector3(0, 0.8, side * 9.7), Vector3(20, 0.12, 0.13), Color(0.35, 0.39, 0.42))
        for i in range(-4, 5, 2):
            _box(Vector3(side * 9.7, 0.4, i * 2), Vector3(0.12, 0.8, 0.12), Color(0.25, 0.29, 0.32))
            _box(Vector3(i * 2, 0.4, side * 9.7), Vector3(0.12, 0.8, 0.12), Color(0.25, 0.29, 0.32))
    for i in range(14):
        var x = -26.0 + i * 4.0
        var h = 4.0 + float((i * 17) % 9)
        _box(Vector3(x, h * 0.5 - 2.0, -22), Vector3(3.2, h, 3.0), Color(0.04 + (i % 3) * 0.01, 0.06, 0.08))
        _box(Vector3(x, h * 0.4 - 2.0, -20.45), Vector3(0.06, h * 0.35, 0.04), Color(0.5, 0.025, 0.04), 0.0, true)

func _make_label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
    var label = Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 2)
    return label

func _button(text: String, size: Vector2) -> Button:
    var button = Button.new()
    button.text = text
    button.custom_minimum_size = size
    button.add_theme_font_size_override("font_size", 20)
    var normal = StyleBoxFlat.new()
    normal.bg_color = Color(0.13, 0.17, 0.21, 0.9)
    normal.border_color = Color(0.9, 0.28, 0.33)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(24)
    var pressed = normal.duplicate()
    pressed.bg_color = Color(0.65, 0.12, 0.18, 0.95)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", normal)
    button.add_theme_stylebox_override("pressed", pressed)
    return button

func _ui() -> void:
    var layer = CanvasLayer.new()
    add_child(layer)
    hud = Control.new()
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(hud)
    count_label = _make_label("HOSTILES  0 / 4", 20)
    count_label.position = Vector2(30, 26)
    hud.add_child(count_label)
    health_label = _make_label("HP  100", 20)
    health_label.position = Vector2(30, 55)
    hud.add_child(health_label)
    tip_label = _make_label("Move  •  Attack  •  Dodge red warnings", 17, Color(0.8, 0.86, 0.9))
    tip_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    tip_label.offset_left = -170
    tip_label.offset_top = 28
    tip_label.offset_right = 200
    tip_label.offset_bottom = 58
    hud.add_child(tip_label)
    joystick = Control.new()
    joystick.set_script(JOYSTICK_SCRIPT)
    joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    joystick.offset_left = 36
    joystick.offset_right = 196
    joystick.offset_top = -196
    joystick.offset_bottom = -36
    hud.add_child(joystick)
    var attack = _button("ATTACK", Vector2(130, 100))
    attack.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    attack.offset_left = -166
    attack.offset_right = -36
    attack.offset_top = -140
    attack.offset_bottom = -40
    hud.add_child(attack)
    attack.button_down.connect(_attack)
    var dodge = _button("DODGE", Vector2(110, 76))
    dodge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    dodge.offset_left = -298
    dodge.offset_right = -188
    dodge.offset_top = -118
    dodge.offset_bottom = -42
    hud.add_child(dodge)
    dodge.button_down.connect(_dodge)
    var pause_button = _button("II", Vector2(64, 56))
    pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    pause_button.offset_left = -92
    pause_button.offset_right = -28
    pause_button.offset_top = 24
    pause_button.offset_bottom = 80
    hud.add_child(pause_button)
    pause_button.pressed.connect(_pause)
    hud.visible = false
    menu = Control.new()
    menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(menu)
    _show_menu("SCARLET VEIL", "NATIVE 3D COMBAT TEST  /  OPERATION NIGHTFALL", "DEPLOY")

func _show_menu(title: String, subtitle: String, action: String) -> void:
    for child in menu.get_children():
        child.queue_free()
    menu.visible = true
    var shade = ColorRect.new()
    shade.color = Color(0.02, 0.035, 0.05, 0.72)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu.add_child(shade)
    var column = VBoxContainer.new()
    column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    column.offset_left = -300
    column.offset_right = 300
    column.offset_top = -205
    column.offset_bottom = 205
    column.add_theme_constant_override("separation", 15)
    menu.add_child(column)
    var kicker = _make_label("SMALL STUDIO  /  SCARLET VEIL", 17, Color(0.96, 0.32, 0.38))
    column.add_child(kicker)
    var heading = _make_label(title, 54)
    column.add_child(heading)
    column.add_child(_make_label(subtitle, 18, Color(0.76, 0.82, 0.85)))
    var button = _button(action, Vector2(260, 60))
    column.add_child(button)
    menu_action = button
    button.pressed.connect(start_game)
    var quality_row = HBoxContainer.new()
    quality_row.add_theme_constant_override("separation", 12)
    column.add_child(quality_row)
    physics_button = _button("", Vector2(285, 52))
    effects_button = _button("", Vector2(285, 52))
    physics_button.add_theme_font_size_override("font_size", 16)
    effects_button.add_theme_font_size_override("font_size", 16)
    quality_row.add_child(physics_button)
    quality_row.add_child(effects_button)
    physics_button.pressed.connect(_cycle_physics)
    effects_button.pressed.connect(_cycle_effects)
    _refresh_quality_labels()

func _refresh_quality_labels() -> void:
    physics_button.text = "PHYSICS: " + ["OFF", "REDUCED", "FULL"][quality_settings.physics]
    effects_button.text = "VFX: " + ["REDUCED", "FULL"][quality_settings.effects]

func _cycle_physics() -> void:
    quality_settings.physics = (quality_settings.physics + 1) % 3
    player.secondary_motion.set_quality(quality_settings.physics)
    quality_settings.save_settings()
    _refresh_quality_labels()

func _cycle_effects() -> void:
    quality_settings.effects = (quality_settings.effects + 1) % 2
    quality_settings.save_settings()
    _refresh_quality_labels()

func start_game() -> void:
    if profile_enabled:
        profile_time = 0.0
        profile_last_us = 0
        profile_frames.clear()
        profile_reported = false
        player.profile_secondary = true
        player.profile_secondary_us = 0
        player.profile_secondary_max_us = 0
        player.profile_secondary_steps = 0
        player.profile_shadow_us = 0
        player.profile_shadow_count = 0
    for node in get_tree().get_nodes_in_group("enemies"):
        node.queue_free()
    player.position = Vector3(0, 0.1, 3)
    player.health = 100
    player.invulnerable = 0.0
    player.attack_timer = 0.0
    player.attack_cooldown = 0.0
    player.attack_buffered = false
    if player.sword_trail: player.sword_trail.clear_trail()
    if player.secondary_motion: player.secondary_motion.reset()
    player.combo = 0
    player.combo_timeout = 0.0
    player.dash_time = 0.0
    player.dash_cooldown = 0.0
    player.velocity = Vector3.ZERO
    player.speed_ratio = 0.0
    player.turn_lean = 0.0
    camera_kick = 0.0
    player.enabled = true
    player.control = Vector2.ZERO
    timer = 0.0
    remaining = 4
    for i in range(4):
        var enemy = ENEMY_SCRIPT.new()
        enemy.target = player
        add_child(enemy)
        enemy.position = Vector3((float(i) - 1.5) * 2.0, 0.1, -3.5)
        enemy.enabled = true
        enemy.defeated.connect(_on_defeated)
    menu.visible = false
    hud.visible = true
    playing = true
    _on_health(100)
    _refresh_count()

# Optional debug-only benchmark enabled by the project profile setting.
# Wall-frame timing includes vsync and all game work, not just the solver.
func _process(delta: float) -> void:
    if not profile_enabled or profile_reported: return
    if not playing:
        profile_last_us = 0
        return
    profile_time += delta
    var now = Time.get_ticks_usec()
    if profile_time > profile_warmup and profile_last_us > 0:
        profile_frames.append(float(now - profile_last_us) / 1000.0)
    profile_last_us = now
    if profile_time >= profile_duration and not profile_frames.is_empty():
        profile_frames.sort()
        var total = 0.0
        for sample in profile_frames: total += sample
        var p50 = profile_frames[clampi(int(ceil(profile_frames.size() * 0.50)) - 1, 0, profile_frames.size() - 1)]
        var p95 = profile_frames[clampi(int(ceil(profile_frames.size() * 0.95)) - 1, 0, profile_frames.size() - 1)]
        var p99 = profile_frames[clampi(int(ceil(profile_frames.size() * 0.99)) - 1, 0, profile_frames.size() - 1)]
        print("SECONDARY_PROFILE frames=%d avg_frame_ms=%.2f p50_frame_ms=%.2f p95_frame_ms=%.2f p99_frame_ms=%.2f solver_steps=%d avg_solver_us=%.1f max_solver_us=%d quality=%d shadow_captures=%d avg_shadow_capture_us=%.1f godot_static_mb=%.1f" % [profile_frames.size(), total / profile_frames.size(), p50, p95, p99, player.profile_secondary_steps, float(player.profile_secondary_us) / maxf(1, player.profile_secondary_steps), player.profile_secondary_max_us, player.secondary_motion.quality, player.profile_shadow_count, float(player.profile_shadow_us) / maxf(1, player.profile_shadow_count), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
        profile_reported = true
        player.profile_secondary = false

func _physics_process(delta: float) -> void:
    if not playing:
        return
    timer += delta
    var keyboard = Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): keyboard.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): keyboard.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): keyboard.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): keyboard.y += 1.0
    player.control = (joystick.direction + keyboard).limit_length(1.0)
    if preview_mode == "move": player.control = Vector2(0.0, -1.0)
    if preview_mode == "review":
        player.control = Vector2(0.0, -0.65) if timer < 0.9 else Vector2.ZERO
        if timer > 1.1 and not review_attack:
            _attack()
            review_attack = true
        if timer > 2.0 and not review_dodge:
            _dodge()
            review_dodge = true
    if not preview_action_started and timer > 0.08:
        if preview_mode == "attack" or preview_mode == "combo" or preview_mode == "impact": _attack()
        if preview_mode == "dodge": _dodge()
        preview_action_started = true
    if preview_mode == "combo" and player.combo == 1 and timer > 0.54: _attack()
    if preview_mode == "combo" and player.combo == 2 and timer > 1.0: _attack()
    if preview_mode == "combo" and player.combo == 3 and timer > 1.46: _attack()
    _update_camera(delta)
    if timer > 8.0: tip_label.visible = false

func _update_camera(delta: float) -> void:
    if preview_mode == "review":
        var center = player.global_position + Vector3(0, 0.95, 0)
        var offset = Vector3(0, 0.35, 1.9)
        if review_camera == "front": offset = Vector3(0, 0.35, -1.9)
        if review_camera == "side": offset = Vector3(1.9, 0.35, 0)
        camera.global_position = center + offset
        camera.look_at(center, Vector3.UP)
        return
    if preview_mode == "grip" and is_instance_valid(player.sword_grip):
        var focus = player.sword_grip.global_position
        camera.global_position = focus + Vector3(0.60, 0.18, 0.80)
        camera.look_at(focus, Vector3.UP)
        return
    var camera_offset = Vector3(0, 3.5, 5.3)
    if preview_mode != "": camera_offset = Vector3(0, 2.0, 2.8)
    var desired = player.global_position + camera_offset
    camera_kick = maxf(0.0, camera_kick - delta * 4.0)
    var shake = Vector3(sin(timer * 87.0), cos(timer * 63.0), 0) * camera_kick * 0.035
    camera.global_position = camera.global_position.lerp(desired, minf(1.0, delta * 5.0)) + shake
    camera.look_at(player.global_position + Vector3(0, 1.0, -0.25 if preview_mode != "" else -1.0))

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_J: _attack()
        elif event.keycode == KEY_SPACE: _dodge()
        elif event.keycode == KEY_ESCAPE: _pause()

func _attack() -> void:
    if playing:
        player.attack()

func _spawn_vfx(kind: String, location: Vector3, stage: int = 1) -> Node3D:
    # Keep transient geometry bounded when hitting several enemies at once.
    var active_effects = get_tree().get_nodes_in_group("combat_effects").filter(func(node): return not node.is_queued_for_deletion())
    var budget = 12 if quality_settings.effects == 1 else 6
    while active_effects.size() >= budget:
        active_effects.pop_front().queue_free()
    var effect = COMBAT_VFX.new()
    effect.add_to_group("combat_effects")
    effect.setup(kind, stage, quality_settings.effects)
    add_child(effect)
    effect.global_position = location
    return effect

func _swing_vfx(stage: int) -> void:
    var effect = _spawn_vfx("slash", player.global_position + Vector3(0, 1.0, 0), stage)
    var yaw = atan2(-player.facing.x, -player.facing.z)
    effect.rotation.y = yaw
    if stage >= 2 and quality_settings.effects == 1:
        var echo = _spawn_vfx("echo", player.global_position + Vector3(0, 1.0, 0), stage)
        echo.rotation.y = yaw
    if stage >= 3:
        _spawn_vfx("finisher", player.global_position + Vector3(0, 0.035, 0), stage)
    if stage == 4:
        var cleave = _spawn_vfx("cleave", player.global_position + player.facing * 1.15 + Vector3(0, 1.0, 0), stage)
        cleave.rotation.y = yaw
        camera_kick = maxf(camera_kick, 0.55)

func _dodge() -> void:
    if playing and player.dodge():
        _spawn_vfx("dodge", player.global_position + Vector3(0, 0.04, 0))

func _hit_enemy(enemy: Node3D, damage: int) -> void:
    if is_instance_valid(enemy):
        camera_kick = 1.0 if damage > 1 else 0.65
        # Place sparks just in front of the target surface rather than inside
        # its opaque mesh, so depth testing does not hide the hit feedback.
        var hit_center = enemy.global_position + Vector3(0, 1.0, 0)
        var toward_camera = (camera.global_position - hit_center).normalized()
        var effect = _spawn_vfx("impact", hit_center + toward_camera * 0.55, player.combo)
        effect.look_at(camera.global_position, Vector3.UP)
        enemy.take_damage(damage)

func _on_defeated() -> void:
    remaining -= 1
    _refresh_count()
    if remaining <= 0:
        playing = false
        player.enabled = false
        hud.visible = false
        _show_menu("ROOFTOP SECURE", "COMBAT TEST COMPLETE  /  %d SECONDS" % int(timer), "RETRY")

func _on_health(value: int) -> void:
    health_label.text = "HP  %d" % value
    if value <= 0 and playing:
        playing = false
        player.enabled = false
        hud.visible = false
        for enemy in get_tree().get_nodes_in_group("enemies"): enemy.enabled = false
        _show_menu("MISSION FAILED", "REGROUP AND TRY AGAIN", "RETRY")

func _refresh_count() -> void:
    count_label.text = "HOSTILES  %d / 4" % remaining

func _pause() -> void:
    if not playing: return
    playing = false
    player.enabled = false
    player.control = Vector2.ZERO
    joystick._reset()
    hud.visible = false
    for enemy in get_tree().get_nodes_in_group("enemies"): enemy.enabled = false
    _show_menu("PAUSED", "RETURN TO THE ROOFTOP WHEN READY", "RESUME")
    menu_action.pressed.disconnect(start_game)
    menu_action.pressed.connect(_resume)

func _resume() -> void:
    menu.visible = false
    hud.visible = true
    player.enabled = true
    for enemy in get_tree().get_nodes_in_group("enemies"): enemy.enabled = true
    playing = true
