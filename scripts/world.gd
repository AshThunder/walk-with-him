class_name World
extends Node3D
## The 3D side: camera rig, area building (Nazareth, the road, Cana), player movement and simple collision, NPC life, miracle effects.
const P = preload("res://scripts/person.gd")
const PR = preload("res://scripts/props.gd")
signal trigger_hit(id: String)
signal tapped_ground(p: Vector3)

var area := ""
var root: Node3D
var player: Person
var jesus: Person
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var circles: Array = []
var rects: Array = []
var bounds := Rect2(-10, -10, 20, 20)
var triggers: Array = []
var control := false
var follow_jesus := false
var move_target = null
var npcs := {}
var guests: Array = []
var sheep_list: Array = []
var markers := {}
var scrolls := {}
var pots: Array = []
var trees: Array = []
var wine_light: OmniLight3D
var beam_nodes: Array = []
var sparkles: Array = []
var minidots: Array = []     # [{n: Node3D, col: Color}] extra moving dots for the minimap (lambs, doves)
var fx_root: Node3D
const SPEED := 3.7
# camera rig
var focus := Vector3.ZERO
var focus_goal := Vector3.ZERO
var csize := 13.0
var csize_goal := 13.0
var pitch := -35.0
var pitch_goal := -35.0
var yaw := 45.0
var yaw_spin := 0.0
var follow_node: Node3D = null
var follow_off := Vector3(0, 0.9, 0)
var cam_k := 5.0
var custom_move := false      # a controller (the flock road) moves the player itself
var tap_walk := true           # a tap on the ground walks the player there
var _stuck := 0.0
var _t := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 42
	env = Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.82, 0.76, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.72, 0.68, 0.66); env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_exposure = 0.78; env.adjustment_enabled = true; env.adjustment_saturation = 0.92; env.tonemap_white = 6.0
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	sun = DirectionalLight3D.new(); sun.shadow_enabled = true; sun.directional_shadow_max_distance = 40.0; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.05; sun.shadow_normal_bias = 1.0; add_child(sun)
	cam = Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.keep_aspect = Camera3D.KEEP_WIDTH; cam.size = csize; cam.near = 0.5; cam.far = 120.0; add_child(cam)
	fx_root = Node3D.new(); add_child(fx_root)
	Touch.world_tap.connect(_on_tap)

# ------------------------------------------------------------------ camera
func _clear_trees(pos: Vector3, r: float) -> void:
	var back := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1)
	for t in trees:
		if not is_instance_valid(t): continue
		if r <= 0.0: t.visible = true; continue
		var d := Vector3(t.position.x - pos.x, 0, t.position.z - pos.z)
		var along := d.dot(back)
		var side := (d - back * along).length()
		t.visible = not (d.length() <= r or (along > 0.0 and side < r * 0.8))
func cam_follow(n: Node3D, size := 13.0, pt := -35.0, off := Vector3(0, 0.9, 0)) -> void:
	_clear_trees(Vector3.ZERO, 0.0)
	follow_node = n; csize_goal = size; pitch_goal = pt; follow_off = off
func cam_look(pos: Vector3, size := 13.0, pt := -35.0) -> void:
	_clear_trees(pos, 6.0 if size < 9.0 else 0.0)
	follow_node = null; focus_goal = pos; csize_goal = size; pitch_goal = pt
func cam_snap() -> void:
	if follow_node: focus_goal = follow_node.global_position + follow_off
	focus = focus_goal; csize = csize_goal; pitch = pitch_goal; _apply_cam()
func _apply_cam() -> void:
	var b := Basis(Vector3.UP, deg_to_rad(yaw))
	var dir := b * Vector3(0, sin(deg_to_rad(-pitch)), cos(deg_to_rad(-pitch)))
	cam.global_position = focus + dir * 45.0
	cam.look_at(focus, Vector3.UP)
	cam.size = csize
func cam_fwd() -> Vector3:
	var f := -cam.global_transform.basis.z; f.y = 0; return f.normalized()
func cam_right() -> Vector3:
	var r := cam.global_transform.basis.x; r.y = 0; return r.normalized()
func screen_to_ground(sp: Vector2) -> Variant:
	var o := cam.project_ray_origin(sp); var n := cam.project_ray_normal(sp)
	if absf(n.y) < 0.001: return null
	var t := -o.y / n.y
	return o + n * t
func ground_to_screen(p: Vector3) -> Vector2:
	return cam.unproject_position(p)

# ------------------------------------------------------------------ area management
func clear_area() -> void:
	if root: root.queue_free()
	if player != null and is_instance_valid(player): player.queue_free()
	player = null; jesus = null; follow_jesus = false; follow_node = null
	circles.clear(); rects.clear(); triggers.clear(); npcs.clear(); guests.clear(); sheep_list.clear(); markers.clear(); scrolls.clear(); pots.clear(); trees.clear()
	custom_move = false; tap_walk = true; yaw = 45.0; yaw_spin = 0.0; cam_k = 5.0; csize_goal = 13.0
	wine_light = null; sparkles.clear(); beam_nodes.clear(); minidots.clear(); move_target = null; Touch.set_capture(false)
	for c in fx_root.get_children(): c.queue_free()
	root = Node3D.new(); add_child(root)

func mood(sun_col: Color, energy: float, rot: Vector3, amb: Color, amb_e: float, bg: Color) -> void:
	sun.light_color = sun_col; sun.light_energy = energy; sun.rotation_degrees = rot
	env.ambient_light_color = amb; env.ambient_light_energy = amb_e; env.background_color = bg

func add_rect(c: Vector3, w: float, d: float, grow := 0.1) -> void:
	rects.append(Rect2(c.x - w * 0.5 - grow, c.z - d * 0.5 - grow, w + grow * 2, d + grow * 2))
func add_circle(c: Vector3, r: float) -> void:
	circles.append([Vector2(c.x, c.z), r])
func add_trigger(id: String, c: Vector3, r: float, active := true) -> void:
	triggers.append({"id": id, "pos": Vector2(c.x, c.z), "r": r, "active": active})
func set_trigger(id: String, active: bool) -> void:
	for t in triggers:
		if t.id == id: t.active = active

func ground(texn: String, tint := Color.WHITE, size := 220.0, tile := 6.0) -> void:
	var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(size, size); mi.mesh = pm
	var m := PR.tmat(texn, tint, 1.0, false); m.uv1_scale = Vector3(size / tile, size / tile, 1); mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mi.position = Vector3(bounds.get_center().x, 0, bounds.get_center().y); root.add_child(mi)

