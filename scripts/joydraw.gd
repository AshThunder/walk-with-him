extends Control
func _process(_d: float) -> void:
	queue_redraw()
func _draw() -> void:
	if not Touch.stick_active: return
	var o: Vector2 = Touch.stick_origin; var p: Vector2 = o + Touch.stick * Touch.STICK_R
	draw_circle(o, Touch.STICK_R, Color(1, 0.9, 0.6, 0.12)); draw_arc(o, Touch.STICK_R, 0, TAU, 48, Color(1, 0.9, 0.6, 0.55), 4.0)
	draw_circle(p, 46.0, Color(1, 0.88, 0.5, 0.55)); draw_arc(p, 46.0, 0, TAU, 32, Color(1, 0.95, 0.75, 0.9), 3.0)
