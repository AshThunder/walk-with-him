extends Control
## Full map of the Holy Land: Bethlehem's fields and town, the Temple at Jerusalem, Nazareth, the road and Cana, with the player, the scrolls and the current objective.
var ui: UI
## region: [map rect, world bounds, title, subtitle, decoration]
const REG := {
	"cana": [Rect2(640, 400, 320, 200), Rect2(-12, -10, 24, 20), "CANA", "the wedding feast", "village"],
	"nazareth": [Rect2(110, 540, 320, 240), Rect2(-13, -13, 27, 26), "NAZARETH", "home village", "village"],
	"temple": [Rect2(610, 860, 320, 200), Rect2(-14, -12, 28, 24), "JERUSALEM", "the Temple", "temple"],
	"fields": [Rect2(90, 1170, 260, 170), Rect2(-14, -12, 28, 24), "THE FIELDS", "shepherds' watch", "fields"],
	"town": [Rect2(400, 1170, 300, 170), Rect2(-14, -12, 28, 24), "BETHLEHEM", "the stable", "village"],
}
const NAZ := Rect2(110, 540, 320, 240)
# the road from Nazareth to Cana (leaves the Nazareth box on its east side)
const ROAD := [Vector2(430, 670), Vector2(490, 690), Vector2(540, 620), Vector2(560, 560), Vector2(600, 520), Vector2(640, 500)]
const PATHS := [[Vector2(350, 1255), Vector2(400, 1255)], [Vector2(560, 1170), Vector2(610, 1110), Vector2(680, 1060)]]
const SCROLLS := [["prov3_5", "nazareth", Vector2(-6.6, 6.0), "Proverbs 3:5"], ["ps119_105", "road", Vector2(21.5, -8.2), "Psalm 119:105"], ["ps34_8", "cana", Vector2(2.4, 6.8), "Psalm 34:8"]]
const PLACES := [["nazareth", Vector2(-0.2, 3.4), "Naomi"], ["nazareth", Vector2(8.0, -4.2), "Jesus"], ["cana", Vector2(3.0, 0.0), "Mary"], ["cana", Vector2(5.0, -5.2), "Waterpots"], ["cana", Vector2(1.8, -3.3), "Governor"],
	["fields", Vector2(7.0, -6.4), "Fold"], ["town", Vector2(7.2, -7.5), "Stable"], ["temple", Vector2(0.0, -6.0), "Simeon"]]
const INK := Color(0.32, 0.18, 0.07)
var _road_len := []
var _total := 0.0

func _ready() -> void:
	var acc := 0.0
	for i in ROAD.size() - 1:
		acc += ROAD[i].distance_to(ROAD[i + 1]); _road_len.append(acc)
	_total = acc

func _process(_d: float) -> void:
	if is_visible_in_tree(): queue_redraw()

func road_at(t: float) -> Array:      # returns [point, tangent]
	var d := clampf(t, 0.0, 1.0) * _total; var prev := 0.0
	for i in _road_len.size():
		if d <= _road_len[i] or i == _road_len.size() - 1:
			var seg: float = _road_len[i] - prev
			var u := clampf((d - prev) / maxf(seg, 0.01), 0.0, 1.0)
			return [ROAD[i].lerp(ROAD[i + 1], u), (ROAD[i + 1] - ROAD[i]).normalized()]
		prev = _road_len[i]
	return [ROAD[0], Vector2.RIGHT]

## world (area, x, z) -> map position
func to_map(area: String, p: Vector2) -> Vector2:
	if area == "road":
		var rt := road_at((p.x + 9.0) / 58.0); var tg: Vector2 = rt[1]
		return rt[0] + Vector2(-tg.y, tg.x) * (p.y / 12.0 * 34.0)
	var rg: Array = REG.get(area, REG["nazareth"])       # an area with no place on the map (the doorpost at home) clamps to Nazareth
	var r: Rect2 = rg[0]; var b: Rect2 = rg[1]
	var u := Vector2((p.x - b.position.x) / b.size.x, (p.y - b.position.y) / b.size.y)
	if not REG.has(area): u = u.clamp(Vector2.ZERO, Vector2.ONE)
	return r.position + u * r.size

func _txt(s: String, pos: Vector2, fs: int, col := INK, f: Font = null, w := -1.0, al := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string(f if f != null else ui.F_U, pos, s, al, w, fs, col)

func _house(p: Vector2, sc := 1.0) -> void:
	draw_rect(Rect2(p - Vector2(13, 8) * sc, Vector2(26, 18) * sc), Color(0.82, 0.68, 0.46)); draw_rect(Rect2(p - Vector2(13, 8) * sc, Vector2(26, 18) * sc), INK, false, 2.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -8) * sc, p + Vector2(0, -22) * sc, p + Vector2(16, -8) * sc]), Color(0.66, 0.35, 0.2))