func hill(pos: Vector3, r: float, h: float, col: Color) -> void:
	var m := P.mk(root, P.sphere(1.0, 12, 6), col, pos, Vector3(r, h, r)); m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func place(n: Node3D, pos: Vector3, yaw_deg := 0.0, parent: Node = null) -> Node3D:
	n.position = pos; n.rotation_degrees.y = yaw_deg; (parent if parent else root).add_child(n); return n

func add_house(pos: Vector3, w: float, d: float, h: float, yaw_deg := 0.0, tint := Color.WHITE, stairs := false) -> Node3D:
	var n := PR.house(w, d, h, tint, stairs); place(n, pos, yaw_deg)
	var sw := w; var sd := d
	if int(round(yaw_deg / 90.0)) % 2 != 0: sw = d; sd = w
	add_rect(pos, sw + 0.1, sd + 0.1, 0.1)
	return n

func person(o: Dictionary, pos: Vector3, yaw_deg := 0.0, key := "") -> Person:
	var p := P.make(o); p.position = pos; p.target_yaw = deg_to_rad(yaw_deg); p.rotation.y = p.target_yaw; root.add_child(p)
	if key != "": npcs[key] = p
	return p

func scatter(path: String, pts: Array, tint := Color.WHITE, smin := 0.8, smax := 1.3) -> void:
	var xs: Array = []
	for p in pts: xs.append(PR.xf(p, rng.randf() * TAU, rng.randf_range(smin, smax)))
	PR.multi(root, path, xs, tint)

func rand_pts(n: int, rect: Rect2, avoid_rects := true, avoid_dist := 0.0) -> Array:
	var out: Array = []; var tries := 0
	while out.size() < n and tries < n * 30:
		tries += 1
		var p := Vector3(rng.randf_range(rect.position.x, rect.end.x), 0, rng.randf_range(rect.position.y, rect.end.y)); var ok := true
		for r in rects:
			if r.grow(0.5).has_point(Vector2(p.x, p.z)): ok = false; break
		if ok:
			for c in circles:
				if Vector2(p.x, p.z).distance_to(c[0]) < c[1] + 0.5: ok = false; break
		if ok and avoid_dist > 0.0:
			for t in triggers:
				if Vector2(p.x, p.z).distance_to(t.pos) < avoid_dist: ok = false; break
		if ok: out.append(p)
	return out

func add_marker(key: String, pos: Vector3, c := Color(1.0, 0.82, 0.35)) -> Node3D:
	var m := PR.marker(c); m.position = pos + Vector3(0, 2.4, 0); root.add_child(m); markers[key] = m; return m
func remove_marker(key: String) -> void:
	if markers.has(key):
		markers[key].queue_free(); markers.erase(key)

func add_tree(kind: String, pos: Vector3, s := 1.0, collide := true) -> void:
	var n: Node3D = PR.olive(s, int(pos.x * 7 + pos.z * 13)) if kind == "olive" else PR.cypress(s)
	place(n, pos, rng.randf() * 360.0); trees.append(n)
	if collide: add_circle(pos, 0.55 * s)

func ring_scenery(inner: Rect2, count := 26, kinds := ["olive", "cypress"]) -> void:
	for i in count:
		var side := rng.randi() % 4; var p := Vector3.ZERO
		match side:
			0: p = Vector3(rng.randf_range(inner.position.x - 6, inner.end.x + 6), 0, inner.position.y - rng.randf_range(1.5, 7))
			1: p = Vector3(rng.randf_range(inner.position.x - 6, inner.end.x + 6), 0, inner.end.y + rng.randf_range(1.5, 7))
			2: p = Vector3(inner.position.x - rng.randf_range(1.5, 7), 0, rng.randf_range(inner.position.y - 6, inner.end.y + 6))
			_: p = Vector3(inner.end.x + rng.randf_range(1.5, 7), 0, rng.randf_range(inner.position.y - 6, inner.end.y + 6))
		add_tree(kinds[rng.randi() % kinds.size()], p, rng.randf_range(0.9, 1.5), false)

func rocks(pts: Array, tint := Color(1.0, 0.92, 0.78)) -> void:
	var names := ["rock_largeA", "rock_largeB", "rock_largeC", "stone_largeA", "stone_largeB", "rock_smallA", "rock_smallB"]
	for p in pts:
		var nm: String = names[rng.randi() % names.size()]
		var s := rng.randf_range(0.9, 1.6) * (0.6 if nm.begins_with("rock_small") else 1.0)
		var n := PR.glb("res://assets/nature/%s.glb" % nm, tint, s); place(n, p, rng.randf() * 360.0)
		if not nm.begins_with("rock_small"): add_circle(p, 0.7 * s)

func flowers(rect: Rect2, n: int) -> void:
	var cols := ["flower_yellowA", "flower_redA", "flower_purpleA", "flower_yellowB"]
	for c in cols:
		var pts := rand_pts(n / cols.size(), rect)
		var xs: Array = []
		for p in pts: xs.append(PR.xf(p, rng.randf() * TAU, rng.randf_range(0.9, 1.4)))
		PR.multi(root, "res://assets/nature/%s.glb" % c, xs)

