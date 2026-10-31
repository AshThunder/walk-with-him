class_name Areas
extends RefCounted
## Builders and props for the Nativity chapters: the shepherds' fields, Bethlehem, the Temple at Jerusalem and the doorpost at home.
## Everything is flat-coloured low-poly (no gradients). Repeated pieces (fences, columns, stars) are MultiMeshes to keep draw calls low.
const P = preload("res://scripts/person.gd")
const PR = preload("res://scripts/props.gd")

const WOOD := Color(0.42, 0.28, 0.16)
const STRAW := Color(0.86, 0.7, 0.34)
const GOLD := Color(1.0, 0.82, 0.35)
const NIGHT := Color(0.05, 0.07, 0.16)
static var _gm := {}

# ------------------------------------------------------------------ small helpers
static func glow(c: Color, a := 1.0) -> StandardMaterial3D:
	var k := "%s_%s" % [c.to_html(), a]
	if _gm.has(k): return _gm[k]
	var m := StandardMaterial3D.new(); m.albedo_color = Color(c.r, c.g, c.b, a); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if a < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_gm[k] = m; return m

static func gmk(parent: Node, mesh: Mesh, c: Color, a := 1.0, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = glow(c, a); mi.position = pos; mi.scale = scl; mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(mi); return mi

static func multi_mesh(parent: Node, mesh: Mesh, xfs: Array, mat: Material, shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = mesh; mm.instance_count = xfs.size()
	for i in xfs.size(): mm.set_instance_transform(i, xfs[i])
	var inst := MultiMeshInstance3D.new(); inst.multimesh = mm; inst.material_override = mat
	if not shadows: inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst); return inst

## A fence run between two points (collides like a wall). Pieces are one MultiMesh.
static func fence(w: World, a: Vector3, b: Vector3, collide := true) -> void:
	var d := b - a; d.y = 0; var len := d.length()
	if len < 0.2: return
	var dir := d / len; var n := maxi(1, int(round(len / 1.7))); var step := len / n
	var yaw := atan2(-dir.z, dir.x); var xs: Array = []
	for i in n:
		var c := a + dir * (step * (i + 0.5))
		xs.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(step / 1.7 * 2.0, 2.0, 2.0)), c))
	PR.multi(w.root, "res://assets/nature/fence_simple.glb", xs, Color(0.95, 0.85, 0.7))
	if collide:
		var mid := (a + b) * 0.5
		if absf(dir.x) > absf(dir.z): w.add_rect(mid, absf(b.x - a.x), 0.3, 0.2)
		else: w.add_rect(mid, 0.3, absf(b.z - a.z), 0.2)

static func campfire(w: World, pos: Vector3, lit := true) -> void:
	var n := Node3D.new(); n.position = pos; w.root.add_child(n)
	for i in 7:
		var a := TAU * i / 7.0
		P.mk(n, P.sphere(0.2, 5, 3), Color(0.38, 0.36, 0.38), Vector3(cos(a) * 0.72, 0.1, sin(a) * 0.72), Vector3(1.2, 0.8, 1.0))
	for i in 3:
		P.mk(n, P.cyl(0.07, 0.07, 1.1, 5), WOOD, Vector3(0, 0.22, 0), Vector3.ONE, Vector3(PI * 0.5 - 0.25, TAU * i / 3.0, 0))
	if lit:
		var fl := Anim.make(n, "flicker"); fl.position.y = 0.1
		gmk(fl, P.cyl(0.0, 0.34, 1.0, 6), Color(1.0, 0.45, 0.12), 1.0, Vector3(0, 0.5, 0))
		gmk(fl, P.cyl(0.0, 0.2, 0.8, 6), Color(1.0, 0.82, 0.3), 1.0, Vector3(0.0, 0.42, 0))
		var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.7, 0.4); l.light_energy = 2.0; l.omni_range = 10.0; l.position = Vector3(0, 1.4, 0); l.shadow_enabled = false
		fl.add_child(l); fl.light = l; fl.light_base = 2.0
	w.add_circle(pos, 0.9)

