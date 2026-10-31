class_name Flock
extends Node
## Lead the Flock: the road. One verb: lead. A named flock is gathered along a short road, kept together, defended with a staff tap and
## brought to the fire. The flock is one MultiMesh (merged sheep, per-instance colour); the boids are cheap (a 2 m grid, followers only).
## Nothing here can fail: wolves scatter lambs but never harm them, and a lamb that wandered is found again at camp.
const P = preload("res://scripts/person.gd")
const PR = preload("res://scripts/props.gd")

enum S { STRAY, FOLLOW, SCATTER, JUMP, SETTLE }
enum W { LURK, STALK, PAUSE, FLEE, LEAVE, GONE }

const SPEED := 4.3                  # the player's top speed on the road
const RECRUIT_R := 2.3
const STAFF_R := 2.7
const STAFF_RANGE := 6.5
const CELL := 2.0

class Lamb:
	var id := 0
	var name := ""
	var p := Vector2.ZERO
	var v := Vector2.ZERO
	var state := 0
	var yaw := 0.0
	var pop := -1.0            # seconds since recruited (squash and jump), -1 = none
	var glow := 0.0            # 0 stray .. 1 follower (wool brightness)
	var ph := 0.0
	var bright := 1.0
	var scat := 0.0
	var home := Vector2.ZERO
	var wcd := 0.0
	var wt := Vector2.ZERO
	var was := false           # has been in the flock at some point
	var rescued := 0           # times scattered and gathered again
	var lie := 0.0
	var rest := Vector2.ZERO
	var stuck := 0.0
	var j0 := Vector2.ZERO
	var j1 := Vector2.ZERO
	var jt := 0.0
	var hop := 0.0
	var hop_d := 0.0

class Wolf:
	var node: Node3D
	var tail: Node3D
	var ring: MeshInstance3D
	var p := Vector2.ZERO
	var v := Vector2.ZERO
	var state := 0
	var t := 0.0
	var lunges := 0
	var away := Vector2.ZERO
	var seen := false

class Dot:
	var position := Vector3.ZERO

var m
var w: World
var ui: UI

var lambs: Array[Lamb] = []
var wolves: Array[Wolf] = []
var dots: Array = []
var mm: MultiMesh
var mmi: MultiMeshInstance3D
var mode := ""                       # "" | road | settle
var cfg := {}
var lay := {}
var pp := Vector2.ZERO
var pv := Vector2.ZERO
var heading := Vector2(0, -1)
var cam_off := Vector3(0, 0.9, -6.0)
var t := 0.0
var staff_cd := 0.0
var shake := 0.0
var last_bleat := -9.0
var last_pop := -9.0
var last_name := -9.0
var nf := 0
var driven := 0
var lunges_total := 0
var _grid := {}
var _lean := 0.0
var _mood_t := 0.0
var _first_wolf := true
var _arrived := false
var _bursts: Array = []
var _burst_i := 0
var hud: Control
var res := {}
var tint_col := Color.WHITE
var _hops := 0.0

static var _mesh: ArrayMesh

func setup(main) -> void:
	m = main; w = main.world; ui = main.ui
	Touch.world_tap.connect(_on_tap)

# ================================================================== the merged lamb
static func sheep_mesh() -> ArrayMesh:
	if _mesh != null: return _mesh
	var src := PR.sheep()
	P.mk(src, P.sphere(0.12, 6, 4), Color(0.93, 0.9, 0.82), Vector3(0, 0.6, 0.5))               # tail tuft
	P.mk(src, P.sphere(0.07, 5, 3), Color(0.93, 0.9, 0.82), Vector3(0, 0.88, -0.38), Vector3(1.4, 0.8, 1.0))   # forelock
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := 0
	var sc := Transform3D(Basis.from_scale(Vector3.ONE * 0.62), Vector3.ZERO)
	for c in src.get_children():
		if not (c is MeshInstance3D): continue
		var mesh: Mesh = c.mesh
		var mat = c.material_override
		var col: Color = mat.albedo_color if mat != null else Color.WHITE
		var xf: Transform3D = sc * c.transform
		var nb := xf.basis.inverse().transposed()
		var arr := mesh.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx = arr[Mesh.ARRAY_INDEX]
		for i in vs.size():
			st.set_color(col); st.set_normal((nb * ns[i]).normalized()); st.add_vertex(xf * vs[i])
		if idx == null or (idx as PackedInt32Array).is_empty():
			for i in vs.size(): st.add_index(base + i)
		else:
			for k in (idx as PackedInt32Array): st.add_index(base + k)
		base += vs.size()
	src.free()
	_mesh = st.commit()
	var fm := StandardMaterial3D.new(); fm.vertex_color_use_as_albedo = true; fm.vertex_color_is_srgb = true; fm.roughness = 1.0
	_mesh.surface_set_material(0, fm)
	return _mesh

static func tint_color(name: String) -> Color:
	match name:
		"gold": return Color(1.0, 0.86, 0.58)
		"rose": return Color(1.0, 0.82, 0.86)
	return Color.WHITE

func _make_mm(n: int) -> void:
	_free_mm()
	mm = MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = sheep_mesh(); mm.instance_count = n
	mmi = MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.custom_aabb = AABB(Vector3(-40, -2, -80), Vector3(80, 8, 160))
	w.root.add_child(mmi)
	tint_col = tint_color(Game.tint)

func retint() -> void:
	tint_col = tint_color(Game.tint); _update_mm()

func _free_mm() -> void:
	if mmi != null and is_instance_valid(mmi): mmi.queue_free()
	mmi = null; mm = null

# ================================================================== setup
func teardown() -> void:
	mode = ""; _arrived = false
	lambs.clear(); wolves.clear(); dots.clear(); _bursts.clear(); _grid.clear()
	_free_mm()
	if hud != null and is_instance_valid(hud): hud.queue_free()
	hud = null; res = {}
	if w != null:
		w.custom_move = false; w.tap_walk = true; w.minidots.clear()
		if w.player != null and is_instance_valid(w.player): w.player.rotation.x = 0.0
	pv = Vector2.ZERO; shake = 0.0