# ------------------------------------------------------------------ Nazareth
func build_nazareth() -> void:
	clear_area(); area = "nazareth"; bounds = Rect2(-13, -13, 27, 26)
	mood(Color(1.0, 0.92, 0.78), 1.15, Vector3(-50, -35, 0), Color(0.78, 0.72, 0.7), 0.85, Color(0.82, 0.74, 0.58))
	ground("sand", Color(1.0, 0.96, 0.88)); player_sandbox_hills()
	PR.ribbon(root, [Vector3(4, 0, 13), Vector3(4, 0, 7), Vector3(3.5, 0, 2.4), Vector3(8, 0, 1.6), Vector3(15, 0, 2.2)], 2.8)
	PR.ribbon(root, [Vector3(3.5, 0, 2.4), Vector3(-2, 0, 3.0), Vector3(-6.5, 0, 4.2)], 2.0)
	PR.ribbon(root, [Vector3(7, 0, 1.8), Vector3(8.2, 0, -2), Vector3(8, 0, -5.5)], 2.0)
	add_house(Vector3(-8, 0, -6.2), 5.0, 4.5, 2.7, 0, Color(1.0, 0.97, 0.92), false)
	add_house(Vector3(-1.2, 0, -9.7), 5.6, 4.0, 3.0, 0, Color(0.98, 0.93, 0.84), true)
	add_house(Vector3(-10.2, 0, 1.0), 4.0, 4.2, 2.5, 90, Color(0.96, 0.92, 0.86))
	var shop := PR.workshop(6.6, 4.6); place(shop, Vector3(8.2, 0, -8.2)); add_rect(Vector3(8.2, 0, -9.0), 6.8, 2.8, 0.1)
	# bench + goods
	var well := PR.well(); place(well, Vector3(-2.0, 0, 2.6)); add_circle(Vector3(-2.0, 0, 2.6), 1.25)
	place(PR.jar(), Vector3(-3.6, 0, 3.6)); place(PR.jar(Color(0.6, 0.36, 0.24), 1.2), Vector3(-0.5, 0, 0.8))
	place(PR.glb("res://assets/survival/barrel.glb", Color.WHITE, 1.6), Vector3(-5.6, 0, -3.5), 20); add_circle(Vector3(-5.6, 0, -3.5), 0.5)
	place(PR.glb("res://assets/survival/box.glb", Color.WHITE, 1.5), Vector3(-6.5, 0, -3.6), 5)
	place(PR.glb("res://assets/town/cart.glb", Color(1, 0.95, 0.85), 1.8), Vector3(3.0, 0, -5.6), 30); add_circle(Vector3(3.0, 0, -5.6), 1.0)
	place(PR.jar(Color(0.62, 0.38, 0.26)), Vector3(-6.4, 0, -3.8)); place(PR.jar(), Vector3(1.8, 0, -7.4))
	# trees
	add_tree("olive", Vector3(-8.2, 0, 7.4), 1.2); add_tree("olive", Vector3(11.5, 0, 8.2), 1.1); add_tree("olive", Vector3(-12, 0, -2.5), 1.2); add_tree("olive", Vector3(1.8, 0, 11.5), 1.0)
	add_tree("cypress", Vector3(-12, 0, -11), 1.3); add_tree("cypress", Vector3(12, 0, -12), 1.3); add_tree("cypress", Vector3(-4.6, 0, -4.3), 1.0); add_tree("cypress", Vector3(12.5, 0, -4.6), 1.1)
	ring_scenery(bounds, 30)
	# sheep pen (the player is a shepherd's child)
	for i in 5:
		var f := PR.glb("res://assets/nature/fence_simple.glb", Color(1, 0.9, 0.75), 2.0); place(f, Vector3(7.0 + i * 1.7, 0, 12.0), 0)
	for i in 3:
		var f2 := PR.glb("res://assets/nature/fence_simple.glb", Color(1, 0.9, 0.75), 2.0); place(f2, Vector3(6.2, 0, 10.4 - i * 1.7 + 0.8), 90)
	add_rect(Vector3(10.5, 0, 12.0), 9.0, 0.4, 0.2)
	for p in [Vector3(8.4, 0, 10.8), Vector3(10.3, 0, 11.0), Vector3(9.5, 0, 9.2), Vector3(11.7, 0, 10.0)]:
		var sh := PR.sheep(); place(sh, p, rng.randf() * 360.0); sheep_list.append({"n": sh, "home": p, "goal": p, "cd": rng.randf() * 3.0})
	rocks([Vector3(-12, 0, 5), Vector3(13, 0, -1.5), Vector3(-5, 0, 11), Vector3(5.5, 0, -11.5), Vector3(-11.8, 0, 9)])
	scatter("res://assets/nature/grass_large.glb", rand_pts(70, bounds), Color(1.0, 0.95, 0.6), 0.8, 1.4)
	scatter("res://assets/nature/plant_bushSmall.glb", rand_pts(18, bounds), Color(0.95, 0.9, 0.55), 0.8, 1.3)
	flowers(bounds, 60)
	# NPCs
	jesus = person(_jesus_look(), Vector3(8.0, 0, -4.2), 0, "jesus")
	var nao := person({"robe": Color(0.5, 0.3, 0.3), "sash": Color(0.8, 0.65, 0.3), "cloth": Color(0.85, 0.8, 0.7), "skin": Color(0.7, 0.5, 0.36), "scale": 0.95, "hair_style": "none", "name": "Naomi"}, Vector3(-0.2, 0, 3.4), 160, "naomi")
	# villagers working
	var vm := person({"robe": Color(0.55, 0.45, 0.32), "sash": Color(0.4, 0.2, 0.15), "cloth": Color(0.8, 0.75, 0.62), "beard": true, "hair": Color(0.35, 0.3, 0.28), "scale": 1.0, "label": false}, Vector3(-6.4, 0, -2.4), 130, "vm"); guests.append(vm)
	var vf := person({"robe": Color(0.35, 0.45, 0.55), "sash": Color(0.8, 0.7, 0.4), "cloth": Color(0.9, 0.85, 0.75), "scale": 0.97, "hair_style": "none", "label": false}, Vector3(-3.4, 0, -6.0), 20, "vf"); guests.append(vf)
	add_circle(Vector3(-0.2, 0, 3.4), 0.4); add_circle(Vector3(8.0, 0, -4.2), 0.4)
	# player
	player = _make_player(Vector3(4.2, 0, 9.0), 200)
	# items
	var sc := PR.scroll_item(); place(sc, Vector3(-6.6, 0.55, 6.0)); scrolls["prov3_5"] = sc
	add_marker("scroll", Vector3(-6.6, -1.2, 6.0))
	# triggers
	add_trigger("naomi", Vector3(-0.4, 0, 3.0), 2.7)
	add_trigger("naomi_back", Vector3(-0.4, 0, 3.0), 2.7, false)
	add_trigger("scroll_prov3_5", Vector3(-6.6, 0, 6.0), 1.5, false)
	add_trigger("jesus", Vector3(8.0, 0, -4.2), 2.9)
	add_trigger("exit", Vector3(14.0, 0, 2.2), 1.7, false)
	cam_follow(player, 13.0); cam_snap()

func player_sandbox_hills() -> void:
	hill(Vector3(-26, -1.0, -20), 16, 5, Color(0.76, 0.68, 0.5)); hill(Vector3(26, -1.0, -24), 18, 6, Color(0.72, 0.66, 0.46)); hill(Vector3(-30, -0.5, 14), 14, 3, Color(0.7, 0.66, 0.46))