static func lamb() -> Node3D:
	var n := PR.sheep(); n.scale = Vector3(0.62, 0.62, 0.62); return n

static func lantern(w: World, pos: Vector3, h := 2.4, yaw := 0.0) -> void:
	w.place(PR.lantern_post(h), pos, yaw)

static func dove() -> Node3D:
	var n := Node3D.new(); var wh := Color(0.97, 0.96, 0.93)
	P.mk(n, P.sphere(0.2, 8, 5), wh, Vector3(0, 0.28, 0), Vector3(0.8, 0.8, 1.3))
	P.mk(n, P.sphere(0.1, 7, 4), wh, Vector3(0, 0.42, -0.24))
	P.mk(n, P.box(0.04, 0.04, 0.09), Color(0.9, 0.6, 0.2), Vector3(0, 0.42, -0.36))
	P.mk(n, P.box(0.14, 0.03, 0.3), Color(0.88, 0.87, 0.84), Vector3(0, 0.3, 0.32), Vector3.ONE, Vector3(-0.3, 0, 0))
	for s in [-1, 1]:
		P.mk(n, P.sphere(0.02, 4, 2), Color(0.1, 0.08, 0.08), Vector3(0.06 * s, 0.45, -0.3))
		var wp := Node3D.new(); wp.position = Vector3(0.15 * s, 0.36, 0); n.add_child(wp)
		P.mk(wp, P.box(0.36, 0.03, 0.26), Color(0.92, 0.91, 0.88), Vector3(0.18 * s, 0, 0))
		n.set_meta("wl" if s < 0 else "wr", wp)
	n.scale = Vector3(1.6, 1.6, 1.6); return n

static func cage() -> Node3D:
	var n := Node3D.new(); var c := Color(0.62, 0.45, 0.24)
	for i in 10:
		var a := TAU * i / 10.0
		P.mk(n, P.cyl(0.03, 0.03, 1.0, 4), c, Vector3(cos(a) * 0.8, 0.5, sin(a) * 0.8))
	for y in [0.05, 1.0]:
		var r := MeshInstance3D.new(); var t := TorusMesh.new(); t.inner_radius = 0.78; t.outer_radius = 0.84; t.rings = 20; t.ring_segments = 4; r.mesh = t
		r.material_override = P.mat(c); r.position.y = y; n.add_child(r)
	gmk(n, P.cyl(0.8, 0.8, 0.02, 20), GOLD, 0.22, Vector3(0, 0.02, 0))
	return n

