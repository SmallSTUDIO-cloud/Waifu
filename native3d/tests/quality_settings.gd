extends SceneTree

func _initialize() -> void:
    call_deferred("run_test")

func fail(message: String) -> void:
    printerr("FAIL quality: ", message)
    quit(1)

func run_test() -> void:
    var SETTINGS = load("res://scripts/settings.gd")
    var settings = SETTINGS.new()
    settings.path = "user://quality-test.cfg"
    settings.physics = 1; settings.effects = 0
    if settings.save_settings() != OK:
        fail("save")
        return
    var reloaded = SETTINGS.new()
    reloaded.path = settings.path
    reloaded.load_settings()
    if reloaded.physics != 1 or reloaded.effects != 0:
        fail("saved settings did not reload")
        return
    var cfg = ConfigFile.new()
    cfg.set_value("quality", "physics", 99)
    cfg.set_value("quality", "effects", -9)
    cfg.save(settings.path)
    reloaded.load_settings()
    if reloaded.physics != 2 or reloaded.effects != 0:
        fail("invalid tiers not clamped")
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.path))
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    scene.quality_settings.effects = 1
    scene._swing_vfx(2)
    var full_count = get_nodes_in_group("combat_effects").size()
    for e in get_nodes_in_group("combat_effects"): e.queue_free()
    await process_frame
    scene.quality_settings.effects = 0
    scene._swing_vfx(2)
    var low_count = get_nodes_in_group("combat_effects").size()
    if low_count != 1 or full_count <= low_count:
        fail("reduced effects did not reduce transient effects")
        return
    for effect in get_nodes_in_group("combat_effects"): effect.queue_free()
    await process_frame
    scene.quality_settings.effects = 1
    for i in range(5): scene._swing_vfx(4)
    scene.quality_settings.effects = 0
    scene._swing_vfx(4)
    var live = get_nodes_in_group("combat_effects").filter(func(e): return not e.is_queued_for_deletion())
    if live.size() > 6:
        fail("switching to reduced did not enforce its effect budget")
        return
    scene.start_game()
    var hp = scene.player.health
    scene._pause()
    scene.profile_enabled = true
    scene.profile_last_us = 12345
    scene._process(1.0)
    if scene.profile_last_us != 0:
        fail("pause polluted profiling frame times")
        return
    scene.profile_enabled = false
    if not scene.menu_action.text == "RESUME" or not scene.physics_button.visible:
        fail("pause quality controls")
        return
    scene._resume()
    if not scene.playing or scene.player.health != hp:
        fail("resume reset encounter")
        return
    ProjectSettings.set_setting("secondary_motion/profile_shadow_enabled", false)
    var isolated_player = load("res://scripts/player.gd").new()
    root.add_child(isolated_player)
    await process_frame
    isolated_player.enabled = true
    if OS.is_debug_build() and (isolated_player.shadow_root != null or not isolated_player.dodge()):
        fail("shadow-off profiling build cannot dodge without allocating shadow")
        return
    isolated_player.queue_free()
    ProjectSettings.set_setting("secondary_motion/profile_shadow_enabled", true)
    print("PASS settings persistence, quality controls, reduced VFX, pause/resume and shadow profiling")
    quit(0)