func _jesus_look() -> Dictionary:
	return {"robe": Color(0.95, 0.91, 0.82), "sash": Color(0.45, 0.28, 0.15), "mantle": Color(0.5, 0.18, 0.18), "skin": Color(0.72, 0.52, 0.37), "hair": Color(0.25, 0.15, 0.09), "hair_style": "long", "beard": true, "scale": 1.05, "name": "Jesus", "eyes": Color(0.22, 0.13, 0.06)}

func _make_player(pos: Vector3, yaw_deg: float) -> Person:
	# the player grows up: child (staff) -> teen (longer tunic) -> adult (cloak and satchel)
	var o := {"scale": 0.76, "head_scale": 1.18, "staff": true, "name": Game.player_name, "skin": Color(0.74, 0.54, 0.38)}
	match Game.age_stage:
		"child": o.merge({"scale": 0.6, "head_scale": 1.3}, true)
		"teen": o.merge({"scale": 0.9, "head_scale": 1.12, "staff": false}, true)
		_: o.merge({"scale": 1.0, "head_scale": 1.0, "staff": false, "satchel": true}, true)
	if Game.player_girl:
		o.merge({"robe": Color(0.72, 0.38, 0.3), "sash": Color(0.9, 0.75, 0.35), "hair": Color(0.15, 0.09, 0.06), "hair_style": "braid", "cloth": null}, true)
	else:
		o.merge({"robe": Color(0.4, 0.5, 0.58), "sash": Color(0.6, 0.4, 0.2), "hair": Color(0.2, 0.12, 0.07), "hair_style": "short"}, true)
	if Game.age_stage == "adult":
		o.merge({"mantle": Color(0.55, 0.42, 0.3)}, true)
	elif Game.age_stage == "teen":
		o.merge({"cloth": Color(0.85, 0.8, 0.7)}, not Game.player_girl)
	var p := P.make(o); p.position = pos; p.target_yaw = deg_to_rad(yaw_deg); p.rotation.y = p.target_yaw; add_child(p)
	return p

func build_fields() -> void: Areas.fields(self)
func build_town(lit_house := false) -> void: Areas.town(self, lit_house)
func build_temple() -> void: Areas.temple(self)
func build_home() -> void: Areas.home(self)

func rebuild_player() -> void:
	var pos := player.position; var yw := player.target_yaw
	player.queue_free(); player = _make_player(pos, rad_to_deg(yw)); player.target_yaw = yw
	if follow_node == null or true: cam_follow(player, csize_goal, pitch_goal)

# ------------------------------------------------------------------ the road to Cana
func build_road() -> void:
	clear_area(); area = "road"; bounds = Rect2(-9, -12, 58, 24)
	mood(Color(1.0, 0.95, 0.84), 1.25, Vector3(-58, -45, 0), Color(0.75, 0.74, 0.72), 0.9, Color(0.78, 0.76, 0.58))
	ground("dry_grass", Color(1.0, 0.98, 0.9), 260.0, 7.0)
	hill(Vector3(10, -1.0, -26), 20, 6, Color(0.66, 0.64, 0.42)); hill(Vector3(40, -1.0, -28), 22, 7, Color(0.7, 0.66, 0.44)); hill(Vector3(22, -1.0, 28), 24, 6, Color(0.64, 0.62, 0.42)); hill(Vector3(-20, -1, 4), 14, 4, Color(0.68, 0.64, 0.44))
	var path := [Vector3(-10, 0, 0.5), Vector3(0, 0, 1.2), Vector3(9, 0, -1.8), Vector3(18, 0, -3.2), Vector3(26, 0, 0.8), Vector3(34, 0, 2.2), Vector3(42, 0, 0.0), Vector3(50, 0, 0.2)]
	PR.ribbon(root, path, 3.0, "path")
	# wheat field
	var xs: Array = []
	for ix in 26:
		for iz in 10:
			xs.append(PR.xf(Vector3(14.0 + ix * 0.55 + rng.randf() * 0.2, 0, -11.5 + iz * 0.55 + rng.randf() * 0.2), rng.randf() * TAU, rng.randf_range(1.5, 2.0)))
	PR.multi(root, "res://assets/nature/crops_wheatStageB.glb", xs, Color(1.0, 0.88, 0.5))
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(15.2, 6.4); fl.mesh = pm; fl.material_override = PR.tmat("sand", Color(0.95, 0.85, 0.65), 1.0, false); fl.material_override.uv1_scale = Vector3(2, 1, 1); fl.position = Vector3(21.0, 0.01, -8.6); fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(fl)
	# second smaller field + trees
	var xs2: Array = []
	for ix in 9:
		for iz in 8: xs2.append(PR.xf(Vector3(36.0 + ix * 0.55, 0, 6.0 + iz * 0.55), rng.randf() * TAU, rng.randf_range(1.4, 1.9)))
	PR.multi(root, "res://assets/nature/crops_wheatStageA.glb", xs2, Color(0.8, 0.9, 0.45))
	for t in [Vector3(6, 0, -6), Vector3(12.5, 0, 5.2), Vector3(31, 0, -5.5), Vector3(40, 0, -4.0), Vector3(2, 0, 8), Vector3(-5, 0, -7.5), Vector3(45, 0, 6.5)]: add_tree("olive", t, rng.randf_range(1.0, 1.3))
	for t in [Vector3(24, 0, 6.5), Vector3(25.8, 0, 7.2), Vector3(-6, 0, 7), Vector3(15, 0, 9.5), Vector3(47, 0, -7)]: add_tree("cypress", t, rng.randf_range(1.0, 1.4))
	rocks([Vector3(4, 0, 4), Vector3(14.5, 0, 1.0), Vector3(29, 0, -2.5), Vector3(38, 0, 5.0), Vector3(20, 0, 8.2), Vector3(8, 0, -9.5), Vector3(44, 0, -3.0), Vector3(-3, 0, -4.5), Vector3(30, 0, 9.5)])
	ring_scenery(bounds, 36)
	scatter("res://assets/nature/grass_large.glb", rand_pts(120, bounds), Color(0.95, 0.95, 0.55), 0.9, 1.6)
	scatter("res://assets/nature/plant_bushSmall.glb", rand_pts(24, bounds), Color(0.9, 0.9, 0.5), 0.8, 1.3)
	flowers(bounds, 90)
	# a flock on the hillside
	for i in 6:
		var p := Vector3(26 + rng.randf_range(-2.5, 2.5), 0, 8.5 + rng.randf_range(-1, 1.5)); var sh := PR.sheep(); place(sh, p, rng.randf() * 360.0); sheep_list.append({"n": sh, "home": p, "goal": p, "cd": rng.randf() * 3.0})
	# Cana ahead
	for h in [[Vector3(55, 0, -4), 5.0, 4.0, 2.8], [Vector3(58, 0, 3), 4.0, 4.0, 2.4], [Vector3(61, 0, -3), 4.5, 4.0, 3.2]]:
		place(PR.house(h[1], h[2], h[3]), h[0], 90.0)
	var sc := PR.scroll_item(); place(sc, Vector3(21.5, 0.55, -8.2)); scrolls["ps119_105"] = sc; add_marker("scroll", Vector3(21.5, -1.2, -8.2))
	jesus = person(_jesus_look(), Vector3(-9.0, 0, 0.0), 90, "jesus")
	player = _make_player(Vector3(-6.5, 0, 0.4), 90)
	add_trigger("scroll_ps119_105", Vector3(21.5, 0, -8.2), 1.5)
	add_trigger("exit", Vector3(47.5, 0, 0.2), 1.8, false)
	follow_jesus = true
	cam_follow(player, 13.0); cam_snap()

