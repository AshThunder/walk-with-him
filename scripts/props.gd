class_name Props
extends RefCounted
## Procedural props + CC0 model loader (Kenney Nature/Survival/Fantasy Town kits, recolored). All geometry is flat-shaded low-poly.
const P = preload("res://scripts/person.gd")
static var _glb_cache := {}
static var _tex_cache := {}

static func tex(n: String) -> Texture2D:
	if not _tex_cache.has(n): _tex_cache[n] = load("res://art/%s.png" % n)
	return _tex_cache[n]

static func tmat(n: String, tint := Color.WHITE, scale := 0.25, triplanar := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_texture = tex(n); m.albedo_color = tint; m.roughness = 1.0
	m.uv1_triplanar = triplanar; m.uv1_scale = Vector3(scale, scale, scale); m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m

static func tbox(parent: Node, size: Vector3, pos: Vector3, texn: String, tint := Color.WHITE, scl := 0.3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = size; mi.mesh = b
	mi.material_override = tmat(texn, tint, scl); mi.position = pos; mi.rotation = rot; parent.add_child(mi); return mi

static func glb(path: String, tint := Color.WHITE, scale := 1.0) -> Node3D:
	if not _glb_cache.has(path): _glb_cache[path] = load(path)
	var ps: PackedScene = _glb_cache[path]
	var n: Node3D = ps.instantiate(); n.scale = Vector3(scale, scale, scale)
	_fix(n, tint); return n

static func _fix(n: Node, tint: Color) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		for s in mi.mesh.get_surface_count():
			var m = mi.mesh.surface_get_material(s)
			if m is StandardMaterial3D:
				var c: StandardMaterial3D = m.duplicate(); c.metallic = 0.0; c.roughness = 1.0
				c.albedo_color = c.albedo_color * tint; mi.set_surface_override_material(s, c)
	for c in n.get_children(): _fix(c, tint)

static func first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D: return n
	for c in n.get_children():
		var r = first_mesh(c)
		if r != null: return r
	return null

## Many copies of one model with one draw call.
static func multi(parent: Node, path: String, xfs: Array, tint := Color.WHITE) -> void:
	var src := glb(path, tint); var mi := first_mesh(src)
	if mi == null: return
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = mi.mesh; mm.instance_count = xfs.size()
	for i in xfs.size(): mm.set_instance_transform(i, xfs[i])
	var inst := MultiMeshInstance3D.new(); inst.multimesh = mm; parent.add_child(inst)
	var cnt: int = mi.mesh.get_surface_count()
	# materials: set on the mesh copy
	var mesh2: Mesh = mi.mesh.duplicate()
	for s in cnt:
		var m = mi.get_surface_override_material(s)
		if m != null: mesh2.surface_set_material(s, m)
	mm.mesh = mesh2
	src.free()

static func xf(pos: Vector3, yaw := 0.0, s := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), pos)

# ---------- buildings ----------
static func house(w: float, d: float, h: float, tint := Color.WHITE, stairs := false, door := true) -> Node3D:
	var n := Node3D.new()
	tbox(n, Vector3(w, h, d), Vector3(0, h * 0.5, 0), "plaster", tint, 0.35)
	tbox(n, Vector3(w + 0.1, 0.32, d + 0.1), Vector3(0, 0.16, 0), "flagstone", Color(0.85, 0.8, 0.72), 0.5)
	# roof slab + parapet
	tbox(n, Vector3(w + 0.24, 0.16, d + 0.24), Vector3(0, h + 0.08, 0), "plaster", Color(0.92, 0.86, 0.76), 0.35)
	var pc := Color(0.95, 0.9, 0.8)
	tbox(n, Vector3(w + 0.24, 0.22, 0.16), Vector3(0, h + 0.27, d * 0.5 + 0.06), "plaster", pc, 0.35)
	tbox(n, Vector3(w + 0.24, 0.22, 0.16), Vector3(0, h + 0.27, -d * 0.5 - 0.06), "plaster", pc, 0.35)
	tbox(n, Vector3(0.16, 0.22, d + 0.24), Vector3(w * 0.5 + 0.06, h + 0.27, 0), "plaster", pc, 0.35)
	tbox(n, Vector3(0.16, 0.22, d + 0.24), Vector3(-w * 0.5 - 0.06, h + 0.27, 0), "plaster", pc, 0.35)
	# beam ends under roof edge (front)
	var nb := int(w / 1.1)
	for i in nb:
		var x := -w * 0.5 + (i + 0.5) * w / nb
		var b := P.mk(n, P.cyl(0.07, 0.07, 0.5, 6), Color(0.42, 0.28, 0.16), Vector3(x, h - 0.12, d * 0.5 + 0.18), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	if door:
		var dw := 1.0
		P.mk(n, P.box(dw + 0.3, 0.22, 0.2), Color(0.62, 0.55, 0.47), Vector3(0, 1.78, d * 0.5 + 0.02))              # lintel
		P.mk(n, P.box(dw, 1.7, 0.14), Color(0.34, 0.21, 0.12), Vector3(0, 0.95, d * 0.5 + 0.0))                       # door
		P.mk(n, P.box(0.12, 1.75, 0.2), Color(0.62, 0.55, 0.47), Vector3(-dw * 0.5 - 0.1, 0.92, d * 0.5 + 0.02))
		P.mk(n, P.box(0.12, 1.75, 0.2), Color(0.62, 0.55, 0.47), Vector3(dw * 0.5 + 0.1, 0.92, d * 0.5 + 0.02))
		P.mk(n, P.box(0.08, 1.6, 0.04), Color(0.2, 0.12, 0.07), Vector3(0, 0.95, d * 0.5 + 0.08))
	# windows (small dark openings with stone frames) on the front and the +x side
	for i in range(int(w / 2.6)):
		var x := -w * 0.5 + (i + 0.5) * (w / int(w / 2.6)) + (w * 0.25 if door and int(w / 2.6) == 1 else 0.0)
		if absf(x) < 0.9 and door: continue
		P.mk(n, P.box(0.62, 0.62, 0.16), Color(0.6, 0.53, 0.45), Vector3(x, h * 0.62, d * 0.5 + 0.02))
		P.mk(n, P.box(0.44, 0.44, 0.2), Color(0.12, 0.09, 0.07), Vector3(x, h * 0.62, d * 0.5 + 0.03))
	for i in range(int(d / 2.8)):
		var z := -d * 0.5 + (i + 0.5) * (d / int(d / 2.8))
		P.mk(n, P.box(0.16, 0.62, 0.62), Color(0.6, 0.53, 0.45), Vector3(w * 0.5 + 0.02, h * 0.62, z))
		P.mk(n, P.box(0.2, 0.44, 0.44), Color(0.12, 0.09, 0.07), Vector3(w * 0.5 + 0.03, h * 0.62, z))
	if stairs:
		var steps := 7
		for i in steps:
			var sh := 0.32 + (h - 0.2) * (i + 1) / steps
			P.mk(n, P.box(0.85, sh, 0.5), Color(0.8, 0.74, 0.64), Vector3(w * 0.5 + 0.55, sh * 0.5, d * 0.5 - 0.5 - i * 0.5))
	# roof details: jar + drying cloth
	P.mk(n, P.cyl(0.2, 0.28, 0.5, 8), Color(0.66, 0.4, 0.26), Vector3(-w * 0.3, h + 0.5, -d * 0.2), Vector3.ONE, Vector3.ZERO, "jar")
	P.mk(n, P.box(0.8, 0.04, 0.5), Color(0.75, 0.3, 0.25), Vector3(w * 0.15, h + 0.2, d * 0.1))
	return n

## Open-front carpenter's workshop (lean-to) with bench, planks, logs.
static func workshop(w: float, d: float) -> Node3D:
	var n := Node3D.new()
	var h := 2.7
	tbox(n, Vector3(w, h, 0.3), Vector3(0, h * 0.5, -d * 0.5), "plaster", Color(1, 0.96, 0.9), 0.35)           # back wall
	tbox(n, Vector3(0.3, h, d), Vector3(-w * 0.5, h * 0.5, 0), "plaster", Color(1, 0.96, 0.9), 0.35)          # left wall
	tbox(n, Vector3(w, 0.1, d), Vector3(0, 0.04, 0), "flagstone", Color(0.9, 0.82, 0.7), 0.4)                   # floor
	for x in [w * 0.5 - 0.1, 0.0]:
		P.mk(n, P.cyl(0.11, 0.13, h, 7), Color(0.42, 0.28, 0.16), Vector3(x, h * 0.5, d * 0.5 - 0.1))
	tbox(n, Vector3(w + 0.5, 0.14, d + 0.5), Vector3(0, h + 0.1, 0.1), "wood", Color(0.9, 0.8, 0.7), 0.4, Vector3(-0.07, 0, 0))   # plank roof
	for i in 8:
		P.mk(n, P.cyl(0.05, 0.05, d + 0.6, 5), Color(0.34, 0.22, 0.12), Vector3(-w * 0.5 + 0.3 + i * (w - 0.4) / 7.0, h + 0.2, 0.1), Vector3.ONE, Vector3(PI * 0.5 - 0.07, 0, 0))
	var bench := glb("res://assets/survival/workbench.glb", Color.WHITE, 1.7); bench.position = Vector3(-w * 0.5 + 1.6, 0, -d * 0.5 + 1.0); n.add_child(bench)
	var grind := glb("res://assets/survival/workbench-grind.glb", Color.WHITE, 1.5); grind.position = Vector3(w * 0.5 - 1.5, 0, -d * 0.5 + 0.9); grind.rotation.y = 0.3; n.add_child(grind)
	var pl := glb("res://assets/survival/resource-planks.glb", Color.WHITE, 1.6); pl.position = Vector3(-w * 0.5 + 0.9, 0, 0.6); pl.rotation.y = 0.4; n.add_child(pl)
	var lg := glb("res://assets/survival/resource-wood.glb", Color.WHITE, 1.6); lg.position = Vector3(0.6, 0, -d * 0.5 + 0.7); n.add_child(lg)
	var ax := glb("res://assets/survival/tool-hammer.glb", Color.WHITE, 1.8); ax.position = Vector3(-w * 0.5 + 1.3, 1.05, -d * 0.5 + 1.0); ax.rotation = Vector3(0, 0.8, 1.2); n.add_child(ax)
	return n

static func well() -> Node3D:
	var n := Node3D.new()
	P.mk(n, P.cyl(0.95, 1.05, 0.75, 12), Color(0.78, 0.7, 0.58), Vector3(0, 0.37, 0), Vector3.ONE, Vector3.ZERO, "wellring")
	P.mk(n, P.cyl(0.8, 0.8, 0.05, 12), Color(0.12, 0.2, 0.28), Vector3(0, 0.7, 0))
	for s in [-1, 1]: P.mk(n, P.cyl(0.07, 0.08, 1.9, 6), Color(0.4, 0.27, 0.15), Vector3(0.0, 1.35, 0.85 * s))
	P.mk(n, P.cyl(0.06, 0.06, 1.9, 6), Color(0.35, 0.23, 0.13), Vector3(0, 2.2, 0), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	P.mk(n, P.cyl(0.04, 0.04, 0.9, 5), Color(0.7, 0.6, 0.4), Vector3(0, 1.75, 0.2))
	var bk := glb("res://assets/survival/bucket.glb", Color.WHITE, 1.2); bk.position = Vector3(0, 1.1, 0.2); n.add_child(bk)
	return n

static func olive(scale := 1.0, seed_v := 0) -> Node3D:
	var n := Node3D.new(); var r := RandomNumberGenerator.new(); r.seed = seed_v + 11
	var bark := Color(0.44, 0.36, 0.28)
	P.mk(n, P.cyl(0.18, 0.3, 1.3, 7), bark, Vector3(0, 0.6, 0), Vector3.ONE, Vector3(0, 0, 0.1))
	P.mk(n, P.cyl(0.1, 0.17, 1.0, 6), bark, Vector3(0.18, 1.4, 0), Vector3.ONE, Vector3(0, 0, -0.35))
	P.mk(n, P.cyl(0.09, 0.14, 0.9, 6), bark, Vector3(-0.2, 1.35, 0.1), Vector3.ONE, Vector3(0.2, 0, 0.5))
	var cols := [Color(0.5, 0.58, 0.38), Color(0.6, 0.66, 0.46), Color(0.42, 0.52, 0.34)]
	for i in 6:
		var a := i * TAU / 6.0 + r.randf() * 0.5; var rad := 0.7 + r.randf() * 0.4
		P.mk(n, P.sphere(1.0, 9, 5), cols[i % 3], Vector3(cos(a) * rad, 2.1 + r.randf() * 0.5, sin(a) * rad), Vector3(1.0, 0.65, 1.0) * (0.75 + r.randf() * 0.35), Vector3.ZERO, "olivebl%d" % (i % 2))
	P.mk(n, P.sphere(1.1, 9, 5), cols[1], Vector3(0, 2.7, 0), Vector3(1.0, 0.7, 1.0), Vector3.ZERO, "olivetop")
	n.scale = Vector3.ONE * scale; return n

static func cypress(scale := 1.0) -> Node3D:
	var n := Node3D.new()
	P.mk(n, P.cyl(0.1, 0.16, 0.5, 6), Color(0.4, 0.3, 0.2), Vector3(0, 0.25, 0))
	P.mk(n, P.sphere(0.7, 7, 6), Color(0.2, 0.36, 0.22), Vector3(0, 1.9, 0), Vector3(0.9, 2.5, 0.9), Vector3.ZERO, "cypress")
	n.scale = Vector3.ONE * scale; return n

static func sheep() -> Node3D:
	var n := Node3D.new(); var wool := Color(0.93, 0.9, 0.82); var dark := Color(0.25, 0.2, 0.18)
	P.mk(n, P.sphere(0.4, 8, 5), wool, Vector3(0, 0.55, 0), Vector3(0.9, 0.85, 1.25), Vector3.ZERO, "sheepbody")
	P.mk(n, P.sphere(0.2, 7, 4), wool, Vector3(0, 0.78, 0.0), Vector3(1.0, 0.7, 1.0))
	P.mk(n, P.sphere(0.15, 8, 5), dark, Vector3(0, 0.66, -0.52), Vector3(0.9, 1.0, 1.2), Vector3.ZERO, "sheephead")
	for s in [-1, 1]:
		P.mk(n, P.sphere(0.06, 5, 3), dark, Vector3(0.14 * s, 0.7, -0.5), Vector3(1.6, 0.6, 0.8))
		for z in [-0.28, 0.3]: P.mk(n, P.cyl(0.04, 0.04, 0.32, 5), dark, Vector3(0.17 * s, 0.16, z))
	return n

static func waterpot() -> Dictionary:
	var n := Node3D.new(); var stone := Color(0.7, 0.64, 0.55)
	P.mk(n, P.cyl(0.42, 0.28, 0.55, 12), stone, Vector3(0, 0.28, 0), Vector3.ONE, Vector3.ZERO, "potlow")
	P.mk(n, P.cyl(0.34, 0.46, 0.34, 12), stone.lightened(0.04), Vector3(0, 0.72, 0), Vector3.ONE, Vector3.ZERO, "potup")
	var rim := P.mk(n, P.cyl(0.4, 0.37, 0.1, 12), stone.darkened(0.12), Vector3(0, 0.93, 0), Vector3.ONE, Vector3.ZERO, "potrim")
	P.mk(n, P.cyl(0.33, 0.33, 0.6, 12), Color(0.2, 0.17, 0.14), Vector3(0, 0.7, 0))      # dark inside
	var liq := MeshInstance3D.new(); var lm := CylinderMesh.new(); lm.top_radius = 0.33; lm.bottom_radius = 0.33; lm.height = 0.04; lm.radial_segments = 12; liq.mesh = lm
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.35, 0.62, 0.85); m.emission_enabled = true; m.emission = Color(0.2, 0.4, 0.6); m.emission_energy_multiplier = 0.25; m.roughness = 0.2
	liq.material_override = m; liq.position = Vector3(0, 0.4, 0); n.add_child(liq)
	return {"node": n, "liquid": liq, "mat": m}

static func table(w: float, d: float, food := true, cloth := Color(0.93, 0.9, 0.82)) -> Node3D:
	var n := Node3D.new()
	P.mk(n, P.box(w, 0.1, d), Color(0.45, 0.3, 0.18), Vector3(0, 0.85, 0))
	P.mk(n, P.box(w + 0.08, 0.04, d + 0.08), cloth, Vector3(0, 0.91, 0))
	P.mk(n, P.box(w + 0.1, 0.45, 0.04), cloth, Vector3(0, 0.7, d * 0.5 + 0.04))
	for x in [-w * 0.5 + 0.15, w * 0.5 - 0.15]:
		for z in [-d * 0.5 + 0.12, d * 0.5 - 0.12]: P.mk(n, P.box(0.1, 0.85, 0.1), Color(0.35, 0.23, 0.13), Vector3(x, 0.42, z))
	if food:
		var r := RandomNumberGenerator.new(); r.seed = int(w * 10)
		for i in int(w / 0.8):
			var x := -w * 0.5 + 0.5 + i * 0.8 + r.randf() * 0.1; var k := r.randi() % 3
			if k == 0:
				P.mk(n, P.cyl(0.2, 0.12, 0.1, 8), Color(0.55, 0.35, 0.2), Vector3(x, 0.99, 0))
				for j in 4: P.mk(n, P.sphere(0.07, 6, 4), [Color(0.8, 0.2, 0.2), Color(0.9, 0.55, 0.15), Color(0.45, 0.2, 0.45), Color(0.8, 0.2, 0.2)][j], Vector3(x + (j % 2 - 0.5) * 0.1, 1.08, (j / 2 - 0.5) * 0.1))
			elif k == 1:
				P.mk(n, P.sphere(0.14, 7, 4), Color(0.8, 0.6, 0.32), Vector3(x, 0.98, 0.06), Vector3(1.4, 0.6, 1.0)); P.mk(n, P.sphere(0.12, 7, 4), Color(0.74, 0.54, 0.28), Vector3(x + 0.2, 0.97, -0.08), Vector3(1.3, 0.6, 1.0))
			else:
				P.mk(n, P.cyl(0.07, 0.05, 0.18, 7), Color(0.6, 0.45, 0.3), Vector3(x, 1.03, 0.05)); P.mk(n, P.cyl(0.05, 0.05, 0.1, 7), Color(0.6, 0.45, 0.3), Vector3(x + 0.25, 1.0, -0.05))
	return n

static func canopy(w: float, d: float, h: float) -> Node3D:
	var n := Node3D.new()
	for x in [-w * 0.5, w * 0.5]:
		for z in [-d * 0.5, d * 0.5]: P.mk(n, P.cyl(0.07, 0.09, h, 6), Color(0.5, 0.34, 0.18), Vector3(x, h * 0.5, z))
	P.mk(n, P.box(w + 0.7, 0.05, d + 0.7), Color(0.94, 0.9, 0.82), Vector3(0, h + 0.05, 0), Vector3.ONE, Vector3(0, 0, 0))
	P.mk(n, P.box(w + 0.7, 0.07, 0.12), Color(0.82, 0.62, 0.22), Vector3(0, h + 0.04, (d + 0.7) * 0.5))
	P.mk(n, P.box(0.12, 0.07, d + 0.7), Color(0.82, 0.62, 0.22), Vector3((w + 0.7) * 0.5, h + 0.04, 0))
	for i in 6: P.mk(n, P.box(0.5, 0.7 + (i % 2) * 0.15, 0.03), [Color(0.7, 0.2, 0.25), Color(0.2, 0.35, 0.6), Color(0.88, 0.7, 0.25)][i % 3], Vector3(-w * 0.5 - 0.1 + i * (w + 0.2) / 5.0, h - 0.4, d * 0.5 + 0.34))
	P.mk(n, P.box(w, 0.04, d), Color(0.75, 0.25, 0.28), Vector3(0, 0.06, 0))     # rug
	return n

static func lantern_post(h := 2.4) -> Node3D:
	var n := Node3D.new()
	P.mk(n, P.cyl(0.05, 0.07, h, 6), Color(0.35, 0.23, 0.13), Vector3(0, h * 0.5, 0))
	P.mk(n, P.box(0.5, 0.05, 0.05), Color(0.35, 0.23, 0.13), Vector3(0.22, h - 0.05, 0))
	P.mk(n, P.cyl(0.12, 0.1, 0.26, 6), Color(1.0, 0.72, 0.3), Vector3(0.44, h - 0.25, 0)).material_override = P.mat(Color(1.0, 0.72, 0.3), 0.5, 1.6)
	return n

static func jar(c := Color(0.66, 0.4, 0.26), s := 1.0) -> Node3D:
	var n := Node3D.new()
	P.mk(n, P.cyl(0.26, 0.3, 0.3, 8), c, Vector3(0, 0.17, 0), Vector3.ONE, Vector3.ZERO, "jarb"); P.mk(n, P.cyl(0.14, 0.28, 0.25, 8), c.lightened(0.05), Vector3(0, 0.44, 0), Vector3.ONE, Vector3.ZERO, "jart")
	P.mk(n, P.cyl(0.17, 0.14, 0.07, 8), c.darkened(0.2), Vector3(0, 0.6, 0)); n.scale = Vector3.ONE * s; return n

static func marker(c := Color(1.0, 0.82, 0.35)) -> Node3D:
	var n := Node3D.new(); n.set_meta("marker", true)
	var d := MeshInstance3D.new(); d.mesh = P.sphere(0.2, 4, 2); d.material_override = P.mat(c, 0.4, 1.8); d.scale = Vector3(0.8, 1.4, 0.8); d.position.y = 0.0; n.add_child(d); d.set_meta("spin", true)
	var ring := MeshInstance3D.new(); var t := TorusMesh.new(); t.inner_radius = 0.55; t.outer_radius = 0.7; t.rings = 18; t.ring_segments = 6; ring.mesh = t
	ring.material_override = P.mat(c, 0.4, 1.2); ring.position.y = -1.3; ring.scale = Vector3(1, 0.1, 1); n.add_child(ring)
	return n

static func scroll_item() -> Node3D:
	var n := Node3D.new()
	var roll := P.mk(n, P.cyl(0.09, 0.09, 0.5, 8), Color(0.93, 0.85, 0.65), Vector3.ZERO, Vector3.ONE, Vector3(0, 0, PI * 0.5))
	P.mk(n, P.cyl(0.11, 0.11, 0.05, 8), Color(0.55, 0.32, 0.16), Vector3(-0.26, 0, 0), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	P.mk(n, P.cyl(0.11, 0.11, 0.05, 8), Color(0.55, 0.32, 0.16), Vector3(0.26, 0, 0), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	P.mk(n, P.cyl(0.095, 0.095, 0.06, 8), Color(0.8, 0.2, 0.2), Vector3(0, 0, 0), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	return n

static func ribbon(parent: Node, pts: Array, width: float, texn := "path", tint := Color.WHITE, y := 0.03) -> MeshInstance3D:
	var curve := Curve3D.new()
	for p in pts: curve.add_point(p)
	# Catmull-Rom smoothing via baked sampling
	var sm: Array = []
	for i in range(pts.size() - 1):
		var p0: Vector3 = pts[maxi(i - 1, 0)]; var p1: Vector3 = pts[i]; var p2: Vector3 = pts[i + 1]; var p3: Vector3 = pts[mini(i + 2, pts.size() - 1)]
		for k in 8:
			var t := k / 8.0; var t2 := t * t; var t3 := t2 * t
			sm.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	sm.append(pts[pts.size() - 1])
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var acc := 0.0
	for i in range(sm.size() - 1):
		var a: Vector3 = sm[i]; var b: Vector3 = sm[i + 1]
		var dir := (b - a); dir.y = 0; var l := dir.length(); if l < 0.001: continue
		dir /= l; var nrm := Vector3(-dir.z, 0, dir.x) * width * 0.5
		var wa := width * (0.9 + 0.2 * sin(i * 0.7)); var na := Vector3(-dir.z, 0, dir.x) * wa * 0.5
		var uv0 := Vector2(0, acc * 0.5); var uv1 := Vector2(0, (acc + l) * 0.5)
		var q := [a - na, a + na, b + na, b - na]; var uvs := [Vector2(0, uv0.y), Vector2(1, uv0.y), Vector2(1, uv1.y), Vector2(0, uv1.y)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP); st.set_uv(uvs[idx]); st.add_vertex(q[idx] + Vector3(0, y, 0))
		acc += l
	var mi := MeshInstance3D.new(); mi.mesh = st.commit()
	var m := tmat(texn, tint, 1.0, false); m.uv1_scale = Vector3(1, 1, 1); m.uv1_triplanar = false; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(mi)
	return mi

static func bunting(parent: Node, a: Vector3, b: Vector3, n := 8) -> void:
	var cols := [Color(0.75, 0.22, 0.25), Color(0.9, 0.72, 0.25), Color(0.2, 0.4, 0.62), Color(0.93, 0.9, 0.82)]
	var line := P.mk(parent, P.cyl(0.012, 0.012, a.distance_to(b), 4), Color(0.3, 0.2, 0.12), (a + b) * 0.5)
	line.basis = Basis.looking_at(b - a, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	for i in n:
		var t := (i + 0.5) / n; var sag := sin(t * PI) * 0.35; var p := a.lerp(b, t) - Vector3(0, sag, 0)
		var f := P.mk(parent, P.box(0.28, 0.32, 0.02), cols[i % 4], p - Vector3(0, 0.16, 0)); f.rotation.y = atan2(-(b - a).z, (b - a).x)