static func manger(parent: Node, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := Node3D.new(); n.position = pos; n.rotation.y = yaw; parent.add_child(n)
	P.mk(n, P.box(1.5, 0.12, 0.8), WOOD, Vector3(0, 0.62, 0))
	P.mk(n, P.box(1.5, 0.5, 0.1), WOOD.lightened(0.08), Vector3(0, 0.45, 0.38), Vector3.ONE, Vector3(-0.2, 0, 0))
	P.mk(n, P.box(1.5, 0.5, 0.1), WOOD.lightened(0.08), Vector3(0, 0.45, -0.38), Vector3.ONE, Vector3(0.2, 0, 0))
	P.mk(n, P.box(0.1, 0.5, 0.8), WOOD, Vector3(0.74, 0.45, 0))
	P.mk(n, P.box(0.1, 0.5, 0.8), WOOD, Vector3(-0.74, 0.45, 0))
	for x in [-0.6, 0.6]:
		P.mk(n, P.box(0.1, 0.45, 0.1), WOOD.darkened(0.15), Vector3(x, 0.22, 0.3), Vector3.ONE, Vector3(0, 0, x * 0.2))
		P.mk(n, P.box(0.1, 0.45, 0.1), WOOD.darkened(0.15), Vector3(x, 0.22, -0.3), Vector3.ONE, Vector3(0, 0, x * 0.2))
	P.mk(n, P.box(1.3, 0.2, 0.6), STRAW, Vector3(0, 0.72, 0))
	return n

static func infant(parent: Node, pos: Vector3) -> Node3D:
	var n := Node3D.new(); n.position = pos; parent.add_child(n)
	var cl := Color(0.95, 0.93, 0.86)
	P.mk(n, P.sphere(0.2, 8, 5), cl, Vector3(0, 0.0, 0.12), Vector3(1.0, 0.7, 2.2))
	P.mk(n, P.sphere(0.13, 8, 5), Color(0.74, 0.54, 0.4), Vector3(0, 0.04, -0.3))
	P.mk(n, P.box(0.42, 0.03, 0.06), Color(0.8, 0.72, 0.5), Vector3(0, 0.1, 0.0))
	P.mk(n, P.box(0.38, 0.03, 0.06), Color(0.8, 0.72, 0.5), Vector3(0, 0.1, 0.3))
	return n

static func cloths(parent: Node, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := Node3D.new(); n.position = pos; n.rotation.y = yaw; parent.add_child(n)
	for i in 3:
		P.mk(n, P.box(0.6, 0.07, 0.42), Color(0.96, 0.94, 0.88), Vector3(0, 0.04 + i * 0.075, 0), Vector3.ONE, Vector3(0, i * 0.15, 0))
	P.mk(n, P.box(0.62, 0.012, 0.07), Color(0.8, 0.7, 0.45), Vector3(0, 0.27, 0), Vector3.ONE, Vector3(0, 0.3, 0))
	return n

## Open-front stable facing +z. kind: "hay" (manger, no cloth), "cloth" (cloth, no manger), "both".
static func stable(w: World, pos: Vector3, kind: String, sw := 5.0, sd := 4.0) -> void:
	var n := Node3D.new(); n.position = pos; w.root.add_child(n)
	var wall := Color(0.9, 0.84, 0.72)
	PR.tbox(n, Vector3(sw, 3.0, 0.3), Vector3(0, 1.5, -sd * 0.5), "plaster", wall, 0.35)
	PR.tbox(n, Vector3(0.3, 3.0, sd), Vector3(-sw * 0.5, 1.5, 0), "plaster", wall, 0.35)
	PR.tbox(n, Vector3(0.3, 3.0, sd), Vector3(sw * 0.5, 1.5, 0), "plaster", wall, 0.35)
	PR.tbox(n, Vector3(sw + 0.8, 0.2, sd + 0.8), Vector3(0, 3.1, 0.1), "wood", Color(0.8, 0.7, 0.6), 0.5)
	P.mk(n, P.box(sw + 0.6, 0.16, sd + 0.6), Color(0.78, 0.62, 0.3), Vector3(0, 3.28, 0.1))
	P.mk(n, P.box(sw - 0.4, 0.05, sd - 0.4), Color(0.7, 0.58, 0.32), Vector3(0, 0.03, 0))
	for x in [-1, 1]:
		P.mk(n, P.cyl(0.1, 0.12, 3.0, 6), WOOD, Vector3(x * (sw * 0.5 - 0.1), 1.5, sd * 0.5))
	if kind == "hay" or kind == "both":
		manger(n, Vector3(0, 0, -sd * 0.5 + 0.9))
	if kind == "hay":
		P.mk(n, P.sphere(0.5, 7, 4), STRAW, Vector3(-1.5, 0.25, -0.6), Vector3(1.3, 0.7, 1.0))
		P.mk(n, P.sphere(0.4, 7, 4), STRAW, Vector3(1.5, 0.2, 0.4), Vector3(1.3, 0.7, 1.0))
	if kind == "cloth":
		P.mk(n, P.cyl(0.35, 0.4, 0.5, 6), WOOD, Vector3(-0.2, 0.25, -0.9))
		cloths(n, Vector3(-0.2, 0.5, -0.9))
		P.mk(n, P.sphere(0.5, 7, 4), STRAW, Vector3(1.6, 0.2, -0.3), Vector3(1.4, 0.6, 1.0))
		w.place(PR.jar(), Vector3(pos.x + 1.4, 0, pos.z - 1.3))
	if kind == "both":
		P.mk(n, P.box(0.5, 0.4, 0.5), WOOD, Vector3(-1.4, 0.2, -0.4))
		cloths(n, Vector3(-1.4, 0.4, -0.4))
		var lp := PR.lantern_post(1.4); lp.position = Vector3(1.8, 0, -1.2); n.add_child(lp)
		var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.78, 0.45); l.light_energy = 1.4; l.omni_range = 7.0; l.position = Vector3(1.0, 1.6, -0.3); n.add_child(l)
	w.add_rect(pos + Vector3(0, 0, -sd * 0.5), sw, 0.5, 0.1)
	w.add_rect(pos + Vector3(-sw * 0.5, 0, 0), 0.5, sd, 0.1)
	w.add_rect(pos + Vector3(sw * 0.5, 0, 0), 0.5, sd, 0.1)

## A line of columns (shaft + base + capital as three MultiMeshes) with an entablature slab over them.
static func colonnade(w: World, xs: Array, z: float, h := 5.0, r := 0.5, slab := true) -> void:
	var sh: Array = []; var bs: Array = []; var cp: Array = []
	for x in xs:
		sh.append(Transform3D(Basis.IDENTITY, Vector3(x, h * 0.5, z)))
		bs.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.2, z)))
		cp.append(Transform3D(Basis.IDENTITY, Vector3(x, h + 0.15, z)))
		w.add_circle(Vector3(x, 0, z), r + 0.05)
	var mat := PR.tmat("plaster", Color(0.95, 0.9, 0.8), 0.3, true)
	multi_mesh(w.root, P.cyl(r, r * 1.08, h, 12), sh, mat)
	multi_mesh(w.root, P.box(r * 2.8, 0.4, r * 2.8), bs, mat)
	multi_mesh(w.root, P.box(r * 2.9, 0.3, r * 2.9), cp, mat)
	if slab:
		var x0: float = xs[0]; var x1: float = xs[xs.size() - 1]
		PR.tbox(w.root, Vector3(x1 - x0 + 2.0, 0.5, 1.6), Vector3((x0 + x1) * 0.5, h + 0.55, z), "plaster", Color(0.92, 0.86, 0.74), 0.3)

