class_name Person
extends Node3D
## Procedural low-poly people (flat-shaded), face toward -Z. Code-driven animation: walk, idle, talk (jaw), gesture, cheer, carry.
## Characters are original geometry, not downloaded models, so faces, robes and head-coverings can follow the story.
var moving := 0.0                 # 0..1, set by the owner every frame
var talking := false
var pose := "idle"                # idle | cheer | carry | pray | amaze
var target_yaw := 0.0
var display_name := ""
var _ph := 0.0
var _t := randf() * 10.0
var _body: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _mouth: MeshInstance3D
var _gest := 0.0
var _gest_cd := randf_range(1.0, 3.0)
var _blink := 0.0
var _eyes: Array = []
var hand_r: Node3D
var _mats := {}
static var _flat_cache := {}
static var _mat_cache := {}

static func mat(c: Color, rough := 1.0, emit := 0.0) -> StandardMaterial3D:
	var k := "%s%s%s" % [c.to_html(), rough, emit]
	if not _mat_cache.has(k):
		var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = rough
		if emit > 0.0: m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = emit
		_mat_cache[k] = m
	return _mat_cache[k]

static func flat(m: Mesh, key: String) -> Mesh:
	if not _flat_cache.has(key):
		var st := SurfaceTool.new(); st.create_from(m, 0); st.deindex(); st.generate_normals()
		_flat_cache[key] = st.commit()
	return _flat_cache[key]