# ------------------------------------------------------------------ Cana
func build_cana() -> void:
	clear_area(); area = "cana"; bounds = Rect2(-12, -10, 24, 20)
	mood(Color(1.0, 0.8, 0.54), 1.1, Vector3(-36, -62, 0), Color(0.86, 0.74, 0.66), 0.85, Color(0.8, 0.68, 0.52))
	ground("sand", Color(1.0, 0.95, 0.85))
	hill(Vector3(-28, -1, -22), 16, 5, Color(0.72, 0.64, 0.46)); hill(Vector3(30, -1, -26), 20, 6, Color(0.7, 0.62, 0.44))
	var fl := PR.tbox(root, Vector3(24.4, 0.08, 20.4), Vector3(0, 0.02, 0), "flagstone", Color(1.0, 0.94, 0.85), 0.18); fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	PR.ribbon(root, [Vector3(-16, 0, 8.5), Vector3(-12, 0, 7.5)], 3.0, "path", Color.WHITE, 0.04)
	# walls (far sides only, so the camera never looks through them)
	PR.tbox(root, Vector3(25.0, 1.3, 0.5), Vector3(0, 0.65, -10.3), "plaster", Color(0.96, 0.9, 0.8), 0.35); add_rect(Vector3(0, 0, -10.3), 25.0, 0.5, 0.1)
	# west wall with a gate: wall - post - gap - post - wall, all one piece of masonry (no free-standing boxes)
	PR.tbox(root, Vector3(0.5, 1.3, 14.6), Vector3(-12.3, 0.65, -3.0), "plaster", Color(0.96, 0.9, 0.8), 0.35); add_rect(Vector3(-12.3, 0, -3.0), 0.5, 14.6, 0.1)
	PR.tbox(root, Vector3(0.5, 1.3, 0.8), Vector3(-12.3, 0.65, 10.0), "plaster", Color(0.96, 0.9, 0.8), 0.35); add_rect(Vector3(-12.3, 0, 10.0), 0.5, 0.8, 0.1)
	for z in [4.7, 9.5]:
		PR.tbox(root, Vector3(0.7, 1.9, 0.7), Vector3(-12.3, 0.95, z), "plaster", Color(0.94, 0.88, 0.78), 0.35)
		PR.tbox(root, Vector3(0.9, 0.16, 0.9), Vector3(-12.3, 1.98, z), "plaster", Color(0.86, 0.78, 0.66), 0.35)
		add_circle(Vector3(-12.3, 0, z), 0.5)
	# wedding house
	var hs := add_house(Vector3(-7.4, 0, -6.6), 8.0, 5.0, 3.2, 0, Color(1.0, 0.95, 0.86), false)
	# stone shelf with the six waterpots
	PR.tbox(root, Vector3(12.6, 0.22, 1.5), Vector3(5.0, 0.11, -8.2), "flagstone", Color(0.9, 0.82, 0.72), 0.5)
	for i in 6:
		var pd := PR.waterpot(); var x := 0.0 + i * 2.0; place(pd.node, Vector3(x, 0.2, -8.2), i * 37.0)
		var sp := CPUParticles3D.new(); sp.emitting = false; sp.amount = 26; sp.lifetime = 2.2; sp.position = Vector3(x, 1.0, -8.2); sp.one_shot = false
		var sm := P.sphere(0.5, 4, 2); sp.mesh = sm; var smat := P.mat(Color(1.0, 0.82, 0.4), 0.5, 2.0); sm.material = smat
		sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; sp.emission_sphere_radius = 0.3; sp.direction = Vector3(0, 1, 0); sp.spread = 25.0; sp.initial_velocity_min = 0.8; sp.initial_velocity_max = 1.6; sp.gravity = Vector3(0, -0.2, 0); sp.scale_amount_min = 0.04; sp.scale_amount_max = 0.1
		root.add_child(sp); sparkles.append(sp)
		var beam := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.3; cm.bottom_radius = 0.42; cm.height = 5.0; cm.radial_segments = 10; beam.mesh = cm
		var bm := StandardMaterial3D.new(); bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; bm.blend_mode = BaseMaterial3D.BLEND_MODE_MIX; bm.albedo_color = Color(1.0, 0.58, 0.14, 0.0); bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam.material_override = bm; beam.position = Vector3(x, 3.4, -8.2); beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(beam); beam_nodes.append(bm)
		pots.append({"node": pd.node, "liquid": pd.liquid, "mat": pd.mat, "level": 0, "pos": Vector3(x, 0.5, -8.2)})
		add_circle(Vector3(x, 0, -8.2), 0.5)
	wine_light = OmniLight3D.new(); wine_light.position = Vector3(5, 2.6, -6.6); wine_light.omni_range = 16.0; wine_light.light_color = Color(1.0, 0.62, 0.4); wine_light.light_energy = 0.0; root.add_child(wine_light)
	# canopy where the bridegroom stands
	place(PR.canopy(4.0, 3.2, 2.5), Vector3(-2.6, 0, 1.0))
	# tables
	var t1 := PR.table(4.8, 1.1); place(t1, Vector3(-1.0, 0, -3.4)); add_rect(Vector3(-1.0, 0, -3.4), 4.8, 1.1, 0.1)
	var t2 := PR.table(5.2, 1.1); place(t2, Vector3(4.2, 0, 3.4)); add_rect(Vector3(4.2, 0, 3.4), 5.2, 1.1, 0.1)
	var t3 := PR.table(5.2, 1.1, true, Color(0.9, 0.85, 0.7)); place(t3, Vector3(5.0, 0, 6.8)); add_rect(Vector3(5.0, 0, 6.8), 5.2, 1.1, 0.1)
	var t4 := PR.table(4.0, 1.1); place(t4, Vector3(-7.6, 0, 3.0), 90); add_rect(Vector3(-7.6, 0, 3.0), 1.1, 4.0, 0.1)
	for p in [Vector3(1.2, 0, 3.4), Vector3(7.0, 0, 3.4), Vector3(2.4, 0, 6.8), Vector3(7.6, 0, 6.8)]:
		place(PR.glb("res://assets/town/stall-stool.glb", Color(1, 0.95, 0.85), 1.4), p, rng.randf() * 360.0)
	# lanterns, bunting, barrels, jars
	for p in [Vector3(-11.4, 0, 3.0), Vector3(11.0, 0, -4.0), Vector3(11.0, 0, 9.0), Vector3(-4.6, 0, 7.6), Vector3(-9.4, 0, -2.2)]:
		place(PR.lantern_post(2.6), p, 0.0)
	PR.bunting(root, Vector3(-11.4, 2.5, 3.0), Vector3(-4.6, 2.5, 7.6), 8); PR.bunting(root, Vector3(-9.4, 2.5, -2.2), Vector3(-4.6, 2.5, 7.6), 10); PR.bunting(root, Vector3(11.0, 2.5, -4.0), Vector3(11.0, 2.5, 9.0), 12)
	place(PR.glb("res://assets/survival/barrel.glb", Color.WHITE, 1.6), Vector3(10.4, 0, -6.0), 10); add_circle(Vector3(10.4, 0, -6.0), 0.5)
	place(PR.glb("res://assets/survival/barrel.glb", Color.WHITE, 1.6), Vector3(11.2, 0, -6.4), 70); add_circle(Vector3(11.2, 0, -6.4), 0.5)
	for p in [Vector3(-9.8, 0, 7.6), Vector3(9.6, 0, 0.0), Vector3(-1.0, 0, -1.2)]: place(PR.jar(Color(0.66, 0.4, 0.26)), p)
	add_tree("olive", Vector3(10.6, 0, 8.4), 1.2); add_tree("cypress", Vector3(-11.2, 0, -9.0), 1.3); add_tree("cypress", Vector3(11.4, 0, -9.0), 1.3)
	ring_scenery(bounds, 22)
	flowers(Rect2(-11.5, -9.5, 23, 19), 36)
	# people
	var groom := person({"robe": Color(0.93, 0.88, 0.78), "sash": Color(0.7, 0.2, 0.25), "mantle": Color(0.8, 0.64, 0.24), "beard": true, "hair": Color(0.15, 0.09, 0.06), "scale": 1.02, "label": false}, Vector3(-3.4, 0, 1.0), 20, "groom")
	var bride := person({"robe": Color(0.96, 0.94, 0.9), "sash": Color(0.8, 0.6, 0.25), "cloth": Color(0.97, 0.95, 0.92), "skin": Color(0.78, 0.58, 0.42), "hair_style": "none", "scale": 0.96, "label": false}, Vector3(-1.9, 0, 1.0), -20, "bride")
	var mary := person({"robe": Color(0.28, 0.4, 0.62), "sash": Color(0.85, 0.7, 0.35), "cloth": Color(0.88, 0.9, 0.95), "skin": Color(0.72, 0.52, 0.37), "hair_style": "none", "scale": 0.98, "name": "Mary"}, Vector3(3.0, 0, 0.0), 220, "mary")
	var stew := person({"robe": Color(0.5, 0.18, 0.28), "sash": Color(0.85, 0.7, 0.3), "cloth": Color(0.9, 0.85, 0.7), "beard": true, "hair": Color(0.45, 0.4, 0.38), "scale": 1.04, "name": "Governor"}, Vector3(1.8, 0, -3.3), 180, "steward")
	var sv: Array = []
	for i in 3:
		sv.append(person({"robe": Color(0.62, 0.52, 0.4), "sash": Color(0.4, 0.25, 0.15), "cloth": Color(0.78, 0.72, 0.6), "beard": i != 1, "hair": Color(0.2, 0.14, 0.1), "scale": 0.97 + i * 0.02, "label": false}, Vector3(1.0 + i * 4.0, 0, -6.2), 0, "servant%d" % i))
	var cols := [Color(0.62, 0.3, 0.3), Color(0.3, 0.45, 0.5), Color(0.65, 0.55, 0.3), Color(0.45, 0.35, 0.55), Color(0.35, 0.5, 0.35), Color(0.7, 0.45, 0.3), Color(0.5, 0.5, 0.6), Color(0.6, 0.35, 0.45)]
	var gpos := [Vector3(3.0, 0, 2.2), Vector3(5.6, 0, 2.2), Vector3(4.2, 0, 4.8), Vector3(6.6, 0, 4.9), Vector3(-6.4, 0, 3.0), Vector3(-9.0, 0, 3.8), Vector3(-0.5, 0, -1.7), Vector3(8.6, 0, 1.4)]
	var gyaw := [0, 20, 180, 160, 90, 110, 60, 200]
	for i in gpos.size():
		var fem := i % 2 == 1
		var g := person({"robe": cols[i], "sash": Color(0.8, 0.65, 0.3), "cloth": Color(0.88, 0.84, 0.74) if (fem or i % 3 == 0) else null, "beard": not fem and i % 3 != 0, "hair": Color(0.18, 0.11, 0.07), "hair_style": "none" if fem else "short", "scale": 0.92 + (i % 3) * 0.04, "skin": Color(0.74, 0.54, 0.38).lerp(Color(0.6, 0.42, 0.3), (i % 4) * 0.2), "label": false}, gpos[i], gyaw[i], "guest%d" % i)
		guests.append(g)
	var drummer := person({"robe": Color(0.55, 0.38, 0.22), "sash": Color(0.7, 0.2, 0.2), "cloth": Color(0.85, 0.8, 0.7), "beard": true, "scale": 0.98, "label": false}, Vector3(10.2, 0, 2.2), 230, "drummer")
	P.mk(drummer, P.cyl(0.28, 0.24, 0.3, 10), Color(0.5, 0.32, 0.18), Vector3(0, 0.82, -0.4), Vector3.ONE, Vector3.ZERO, "drum"); drummer.pose = "carry"
	var dn1 := person({"robe": Color(0.82, 0.4, 0.35), "sash": Color(0.9, 0.8, 0.4), "cloth": Color(0.95, 0.9, 0.8), "hair_style": "none", "scale": 0.95, "label": false}, Vector3(9.0, 0, 4.4), 250, "dancer1"); dn1.pose = "cheer"
	var dn2 := person({"robe": Color(0.35, 0.55, 0.5), "sash": Color(0.9, 0.8, 0.4), "cloth": Color(0.95, 0.9, 0.8), "hair_style": "none", "scale": 0.93, "label": false}, Vector3(10.4, 0, 5.4), 250, "dancer2"); dn2.pose = "cheer"
	for d in [dn1, dn2, drummer]: guests.append(d)
	jesus = P.make(_jesus_look()); jesus.position = Vector3(-10.5, 0, 8.4); jesus.target_yaw = deg_to_rad(250); jesus.rotation.y = jesus.target_yaw; root.add_child(jesus); npcs["jesus"] = jesus
	player = _make_player(Vector3(-9.6, 0, 7.4), 250)
	add_trigger("mary", Vector3(3.0, 0, 0.0), 3.4, false)
	add_trigger("steward", Vector3(1.8, 0, -3.3), 2.8, false)
	var sc := PR.scroll_item(); place(sc, Vector3(2.4, 1.1, 6.8)); scrolls["ps34_8"] = sc; add_marker("scroll", Vector3(2.4, -0.2, 6.8))
	add_trigger("scroll_ps34_8", Vector3(2.4, 0, 6.8), 2.0)
	follow_jesus = true
	cam_follow(player, 13.0); cam_snap()

