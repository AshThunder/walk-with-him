extends Control
## Trace the Star (chapter 5): a night sky with the star at one end of a dotted path and a lit house at the other.
## The finger follows the path and the gold line grows behind it. It cannot fail: leave it alone and the star draws its own road.
signal finished
var font: Font
var pts := PackedVector2Array()
var prog := 0
var prog_f := 0.0
var drawing := false
var active := false
var done := false
var idle := 0.0
var _t := 0.0
var _stars: Array = []
const TOL := 150.0
const GOLD := Color(1.0, 0.82, 0.35)

func _ready() -> void:
	size = Vector2(1080, 1920); mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a := Vector2(190, 470); var b := Vector2(1010, 640); var c := Vector2(70, 1090); var d := Vector2(800, 1420)
	for i in 61:
		var t := i / 60.0; var u := 1.0 - t
		pts.append(u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d)
	var r := RandomNumberGenerator.new(); r.seed = 77
	for i in 70: _stars.append([Vector2(r.randf_range(20, 1060), r.randf_range(80, 1500)), r.randf_range(1.5, 4.5)])
	set_process(true)

func gesture(kind: String, pos: Vector2) -> void:
	if not active or done: return
	var p := pos - global_position
	match kind:
		"down": drawing = p.distance_to(pts[prog]) < TOL
		"up": drawing = false
		"move":
			if not drawing:
				if p.distance_to(pts[prog]) < TOL: drawing = true
				else: return
			var best := prog; var bd := 1e9
			for j in range(prog, mini(prog + 10, pts.size())):
				var dd := p.distance_to(pts[j])
				if dd < bd: bd = dd; best = j
			if bd < TOL and best > prog: _advance(best)

func _advance(i: int) -> void:
	prog = i; prog_f = float(i); idle = 0.0
	if prog >= pts.size() - 2 and not done:
		done = true; active = false; finished.emit()
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if active and not done:
		idle += dt
		if idle > 12.0:                         # nobody is tracing: the star draws its own road
			prog_f += dt * 14.0
			if int(prog_f) > prog: _advance(mini(int(prog_f), pts.size() - 1)); idle = 12.0
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.14, 0.94))
	for s in _stars: draw_circle(s[0], s[1] * (1.0 + 0.25 * sin(_t * 2.0 + s[0].x)), Color(0.85, 0.88, 1.0, 0.8))
	# the dotted road still to draw
	for i in range(0, pts.size(), 2):
		if i > prog: draw_circle(pts[i], 7.0, Color(0.6, 0.66, 0.9, 0.75))
	if prog > 0: draw_polyline(pts.slice(0, prog + 1), GOLD, 16.0, true)
	# the little town: a hill and a lit house
	var e: Vector2 = pts[pts.size() - 1]
	draw_colored_polygon(PackedVector2Array([Vector2(480, 1600), Vector2(700, 1470), Vector2(1080, 1440), Vector2(1080, 1600)]), Color(0.1, 0.13, 0.26))
	draw_rect(Rect2(e.x - 70, e.y + 60, 140, 90), Color(0.18, 0.2, 0.36))
	draw_colored_polygon(PackedVector2Array([Vector2(e.x - 84, e.y + 62), Vector2(e.x, e.y + 14), Vector2(e.x + 84, e.y + 62)]), Color(0.14, 0.16, 0.3))
	draw_rect(Rect2(e.x - 18, e.y + 92, 36, 58), GOLD)
	# the star at the finger's end of the line
	var p: Vector2 = pts[prog]; var k := 1.0 + 0.12 * sin(_t * 5.0) + (0.0 if drawing else 0.1 * absf(sin(_t * 2.5)))
	draw_circle(p, 62.0 * k, Color(1.0, 0.9, 0.5, 0.25))
	var poly := PackedVector2Array()
	for i in 8:
		var rr := (46.0 if i % 2 == 0 else 17.0) * k; var a := TAU * i / 8.0
		poly.append(p + Vector2(sin(a), -cos(a)) * rr)
	draw_colored_polygon(poly, GOLD)
	if font != null and not done:
		draw_string(font, Vector2(0, 250), "Trace the star's road", HORIZONTAL_ALIGNMENT_CENTER, 1080, 64, Color(1, 0.92, 0.7))
		draw_string(font, Vector2(0, 318), "Follow the star with your finger", HORIZONTAL_ALIGNMENT_CENTER, 1080, 40, Color(0.8, 0.84, 1.0))