static func mk(parent: Node, mesh: Mesh, c: Color, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO, key := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = flat(mesh, key) if key != "" else mesh
	mi.material_override = mat(c); mi.position = pos; mi.scale = scl; mi.rotation = rot
	parent.add_child(mi); return mi

static func sphere(r: float, seg := 10, rings := 6) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = seg; s.rings = rings; return s
static func cyl(rt: float, rb: float, h: float, seg := 10) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = rt; c.bottom_radius = rb; c.height = h; c.radial_segments = seg; c.rings = 1; return c
static func box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new(); b.size = Vector3(x, y, z); return b

## opts: robe, sash, skin, hair, scale, head_scale, hair_style(short|long|none|braid), beard, cloth (head covering color), mantle, female, brow
static func make(o: Dictionary) -> Person:
	var p := Person.new()
	var sc: float = o.get("scale", 1.0)
	p.scale = Vector3(sc, sc, sc)
	p.display_name = o.get("name", "")
	var robe: Color = o.get("robe", Color(0.9, 0.85, 0.75)); var sash: Color = o.get("sash", Color(0.45, 0.3, 0.15))
	var skin: Color = o.get("skin", Color(0.76, 0.56, 0.4)); var hair: Color = o.get("hair", Color(0.18, 0.11, 0.07))
	var skin_d := skin.darkened(0.18)
	p._body = Node3D.new(); p.add_child(p._body)
	# feet (sandals) + legs hidden by robe
	p._leg_l = Node3D.new(); p._leg_l.position = Vector3(-0.1, 0.16, 0); p._body.add_child(p._leg_l)
	p._leg_r = Node3D.new(); p._leg_r.position = Vector3(0.1, 0.16, 0); p._body.add_child(p._leg_r)
	for l in [p._leg_l, p._leg_r]:
		mk(l, sphere(0.085, 8, 4), Color(0.32, 0.2, 0.12), Vector3(0, -0.1, -0.03), Vector3(1, 0.55, 1.5), Vector3.ZERO, "foot")
	# robe: skirt + chest
	mk(p._body, cyl(0.2, 0.34, 0.78, 10), robe, Vector3(0, 0.55, 0), Vector3.ONE, Vector3.ZERO, "skirt")
	mk(p._body, cyl(0.19, 0.22, 0.46, 10), robe, Vector3(0, 1.0, 0), Vector3.ONE, Vector3.ZERO, "chest")
	mk(p._body, cyl(0.225, 0.225, 0.07, 10), sash, Vector3(0, 0.82, 0), Vector3.ONE, Vector3.ZERO, "sash")
	if o.get("mantle", null) != null:
		var mc: Color = o.mantle
		mk(p._body, box(0.56, 0.1, 0.36), mc, Vector3(0, 1.2, 0.01), Vector3.ONE, Vector3(0, 0, 0))
		mk(p._body, box(0.2, 0.62, 0.1), mc, Vector3(-0.18, 0.93, -0.17), Vector3.ONE, Vector3(0.05, 0, 0.04))
		mk(p._body, box(0.34, 0.6, 0.06), mc, Vector3(0.0, 0.88, 0.2), Vector3.ONE, Vector3(-0.04, 0, 0))
	# arms
	for side in [-1, 1]:
		var a := Node3D.new(); a.position = Vector3(0.24 * side, 1.17, 0); p._body.add_child(a)
		var cap := CapsuleMesh.new(); cap.radius = 0.065; cap.height = 0.5; cap.radial_segments = 8; cap.rings = 2
		mk(a, cap, robe, Vector3(0, -0.22, 0), Vector3.ONE, Vector3.ZERO, "arm")
		var h := Node3D.new(); h.position = Vector3(0, -0.5, 0); a.add_child(h)
		mk(h, sphere(0.06, 8, 4), skin, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "hand")
		if side < 0: p._arm_l = a
		else: p._arm_r = a; p.hand_r = h
	# head
	p._head = Node3D.new(); p._head.position = Vector3(0, 1.37, 0); p._body.add_child(p._head)
	var hs: float = o.get("head_scale", 1.0); p._head.scale = Vector3(hs, hs, hs)
	mk(p._body, cyl(0.07, 0.09, 0.12, 8), skin, Vector3(0, 1.28, 0), Vector3.ONE, Vector3.ZERO, "neck")
	var hd := MeshInstance3D.new(); hd.mesh = sphere(0.19, 16, 10); hd.material_override = mat(skin, 0.8); hd.scale = Vector3(0.95, 1.05, 1.0); p._head.add_child(hd)
	# face
	for s in [-1, 1]:
		var ey := Node3D.new(); ey.position = Vector3(0.072 * s, 0.025, -0.165); p._head.add_child(ey)
		var w := MeshInstance3D.new(); w.mesh = sphere(0.034, 10, 6); w.material_override = mat(Color(0.97, 0.95, 0.92), 0.4); w.scale = Vector3(1.0, 0.85, 0.5); ey.add_child(w)
		var ir := MeshInstance3D.new(); ir.mesh = sphere(0.021, 8, 5); ir.material_override = mat(o.get("eyes", Color(0.2, 0.12, 0.06)), 0.3); ir.position = Vector3(0, 0, -0.012); ir.scale = Vector3(1, 1, 0.6); ey.add_child(ir)
		p._eyes.append(ey)
		var brow := mk(p._head, box(0.07, 0.016, 0.02), hair.darkened(0.1), Vector3(0.072 * s, 0.078, -0.176), Vector3.ONE, Vector3(0, 0, -0.12 * s))
	var nose := MeshInstance3D.new(); nose.mesh = sphere(0.03, 8, 5); nose.material_override = mat(skin_d, 0.8); nose.position = Vector3(0, -0.015, -0.19); nose.scale = Vector3(0.8, 1.1, 1.0); p._head.add_child(nose)
	p._mouth = mk(p._head, box(0.07, 0.014, 0.012), Color(0.45, 0.16, 0.14), Vector3(0, -0.085, -0.178))
	for s in [-1, 1]:
		mk(p._head, sphere(0.022, 6, 4), skin.lightened(0.05), Vector3(0.16 * s, -0.04, 0.0), Vector3(0.5, 1, 1))   # ears
	# hair / covering
	var style: String = o.get("hair_style", "short")
	if style != "none":
		mk(p._head, sphere(0.2, 12, 6), hair, Vector3(0, 0.055, 0.035), Vector3(1.0, 0.82, 1.0), Vector3.ZERO, "haircap")
	if style == "long":
		mk(p._head, box(0.36, 0.46, 0.1), hair, Vector3(0, -0.12, 0.15), Vector3.ONE, Vector3(0.08, 0, 0))
		for s in [-1, 1]:
			mk(p._head, box(0.06, 0.34, 0.1), hair, Vector3(0.175 * s, -0.04, 0.04), Vector3.ONE, Vector3(0, 0, 0.05 * s))
	if style == "braid":
		mk(p._head, box(0.08, 0.4, 0.08), hair, Vector3(0.0, -0.2, 0.19), Vector3.ONE, Vector3(0.15, 0, 0))
		mk(p._head, sphere(0.05, 6, 4), sash, Vector3(0.0, -0.4, 0.22))
	if o.get("beard", false):
		mk(p._head, sphere(0.12, 10, 6), hair, Vector3(0, -0.125, -0.085), Vector3(1.0, 1.0, 0.7), Vector3.ZERO, "beard")
		mk(p._head, box(0.09, 0.02, 0.02), hair, Vector3(0, -0.06, -0.178))   # moustache
	if o.get("cloth", null) != null:
		var cc: Color = o.cloth
		mk(p._head, sphere(0.215, 12, 6), cc, Vector3(0, 0.07, 0.03), Vector3(1.0, 0.8, 1.05), Vector3.ZERO, "headcloth")
		mk(p._head, box(0.4, 0.5, 0.1), cc, Vector3(0, -0.15, 0.15), Vector3.ONE, Vector3(0.08, 0, 0))
		for s in [-1, 1]: mk(p._head, box(0.06, 0.3, 0.14), cc, Vector3(0.19 * s, -0.04, 0.02), Vector3.ONE, Vector3(0, 0, 0.05 * s))
		mk(p._head, box(0.38, 0.03, 0.05), sash, Vector3(0, 0.1, -0.15), Vector3.ONE, Vector3(-0.2, 0, 0))
	if o.get("staff", false):
		var st := mk(p.hand_r, cyl(0.025, 0.03, 1.5, 6), Color(0.45, 0.3, 0.16), Vector3(0, 0.2, 0), Vector3.ONE, Vector3(0, 0, 0))
		mk(st, sphere(0.05, 6, 4), Color(0.45, 0.3, 0.16), Vector3(0, 0.75, 0))
	if o.get("label", true) and p.display_name != "":
		var l := Label3D.new(); l.text = p.display_name; l.font_size = 64; l.pixel_size = 0.0045; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true
		l.position = Vector3(0, 1.95 / maxf(sc, 0.1), 0); l.modulate = Color(1, 0.92, 0.7); l.outline_size = 14; l.outline_modulate = Color(0.1, 0.06, 0.03, 0.9); l.fixed_size = false
		p.add_child(l); l.set_meta("nm", true)
	return p

func face(d: Vector3) -> void:
	d.y = 0
	if d.length() < 0.001: return
	target_yaw = atan2(-d.x, -d.z)

func face_point(pt: Vector3) -> void:
	face(pt - global_position)

func head_pos() -> Vector3:
	return global_position + Vector3(0, 1.4 * scale.y, 0)

func _process(dt: float) -> void:
	_t += dt
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-12.0 * dt))
	var spd := moving
	_ph += dt * (7.0 + 3.0 * spd) * (1.0 if spd > 0.05 else 0.0)
	var sw := sin(_ph) * 0.7 * spd
	_leg_l.rotation.x = sw; _leg_r.rotation.x = -sw
	var bob := absf(sin(_ph)) * 0.045 * spd
	_body.position.y = bob + sin(_t * 1.8) * 0.006
	_body.rotation.z = lerp(_body.rotation.z, sin(_ph) * 0.03 * spd, 0.2)
	# arms
	var al := -sw * 0.8; var ar := sw * 0.8; var al_z := -0.06; var ar_z := 0.06
	match pose:
		"cheer":
			al = -2.7 + sin(_t * 9.0) * 0.25; ar = -2.7 + cos(_t * 9.0) * 0.25; al_z = -0.2; ar_z = 0.2; _body.position.y += absf(sin(_t * 7.0)) * 0.1
		"carry":
			al = -1.0; ar = -1.0; al_z = 0.25; ar_z = -0.25
		"pray":
			al = -0.9; ar = -0.9; al_z = 0.35; ar_z = -0.35
		"amaze":
			al = -0.5 + sin(_t * 2.0) * 0.05; ar = -0.5; al_z = -0.5; ar_z = 0.5
		_:
			if talking:
				_gest_cd -= dt
				if _gest_cd < 0.0: _gest = 1.0; _gest_cd = randf_range(1.2, 2.6)
				_gest = maxf(0.0, _gest - dt * 0.9)
				ar += -0.9 * sin(_gest * PI); al += -0.3 * sin(_gest * PI)
	_arm_l.rotation = Vector3(lerp(_arm_l.rotation.x, al, 0.25), 0, lerp(_arm_l.rotation.z, al_z, 0.25))
	_arm_r.rotation = Vector3(lerp(_arm_r.rotation.x, ar, 0.25), 0, lerp(_arm_r.rotation.z, ar_z, 0.25))
	# head + mouth
	_head.rotation.x = lerp(_head.rotation.x, (0.06 * sin(_t * 12.0) if talking else 0.0) + (-0.15 if pose == "amaze" else 0.0), 0.2)
	var open := 1.0
	if talking: open = 1.0 + (absf(sin(_t * 13.0)) * 0.6 + absf(sin(_t * 7.3)) * 0.5) * 2.2
	elif pose == "amaze": open = 3.0
	elif pose == "cheer": open = 2.6
	_mouth.scale = Vector3(1.0 if open < 2.0 else 0.8, open, 1.0)
	_mouth.position.y = -0.085 - (open - 1.0) * 0.004
	_blink -= dt
	if _blink < -3.0: _blink = 0.12
	for e in _eyes: e.scale.y = 0.15 if _blink > 0.0 else 1.0