# ------------------------------------------------------------------ miracle helpers
func pot_screen_pos(i: int) -> Vector2:
	return ground_to_screen(pots[i].pos)
func pick_pot(sp: Vector2) -> int:
	var best := -1; var bd := 230.0
	for i in pots.size():
		var d := sp.distance_to(pot_screen_pos(i))
		if d < bd: bd = d; best = i
	return best
func pot_set_level(i: int, lv: int, total := 4) -> void:
	var p = pots[i]; p.level = lv
	var y := lerpf(0.4, 0.84, float(lv) / total)
	create_tween().tween_property(p.liquid, "position:y", y, 0.25)
func pots_to_wine(dur_each := 1.0) -> void:
	for bm in beam_nodes:
		create_tween().tween_property(bm, "albedo_color:a", 0.34, 2.5)
	for sp in sparkles: sp.emitting = true
	create_tween().tween_property(wine_light, "light_energy", 3.0, 3.0)
	var wine := Color(0.5, 0.05, 0.14)
	for i in pots.size():
		var m: StandardMaterial3D = pots[i].mat
		var tw := create_tween().set_parallel(true)
		tw.tween_property(m, "albedo_color", wine, dur_each * 1.4); tw.tween_property(m, "emission", Color(0.8, 0.12, 0.1), dur_each * 1.4); tw.tween_property(m, "emission_energy_multiplier", 0.9, dur_each * 1.4)
		await Game.sleep(self, dur_each * 0.55)