## Four-point star that always faces the camera. Flat gold, no gradient.
static func star(size := 1.0, c := GOLD) -> Node3D:
	var n := Node3D.new()
	for k in 2:
		var sz := size * (1.0 if k == 0 else 1.9)
		var pts: Array = []
		for i in 8:
			var rr := sz if i % 2 == 0 else sz * 0.34
			var a := TAU * i / 8.0 + (0.0 if k == 0 else PI / 4.0)
			pts.append(Vector3(sin(a) * rr, cos(a) * rr, 0))
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 8:
			st.add_vertex(Vector3.ZERO); st.add_vertex(pts[(i + 1) % 8]); st.add_vertex(pts[i])
		var mi := MeshInstance3D.new(); mi.mesh = st.commit()
		var m := glow(c if k == 0 else Color(1.0, 0.95, 0.7), 1.0 if k == 0 else 0.3).duplicate() as StandardMaterial3D
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mi.position.z = 0.0 if k == 1 else 0.02
		n.add_child(mi)
	var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.92, 0.6); l.light_energy = 1.2; l.omni_range = 9.0; l.position = Vector3(0, -1.5, 0); n.add_child(l)
	return n

## A tall translucent column of light with a halo and drifting sparks (the angels of the sky-look chapter).
static func light_column(h := 40.0, r := 1.0, c := Color(1.0, 0.94, 0.7), k := 1.0) -> Node3D:
	var n := Node3D.new()
	gmk(n, P.cyl(r * 0.55, r, h, 14), c, 0.2 * k, Vector3(0, h * 0.5, 0))
	gmk(n, P.cyl(r * 0.25, r * 0.45, h, 10), Color(1, 1, 0.92), minf(0.28 * k, 0.95), Vector3(0, h * 0.5, 0))
	var halo := MeshInstance3D.new(); var t := TorusMesh.new(); t.inner_radius = r * 0.9; t.outer_radius = r * 1.1; t.rings = 24; t.ring_segments = 4; halo.mesh = t
	halo.material_override = glow(Color(1, 0.96, 0.75), 0.9); halo.position.y = h * 0.62; halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; n.add_child(halo)
	var p := CPUParticles3D.new(); p.amount = 30; p.lifetime = 5.0; p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = r * 0.8
	p.direction = Vector3.UP; p.spread = 8.0; p.initial_velocity_min = 0.6; p.initial_velocity_max = 1.6; p.gravity = Vector3.ZERO
	var sm := SphereMesh.new(); sm.radius = 0.09; sm.height = 0.18; sm.radial_segments = 4; sm.rings = 2; p.mesh = sm; p.material_override = glow(Color(1, 0.95, 0.7)); p.position.y = h * 0.4
	n.add_child(p)
	return n

