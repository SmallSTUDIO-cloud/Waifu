extends SceneTree

var failures: int = 0

func _initialize() -> void:
    call_deferred("run_test")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        printerr("FAIL character: ", message)

func run_test() -> void:
    var SETTINGS = load("res://scripts/settings.gd")
    var settings = SETTINGS.new()
    settings.path = "user://character-test.cfg"
    settings.character = "tesla"
    if settings.save_settings() != OK:
        fail("save")
        return
    var reloaded = SETTINGS.new()
    reloaded.path = settings.path
    reloaded.load_settings()
    check(reloaded.character == "tesla", "character did not persist")
    var cfg = ConfigFile.new()
    cfg.set_value("quality", "character", "hacked")
    cfg.save(settings.path)
    reloaded.load_settings()
    check(reloaded.character == "scarlet", "invalid character not clamped")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.path))

    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var player = scene.player
    check(player.character_name == "scarlet", "default character")
    check(player.headband != null and not player.headband.visible, "headband hidden for scarlet")
    check(player.tinted_materials.size() > 0 and player.original_albedos.size() == player.tinted_materials.size(), "material table")
    var original_sum := Color(0, 0, 0, 0)
    for c in player.original_albedos: original_sum += c

    scene._cycle_character()
    check(scene.quality_settings.character == "tesla", "cycle to tesla")
    check(player.character_name == "tesla" and player.headband.visible, "tesla applied in player")
    var tesla_sum := Color(0, 0, 0, 0)
    for m in player.tinted_materials: tesla_sum += m.albedo_color
    check(tesla_sum != original_sum, "tesla palette did not recolor materials")
    check(scene.character_button.text == "CHARACTER: TESLA", "menu label")
    check(player.skeleton.get_bone_count() > 20, "rig unchanged")
    var attachment = player.headband.get_parent()
    check(attachment is BoneAttachment3D and attachment.bone_name == "J_Bip_C_Head", "headband on head bone")

    # Combat regression for the alternate character.
    scene.start_game()
    await process_frame
    check(player.character_name == "tesla", "start_game kept tesla")
    var enemies = get_nodes_in_group("enemies")
    check(enemies.size() == 4, "encounter spawns")
    enemies[0].global_position = player.global_position + Vector3(0, 0, -1.0)
    player.facing = Vector3(0, 0, -1)
    var hp_before = enemies[0].hp
    player.attack()
    for i in range(20): await physics_frame
    check(enemies[0].hp < hp_before, "tesla attack hits")
    player.dash_cooldown = 0.0
    check(player.dodge(), "tesla dodge works")

    scene._cycle_character()
    check(player.character_name == "scarlet" and not player.headband.visible, "cycle back to scarlet")
    var restored_sum := Color(0, 0, 0, 0)
    for m in player.tinted_materials: restored_sum += m.albedo_color
    check(restored_sum == original_sum, "scarlet palette not restored")

    scene.queue_free()
    if failures == 0:
        print("PASS character select: persistence, palette swap, headband, combat regression")
    quit(1 if failures else 0)

func fail(message: String) -> void:
    printerr("FAIL character: ", message)
    quit(1)
