extends RefCounted
# Small fixed-step angular spring. This is a bounded approximation, not a soft-body solver.
var angle: float = 0.0
var velocity: float = 0.0

func step(target: float, delta: float, stiffness: float, damping: float, limit: float) -> float:
    var dt: float = clampf(delta, 0.0, 1.0 / 30.0)
    var safe_target: float = clampf(target, -limit, limit)
    velocity += ((safe_target - angle) * stiffness - velocity * damping) * dt
    angle = clampf(angle + velocity * dt, -limit, limit)
    if absf(angle) >= limit:
        velocity = 0.0
    return angle