func pots_fill_now() -> void:
	for p in pots:
		p.level = 4; p.liquid.position.y = 0.84
func pots_wine_now() -> void:
	pots_fill_now()
	for p in pots:
		var m: StandardMaterial3D = p.mat
		m.albedo_color = Color(0.5, 0.05, 0.14); m.emission = Color(0.8, 0.12, 0.1); m.emission_energy_multiplier = 0.9
	for bm in beam_nodes:
		var bc: Color = bm.albedo_color; bc.a = 0.10; bm.albedo_color = bc
	for sp in sparkles: sp.emitting = false
	if wine_light != null: wine_light.light_energy = 1.2
func miracle_fade_beams() -> void:
	for bm in beam_nodes: create_tween().tween_property(bm, "albedo_color:a", 0.10, 3.0)
	for sp in sparkles: sp.emitting = false
	create_tween().tween_property(wine_light, "light_energy", 1.2, 3.0)

# ------------------------------------------------------------------ NPC walking helper
func npc_go(p: Person, dest: Vector3, speed := 2.2) -> void:
	var d := dest - p.position; d.y = 0
	if d.length() < 0.05: return
	p.face(d); var dur := d.length() / speed
	p.moving = 1.0
	var tw := create_tween(); tw.tween_property(p, "position", dest, dur)
	await tw.finished
	if is_instance_valid(p): p.moving = 0.0

# ------------------------------------------------------------------ per-frame
func _on_tap(sp: Vector2) -> void:
	if not control or not tap_walk: return
	var g = screen_to_ground(sp)
	if g == null: return
	g.x = clampf(g.x, bounds.position.x + 0.5, bounds.end.x - 0.5); g.z = clampf(g.z, bounds.position.y + 0.5, bounds.end.y - 0.5)
	move_target = Vector3(g.x, 0, g.z); _stuck = 0.0
	_tap_fx(move_target); tapped_ground.emit(move_target)

func _tap_fx(p: Vector3) -> void:
	var r := MeshInstance3D.new(); var t := TorusMesh.new(); t.inner_radius = 0.3; t.outer_radius = 0.38; t.rings = 16; t.ring_segments = 5; r.mesh = t
	r.material_override = P.mat(Color(1, 0.9, 0.6), 0.5, 1.4); r.position = p + Vector3(0, 0.08, 0); r.scale = Vector3(0.3, 0.1, 0.3); fx_root.add_child(r)
	var tw := create_tween().set_parallel(true); tw.tween_property(r, "scale", Vector3(1.3, 0.1, 1.3), 0.5); tw.tween_property(r, "scale:y", 0.02, 0.5)
	tw.chain().tween_callback(r.queue_free)