func _draw() -> void:
	var w: World = ui.world
	# parchment
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.93, 0.85, 0.66); sb.border_color = Color(0.45, 0.26, 0.1); sb.set_border_width_all(8); sb.set_corner_radius_all(36); sb.shadow_size = 14; sb.shadow_color = Color(0, 0, 0, 0.5)
	draw_style_box(sb, Rect2(40, 170, 1000, 1640))
	_txt("THE HOLY LAND", Vector2(40, 270), 84, INK, ui.F_T, 1000)
	_txt("Tap Close, or press Back, to return", Vector2(40, 330), 34, Color(0.5, 0.35, 0.18), ui.F_S, 1000)
	# land & lake
	draw_colored_polygon(PackedVector2Array([Vector2(80, 380), Vector2(1000, 380), Vector2(1000, 1500), Vector2(80, 1500)]), Color(0.86, 0.78, 0.56, 0.55))
	var lake := PackedVector2Array(); for i in 28:
		var a := TAU * float(i) / 28.0; lake.append(Vector2(985, 730) + Vector2(cos(a) * 62.0, sin(a) * 170.0))
	draw_colored_polygon(lake, Color(0.55, 0.73, 0.82, 0.8)); _txt("Sea of Galilee", Vector2(985, 720), 26, Color(0.2, 0.35, 0.5), ui.F_S, 110)
	for h in [Vector2(250, 450), Vector2(420, 430), Vector2(480, 900), Vector2(200, 960)]:
		draw_colored_polygon(PackedVector2Array([h + Vector2(-90, 50), h + Vector2(0, -40), h + Vector2(90, 50)]), Color(0.74, 0.66, 0.44, 0.7))
	# road
	var rp := PackedVector2Array(ROAD)
	draw_polyline(rp, Color(0.55, 0.38, 0.2), 30.0, true); draw_polyline(rp, Color(0.8, 0.66, 0.4), 22.0, true)
	for i in 30:
		var q: Array = road_at(float(i) / 30.0 + 0.016); draw_circle(q[0], 3.0, Color(0.55, 0.38, 0.2))
	var mid_r: Array = road_at(0.5)
	_txt("THE ROAD", mid_r[0] + Vector2(-210, 8), 40, INK, ui.F_U, 160)
	for pth in PATHS: draw_polyline(PackedVector2Array(pth), Color(0.55, 0.38, 0.2), 20.0, true); draw_polyline(PackedVector2Array(pth), Color(0.8, 0.66, 0.4), 13.0, true)
	# regions
	for ar in REG:
		var rg: Array = REG[ar]; var rc: Rect2 = rg[0]
		var rsb := StyleBoxFlat.new(); rsb.bg_color = Color(0.82, 0.88, 0.6, 0.85); rsb.border_color = INK; rsb.set_border_width_all(5); rsb.set_corner_radius_all(40)
		draw_style_box(rsb, rc)
		if w.area != ar:
			match rg[4]:
				"fields":
					for hp in [Vector2(0.25, 0.35), Vector2(0.45, 0.6), Vector2(0.7, 0.3), Vector2(0.78, 0.65)]: draw_circle(rc.position + hp * rc.size, 9.0, Color(0.97, 0.95, 0.9)); draw_arc(rc.position + hp * rc.size, 9.0, 0, TAU, 10, INK, 2.0)
					draw_circle(rc.position + Vector2(0.5, 0.3) * rc.size, 8.0, Color(0.95, 0.5, 0.15))
				"temple":
					for i in 6: draw_rect(Rect2(rc.position + Vector2(28 + i * 48, 40), Vector2(14, 70)), Color(0.9, 0.84, 0.7)); draw_rect(Rect2(rc.position + Vector2(28 + i * 48, 40), Vector2(14, 70)), INK, false, 2.0)
					draw_rect(Rect2(rc.position + Vector2(20, 120), Vector2(rc.size.x - 40, 14)), Color(0.9, 0.84, 0.7)); draw_rect(Rect2(rc.position + Vector2(20, 120), Vector2(rc.size.x - 40, 14)), INK, false, 2.0)
				_:
					for hp in ([Vector2(0.25, 0.3), Vector2(0.62, 0.25), Vector2(0.4, 0.6), Vector2(0.75, 0.62), Vector2(0.2, 0.75)]): _house(rc.position + hp * rc.size, 1.0 if rc.size.y < 200 else 1.2)
		else:
			for r in w.rects:
				var a := to_map(ar, (r as Rect2).position); var b := to_map(ar, (r as Rect2).end)
				draw_rect(Rect2(a, b - a).abs(), Color(0.72, 0.52, 0.32, 0.95)); draw_rect(Rect2(a, b - a).abs(), INK, false, 1.5)
		_txt(rg[2], Vector2(rc.position.x, rc.end.y + 50), 52 if rc.size.x > 280 else 44, INK, ui.F_T, rc.size.x)
		_txt(rg[3], Vector2(rc.position.x, rc.end.y + 92), 32, Color(0.5, 0.35, 0.18), ui.F_S, rc.size.x)
	# fixed story places
	for pl in PLACES:
		var mp := to_map(pl[0], pl[1]); draw_circle(mp, 7.0, Color(0.95, 0.6, 0.45)); draw_arc(mp, 7.0, 0, TAU, 14, INK, 2.0)
		_txt(pl[2], mp + Vector2(-60, -14), 30, INK, ui.F_S, 120)
	# scrolls
	for s in (SCROLLS if Game.age_stage == "adult" else []):
		var sp := to_map(s[1], s[2]); var got: bool = Game.scrolls.has(s[0])
		draw_rect(Rect2(sp - Vector2(11, 11), Vector2(22, 22)), Color(0.7, 0.68, 0.62) if got else Color(1.0, 0.9, 0.4)); draw_rect(Rect2(sp - Vector2(11, 11), Vector2(22, 22)), INK, false, 3.0)
		if got: draw_polyline(PackedVector2Array([sp + Vector2(-6, 0), sp + Vector2(-1, 6), sp + Vector2(8, -6)]), Color(0.2, 0.5, 0.2), 4.0)
		_txt(s[3], sp + Vector2(-80, 34), 28, INK, ui.F_S, 160)
	# objective (gold pulsing marker) + player
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	if ui.goal != null:
		var gp := to_map(w.area, Vector2(ui.goal.x, ui.goal.z))
		draw_arc(gp, 24.0 + pulse * 12.0, 0, TAU, 28, Color(0.9, 0.55, 0.1, 0.9 - pulse * 0.5), 5.0)
		var star := PackedVector2Array([gp + Vector2(0, -26), gp + Vector2(8, -8), gp + Vector2(26, 0), gp + Vector2(8, 8), gp + Vector2(0, 26), gp + Vector2(-8, 8), gp + Vector2(-26, 0), gp + Vector2(-8, -8)])
		draw_colored_polygon(star, Color(1.0, 0.78, 0.15)); draw_polyline(PackedVector2Array(star + PackedVector2Array([star[0]])), INK, 3.0)
	if is_instance_valid(w.player):
		var pm := to_map(w.area, Vector2(w.player.position.x, w.player.position.z))
		var yw: float = w.player.rotation.y
		var hv := Vector2(-sin(yw), -cos(yw)); var pp := Vector2(-hv.y, hv.x)
		draw_circle(pm, 30.0 + pulse * 6.0, Color(0.2, 0.5, 0.9, 0.22))
		var poly := PackedVector2Array([pm + hv * 26.0, pm - hv * 16.0 + pp * 18.0, pm - hv * 7.0, pm - hv * 16.0 - pp * 18.0])
		draw_colored_polygon(poly, Color(1, 1, 1)); draw_polyline(PackedVector2Array(poly + PackedVector2Array([poly[0]])), Color(0.15, 0.4, 0.75), 4.0)
		_txt("YOU", pm + Vector2(-40, 58), 34, Color(0.1, 0.3, 0.65), ui.F_U, 80)
	# legend / quest
	var ly := 1500.0
	draw_line(Vector2(80, ly - 16), Vector2(1000, ly - 16), Color(0.45, 0.26, 0.1, 0.5), 2.0)
	_txt("GOAL", Vector2(80, ly + 34), 34, Color(0.6, 0.38, 0.1), ui.F_U, 200, HORIZONTAL_ALIGNMENT_LEFT)
	_txt(ui.obj_lbl.text, Vector2(190, ly + 36), 42, INK, ui.F_S, 810, HORIZONTAL_ALIGNMENT_LEFT)
	if Game.age_stage == "adult": _txt("Scrolls %d / 3" % Game.scrolls.size(), Vector2(80, ly + 92), 40, INK, ui.F_U, 400, HORIZONTAL_ALIGNMENT_LEFT)
	draw_colored_polygon(PackedVector2Array([Vector2(540, ly + 74), Vector2(550, ly + 88), Vector2(540, ly + 102), Vector2(530, ly + 88)]), Color(1.0, 0.78, 0.15))
	_txt("goal", Vector2(560, ly + 94), 30, INK, ui.F_S, 100, HORIZONTAL_ALIGNMENT_LEFT)
	if Game.age_stage == "adult":
		draw_rect(Rect2(660, ly + 76, 20, 20), Color(1.0, 0.9, 0.4)); draw_rect(Rect2(660, ly + 76, 20, 20), INK, false, 2.0)
		_txt("scroll", Vector2(690, ly + 94), 30, INK, ui.F_S, 100, HORIZONTAL_ALIGNMENT_LEFT)
	draw_colored_polygon(PackedVector2Array([Vector2(810, ly + 100), Vector2(800, ly + 78), Vector2(820, ly + 82)]) , Color(1, 1, 1)); _txt("you", Vector2(840, ly + 94), 30, INK, ui.F_S, 100, HORIZONTAL_ALIGNMENT_LEFT)