func _new_lamb(i: int, name: String, p: Vector2) -> Lamb:
	var l := Lamb.new(); l.id = i; l.name = name; l.p = p; l.home = p
	l.yaw = randf() * TAU; l.ph = randf() * TAU; l.bright = randf_range(0.93, 1.0); l.wcd = randf() * 2.0
	return l

func _free_spot(p: Vector2, r := 0.5) -> Vector2:
	for c in w.circles:
		var d: Vector2 = p - c[0]; var mm_: float = c[1] + r
		if d.length_squared() < mm_ * mm_: p = c[0] + (d.normalized() if d.length() > 0.001 else Vector2.RIGHT) * mm_
	for rc0 in w.rects:
		var rc: Rect2 = rc0
		if (rc as Rect2).grow(r).has_point(p):
			var dl := p.x - rc.position.x; var dr := rc.end.x - p.x; var dt := p.y - rc.position.y; var db := rc.end.y - p.y; var mn := minf(minf(dl, dr), minf(dt, db))
			if mn == dl: p.x = rc.position.x - r
			elif mn == dr: p.x = rc.end.x + r
			elif mn == dt: p.y = rc.position.y - r
			else: p.y = rc.end.y + r
	var b := w.bounds
	p.x = clampf(p.x, b.position.x + 0.6, b.end.x - 0.6); p.y = clampf(p.y, b.position.y + 0.6, b.end.y - 0.6)
	return p

## Build the lambs, wolves and HUD for a road laid by Roads.build(). The road is not live until begin().
func populate(c: Dictionary, l: Dictionary) -> void:
	teardown()
	cfg = c; lay = l; t = 0.0; driven = 0; lunges_total = 0; _arrived = false; res = {}
	var rng := RandomNumberGenerator.new(); rng.seed = int(c.seed) * 31 + 7
	var start: Vector3 = l.start
	pp = Vector2(start.x, start.z); pv = Vector2.ZERO; heading = Vector2(0, -1)
	var n_start: int = int(c.start); var n_stray: int = int(c.strays); var total := n_start + n_stray
	_make_mm(total)
	var idx := 0
	for i in n_start:
		var name: String = Game.roster[i] if i < Game.roster.size() else Game.lamb_name(i)
		var a := TAU * i / maxf(n_start, 1.0) + 0.6
		var lm := _new_lamb(idx, name, pp + Vector2(cos(a), sin(a)) * (1.2 + 0.25 * (i % 3)) + Vector2(0, 1.4)); idx += 1
		lm.state = S.FOLLOW; lm.glow = 1.0; lm.was = true; lambs.append(lm)
	var name_base := maxi(n_start, Game.roster.size())
	var placed := 0
	var centers: Array = []
	var zlo: float = (l.goal as Vector3).z + 9.0; var zhi: float = start.z - 7.0
	var ncl := int(ceil(n_stray / 2.5))
	for k in ncl:
		var z := lerpf(zhi, zlo, (k + rng.randf_range(0.1, 0.9)) / ncl)
		var side := -1.0 if k % 2 == 0 else 1.0
		var x: float = Roads.road_x(l, z) + side * rng.randf_range(2.6, 6.2)
		centers.append(_free_spot(Vector2(x, z), 1.2))
	var ci := 0
	while placed < n_stray:
		var cc: Vector2 = centers[ci % centers.size()]; ci += 1
		var np := _free_spot(cc + Vector2(rng.randf_range(-1.1, 1.1), rng.randf_range(-1.1, 1.1)), 0.5)
		var lm := _new_lamb(idx, Game.lamb_name(name_base + placed), np); idx += 1; placed += 1
		lm.wt = np; lambs.append(lm)
	for lm in lambs:
		var d := Dot.new(); d.position = Vector3(lm.p.x, 0, lm.p.y); dots.append(d)
		w.minidots.append({"n": d, "col": Color(0.85, 0.82, 0.78)})
	# wolves
	var nw: int = int(c.wolves)
	for k in nw:
		var z := lerpf(start.z - 22.0, (l.goal as Vector3).z + 14.0, (k + 0.5) / maxf(nw, 1.0)) + rng.randf_range(-3, 3)
		var side := 1.0 if (k + int(c.seed)) % 2 == 0 else -1.0
		_add_wolf(Vector2(Roads.road_x(l, z) + side * rng.randf_range(6.0, 8.0), z))
	for k in 5:
		var pr := CPUParticles3D.new(); pr.one_shot = true; pr.emitting = false; pr.amount = 9; pr.lifetime = 0.5; pr.explosiveness = 1.0
		var qm := QuadMesh.new(); qm.size = Vector2(0.14, 0.14); pr.mesh = qm; pr.material_override = _spark_mat()
		pr.direction = Vector3(0, 1, 0); pr.spread = 70.0; pr.initial_velocity_min = 1.6; pr.initial_velocity_max = 3.0; pr.gravity = Vector3(0, -7, 0)
		pr.scale_amount_min = 0.7; pr.scale_amount_max = 1.4; w.fx_root.add_child(pr); _bursts.append(pr)
	_build_hud()
	w.custom_move = true; w.tap_walk = false
	w.player.position = Vector3(pp.x, 0, pp.y)
	cam_off = Vector3(0, 0.9, -6.0)
	w.cam_k = 4.0
	w.cam_follow(w.player, _csize(), -48.0, cam_off); w.cam_snap()
	_mood_apply(0.0)
	_update_mm()
	_update_hud()

static var _sm: StandardMaterial3D
func _spark_mat() -> StandardMaterial3D:
	if _sm == null:
		_sm = StandardMaterial3D.new(); _sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; _sm.albedo_color = Color(1.0, 0.9, 0.55); _sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return _sm

