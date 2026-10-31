extends Control
## On-screen objective guide: a gold arrow orbiting the player that points at the goal, a distance read-out, and a glowing dotted trail on the ground.
var ui: UI

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var w: World = ui.world if ui != null else null
	if w == null or ui.goal == null or not ui.hud_on or ui.overlay_open() or not is_instance_valid(w.player) or w.cam == null: return
	var pp: Vector3 = w.player.position; var g: Vector3 = ui.goal
	var dv := Vector3(g.x - pp.x, 0, g.z - pp.z); var dist := dv.length()
	if dist < 3.2: return
	var t := Time.get_ticks_msec() * 0.001
	var ps := w.ground_to_screen(pp + Vector3(0, 0.9, 0))
	# glowing trail on the ground (straight line toward the goal, up to ~11 units)
	var dir := dv / dist
	for i in range(1, 10):
		var u := float(i) * 1.15
		if u > minf(dist - 1.5, 11.0): break
		var ph := fposmod(t * 1.6 - float(i) * 0.22, 1.0)
		var a := 0.25 + 0.6 * (1.0 - ph)
		var sp := w.ground_to_screen(pp + dir * u + Vector3(0, 0.05, 0))
		draw_circle(sp, 20.0, Color(1.0, 0.82, 0.3, a * 0.18)); draw_circle(sp, 11.0, Color(1.0, 0.86, 0.4, a * 0.5)); draw_circle(sp, 5.0, Color(1.0, 0.97, 0.8, a))
	# the arrow
	var gs := w.ground_to_screen(g + Vector3(0, 0.9, 0))
	var d2 := gs - ps
	if d2.length() < 1.0: return
	var dn := d2.normalized(); var pn := Vector2(-dn.y, dn.x)
	var r := 170.0 + 10.0 * sin(t * 4.0)
	var c := ps + dn * r
	var tip := c + dn * 38.0
	var poly := PackedVector2Array([tip, c - dn * 14.0 + pn * 34.0, c - dn * 2.0, c - dn * 14.0 - pn * 34.0])
	draw_colored_polygon(PackedVector2Array([tip + dn * 8.0, c - dn * 22.0 + pn * 44.0, c - dn * 4.0, c - dn * 22.0 - pn * 44.0]), Color(0.1, 0.05, 0.02, 0.45))
	draw_colored_polygon(poly, Color(1.0, 0.82, 0.22)); draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), Color(0.4, 0.22, 0.05), 4.0)
	var txt := "%d m" % int(round(dist))
	var tp := c - dn * 52.0 - Vector2(40, -10)
	draw_string_outline(ui.F_U, tp, txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 34, 8, Color(0.1, 0.05, 0.02, 0.9))
	draw_string(ui.F_U, tp, txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 34, Color(1, 0.94, 0.7))