# ------------------------------------------------------------------ the fields by night
static func night(w: World) -> void:
	w.mood(Color(0.55, 0.66, 1.0), 0.7, Vector3(-55, -30, 0), Color(0.3, 0.36, 0.6), 0.95, NIGHT)

static func fields(w: World) -> void:
	w.clear_area(); w.area = "fields"; w.bounds = Rect2(-14, -12, 28, 24)
	night(w)
	w.ground("dry_grass", Color(0.55, 0.65, 0.78), 220.0, 7.0)
	w.hill(Vector3(-28, -1, -22), 18, 6, Color(0.14, 0.18, 0.28)); w.hill(Vector3(26, -1, -24), 20, 7, Color(0.12, 0.16, 0.26)); w.hill(Vector3(-30, -0.5, 14), 15, 4, Color(0.13, 0.17, 0.27)); w.hill(Vector3(28, -1, 16), 15, 4, Color(0.13, 0.17, 0.27))
	w.add_tree("olive", Vector3(-11, 0, -8.5), 1.2); w.add_tree("olive", Vector3(11.5, 0, 9), 1.1); w.add_tree("olive", Vector3(-12, 0, 8), 1.1); w.add_tree("cypress", Vector3(12.5, 0, -1), 1.2)
	w.ring_scenery(w.bounds, 18, ["olive"])
	w.rocks([Vector3(-12.5, 0, 0), Vector3(13, 0, 5), Vector3(0.5, 0, -10.5), Vector3(-6.5, 0, -10.8)], Color(0.6, 0.66, 0.8))
	w.scatter("res://assets/nature/grass_large.glb", w.rand_pts(60, w.bounds), Color(0.5, 0.62, 0.55), 0.8, 1.4)
	w.scatter("res://assets/nature/plant_bushSmall.glb", w.rand_pts(14, w.bounds), Color(0.45, 0.58, 0.5), 0.8, 1.3)
	campfire(w, Vector3(-5, 0, 3))
	# the fold: a fenced pen with a gap on its south side
	fence(w, Vector3(4.6, 0, -8.6), Vector3(9.6, 0, -8.6)); fence(w, Vector3(4.6, 0, -8.6), Vector3(4.6, 0, -4.6)); fence(w, Vector3(9.6, 0, -8.6), Vector3(9.6, 0, -4.6))
	fence(w, Vector3(4.6, 0, -4.6), Vector3(6.2, 0, -4.6)); fence(w, Vector3(7.8, 0, -4.6), Vector3(9.6, 0, -4.6))
	PR.tbox(w.root, Vector3(4.8, 0.04, 3.8), Vector3(7.1, 0.02, -6.6), "dry_grass", Color(0.78, 0.7, 0.5), 0.5)
	var si := 0
	for p in [Vector3(-6.7, 0, 1.4), Vector3(-3.3, 0, 1.4), Vector3(-5.0, 0, 5.0)]:
		si += 1
		w.person({"robe": Color(0.5, 0.4, 0.3), "sash": Color(0.35, 0.2, 0.12), "cloth": Color(0.78, 0.72, 0.6), "beard": p.x > -4, "hair": Color(0.3, 0.25, 0.2), "scale": 0.98, "staff": true, "label": false}, p, rad2yaw(Vector3(-5, 0, 3) - p), "sh%d" % (si - 1))
	w.player = w._make_player(Vector3(-1.4, 0, 5.8), 200)
	w.cam_follow(w.player, 14.0); w.cam_snap()