func _collide(n: Node3D, r: float) -> void:
	var p := Vector2(n.position.x, n.position.z)
	for c in circles:
		var d: Vector2 = p - c[0]; var m: float = c[1] + r
		if d.length_squared() < m * m:
			p = c[0] + (d.normalized() if d.length() > 0.001 else Vector2.RIGHT) * m
	for rc in rects:
		var cl := Vector2(clampf(p.x, rc.position.x, rc.end.x), clampf(p.y, rc.position.y, rc.end.y)); var d := p - cl
		if d.length_squared() < r * r:
			if d.length() > 0.0001: p = cl + d.normalized() * r
			else:
				var dl: float = p.x - rc.position.x; var dr: float = rc.end.x - p.x; var dt: float = p.y - rc.position.y; var db: float = rc.end.y - p.y; var mn: float = minf(minf(dl, dr), minf(dt, db))
				if mn == dl: p.x = rc.position.x - r
				elif mn == dr: p.x = rc.end.x + r
				elif mn == dt: p.y = rc.position.y - r
				else: p.y = rc.end.y + r
	p.x = clampf(p.x, bounds.position.x + 0.4, bounds.end.x - 0.4); p.y = clampf(p.y, bounds.position.y + 0.4, bounds.end.y - 0.4)
	n.position.x = p.x; n.position.z = p.y

func _process(dt: float) -> void:
	_t += dt
	if player == null: return
	if control and not custom_move: _step_player(dt)
	elif not control:
		player.moving = lerpf(player.moving, 0.0, 0.3)
	if follow_jesus and jesus != null and control: _step_follower(dt)
	# triggers
	if control:
		var pp := Vector2(player.position.x, player.position.z)
		for t in triggers:
			if t.active and pp.distance_to(t.pos) < t.r:
				t.active = false; trigger_hit.emit(t.id); break
	# markers + scroll spin
	for k in markers:
		var m: Node3D = markers[k]; m.position.y = m.get_meta("by", m.position.y) if m.has_meta("by") else m.position.y
		if not m.has_meta("by"): m.set_meta("by", m.position.y)
		m.position.y = m.get_meta("by") + sin(_t * 3.0) * 0.18
		m.get_child(0).rotation.y += dt * 2.0
	for k in scrolls:
		if is_instance_valid(scrolls[k]): scrolls[k].rotation.y += dt * 1.5; scrolls[k].position.y = scrolls[k].position.y + sin(_t * 3.0) * 0.0015
	# sheep
	for s in sheep_list:
		s.cd -= dt
		var n: Node3D = s.n
		if s.cd < 0.0:
			s.cd = rng.randf_range(2.0, 6.0); s.goal = s.home + Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))
		var to: Vector3 = s.goal - n.position; to.y = 0
		if to.length() > 0.1:
			n.position += to.normalized() * 0.6 * dt; n.rotation.y = lerp_angle(n.rotation.y, atan2(-to.x, -to.z), 0.1); n.position.y = absf(sin(_t * 8.0)) * 0.03
	# guests idle life
	for g in guests:
		if g is Person and g.pose == "idle":
			if int(_t * 0.5 + g.get_instance_id() % 7) % 5 == 0: g.talking = true
			else: g.talking = false
	# camera
	if follow_node != null and is_instance_valid(follow_node): focus_goal = follow_node.global_position + follow_off
	var k := 1.0 - exp(-cam_k * dt)
	focus = focus.lerp(focus_goal, k); csize = lerpf(csize, csize_goal, k); pitch = lerpf(pitch, pitch_goal, k)
	yaw += yaw_spin * dt
	_apply_cam()
	_tidy(dt)

var _tidy_cd := 0.0
## Every 0.2s: simplify faces of distant people (fewer draw calls) and keep name labels from overlapping (the player's yields first).
func _tidy(dt: float) -> void:
	_tidy_cd -= dt
	if _tidy_cd > 0.0: return
	_tidy_cd = 0.2
	var list: Array = []
	if is_instance_valid(player): list.append(player)
	for k in npcs:
		var n = npcs[k]
		if is_instance_valid(n) and not list.has(n): list.append(n)
	for g in guests:
		if is_instance_valid(g) and g is Person and not list.has(g): list.append(g)
	var near := csize < 8.5
	var labelled: Array = []
	for p in list:
		var d := Vector2(p.position.x - focus.x, p.position.z - focus.z).length()
		p.set_detail(near or d < 6.5 or p == player or p == jesus)
		if p.name_lbl != null and is_instance_valid(p.name_lbl):
			p.name_lbl.visible = true; labelled.append(p)
	for i in labelled.size():
		for j in range(i + 1, labelled.size()):
			var a: Person = labelled[i]; var b: Person = labelled[j]
			if not (a.name_lbl.visible and b.name_lbl.visible): continue
			var pa := ground_to_screen(a.position + Vector3(0, 2.0, 0)); var pb := ground_to_screen(b.position + Vector3(0, 2.0, 0))
			if absf(pa.x - pb.x) < 190.0 and absf(pa.y - pb.y) < 64.0:
				var loser: Person = a if a == player else (b if b == player else (a if Vector2(a.position.x - focus.x, a.position.z - focus.z).length() > Vector2(b.position.x - focus.x, b.position.z - focus.z).length() else b))
				loser.name_lbl.visible = false

func _step_player(dt: float) -> void:
	var dir := Vector3.ZERO
	if Touch.stick_active and Touch.stick.length() > 0.1:
		move_target = null
		dir = (cam_right() * Touch.stick.x + cam_fwd() * (-Touch.stick.y)); dir = dir.normalized() * minf(1.0, Touch.stick.length() * 1.15)
	elif move_target != null:
		var to: Vector3 = move_target - player.position; to.y = 0
		if to.length() < 0.15: move_target = null
		else: dir = to.normalized()
	var before := player.position
	if dir.length() > 0.02:
		player.position += dir * SPEED * dt; player.face(dir)
	_collide(player, 0.3)
	var spd := (player.position - before).length() / maxf(dt, 0.0001)
	player.moving = clampf(spd / SPEED, 0.0, 1.0)
	if move_target != null and dir.length() > 0.02:
		if spd < 0.3 * SPEED: _stuck += dt
		else: _stuck = 0.0
		if _stuck > 0.5: move_target = null; _stuck = 0.0

func _step_follower(dt: float) -> void:
	var to := player.position - jesus.position; to.y = 0
	var dist := to.length()
	var before := jesus.position
	if dist > 2.1:
		var sp := minf(SPEED * 1.1, 1.2 + (dist - 1.8) * 2.5)
		jesus.position += to.normalized() * sp * dt; jesus.face(to)
	elif dist < 1.3:
		jesus.position -= to.normalized() * 1.0 * dt
	_collide(jesus, 0.35)
	var v := (jesus.position - before).length() / maxf(dt, 0.0001)
	jesus.moving = clampf(v / SPEED, 0.0, 1.0)
	if v < 0.2: jesus.face(to)
