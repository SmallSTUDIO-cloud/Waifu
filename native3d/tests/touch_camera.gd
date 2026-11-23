extends SceneTree

var failures: int = 0

func _initialize() -> void:
    call_deferred("run_test")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        printerr("FAIL camera: ", message)

func touch(index: int, pressed: bool, pos: Vector2) -> InputEventScreenTouch:
    var e = InputEventScreenTouch.new()
    e.index = index
    e.pressed = pressed
    e.position = pos
    return e

func drag(index: int, pos: Vector2) -> InputEventScreenDrag:
    var e = InputEventScreenDrag.new()
    e.index = index
    e.position = pos
    return e

func route_input(scene: Node, event: InputEvent) -> void:
    # Both Node._input callbacks receive every event. Route joystick first so
    # ownership is deterministic in this headless regression.
    scene.joystick._input(event)
    scene._input(event)

func run_test() -> void:
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    scene.start_game()
    await process_frame
    for enemy in get_nodes_in_group("enemies"): enemy.enabled = false

    # Controls claim touches before camera gestures, independently of dispatch order.
    # (pause_button is excluded here because routing a press on it pauses the game.)
    for control in [scene.joystick, scene.attack_button, scene.dodge_button]:
        var pos = control.get_global_rect().get_center()
        scene._input(touch(11, true, pos))
        check(scene.camera_touches.is_empty(), "HUD control claimed by camera")
        scene._input(touch(11, false, pos))

    var center = Vector2(400, 200)
    scene._input(touch(1, true, center))
    var yaw_before: float = scene.camera_yaw
    scene._input(drag(1, center + Vector2(100, 40)))
    check(scene.camera_yaw != yaw_before and scene.camera_pitch > scene.CAMERA_DEFAULT_PITCH, "one-finger orbit")
    scene._input(drag(1, center + Vector2(100, 10000)))
    check(is_equal_approx(scene.camera_pitch, scene.CAMERA_MAX_PITCH), "upper pitch limit")
    scene._input(drag(1, center + Vector2(100, -10000)))
    check(is_equal_approx(scene.camera_pitch, scene.CAMERA_MIN_PITCH), "lower pitch limit")
    scene._input(touch(1, false, center))

    scene.camera_yaw = 0.0
    scene.camera_pitch = scene.CAMERA_DEFAULT_PITCH
    scene.camera_distance = scene.CAMERA_DEFAULT_DISTANCE
    scene._input(touch(1, true, Vector2(400, 200)))
    scene._input(touch(2, true, Vector2(600, 200)))
    scene._input(touch(3, true, Vector2(800, 200)))
    check(scene.camera_touches.size() == 2, "third camera finger claimed")
    scene._input(drag(2, Vector2(800, 200)))
    check(scene.camera_distance < scene.CAMERA_DEFAULT_DISTANCE and is_zero_approx(scene.camera_yaw), "pinch out zooms in without orbit")
    scene._input(drag(2, Vector2(3000, 200)))
    check(is_equal_approx(scene.camera_distance, scene.CAMERA_MIN_DISTANCE), "minimum zoom")
    scene._input(drag(2, Vector2(410, 200)))
    check(is_equal_approx(scene.camera_distance, scene.CAMERA_MAX_DISTANCE), "maximum zoom")
    scene._input(touch(2, false, Vector2(410, 200)))
    scene._input(drag(1, Vector2(420, 200)))
    check(scene.camera_yaw != 0.0 and scene.camera_pinch_distance == 0.0, "one finger resumes orbit after pinch")
    scene._input(touch(1, false, Vector2(420, 200)))

    # Coincident fingers should never create NaNs or an initial zoom jump.
    scene.camera_distance = scene.CAMERA_DEFAULT_DISTANCE
    scene._input(touch(1, true, center))
    scene._input(touch(2, true, center))
    scene._input(drag(2, center + Vector2(40, 0)))
    check(is_equal_approx(scene.camera_distance, scene.CAMERA_DEFAULT_DISTANCE), "coincident pinch rebaseline")
    scene._input(touch(1, false, center))
    scene._input(touch(2, false, center))

    # Verify actual event routing while the movement joystick is held.
    var stick_center: Vector2 = scene.joystick.get_global_rect().get_center()
    route_input(scene, touch(7, true, stick_center))
    route_input(scene, drag(7, stick_center + Vector2(0, -45)))
    route_input(scene, touch(8, true, center))
    route_input(scene, drag(8, center + Vector2(40, 0)))
    await process_frame
    check(scene.joystick.touch_index == 7 and scene.joystick.direction.y < -0.1, "simultaneous joystick input")
    check(scene.camera_touches.has(8) and not scene.camera_touches.has(7), "separate camera ownership")
    route_input(scene, touch(7, false, stick_center))
    route_input(scene, touch(8, false, center))
    await process_frame
    check(scene.joystick.touch_index == -1 and scene.camera_touches.is_empty(), "release cleanup")

    # HUD buttons must work while the joystick finger is held (multi-touch).
    scene.player.attack_cooldown = 0.0
    scene.player.attack_timer = 0.0
    scene.player.dash_time = 0.0
    route_input(scene, touch(7, true, stick_center))
    route_input(scene, drag(7, stick_center + Vector2(0, -45)))
    var atk_center: Vector2 = scene.attack_button.get_global_rect().get_center()
    route_input(scene, touch(9, true, atk_center))
    check(scene.control_touches.get(9) == scene.attack_button, "attack button claimed its touch")
    check(scene.player.attack_timer > 0.0, "attack fired while joystick held")
    check(scene.joystick.touch_index == 7 and scene.joystick.direction.y < -0.1, "joystick still owned while button pressed")
    check(scene.camera_touches.is_empty(), "button touch not claimed by camera")
    route_input(scene, touch(9, false, atk_center))
    check(not scene.control_touches.has(9), "button touch released")
    route_input(scene, touch(7, false, stick_center))

    # Forward and dodge follow the displayed camera, not world north.
    scene.camera.global_position = scene.player.global_position + Vector3(5, 3, 0)
    scene.joystick.direction = Vector2(0, -1)
    scene._physics_process(0.0)
    check(scene.player.control.x < -0.99 and absf(scene.player.control.y) < 0.01, "camera-relative movement")
    scene.player.dash_cooldown = 0.0
    scene._dodge()
    check(scene.player.dash_direction.x < -0.99, "camera-relative dodge")
    scene.joystick._reset()

    scene._input(touch(1, true, center))
    scene._pause()
    check(scene.camera_touches.is_empty(), "pause clears gesture")
    var paused_yaw: float = scene.camera_yaw
    scene._input(drag(1, center + Vector2(200, 0)))
    scene._resume()
    scene._input(drag(1, center + Vector2(400, 0)))
    check(scene.camera_yaw == paused_yaw and scene.camera_touches.is_empty(), "stale touch after resume")
    scene._input(touch(2, true, center))
    scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    check(scene.camera_touches.is_empty(), "focus loss clears touches")

    scene.queue_free()
    if failures == 0:
        print("PASS touch camera: orbit, pinch, limits, control ownership, movement, pause")
    quit(1 if failures else 0)
