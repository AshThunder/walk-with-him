extends Control
## Corner minimap: the neighbourhood of the player, rotated so "up" is the way the camera looks. Arrow = player, gold diamond = objective.
var ui: UI
const VIEW := 13.0          # world units from the centre to the edge
var _fr := 0

func _process(_d: float) -> void:
	_fr += 1
	if _fr % 2 == 0 and is_visible_in_tree(): queue_redraw()

func _xf(w: World, p: Vector2, c: Vector2, k: float) -> Vector2:
	var cr := w.cam_right(); var cf := w.cam_fwd()
	var rel := p - Vector2(w.player.position.x, w.player.position.z)
	return c + Vector2(rel.x * cr.x + rel.y * cr.z, -(rel.x * cf.x + rel.y * cf.z)) * k

func _draw() -> void:
	var w: World = ui.world if ui != null else null
	if w == null or not is_instance_valid(w.player) or w.cam == null: return
	var c := size * 0.5; var k := size.x * 0.5 / VIEW
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.36, 0.27, 0.16, 0.92))
	# walkable ground
	var b := w.bounds
	var gp := PackedVector2Array([_xf(w, b.position, c, k), _xf(w, Vector2(b.end.x, b.position.y), c, k), _xf(w, b.end, c, k), _xf(w, Vector2(b.position.x, b.end.y), c, k)])
	draw_colored_polygon(gp, Color(0.86, 0.76, 0.54, 0.96))
	# buildings / tables / wells
	for r in w.rects:
		var rc: Rect2 = r
		draw_colored_polygon(PackedVector2Array([_xf(w, rc.position, c, k), _xf(w, Vector2(rc.end.x, rc.position.y), c, k), _xf(w, rc.end, c, k), _xf(w, Vector2(rc.position.x, rc.end.y), c, k)]), Color(0.55, 0.38, 0.22, 0.95))
	for ci in w.circles:
		draw_circle(_xf(w, ci[0], c, k), maxf(2.0, ci[1] * k * 0.8), Color(0.5, 0.36, 0.22, 0.9))
	# people
	for key in w.npcs:
		var n = w.npcs[key]
		if is_instance_valid(n) and n != w.jesus and n.name_lbl != null:
			draw_circle(_xf(w, Vector2(n.position.x, n.position.z), c, k), 5.0, Color(0.95, 0.6, 0.45))
	if is_instance_valid(w.jesus): 
		var jp := _xf(w, Vector2(w.jesus.position.x, w.jesus.position.z), c, k)
		draw_circle(jp, 7.0, Color(1, 1, 1, 0.95)); draw_arc(jp, 7.0, 0, TAU, 16, Color(0.4, 0.25, 0.1), 2.0)
	for md in w.minidots:                                  # lambs and doves
		if is_instance_valid(md.n):
			draw_circle(_xf(w, Vector2(md.n.position.x, md.n.position.z), c, k), 4.5, md.col); draw_arc(_xf(w, Vector2(md.n.position.x, md.n.position.z), c, k), 4.5, 0, TAU, 10, Color(0.3, 0.2, 0.1), 1.5)
	# scrolls
	for key in w.scrolls:
		var sc = w.scrolls[key]
		if is_instance_valid(sc) and sc.visible:
			var sp := _xf(w, Vector2(sc.position.x, sc.position.z), c, k)
			draw_rect(Rect2(sp - Vector2(5, 5), Vector2(10, 10)), Color(1.0, 0.92, 0.5)); draw_rect(Rect2(sp - Vector2(5, 5), Vector2(10, 10)), Color(0.45, 0.28, 0.1), false, 2.0)
	# objective
	if ui.goal != null:
		var gv := Vector2(ui.goal.x, ui.goal.z)
		var gp2 := _xf(w, gv, c, k)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		var lim := size.x * 0.5 - 16.0
		var off := gp2 - c
		if absf(off.x) > lim or absf(off.y) > lim:
			var dirv := off.normalized()
			var e := c + off * (lim / maxf(absf(off.x), absf(off.y)))
			var perp := Vector2(-dirv.y, dirv.x)
			draw_colored_polygon(PackedVector2Array([e + dirv * 13.0, e - dirv * 6.0 + perp * 11.0, e - dirv * 6.0 - perp * 11.0]), Color(1.0, 0.82, 0.2))
		else:
			draw_arc(gp2, 11.0 + pulse * 6.0, 0, TAU, 24, Color(1.0, 0.85, 0.3, 0.8 - pulse * 0.5), 3.0)
			draw_colored_polygon(PackedVector2Array([gp2 + Vector2(0, -12), gp2 + Vector2(10, 0), gp2 + Vector2(0, 12), gp2 + Vector2(-10, 0)]), Color(1.0, 0.82, 0.2))
			draw_polyline(PackedVector2Array([gp2 + Vector2(0, -12), gp2 + Vector2(10, 0), gp2 + Vector2(0, 12), gp2 + Vector2(-10, 0), gp2 + Vector2(0, -12)]), Color(0.35, 0.2, 0.05), 2.0)
	# player arrow (heading in camera space)
	var yawp: float = w.player.rotation.y
	var f3 := Vector3(-sin(yawp), 0, -cos(yawp))
	var cr := w.cam_right(); var cf := w.cam_fwd()
	var hv := Vector2(f3.dot(cr), -f3.dot(cf))
	if hv.length() < 0.01: hv = Vector2(0, -1)
	hv = hv.normalized(); var pp := Vector2(-hv.y, hv.x)
	var poly := PackedVector2Array([c + hv * 15.0, c - hv * 9.0 + pp * 10.0, c - hv * 4.0, c - hv * 9.0 - pp * 10.0])
	draw_colored_polygon(poly, Color(1, 1, 1)); draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), Color(0.15, 0.4, 0.75), 3.0)
	# frame
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0, 0, 0, 0); sb.set_border_width_all(6); sb.border_color = Color(0.93, 0.74, 0.34); sb.set_corner_radius_all(22)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	draw_string(ui.F_U, Vector2(10, size.y - 8), "MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.92, 0.65))