func _add_wolf(p: Vector2) -> void:
	var wf := Wolf.new(); wf.p = p
	var n := Node3D.new(); n.position = Vector3(p.x, 0, p.y); n.scale = Vector3.ONE * 1.1
	var fur := Color(0.43, 0.41, 0.42); var dark := Color(0.24, 0.23, 0.26)
	P.mk(n, P.sphere(0.34, 8, 5), fur, Vector3(0, 0.52, 0.0), Vector3(0.8, 0.82, 1.55))
	P.mk(n, P.sphere(0.25, 8, 5), fur.darkened(0.08), Vector3(0, 0.6, -0.36), Vector3(0.95, 0.95, 1.0))
	P.mk(n, P.sphere(0.2, 8, 5), fur, Vector3(0, 0.66, -0.66), Vector3(0.85, 0.8, 1.0))
	P.mk(n, P.box(0.12, 0.1, 0.22), dark, Vector3(0, 0.6, -0.9))
	for s in [-1, 1]:
		P.mk(n, P.cyl(0.0, 0.07, 0.2, 4), dark, Vector3(0.1 * s, 0.9, -0.6), Vector3.ONE, Vector3(0.15, 0, 0.2 * s))
		Areas.gmk(n, P.sphere(0.035, 4, 3), Color(1.0, 0.8, 0.25), 1.0, Vector3(0.09 * s, 0.7, -0.82))
		for z in [-0.34, 0.36]: P.mk(n, P.cyl(0.05, 0.04, 0.46, 5), dark, Vector3(0.15 * s, 0.22, z))
	var tail := Node3D.new(); tail.position = Vector3(0, 0.62, 0.62); n.add_child(tail)
	P.mk(tail, P.cyl(0.07, 0.01, 0.55, 5), dark, Vector3(0, -0.12, 0.12), Vector3.ONE, Vector3(-0.9, 0, 0))
	wf.tail = tail
	var rg := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.92; tm.outer_radius = 1.04; tm.rings = 24; tm.ring_segments = 3; rg.mesh = tm
	rg.material_override = Areas.glow(Color(1.0, 0.4, 0.25), 0.7); rg.position = Vector3(0, 0.05, 0); rg.scale = Vector3(1, 0.05, 1); rg.visible = false
	rg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; w.root.add_child(rg); wf.ring = rg
	w.root.add_child(n); wf.node = n; wolves.append(wf)

# ================================================================== HUD
class Hud extends Control:
	var f: Flock
	var pulse := 0.0
	var _sb := StyleBoxFlat.new()
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE; size = Vector2(1080, 1920)
		_sb.bg_color = Color(0.1, 0.06, 0.04, 0.82); _sb.border_color = Color(0.93, 0.74, 0.34, 0.8); _sb.set_border_width_all(3); _sb.set_corner_radius_all(22)
	func _draw() -> void:
		if f == null or f.mode != "road": return
		var gold := Color(0.93, 0.74, 0.34); var ink := Color(1, 0.95, 0.82); var dim := Color(0.62, 0.52, 0.42)
		# the flock count
		draw_style_box(_sb, Rect2(28, 196, 250, 112))
		var fs := int(78.0 * (1.0 + 0.22 * pulse))
		var num := str(f.nf)
		var tw := f.ui.F_T.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f.ui.F_T, Vector2(52, 262 + (78 - fs) * 0.0 - 0.0 * tw.y), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.96, 0.84))
		draw_string(f.ui.F_U, Vector2(52 + maxf(tw.x, 70.0) + 14, 232), "IN YOUR", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, gold)
		draw_string(f.ui.F_U, Vector2(52 + maxf(tw.x, 70.0) + 14, 262), "FLOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, gold)
		# goals
		draw_style_box(_sb, Rect2(28, 322, 560, 188))
		var rows: Array = f.goal_rows()
		for i in rows.size():
			var r: Dictionary = rows[i]; var y := 340.0 + i * 54.0
			var bx := Rect2(50, y + 6, 32, 32)
			if r.ok: draw_rect(bx, gold)
			else: draw_rect(bx, Color(0.1, 0.06, 0.04, 0.0)); draw_rect(bx, dim, false, 3.0)
			if r.ok: draw_polyline(PackedVector2Array([bx.position + Vector2(7, 17), bx.position + Vector2(14, 24), bx.position + Vector2(26, 9)]), Color(0.1, 0.06, 0.04), 4.0)
			draw_string(f.ui.F_S, Vector2(98, y + 36), r.text, HORIZONTAL_ALIGNMENT_LEFT, 360, 30, ink if r.ok else Color(0.9, 0.84, 0.7))
			if r.has("bar"):
				var br := Rect2(430, y + 14, 130, 16)
				draw_rect(br, Color(0.28, 0.2, 0.14)); draw_rect(Rect2(br.position, Vector2(br.size.x * clampf(r.bar, 0.0, 1.0), br.size.y)), gold if r.bar > 0.25 else Color(0.9, 0.45, 0.25))
		# a stalking wolf out of sight: a small red marker at the screen edge
		var vr := Rect2(36, 120, size.x - 72, f.get_viewport().get_visible_rect().size.y - 240)
		for wf in f.wolves:
			if wf.state != W.STALK and wf.state != W.PAUSE: continue
			var sp: Vector2 = f.w.ground_to_screen(Vector3(wf.p.x, 0, wf.p.y))
			if vr.has_point(sp): continue
			var c := sp.clamp(vr.position, vr.end); var d := (sp - c).normalized()
			var pts := PackedVector2Array([c + d * 26.0, c + d.rotated(2.5) * 22.0, c + d.rotated(-2.5) * 22.0])
			draw_colored_polygon(pts, Color(0.95, 0.35, 0.22)); draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0.1, 0.06, 0.04), 3.0)

func _build_hud() -> void:
	hud = Hud.new(); hud.f = self; ui.top.add_child(hud)