static func rad2yaw(d: Vector3) -> float:
	return rad_to_deg(atan2(-d.x, -d.z))

# ------------------------------------------------------------------ Bethlehem town by night
static func town(w: World, lit_house := false) -> void:
	w.clear_area(); w.area = "town"; w.bounds = Rect2(-14, -12, 28, 24)
	night(w)
	w.ground("sand", Color(0.55, 0.62, 0.78), 220.0, 6.0)
	w.hill(Vector3(-28, -1, -22), 18, 6, Color(0.14, 0.18, 0.28)); w.hill(Vector3(26, -1, -24), 20, 7, Color(0.12, 0.16, 0.26)); w.hill(Vector3(-30, -0.5, 14), 15, 4, Color(0.13, 0.17, 0.27))
	PR.ribbon(w.root, [Vector3(0, 0, 13), Vector3(0, 0, 6), Vector3(-1, 0, 1), Vector3(-1, 0, -5)], 3.0, "path", Color(0.62, 0.66, 0.8))
	PR.ribbon(w.root, [Vector3(-15, 0, 6), Vector3(-6, 0, 5), Vector3(0, 0, 5)], 2.4, "path", Color(0.62, 0.66, 0.8))
	PR.ribbon(w.root, [Vector3(-1, 0, -1), Vector3(5, 0, -1), Vector3(10, 0, 2)], 2.2, "path", Color(0.62, 0.66, 0.8))
	# three stables along the north wall (their contents are the clues)
	stable(w, Vector3(-8.5, 0, -8.0), "hay"); stable(w, Vector3(-0.8, 0, -8.5), "cloth"); stable(w, Vector3(7.2, 0, -8.0), "both")
	# homes
	w.add_house(Vector3(-11.6, 0, 1.0), 4.0, 4.4, 2.6, 90, Color(0.62, 0.66, 0.8))
	var hh := w.add_house(Vector3(10.6, 0, 3.4), 4.6, 4.2, 2.9, 0, Color(0.7, 0.72, 0.84))
	w.add_house(Vector3(-8.0, 0, 8.6), 4.2, 3.6, 2.4, 0, Color(0.62, 0.66, 0.8))
	w.add_house(Vector3(8.0, 0, 11.0), 4.0, 3.2, 2.4, 0, Color(0.62, 0.66, 0.8))
	if lit_house:
		gmk(hh, P.box(0.9, 1.5, 0.05), Color(1.0, 0.8, 0.42), 1.0, Vector3(0, 0.95, 4.2 * 0.5 + 0.08))
		gmk(hh, P.box(0.5, 0.5, 0.05), Color(1.0, 0.8, 0.42), 1.0, Vector3(1.2, 1.7, 4.2 * 0.5 + 0.05))
		var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.78, 0.45); l.light_energy = 2.4; l.omni_range = 9.0; l.position = Vector3(0, 1.8, 3.2); hh.add_child(l)
	var well := PR.well(); w.place(well, Vector3(-1.0, 0, 3.0)); w.add_circle(Vector3(-1.0, 0, 3.0), 1.25)
	w.place(PR.glb("res://assets/town/cart.glb", Color(0.7, 0.7, 0.85), 1.8), Vector3(4.5, 0, 6.8), 40); w.add_circle(Vector3(4.5, 0, 6.8), 1.0)
	for p in [Vector3(-3.3, 0, 8.2), Vector3(3.2, 0, 8.2), Vector3(-3.0, 0, -4.2), Vector3(3.2, 0, -4.4), Vector3(-5.6, 0, -4.4), Vector3(8.6, 0, 6.6)]:
		lantern(w, p, 2.4, 0.0); w.add_circle(p, 0.2)
	w.place(PR.jar(Color(0.55, 0.4, 0.34)), Vector3(-5.2, 0, 3.2)); w.place(PR.jar(), Vector3(2.4, 0, 3.8))
	w.add_tree("olive", Vector3(-12.5, 0, -7), 1.2); w.add_tree("olive", Vector3(12.5, 0, -9), 1.2); w.add_tree("cypress", Vector3(-12.6, 0, 9), 1.3)
	w.ring_scenery(w.bounds, 14, ["olive", "cypress"])
	w.scatter("res://assets/nature/grass_large.glb", w.rand_pts(36, w.bounds, true, 0.0), Color(0.5, 0.62, 0.55), 0.8, 1.3)
	w.player = w._make_player(Vector3(0, 0, 10.0), 180)
	w.cam_follow(w.player, 14.0); w.cam_snap()

