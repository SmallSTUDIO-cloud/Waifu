extends Control

var direction: Vector2 = Vector2.ZERO
var touch_index: int = -1
var dragging: bool = false
var sprinting: bool = false
var knob: Vector2 = Vector2.ZERO
const RADIUS: float = 72.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _draw() -> void:
    # Glass look: translucent disc, bright rim, top highlight, frosted knob.
    # While sprinting the whole control glows blue.
    var center: Vector2 = size * 0.5
    var rim = Color(0.40, 0.78, 1.0) if sprinting else Color(1, 1, 1)
    if sprinting:
        draw_circle(center, RADIUS, Color(0.30, 0.62, 1.0, 0.16))
        draw_arc(center, RADIUS + 8.0, 0.0, TAU, 64, Color(rim.r, rim.g, rim.b, 0.15), 10.0)
        draw_arc(center, RADIUS + 4.0, 0.0, TAU, 64, Color(rim.r, rim.g, rim.b, 0.35), 5.0)
    else:
        draw_circle(center, RADIUS, Color(1, 1, 1, 0.10))
    draw_arc(center, RADIUS, 0.0, TAU, 64, Color(rim.r, rim.g, rim.b, 0.85 if sprinting else 0.38), 2.5 if sprinting else 2.0)
    draw_arc(center, RADIUS - 9.0, PI * 1.02, PI * 1.62, 32, Color(rim.r, rim.g, rim.b, 0.28), 7.0)
    var knob_pos = center + knob * RADIUS * 0.65
    draw_circle(knob_pos, 30.0, Color(rim.r, rim.g, rim.b, 0.28 if sprinting else 0.25))
    draw_arc(knob_pos, 30.0, 0.0, TAU, 32, Color(rim.r, rim.g, rim.b, 0.9 if sprinting else 0.60), 2.0)
    draw_arc(knob_pos, 23.0, PI * 1.05, PI * 1.7, 24, Color(rim.r, rim.g, rim.b, 0.45), 5.0)

func _input(event: InputEvent) -> void:
    if not visible or not is_inside_tree():
        return
    if event is InputEventScreenTouch:
        if event.pressed and touch_index == -1 and get_global_rect().has_point(event.position):
            touch_index = event.index
            _move(event.position)
        elif not event.pressed and event.index == touch_index:
            _reset()
    elif event is InputEventScreenDrag and event.index == touch_index:
        _move(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed and get_global_rect().has_point(event.position):
            dragging = true
            _move(event.position)
        elif not event.pressed and dragging:
            dragging = false
            _reset()
    elif event is InputEventMouseMotion and dragging:
        _move(event.position)

func _move(point: Vector2) -> void:
    knob = ((point - global_position - size * 0.5) / RADIUS).limit_length(1.0)
    direction = knob
    queue_redraw()

func _reset() -> void:
    touch_index = -1
    dragging = false
    knob = Vector2.ZERO
    direction = Vector2.ZERO
    queue_redraw()