func goal_rows() -> Array:
	var need: int = int(cfg.need)
	var astray := 0
	for l in lambs:
		if l.was and l.state != S.FOLLOW: astray += 1
	var left: float = float(cfg.daylight) - t
	return [
		{"text": "Bring %d lambs  %d/%d" % [need, nf, need], "ok": nf >= need},
		{"text": "Lose none" + ("" if astray == 0 else "  \u00B7  %d astray" % astray), "ok": astray == 0},
		{"text": "Reach the fire by dusk", "ok": left > 0.0, "bar": left / float(cfg.daylight)}]

func _update_hud() -> void:
	if hud != null: hud.queue_redraw()

func _pulse() -> void:
	if hud == null: return
	hud.pulse = 1.0; create_tween().tween_property(hud, "pulse", 0.0, 0.35).set_ease(Tween.EASE_OUT)

# ================================================================== run
func begin() -> void:
	mode = "road"; m.cut(false); w.control = true; Touch.reset()
	w.custom_move = true; w.tap_walk = false

func _csize() -> float:
	return 11.6 + 0.075 * nf

func _process(dt: float) -> void:
	if w == null or not is_instance_valid(w) or mm == null: return
	dt = minf(dt, 0.05); t += dt
	if mode == "road":
		staff_cd = maxf(0.0, staff_cd - dt)
		if w.control: _step_player(dt)
		else: _stop_player(dt)
		_step_lambs(dt); _step_wolves(dt); _camera(dt); _daylight(dt)
		if not _arrived and w.control and pp.distance_to(Vector2((lay.goal as Vector3).x, (lay.goal as Vector3).z)) < 5.0: _arrived = true
		_update_hud()
	elif mode == "settle":
		_step_settle(dt)
	_update_mm()

func arrived() -> bool:
	return _arrived

func _stop_player(dt: float) -> void:
	pv = pv.move_toward(Vector2.ZERO, 30.0 * dt)
	w.player.moving = lerpf(w.player.moving, 0.0, 0.3)
	_lean = lerpf(_lean, 0.0, 0.2); w.player.rotation.x = _lean

func _step_player(dt: float) -> void:
	var want := Vector2.ZERO
	if Touch.stick_active:
		var s := Touch.stick; var ln := s.length()
		if ln > 0.1:
			var d := w.cam_right() * s.x + w.cam_fwd() * (-s.y)
			want = Vector2(d.x, d.z).normalized() * clampf((ln - 0.1) / 0.7, 0.0, 1.0)
	var tgt := want * SPEED
	pv = pv.move_toward(tgt, (26.0 if want != Vector2.ZERO else 20.0) * dt)
	var old := pp
	w.player.position = Vector3(pp.x + pv.x * dt, 0, pp.y + pv.y * dt); w._collide(w.player, 0.3)
	pp = Vector2(w.player.position.x, w.player.position.z)
	var real := (pp - old) / maxf(dt, 0.0001)
	if real.length() < pv.length() * 0.6: pv = pv.lerp(real, 0.5)
	var sp := pv.length()
	w.player.moving = clampf(sp / SPEED, 0.0, 1.0)
	if sp > 0.4:
		w.player.face(Vector3(pv.x, 0, pv.y)); heading = heading.lerp(pv / sp, 1.0 - exp(-6.0 * dt)).normalized()
	_lean = lerpf(_lean, -0.16 * clampf(sp / SPEED, 0.0, 1.0), 1.0 - exp(-12.0 * dt))
	w.player.rotation.x = _lean

func _camera(dt: float) -> void:
	var look := Vector3(pv.x, 0, pv.y) * 0.45 + Vector3(0, 0.9, -6.5)
	cam_off = cam_off.lerp(look, 1.0 - exp(-2.4 * dt))
	shake = maxf(0.0, shake - dt * 2.4)
	var sh := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * shake * 0.35
	w.follow_off = cam_off + sh
	w.csize_goal = _csize()

# ---- the sky slowly goes down while you gather (no pressure beyond the goal; the road never ends in a fail)
func _mood_apply(u: float) -> void:
	var a: Array = Roads.pal(cfg.pal).a; var b: Array = Roads.pal(cfg.pal).b
	_mood_mix(a, b, u)

func _mood_mix(a: Array, b: Array, u: float) -> void:
	w.mood((a[0] as Color).lerp(b[0], u), lerpf(a[1], b[1], u), (a[2] as Vector3).lerp(b[2], u), (a[3] as Color).lerp(b[3], u), lerpf(a[4], b[4], u), (a[5] as Color).lerp(b[5], u))

func _daylight(dt: float) -> void:
	_mood_t -= dt
	if _mood_t > 0.0: return
	_mood_t = 0.2
	_mood_apply(clampf(t / float(cfg.daylight), 0.0, 1.0))

# ================================================================== lambs
func _cell(p: Vector2) -> int:
	return int(floorf(p.x / CELL)) * 4096 + int(floorf(p.y / CELL))

func _push(p: Vector2, r: float) -> Vector2:
	for c in w.circles:
		var d: Vector2 = p - c[0]; var mr: float = c[1] + r
		if d.length_squared() < mr * mr: p = c[0] + (d.normalized() if d.length_squared() > 0.000001 else Vector2.RIGHT) * mr
	for rc in w.rects:
		var cl := Vector2(clampf(p.x, rc.position.x, rc.end.x), clampf(p.y, rc.position.y, rc.end.y)); var d := p - cl
		if d.length_squared() < r * r:
			if d.length_squared() > 0.000001: p = cl + d.normalized() * r
			else: p = _free_spot(p, r)
	var b := w.bounds
	p.x = clampf(p.x, b.position.x + 0.5, b.end.x - 0.5); p.y = clampf(p.y, b.position.y + 0.5, b.end.y - 0.5)
	return p