# ------------------------------------------------------------------ the Temple court at Jerusalem
static func temple(w: World) -> void:
	w.clear_area(); w.area = "temple"; w.bounds = Rect2(-14, -12, 28, 24)
	w.mood(Color(1.0, 0.92, 0.78), 1.1, Vector3(-52, -35, 0), Color(0.78, 0.74, 0.72), 0.85, Color(0.8, 0.74, 0.6))
	w.ground("flagstone", Color(0.98, 0.93, 0.84), 220.0, 3.0)
	w.hill(Vector3(-28, -1, 10), 14, 4, Color(0.7, 0.66, 0.5)); w.hill(Vector3(30, -1, 8), 14, 4, Color(0.68, 0.64, 0.48))
	# back wall, colonnade, the steps to the Sanctuary
	PR.tbox(w.root, Vector3(28.0, 6.2, 0.6), Vector3(0, 3.1, -11.5), "plaster", Color(0.95, 0.9, 0.8), 0.3); w.add_rect(Vector3(0, 0, -11.4), 28, 0.8, 0.1)
	colonnade(w, [-11.0, -7.0, -3.0, 1.0, 5.0, 9.0, 13.0], -9.2)
	for i in 3: PR.tbox(w.root, Vector3(10.0 - i * 1.2, 0.2 * (3 - i), 2.2 - i * 0.5), Vector3(0, 0.1 * (3 - i), -8.0 + i * 0.4), "flagstone", Color(0.95, 0.9, 0.82), 0.5)
	# side walls with columns
	PR.tbox(w.root, Vector3(0.6, 2.2, 22.0), Vector3(-13.6, 1.1, 0.0), "plaster", Color(0.94, 0.88, 0.78), 0.3); w.add_rect(Vector3(-13.6, 0, 0), 0.8, 22.0, 0.1)
	PR.tbox(w.root, Vector3(0.6, 2.2, 22.0), Vector3(13.6, 1.1, 0.0), "plaster", Color(0.94, 0.88, 0.78), 0.3); w.add_rect(Vector3(13.6, 0, 0), 0.8, 22.0, 0.1)
	# the dove seller's stall (east)
	var stall := PR.table(2.6, 1.0, false); w.place(stall, Vector3(8.8, 0, -1.8), 0); w.add_rect(Vector3(8.8, 0, -1.8), 2.8, 1.2, 0.1)
	w.place(PR.canopy(3.2, 1.8, 2.6), Vector3(8.8, 0, -2.2))
	for i in 3:
		var c := P.mk(w.root, P.box(0.5, 0.4, 0.4), Color(0.62, 0.45, 0.24), Vector3(8.0 + i * 0.8, 1.15, -1.8)); c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.place(PR.jar(Color(0.6, 0.38, 0.28)), Vector3(10.6, 0, -1.0)); w.place(PR.jar(), Vector3(6.8, 0, -3.0))
	for p in [Vector3(-9.5, 0, -6.4), Vector3(9.8, 0, -6.4), Vector3(-9.5, 0, 6.4), Vector3(9.8, 0, 6.8)]:
		lantern(w, p, 2.4, 0.0); w.add_circle(p, 0.2)
	# a low bronze basin
	P.mk(w.root, P.cyl(0.9, 0.7, 0.7, 12), Color(0.7, 0.5, 0.24), Vector3(-9, 0.35, 1.0)); w.add_circle(Vector3(-9, 0, 1.0), 1.0)
	w.player = w._make_player(Vector3(0, 0, 9.0), 180)
	w.cam_follow(w.player, 14.0); w.cam_snap()

