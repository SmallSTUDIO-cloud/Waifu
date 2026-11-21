extends Control

var direction: Vector2 = Vector2.ZERO
var touch_index: int = -1
var dragging: bool = false
var knob: Vector2 = Vector2.ZERO
const RADIUS: float = 72.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _draw() -> void:
    var center: Vector2 = size * 0.5
    draw_circle(center, RADIUS, Color(0.04, 0.08, 0.12, 0.55))
    draw_arc(center, RADIUS, 0.0, TAU, 64, Color(0.9, 0.95, 1.0, 0.38), 2.0)
    draw_circle(center + knob * RADIUS * 0.65, 27.0, Color(0.8, 0.88, 0.92, 0.35))
    draw_arc(center + knob * RADIUS * 0.65, 27.0, 0.0, TAU, 32, Color(0.95, 0.96, 1.0, 0.6), 2.0)

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