func _recruit(l: Lamb, loud := true) -> void:
	l.state = S.FOLLOW; l.pop = 0.0; l.was = true; l.stuck = 0.0
	nf += 1
	if loud:
		var k := clampf(nf / 40.0, 0.0, 1.0)
		if t - last_pop > 0.05:
			last_pop = t; Audio.sfx("pop", -9.0, randf_range(0.92, 1.08) * (0.9 + 0.35 * k))
		if t - last_bleat > 0.22:
			last_bleat = t; Audio.sfx("bleat", -7.0, (0.82 + 0.55 * k) * randf_range(0.92, 1.08))
			Input.vibrate_handheld(14)
		_burst(l.p)
		if t - last_name > 0.45 and l.id >= int(cfg.start): last_name = t; _name_pop(l)
		_pulse()
		w.csize_goal = _csize()
		w.csize = w.csize - 0.12        # a small zoom punch that settles back

func _burst(p: Vector2) -> void:
	if _bursts.is_empty(): return
	var b: CPUParticles3D = _bursts[_burst_i % _bursts.size()]; _burst_i += 1
	b.position = Vector3(p.x, 0.5, p.y); b.restart(); b.emitting = true

func _name_pop(l: Lamb) -> void:
	var lb := Label3D.new(); lb.text = l.name; lb.font = ui.F_U; lb.font_size = 56; lb.pixel_size = 0.0105; lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true; lb.modulate = Color(1.0, 0.95, 0.78); lb.outline_size = 14; lb.outline_modulate = Color(0.12, 0.07, 0.04, 0.95); lb.render_priority = 5
	lb.position = Vector3(l.p.x, 1.5, l.p.y); w.fx_root.add_child(lb)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lb, "position:y", 2.6, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(lb, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.chain().tween_callback(lb.queue_free)

func _scatter(l: Lamb, from: Vector2, speed := 6.0) -> void:
	if l.state == S.FOLLOW: nf -= 1
	var d := l.p - from
	l.v = (d.normalized() if d.length_squared() > 0.001 else Vector2.RIGHT.rotated(randf() * TAU)) * speed
	l.state = S.SCATTER; l.scat = 1.6; l.glow = 0.0; l.rescued += 1

func _step_lambs(dt: float) -> void:
	_grid.clear(); nf = 0
	var cen := Vector2.ZERO
	for l in lambs:
		if l.state == S.FOLLOW:
			nf += 1; cen += l.p
			var k := _cell(l.p)
			if _grid.has(k): _grid[k].append(l)
			else: _grid[k] = [l]
	if nf > 0: cen /= nf
	var R := 1.4 + 0.05 * nf
	var moving := pv.length() > 0.6
	var pn := heading
	var wolf_pos: Array = []
	for wf in wolves:
		if wf.state != W.GONE and wf.state != W.FLEE: wolf_pos.append(wf.p)
	var recruits: Array = []
	for l in lambs:
		match l.state:
			S.FOLLOW:
				var to := pp - l.p; var dist := to.length()
				var f := Vector2.ZERO
				if dist > R: f += to / dist * clampf((dist - R) / 2.5, 0.0, 1.0) * 1.7
				var rel := l.p - pp
				if moving:
					var ahead := rel.dot(pn)
					if ahead > -0.3 and dist < R + 1.6:
						var side := rel - pn * ahead
						f += -pn * 1.1 + (side.normalized() if side.length_squared() > 0.01 else pn.orthogonal()) * 0.6
				elif dist < 0.9:
					f += (-to / maxf(dist, 0.05)) * 0.9
				# neighbours: separation + a little alignment
				var cx := int(floorf(l.p.x / CELL)); var cy := int(floorf(l.p.y / CELL))
				var av := Vector2.ZERO; var an := 0
				for ox in [-1, 0, 1]:
					for oy in [-1, 0, 1]:
						var lst = _grid.get((cx + ox) * 4096 + cy + oy)
						if lst == null: continue
						for o in lst:
							if o == l: continue
							var dd: Vector2 = l.p - o.p; var dl := dd.length()
							if dl < 0.85 and dl > 0.001: f += dd / dl * (0.85 - dl) * 2.6
							elif dl <= 0.001: f += Vector2.RIGHT.rotated(randf() * TAU) * 0.5
							if dl < 2.2: av += o.v; an += 1
				if an > 0: f += (av / an).limit_length(1.0) * 0.18
				f += (cen - l.p).limit_length(1.0) * 0.12
				for wpos in wolf_pos:
					var wd: Vector2 = l.p - wpos
					if wd.length() < 3.4: f += wd.normalized() * (3.4 - wd.length()) * 0.9
				f += Vector2(cos(t * 0.8 + l.ph), sin(t * 0.7 + l.ph * 1.3)) * 0.12
				var catch := clampf((dist - R) / 5.0, 0.0, 1.0)
				var tgt := f.limit_length(1.0) * (2.6 + 3.6 * catch)
				if not moving and dist < R + 0.6: tgt *= 0.5
				l.v = l.v.lerp(tgt, 1.0 - exp(-5.5 * dt))
				_move_lamb(l, dt)
				l.glow = minf(1.0, l.glow + dt * 3.0)
				# stuck behind a fence: leap over to the player's side
				if dist > R + 3.0 and l.v.length() < 0.5: l.stuck += dt
				else: l.stuck = maxf(0.0, l.stuck - dt)
				if l.stuck > 1.6:
					l.state = S.JUMP; l.j0 = l.p; l.jt = 0.0
					var back := -pn if moving else Vector2(0, 1)
					l.j1 = _free_spot(pp + back * 2.2 + back.orthogonal() * randf_range(-1.5, 1.5), 0.5); l.stuck = 0.0
			S.STRAY:
				l.wcd -= dt
				if l.wcd <= 0.0:
					l.wcd = randf_range(2.0, 5.0); l.wt = _free_spot(l.home + Vector2(randf_range(-1.3, 1.3), randf_range(-1.3, 1.3)), 0.5)
				var dv := l.wt - l.p
				var tgt := Vector2.ZERO
				if dv.length() > 0.25: tgt = dv.normalized() * 0.5
				for wpos in wolf_pos:
					var wd: Vector2 = l.p - wpos
					if wd.length() < 3.4: tgt += wd.normalized() * 2.8
				l.v = l.v.lerp(tgt, 1.0 - exp(-4.0 * dt))
				_move_lamb(l, dt)
				l.glow = maxf(0.0, l.glow - dt * 2.0)
				# face the shepherd when close: it has noticed you
				var dp := pp.distance_to(l.p)
				if dp < 6.0 and l.v.length() < 0.3: l.yaw = lerp_angle(l.yaw, atan2(-(pp.x - l.p.x), -(pp.y - l.p.y)), 1.0 - exp(-4.0 * dt))
				if dp < RECRUIT_R: recruits.append(l)
				else:
					var cx := int(floorf(l.p.x / CELL)); var cy := int(floorf(l.p.y / CELL)); var hit := false
					for ox in [-1, 0, 1]:
						for oy in [-1, 0, 1]:
							var lst = _grid.get((cx + ox) * 4096 + cy + oy)
							if lst == null: continue
							for o in lst:
								if o.p.distance_to(l.p) < 1.0 and o.state == S.FOLLOW: hit = true; break
							if hit: break
						if hit: break
					if hit: recruits.append(l)
			S.SCATTER:
				l.scat -= dt
				l.v = l.v.lerp(Vector2.ZERO, 1.0 - exp(-2.2 * dt))
				_move_lamb(l, dt)
				l.glow = maxf(0.0, l.glow - dt * 2.0)
				if l.scat <= 0.0: l.state = S.STRAY; l.home = l.p; l.wt = l.p; l.wcd = 1.0
			S.JUMP:
				l.jt += dt / 0.55
				var u := clampf(l.jt, 0.0, 1.0)
				l.p = l.j0.lerp(l.j1, u); l.hop = sin(u * PI) * 1.3
				l.yaw = lerp_angle(l.yaw, atan2(-(l.j1.x - l.j0.x), -(l.j1.y - l.j0.y)), 0.2)
				if u >= 1.0: l.state = S.FOLLOW; l.hop = 0.0; l.v = Vector2.ZERO
		# hop from a staff cheer
		if l.hop_d > 0.0:
			l.hop_d -= dt
			if l.hop_d <= 0.0: l.pop = 0.12
		if l.pop >= 0.0:
			l.pop += dt
			if l.pop > 0.9: l.pop = -1.0
	for l in recruits: _recruit(l)
	nf = 0
	for l in lambs: if l.state == S.FOLLOW: nf += 1
	for i in lambs.size():
		var l: Lamb = lambs[i]; var d: Dot = dots[i]
		d.position = Vector3(l.p.x, 0, l.p.y)
		var col := Color(1.0, 0.82, 0.35) if l.state == S.FOLLOW else Color(0.85, 0.82, 0.78)
		if i < w.minidots.size(): w.minidots[i].col = col

func _move_lamb(l: Lamb, dt: float) -> void:
	var sp := l.v.length()
	if sp > 0.02:
		l.p = _push(l.p + l.v * dt, 0.32)
		l.yaw = lerp_angle(l.yaw, atan2(-l.v.x, -l.v.y), 1.0 - exp(-9.0 * dt))
	l.ph += dt * (7.0 + sp * 1.8)

func _update_mm() -> void:
	if mm == null: return
	var stray_c := Color(0.8, 0.78, 0.76); var n := lambs.size()
	for i in n:
		var l: Lamb = lambs[i]
		var sy := 1.0; var sx := 1.0; var y := l.hop
		var sp := l.v.length() if (l.state != S.SETTLE or l.lie < 0.5) else 0.0
		y += absf(sin(l.ph)) * 0.075 * clampf(sp / 3.0, 0.0, 1.3)
		if l.pop >= 0.0:
			var pt := l.pop
			sy = 1.0 + 0.45 * exp(-6.5 * pt) * sin(20.0 * pt + 0.6)
			sx = 1.0 / sqrt(maxf(sy, 0.5))
			y += 0.55 * sin(clampf(pt / 0.34, 0.0, 1.0) * PI)
		if l.lie > 0.0:
			sy *= lerpf(1.0, 0.8, l.lie); y -= 0.04 * l.lie
			sy *= 1.0 + 0.018 * sin(t * 1.6 + l.ph)
		var b := Basis(Vector3.UP, l.yaw).scaled_local(Vector3(sx, sy, sx))
		mm.set_instance_transform(i, Transform3D(b, Vector3(l.p.x, y, l.p.y)))
		var base := stray_c.lerp(Color.WHITE, l.glow if l.state != S.SETTLE else 1.0)
		mm.set_instance_color(i, Color(base.r * tint_col.r * l.bright, base.g * tint_col.g * l.bright, base.b * tint_col.b * l.bright))

# ================================================================== wolves
func _step_wolves(dt: float) -> void:
	for wf in wolves:
		var n: Node3D = wf.node
		if wf.state == W.GONE:
			n.visible = false; wf.ring.visible = false; continue
		var tgt_v := Vector2.ZERO
		var look := Vector2.ZERO
		match wf.state:
			W.LURK:
				var near := pp.distance_to(wf.p) < 10.5
				if not near:
					for l in lambs:
						if l.state != S.SETTLE and l.p.distance_to(wf.p) < 7.0: near = true; break
				if near: wf.state = W.STALK; wf.t = 0.0; Audio.sfx("growl", -8.0, randf_range(0.9, 1.1)); _wolf_hint()
			W.STALK:
				wf.t += dt
				var best = null; var bd := 17.0
				for l in lambs:
					if l.state == S.SETTLE or l.state == S.JUMP: continue
					var d := l.p.distance_to(wf.p) - (0.0 if l.state != S.FOLLOW else 0.3)
					if d < bd: bd = d; best = l
				if best == null: wf.state = W.LURK
				else:
					var dv: Vector2 = best.p - wf.p
					tgt_v = dv.normalized() * (2.5 + 0.6 * wf.lunges + minf(wf.t * 0.05, 0.6)); look = dv
					if dv.length() < 0.95: _lunge(wf)
			W.PAUSE:
				wf.t -= dt
				if wf.t <= 0.0:
					if wf.lunges >= 3: wf.state = W.LEAVE; wf.away = (wf.p - pp).normalized()
					else: wf.state = W.STALK; wf.t = 0.0
			W.FLEE:
				wf.t -= dt; tgt_v = wf.away * 8.5; look = wf.away
				if wf.t <= 0.0: wf.state = W.GONE; driven += 1
			W.LEAVE:
				tgt_v = wf.away * 3.2; look = wf.away
				if wf.p.distance_to(pp) > 18.0: wf.state = W.GONE
		wf.v = wf.v.lerp(tgt_v, 1.0 - exp(-8.0 * dt))
		wf.p += wf.v * dt
		var b := w.bounds; wf.p.x = clampf(wf.p.x, b.position.x - 8.0, b.end.x + 8.0); wf.p.y = clampf(wf.p.y, b.position.y - 8.0, b.end.y + 8.0)
		var sp := wf.v.length()
		n.position = Vector3(wf.p.x, absf(sin(t * 11.0 + wf.p.x)) * 0.05 * minf(sp, 3.0), wf.p.y)
		if look.length() > 0.01: n.rotation.y = lerp_angle(n.rotation.y, atan2(-look.x, -look.y), 1.0 - exp(-8.0 * dt))
		wf.tail.rotation.y = sin(t * (14.0 if wf.state == W.STALK else 4.0)) * 0.5
		var alert := wf.state == W.STALK or wf.state == W.PAUSE
		wf.ring.visible = alert
		if alert:
			wf.ring.position = Vector3(wf.p.x, 0.06, wf.p.y); var s := 1.0 + 0.12 * sin(t * 8.0); wf.ring.scale = Vector3(s, 0.05, s)
		n.scale = Vector3.ONE * 1.1 * (0.78 if wf.state == W.LURK else 1.0)

func _wolf_hint() -> void:
	if _first_wolf and mode == "road":
		_first_wolf = false; ui.toast("A wolf! Tap it with your staff to drive it off.", 4.5)

func _lunge(wf: Wolf) -> void:
	var cands: Array = []
	for l in lambs:
		if l.state == S.SETTLE or l.state == S.JUMP: continue
		var d := l.p.distance_to(wf.p)
		if d < 2.4: cands.append([d, l])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var n := 0
	for c in cands:
		if n >= 5: break
		_scatter(c[1], wf.p, randf_range(5.0, 7.0)); n += 1
	wf.state = W.PAUSE; wf.t = 1.7; wf.lunges += 1; lunges_total += 1
	wf.v = Vector2.ZERO
	Audio.sfx("growl", -4.0, randf_range(0.85, 1.0)); Audio.sfx("yelp", -10.0, randf_range(0.95, 1.2))
	shake = 0.7; Input.vibrate_handheld(30)
	_pulse()

# ================================================================== the staff
func _on_tap(sp: Vector2) -> void:
	if mode != "road" or not w.control or staff_cd > 0.0 or ui.overlay_open(): return
	var g = w.screen_to_ground(sp)
	if g == null: return
	var d := Vector2(g.x, g.z) - pp
	if d.length() > STAFF_RANGE: d = d.normalized() * STAFF_RANGE
	var c := pp + d
	staff_cd = 0.28
	w.player.face(Vector3(d.x, 0, d.y)); w.player.target_yaw = atan2(-d.x, -d.y)
	Audio.sfx("staff", -5.0, randf_range(0.92, 1.08)); Input.vibrate_handheld(10)
	_ring(c, STAFF_R, Color(1.0, 0.88, 0.45))
	var hit := false
	for wf in wolves:
		if wf.state == W.GONE or wf.state == W.FLEE: continue
		if wf.p.distance_to(c) < STAFF_R + 0.5:
			wf.state = W.FLEE; wf.t = 1.5; wf.away = (wf.p - c).normalized() if wf.p.distance_to(c) > 0.05 else (wf.p - pp).normalized()
			Audio.sfx("yelp", -5.0, randf_range(0.9, 1.1)); shake = 0.25; hit = true; _burst(wf.p)
	for l in lambs:
		if l.state == S.STRAY and l.p.distance_to(c) < 2.1: _recruit(l)
		elif l.state == S.FOLLOW:
			l.hop_d = clampf(l.p.distance_to(c) * 0.06, 0.0, 0.3)
	if hit: Audio.sfx("pop", -6.0, 0.7)

func _ring(c: Vector2, r: float, col: Color) -> void:
	for k in 2:
		var mi := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.9; tm.outer_radius = 1.0; tm.rings = 28; tm.ring_segments = 3; mi.mesh = tm
		var mat := Areas.glow(col, 0.85 if k == 0 else 0.5).duplicate() as StandardMaterial3D; mi.material_override = mat; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(c.x, 0.1, c.y); mi.scale = Vector3(0.3, 0.06, 0.3); w.fx_root.add_child(mi)
		var tw := create_tween().set_parallel(true)
		var dur := 0.3 + 0.12 * k
		tw.tween_property(mi, "scale", Vector3(r * (1.0 - 0.3 * k), 0.06, r * (1.0 - 0.3 * k)), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(mat, "albedo_color:a", 0.0, dur + 0.12).set_delay(0.08)
		tw.chain().tween_callback(mi.queue_free)

# ================================================================== arrival
func finish() -> Dictionary:
	mode = "settle"; _arrived = true
	var goal: Vector3 = lay.goal
	var lost: Array = []
	var came: Array = []
	for l in lambs:
		if l.state == S.FOLLOW or l.state == S.JUMP: came.append(l)
		elif l.was: lost.append(l)
	var need: int = int(cfg.need)
	var left: float = float(cfg.daylight) - t
	res = {"followers": came.size(), "need": need, "lost": lost.map(func(l): return l.name), "driven": driven, "lunges": lunges_total, "time": t,
		"goals": [came.size() >= need, lost.is_empty(), left > 0.0]}
	var met := 0
	for g in res.goals: if g: met += 1
	res["met"] = met
	# the best-rescued lamb: the one that was scattered and gathered again most (else the first one met on the road)
	var star = null
	for l in came:
		if l.id >= int(cfg.start) and (star == null or l.rescued > star.rescued): star = l
	if star == null and not came.is_empty(): star = came[0]
	res["star"] = star.name if star != null else ""
	res["star_rescued"] = star.rescued if star != null else 0
	res["total"] = lambs.size()
	_assign_rest(came, Vector2(goal.x, goal.z))
	for l in came: l.state = S.SETTLE
	for wf in wolves:
		if wf.state != W.GONE: wf.state = W.GONE
	for l in lost: l.state = S.STRAY; l.v = Vector2.ZERO
	w.custom_move = true; w.control = false; w.player.moving = 0.0; pv = Vector2.ZERO
	if hud != null: hud.visible = false
	return res

func _assign_rest(list: Array, c: Vector2) -> void:
	var slots: Array = []
	for i in list.size() + 6:
		var r := 2.5 + 0.34 * sqrt(i * 4.0); var a := 2.399 * i + 0.4
		slots.append(c + Vector2(cos(a) * r, sin(a) * r * 0.9))
	list.sort_custom(func(a, b): return a.p.distance_to(c) < b.p.distance_to(c))
	for i in list.size(): list[i].rest = _free_spot(slots[i], 0.4)

func _step_settle(dt: float) -> void:
	for l in lambs:
		if l.state != S.SETTLE and l.state != S.STRAY: continue
		if l.state == S.STRAY:       # a found lamb walking in
			if l.rest == Vector2.ZERO: continue
		var d: Vector2 = l.rest - l.p; var dist := d.length()
		if dist > 0.12:
			var sp := minf(3.2, dist * 1.4 + 0.4)
			l.v = l.v.lerp(d / dist * sp, 1.0 - exp(-6.0 * dt)); l.p += l.v * dt
			l.yaw = lerp_angle(l.yaw, atan2(-l.v.x, -l.v.y), 1.0 - exp(-8.0 * dt)); l.ph += dt * (7.0 + sp * 1.8)
			l.lie = maxf(0.0, l.lie - dt * 2.0)
		else:
			l.v = l.v.lerp(Vector2.ZERO, 0.2)
			if l.state == S.STRAY: l.state = S.SETTLE
			var fc: Vector2 = Vector2((lay.goal as Vector3).x, (lay.goal as Vector3).z) if lay.has("goal") else l.p + Vector2(0, -1)
			l.yaw = lerp_angle(l.yaw, atan2(-(fc.x - l.p.x), -(fc.y - l.p.y)) + sin(l.id * 1.7) * 0.5, 1.0 - exp(-3.0 * dt))
			l.lie = minf(1.0, l.lie + dt * (0.5 + 0.2 * (l.id % 3)))
		l.glow = 1.0
		if l.pop >= 0.0:
			l.pop += dt
			if l.pop > 0.9: l.pop = -1.0

## Lost lambs find the fire: they walk in from the edge of the light.
func bring_lost(names: Array) -> void:
	var goal: Vector3 = lay.goal
	var c := Vector2(goal.x, goal.z)
	var list: Array = []
	for l in lambs:
		if names.has(l.name) and l.state == S.STRAY: list.append(l)
	var k := 0
	for l in list:
		var side := -1.0 if k % 2 == 0 else 1.0
		l.p = Vector2(c.x + side * (9.5 + k * 0.5), c.y + 9.0 + k * 0.7); l.v = Vector2.ZERO; l.glow = 1.0
		k += 1
	var base := 0
	for l in lambs: if l.state == S.SETTLE: base += 1
	for i in list.size():
		var r := 2.5 + 0.34 * sqrt((base + i) * 4.0); var a := 2.399 * (base + i) + 0.4
		list[i].rest = _free_spot(c + Vector2(cos(a) * r, sin(a) * r * 0.9), 0.4)
		list[i].lie = 0.0

func all_settled(names: Array) -> bool:
	for l in lambs:
		if names.has(l.name) and l.state != S.SETTLE: return false
		if names.has(l.name) and l.lie < 0.3: return false
	return true

func arrived_names() -> Array:
	var out: Array = []
	for l in lambs:
		if l.was: out.append(l.name)
	return out

# ================================================================== a flock at rest (the angels chapter, camp)
func settle_at(center: Vector3, names: Array, face_to := Vector3.ZERO) -> void:
	teardown()
	lay = {"goal": center}
	var n := names.size()
	_make_mm(n)
	var c := Vector2(center.x, center.z)
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	for i in n:
		var r := 2.4 + 0.33 * sqrt(i * 4.0); var a := 2.399 * i + 0.4
		var l := _new_lamb(i, names[i], _free_spot(c + Vector2(cos(a) * r, sin(a) * r * 0.9), 0.4))
		l.state = S.SETTLE; l.glow = 1.0; l.lie = 1.0; l.was = true; l.rest = l.p
		var fc := Vector2(face_to.x, face_to.z) if face_to != Vector3.ZERO else c
		l.yaw = atan2(-(fc.x - l.p.x), -(fc.y - l.p.y)) + rng.randf_range(-0.6, 0.6)
		lambs.append(l)
	mode = "settle"; _update_mm()