# ------------------------------------------------------------------ home: the doorpost with the growth marks
const POST_X := 1.2
const POST_Z := -2.65
const MARK_Y := [1.0, 1.55, 1.95]

static func home(w: World) -> void:
	w.clear_area(); w.area = "home"; w.bounds = Rect2(-5, -3.6, 10, 8)
	w.mood(Color(1.0, 0.88, 0.7), 0.9, Vector3(-45, -30, 0), Color(0.82, 0.72, 0.62), 1.0, Color(0.25, 0.2, 0.15))
	w.ground("flagstone", Color(0.9, 0.82, 0.7), 60.0, 2.5)
	PR.tbox(w.root, Vector3(14.0, 4.0, 0.4), Vector3(0, 2.0, -3.1), "plaster", Color(1.0, 0.94, 0.82), 0.35)
	PR.tbox(w.root, Vector3(0.4, 4.0, 10.0), Vector3(-6.0, 2.0, 0.5), "plaster", Color(0.96, 0.9, 0.78), 0.35)
	w.add_rect(Vector3(0, 0, -3.1), 14, 0.5, 0.1); w.add_rect(Vector3(-6.0, 0, 0), 0.5, 10, 0.1)
	# the doorway with its post (the marks are carved into the left post)
	P.mk(w.root, P.box(1.5, 2.3, 0.1), Color(0.18, 0.12, 0.08), Vector3(POST_X + 1.05, 1.15, -2.88))
	P.mk(w.root, P.box(0.26, 2.5, 0.3), WOOD, Vector3(POST_X + 0.12, 1.25, -2.8))
	P.mk(w.root, P.box(0.26, 2.5, 0.3), WOOD, Vector3(POST_X + 1.95, 1.25, -2.8))
	P.mk(w.root, P.box(2.4, 0.26, 0.3), WOOD, Vector3(POST_X + 1.05, 2.55, -2.8))
	var marks: Array = []
	for y in MARK_Y:
		marks.append(P.mk(w.root, P.box(0.3, 0.05, 0.05), Color(0.2, 0.12, 0.07), Vector3(POST_X + 0.12, y, -2.62)))
	w.set_meta("marks", marks)
	# furniture
	var tb := PR.table(2.0, 1.0, true); w.place(tb, Vector3(-3.0, 0, -1.8)); w.add_rect(Vector3(-3.0, 0, -1.8), 2.2, 1.2, 0.1)
	w.place(PR.jar(), Vector3(-5.0, 0, -2.4)); w.place(PR.jar(Color(0.6, 0.38, 0.26), 1.2), Vector3(-5.2, 0, -1.4)); w.place(PR.lantern_post(2.0), Vector3(-1.4, 0, -2.5))
	P.mk(w.root, P.box(1.6, 0.12, 0.8), Color(0.78, 0.62, 0.4), Vector3(-4.2, 0.06, 1.8))
	var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.8, 0.5); l.light_energy = 1.6; l.omni_range = 9.0; l.position = Vector3(0, 2.4, -1.0); w.root.add_child(l)
	w.person({"robe": Color(0.5, 0.3, 0.3), "sash": Color(0.8, 0.65, 0.3), "cloth": Color(0.85, 0.8, 0.7), "skin": Color(0.7, 0.5, 0.36), "scale": 0.95, "hair_style": "none", "name": "Mary"}, Vector3(-3.0, 0, -0.4), 200, "mary")
	w.player = w._make_player(Vector3(POST_X - 0.5, 0, -1.8), 0)
	w.cam_look(Vector3(0.6, 1.0, -1.2), 7.5, -22.0); w.cam_snap()
