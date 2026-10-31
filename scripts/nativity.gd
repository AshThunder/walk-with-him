class_name Nativity
extends Node
## Chapters 1-5 (the Nativity, played as a shepherd's child) and the first age jump.
## Each chapter ends with m._stage(next) (checkpoint + autosave) and then run(next).
const P = preload("res://scripts/person.gd")
const PR = preload("res://scripts/props.gd")
const _Trace = preload("res://scripts/startrace.gd")

var m                                   # Main: the story flow (cut, obj, wait, _stage ...)
var w: World
var ui: UI
var fl: Flock                           # the flock on the road (chapter 1, Road of the Day) and at rest (chapter 2, camp)

# ---- chapter 1: the flock
const GATE := Vector3(7.0, 0, -4.4)
const FOLD := Rect2(4.9, -8.3, 4.4, 3.3)
const FLEE := 2.8
const LAMBS := [Vector3(-10, 0, 6.5), Vector3(-1, 0, -8), Vector3(2, 0, 8.5), Vector3(11, 0, 4), Vector3(-9.5, 0, -6.5)]
var lambs: Array = []
var herd := false
var folded := 0
var _pat := 0.0
const PATIENCE := 35.0                  # no lamb folded for this long: a shepherd whistles one in (nothing here can fail)
# ---- chapter 3: the stables
const STABLES := [Vector3(-8.5, 0, -8.0), Vector3(-0.8, 0, -8.5), Vector3(7.2, 0, -8.0)]
const STABLE_KIND := [[0, 1], [1, 0], [1, 1]]      # [cloth, manger]
var visited: Array = []
# ---- chapter 4: the doves
const DOVE_AREA := Rect2(-5, -4, 12, 9)
var doves: Array = []
var cage: Node3D
var doves_on := false
var _caught := 0
var _dove_t := 0.0
var _ctarget := Vector3(1, 0, 0)
# ---- gestures
var sky_on := false
var cage_on := false
var trace: Control = null
var _lp := Vector2.ZERO
var jump_wait := false
var jump_pos := Vector3.ZERO
var jump_tapped := false
var _t := 0.0

func setup(main) -> void:
	m = main; w = main.world; ui = main.ui
	fl = Flock.new(); add_child(fl); fl.setup(main)
	Touch.gesture.connect(_on_gesture); Touch.world_tap.connect(_on_world_tap)

# ================================================================== looks
func _look(kind: String) -> Dictionary:
	match kind:
		"shepherd": return {"robe": Color(0.5, 0.4, 0.3), "sash": Color(0.35, 0.2, 0.12), "cloth": Color(0.78, 0.72, 0.6), "beard": true, "hair": Color(0.3, 0.25, 0.2), "scale": 0.98, "staff": true, "label": false}
		"mary": return {"robe": Color(0.5, 0.3, 0.3), "sash": Color(0.8, 0.65, 0.3), "cloth": Color(0.85, 0.8, 0.7), "skin": Color(0.7, 0.5, 0.36), "scale": 0.95, "hair_style": "none", "name": "Mary"}
		"joseph": return {"robe": Color(0.5, 0.4, 0.28), "sash": Color(0.3, 0.2, 0.12), "cloth": Color(0.7, 0.62, 0.5), "beard": true, "hair": Color(0.2, 0.14, 0.1), "scale": 1.0, "name": "Joseph"}
		"simeon": return {"robe": Color(0.9, 0.88, 0.8), "sash": Color(0.25, 0.35, 0.6), "cloth": Color(0.92, 0.9, 0.84), "beard": true, "hair": Color(0.88, 0.88, 0.88), "scale": 0.98, "name": "Simeon"}
		"anna": return {"robe": Color(0.35, 0.3, 0.5), "sash": Color(0.7, 0.6, 0.3), "cloth": Color(0.8, 0.75, 0.85), "skin": Color(0.7, 0.5, 0.38), "scale": 0.93, "hair_style": "none", "name": "Anna"}
		"seller": return {"robe": Color(0.65, 0.5, 0.3), "sash": Color(0.4, 0.2, 0.15), "cloth": Color(0.8, 0.3, 0.25), "beard": true, "hair": Color(0.2, 0.15, 0.1), "scale": 1.0, "label": false}
		"toddler": return {"robe": Color(0.95, 0.92, 0.84), "sash": Color(0.85, 0.7, 0.35), "scale": 0.42, "head_scale": 1.5, "hair": Color(0.25, 0.16, 0.1), "label": false}
	return {}

func _wise(i: int) -> Dictionary:
	var rob: Color = [Color(0.35, 0.2, 0.5), Color(0.2, 0.4, 0.5), Color(0.6, 0.25, 0.25), Color(0.25, 0.4, 0.3)][i]
	return {"robe": rob, "sash": Color(0.9, 0.75, 0.35), "cloth": Color(0.95, 0.9, 0.78), "mantle": rob.lightened(0.15), "beard": i != 3, "hair": Color(0.15, 0.1, 0.08), "scale": 1.02, "skin": [Color(0.7, 0.5, 0.36), Color(0.5, 0.34, 0.24), Color(0.78, 0.6, 0.45), Color(0.6, 0.42, 0.3)][i], "label": false}

func _pop(n: Node3D) -> void:
	var s := n.scale; n.scale = s * 0.05; create_tween().tween_property(n, "scale", s, 0.5)

func _face_now(p: Person, pt: Vector3) -> void:
	p.face_point(pt); p.rotation.y = p.target_yaw

# ================================================================== flow
func extra() -> int:
	return folded if m.phase == "n1" else 0     # only the classic chapter 1 carries a count; a road restarts from its beginning

func _leave() -> void:
	m.cut(true); m._nogoal(); ui.show_pour(false); ui.show_clues(false)
	sky_on = false; cage_on = false; doves_on = false; herd = false; jump_wait = false
	lambs.clear(); doves.clear(); Touch.set_capture(false); fl.teardown()
	if trace != null and is_instance_valid(trace): trace.queue_free()
	trace = null
	if ui.fade_rect.color.a < 0.99: await ui.fade(1.0, 0.8)

func run(id: String, resume := false, extra_n := 0, pos = null, yaw := 0.0) -> void:
	match id:
		"n1_flock": await ch1()
		"n1_classic": await ch1_classic(resume, extra_n, pos, yaw)
		"daily": await road_daily()
		"n2_sky": await ch2()
		"n3_town": await ch3()
		"n4_temple": await ch4()
		"n5_star": await ch5()
		"jump": await ch_jump()

func _process(dt: float) -> void:
	_t += dt
	if w == null or not is_instance_valid(w) or w.player == null or not is_instance_valid(w.player): return
	if not lambs.is_empty(): _step_lambs(dt)
	if doves_on: _step_doves(dt)
	if cage_on: _step_cage(dt)

func on_trigger(id: String) -> void:
	if id.begins_with("n_stable_"): await _peek(int(id.substr(9)))

func _on_gesture(kind: String, pos: Vector2) -> void:
	if sky_on:
		if kind == "down": _lp = pos
		elif kind == "move": w.pitch_goal = clampf(w.pitch_goal - (pos.y - _lp.y) * 0.1, -30.0, 16.0); _lp = pos
	if cage_on and kind != "up":
		var g = w.screen_to_ground(pos)
		if g != null: _ctarget = Vector3(g.x, 0, g.z)
	if trace != null and is_instance_valid(trace): trace.gesture(kind, pos)

func _on_world_tap(sp: Vector2) -> void:
	if jump_wait and w.ground_to_screen(jump_pos).distance_to(sp) < 130.0: jump_tapped = true

# ================================================================== 1 (classic) · Gather the Flock: the first prototype, kept reachable from Chapters
func _spawn_lambs(n_folded: int) -> void:
	lambs.clear(); folded = 0
	for i in LAMBS.size():
		var n := Areas.lamb(); w.root.add_child(n)
		var L := {"n": n, "state": "free", "goal": Vector2.ZERO, "via": false, "cd": 0.0, "wander": Vector2.ZERO}
		if i < n_folded:
			n.position = Vector3(randf_range(5.6, 8.6), 0, randf_range(-7.6, -5.8)); L.state = "fold"; folded += 1
		else:
			n.position = LAMBS[i]
		n.rotation.y = randf() * TAU; lambs.append(L)
		w.minidots.append({"n": n, "col": Color(1, 0.95, 0.85) if L.state == "free" else Color(1.0, 0.82, 0.35)})

func _step_lambs(dt: float) -> void:
	var pp := Vector2(w.player.position.x, w.player.position.z); var g2 := Vector2(GATE.x, GATE.z)
	var inner := FOLD.grow(-0.4)
	for L in lambs:
		var n: Node3D = L.n
		if not is_instance_valid(n): continue
		var p := Vector2(n.position.x, n.position.z); var v := Vector2.ZERO; var spd := 0.0
		match L.state:
			"in":
				var tgt: Vector2 = Vector2(7.0, -4.0) if L.via else L.goal
				var d := tgt - p
				if d.length() < 0.3:
					if L.via: L.via = false
					else: L.state = "fold"; _lamb_folded(L)
				else: v = d.normalized(); spd = 2.2
			"trot":
				var d := Vector2(7.0, -3.4) - p
				if d.length() < 0.4: _lamb_in(L)
				else: v = d.normalized(); spd = 2.4
			"fold":
				L.cd -= dt
				if L.cd <= 0.0: L.cd = randf_range(1.5, 3.5); L.wander = Vector2(randf_range(inner.position.x, inner.end.x), randf_range(inner.position.y, inner.end.y))
				var d: Vector2 = L.wander - p
				if d.length() > 0.2: v = d.normalized(); spd = 0.5
			_:
				if inner.has_point(p): L.state = "fold"; _lamb_folded(L)
				elif herd:
					var d := p - pp; var dist := d.length()
					if dist < FLEE:
						var away := d.normalized() if dist > 0.01 else Vector2.RIGHT
						var tg := (g2 - p).normalized()
						v = (away * 0.55 + tg * 0.45).normalized()
						# pinned against the field edge: slide along it towards the gate instead of sticking
						var bd := w.bounds
						if (p.x < bd.position.x + 1.0 and v.x < 0.0) or (p.x > bd.end.x - 1.0 and v.x > 0.0): v = Vector2(0.0, signf(tg.y if absf(tg.y) > 0.05 else 1.0)).lerp(tg, 0.3).normalized()
						elif (p.y < bd.position.y + 1.0 and v.y < 0.0) or (p.y > bd.end.y - 1.0 and v.y > 0.0): v = Vector2(signf(tg.x if absf(tg.x) > 0.05 else 1.0), 0.0).lerp(tg, 0.3).normalized()
						spd = 0.8 + 2.0 * (1.0 - dist / FLEE)
						if p.distance_to(g2) < 2.2: _lamb_in(L)
		if spd > 0.0:
			var np := n.position + Vector3(v.x, 0, v.y) * spd * dt
			if L.state == "free" or L.state == "trot":
				np.x = clampf(np.x, w.bounds.position.x + 0.6, w.bounds.end.x - 0.6); np.z = clampf(np.z, w.bounds.position.y + 0.6, w.bounds.end.y - 0.6)
			elif L.state == "fold":
				np.x = clampf(np.x, inner.position.x, inner.end.x); np.z = clampf(np.z, inner.position.y, inner.end.y)
			n.position.x = np.x; n.position.z = np.z
			if L.state == "free": w._collide(n, 0.35)
			n.rotation.y = lerp_angle(n.rotation.y, atan2(-v.x, -v.y), 1.0 - exp(-9.0 * dt))
			n.position.y = absf(sin(_t * (6.0 + spd * 2.0) + n.get_instance_id() % 7)) * 0.07 * minf(spd, 2.0)
		else:
			n.position.y = lerpf(n.position.y, 0.0, 0.2)
	# no-fail: if nobody is making headway, a shepherd whistles a lamb into the fold
	if herd:
		_pat += dt
		if _pat > PATIENCE:
			_pat = PATIENCE * 0.5
			var best = null; var bd := 1e9
			for L in lambs:
				if L.state == "free" and is_instance_valid(L.n):
					var d := Vector2(L.n.position.x, L.n.position.z).distance_to(g2)
					if d < bd: bd = d; best = L
			if best != null:
				best.state = "trot"; Audio.sfx("whistle", -6.0); ui.toast("A shepherd whistles. A lamb trots to the fold.", 3.0)

func _lamb_in(L: Dictionary) -> void:
	L.state = "in"; L.via = true; L.goal = Vector2(randf_range(5.7, 8.5), randf_range(-7.5, -5.9))

func _lamb_folded(L: Dictionary) -> void:
	folded += 1; _pat = 0.0
	L.cd = 0.0
	for md in w.minidots:
		if md.n == L.n: md.col = Color(1.0, 0.82, 0.35)
	Audio.sfx("pickup", -6.0, 1.0 + 0.06 * folded)
	ui.set_pour(folded, lambs.size(), "Lambs in the fold"); m._save()

func ch1_classic(resume: bool, extra_n: int, pos, yaw: float) -> void:
	await _leave()
	m.phase = "n1"
	w.build_fields(); Audio.music("night", -9.0, 1.5)
	if pos != null:
		w.player.position = Vector3(pos.x, 0, pos.z); w.player.rotation.y = yaw; w.player.target_yaw = yaw
	_spawn_lambs(extra_n if resume else 0)
	m.cam_back(14.0); w.cam_snap(); m.cut(true)
	await ui.fade(0.0, 1.0)
	if not resume:
		m._stage("n1_classic")
		ui.area_card("The Night Field", "Bethlehem  \u00B7  Luke 2")
		await m.wait(2.0)
		await ui.verse("n_lk2_8")
		w.cam_look(Vector3(-3.4, 0.9, 3.4), 9.0, -28.0)
		await m.wait(0.8)
		await ui.line("sh_send", w.npcs.get("sh0"))
		m.cam_back(14.0)
	else:
		ui.area_card("The Night Field", "Welcome back")
	m.obj("Gather the lambs into the fold", Vector3(7.0, -1.0, -5.6), Vector3(7, 0, -5.6))
	ui.show_pour(true); ui.set_pour(folded, lambs.size(), "Lambs in the fold")
	herd = true; _pat = 0.0; m.cut(false)
	ui.toast("Walk toward a lamb and it runs from you. Guide it to the fold.", 6.0)
	while folded < lambs.size(): await Game.frame(self)
	herd = false; m.cut(true); ui.show_pour(false); m._nogoal()
	Audio.sfx("complete", -4.0)
	w.cam_look(Vector3(-3.4, 0.9, 3.4), 9.0, -28.0)
	await m.wait(1.0)
	await ui.line("sh_done", w.npcs.get("sh1"))
	m._stage("n2_sky"); run("n2_sky")

# ================================================================== 1 · Lead the Flock (the road), and the Road of the Day
func ch1() -> void:
	await _road(Roads.story_cfg(), true)

func road_daily() -> void:
	await _road(Roads.daily_cfg(Game.today()), false)

func _flock_names(min_n: int) -> Array:
	var out: Array = Game.roster.duplicate()
	while out.size() < min_n: out.append(Game.lamb_name(out.size()))
	return out

func _light_to_end(pal_name: String, dur: float) -> void:
	var e: Array = Roads.pal(pal_name).end
	var st: Array = [w.sun.light_color, w.sun.light_energy, w.sun.rotation_degrees, w.env.ambient_light_color, w.env.ambient_light_energy, w.env.background_color]
	var tw := create_tween(); tw.tween_method(func(u: float): fl._mood_mix(st, e, u), 0.0, 1.0, dur)

func _journal(title: String, text: String) -> void:
	for i in range(Game.journal.size() - 1, -1, -1):
		if Game.journal[i].get("title", "") == title: Game.journal.remove_at(i)
	Game.journal.append({"title": title, "text": text})

func _keep_stone(line_id: String, lamb: String, road: String) -> Dictionary:
	var d: Dictionary = Game.lines[line_id]
	var stone := {"id": line_id, "ref": d.ref, "text": d.text, "lamb": lamb, "road": road}
	for i in range(Game.stones.size() - 1, -1, -1):
		if Game.stones[i] is Dictionary and Game.stones[i].get("id", "") == line_id: Game.stones.remove_at(i)
	Game.stones.append(stone)
	return stone

func _road(cfg: Dictionary, story: bool) -> void:
	await _leave()
	m.phase = "n1r" if story else "daily"
	var lay := Roads.build(w, cfg)
	var goal: Vector3 = lay.goal
	Audio.music("night" if cfg.pal == "dusk" else "village", -10.0, 1.5)
	fl.populate(cfg, lay)
	m.cut(true); w.control = false
	await ui.fade(0.0, 1.0)
	if story: m._stage("n1_flock")
	else: m.stage = "daily"; m._save_cd = 15.0
	ui.area_card(cfg.title, cfg.sub)
	await m.wait(1.6)
	# spot the destination: the camera drifts to the fire and back
	w.cam_k = 1.5
	w.cam_look(goal + Vector3(0, 0.9, 5.0), 15.0, -42.0)
	await m.wait(2.4)
	if story: await ui.line("sh_road", w.npcs.get("sh0"))
	else: await m.wait(0.8)
	w.cam_follow(w.player, fl._csize(), -48.0, fl.cam_off)
	await m.wait(1.5)
	w.cam_k = 4.0
	m.obj("Lead the lambs to the fire", goal + Vector3(0, -1.0, 0), goal)
	fl.begin()
	ui.toast("Drag to lead.  Tap to swing your staff.", 6.0)
	while not fl.arrived(): await Game.frame(self)
	# arrival: the flock settles, the light changes, one chime
	var res := fl.finish()
	m.cut(true); m._nogoal()
	Audio.sfx("chime", -2.0)
	_light_to_end(cfg.pal, 4.5)
	w.cam_k = 1.8
	w.cam_look(goal + Vector3(0, 0.6, 10.0), 15.5, -62.0)
	await m.wait(3.4)
	var lost: Array = res.lost
	if not lost.is_empty(): fl.bring_lost(lost)
	await ui.line("sh_camp_all" if lost.is_empty() else "sh_camp_lost", w.npcs.get("sh0"))
	var t0 := 0.0
	while not lost.is_empty() and not fl.all_settled(lost) and t0 < 16.0: await Game.frame(self); t0 += get_process_delta_time()
	await m.wait(1.0)
	await m.camp.result_card(res, cfg)
	# what is kept
	for nm in fl.arrived_names():
		if not Game.roster.has(nm): Game.roster.append(nm)
	var star: String = res.star
	var txt := "%d lambs came to the fire." % res.followers
	if not lost.is_empty(): txt += " %s wandered in the dark and were found at the fire." % m.camp._names(lost, 3)
	if star != "": txt += " You will remember %s, who %s." % [star, "strayed and was gathered again" if res.star_rescued > 0 else "was the first to follow you"]
	Game.best[cfg.id] = maxi(int(Game.best.get(cfg.id, 0)), int(res.met))
	if story:
		_journal(cfg.title, txt)
		var stone := _keep_stone("n_ps23_1", star if star != "" else str(Game.roster[0]), cfg.title)
		Game.save_meta()
		m._stage("n2_sky")
		await m.camp.stone_card(stone)
		await m.camp.open("Walk on")
		m._stage("n2_sky"); run("n2_sky")
	else:
		_journal("%s  \u00B7  %s" % [cfg.title, Game.today()], txt)
		if Game.daily_done != Game.today(): Game.daily_total += 1
		Game.daily_done = Game.today()
		Game.save_meta()
		await m.camp.open("Back to the title")
		m._to_title()

# ================================================================== 2 · The angels' announcement: a spectacle. No score, no timer, nothing to lose.
func _glory_motes(at: Vector3, col: Color) -> CPUParticles3D:
	var pr := CPUParticles3D.new(); pr.amount = 90; pr.lifetime = 7.0; pr.preprocess = 3.0; pr.emitting = false
	var qm := QuadMesh.new(); qm.size = Vector2(0.13, 0.13); pr.mesh = qm
	var mt := StandardMaterial3D.new(); mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mt.albedo_color = col; mt.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pr.material_override = mt; pr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pr.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; pr.emission_box_extents = Vector3(8.0, 0.2, 7.0)
	pr.direction = Vector3(0, 1, 0); pr.spread = 12.0; pr.initial_velocity_min = 0.5; pr.initial_velocity_max = 1.1; pr.gravity = Vector3.ZERO
	pr.scale_amount_min = 0.5; pr.scale_amount_max = 1.5; pr.position = at; w.root.add_child(pr)
	return pr

func ch2() -> void:
	await _leave()
	m.phase = "n2"
	var cfg := Roads.story_cfg()
	var lay := Roads.build(w, cfg)
	(lay.road as MeshInstance3D).visible = false
	var goal: Vector3 = lay.goal
	var e: Array = Roads.pal("dusk").end
	w.mood(e[0], e[1], e[2], e[3], e[4], e[5])
	Audio.music("night", -12.0, 1.5)
	w.player.position = goal + Vector3(2.9, 0, 3.7); w.player.face_point(goal); w.player.rotation.y = w.player.target_yaw
	var names := _flock_names(14)
	fl.settle_at(goal, names, goal)
	var base := goal + Vector3(1.0, 4.0, 3.4)
	w.cam_look(base, 15.0, -30.0); w.cam_snap(); m.cut(true)
	await ui.fade(0.0, 1.2)
	ui.area_card("Glory in the Sky", "Luke 2")
	await m.wait(3.0)
	# the sky: stars (one MultiMesh) and, hidden until the look, the angel and the host
	var fwd := w.cam_fwd(); var rt := w.cam_right(); var ctr := Vector3(base.x, 0, base.z)
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var xfs: Array = []
	for i in 90:
		var s := rng.randf_range(0.07, 0.2)
		xfs.append(Transform3D(Basis().scaled(Vector3(s, s, s)), ctr + fwd * 34.0 + rt * rng.randf_range(-16, 16) + Vector3(0, rng.randf_range(4, 36), 0)))
	var stars := Areas.multi_mesh(w.root, P.sphere(1.0, 4, 3), xfs, Areas.glow(Color(0.92, 0.94, 1.0)), false)
	var angel := Areas.light_column(16.0, 1.3, Color(1.0, 0.86, 0.45), 3.0); angel.position = ctr + fwd * 26.0 + Vector3(0, 9.0, 0); w.root.add_child(angel); angel.visible = false
	var host: Array = []
	for i in 7:
		var c := Areas.light_column(4.0, 0.5, Color(1.0, 0.9, 0.55), 3.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		c.position = ctr + fwd * 24.0 + rt * (side * (3.6 + 1.7 * (i / 2))) + Vector3(0, 10.0 + 3.5 * ((i * 5) % 3), 0)
		w.root.add_child(c); c.visible = false; c.scale = Vector3(1, 0.02, 1); host.append(c)
	angel.scale = Vector3(1, 0.02, 1)
	var motes := _glory_motes(Vector3(goal.x, 0.3, goal.z + 1.0), Color(1.0, 0.9, 0.55))
	# look up: drag a finger upwards (it always happens; if no one drags, the sky lifts by itself)
	w.control = false; Touch.set_capture(true); sky_on = true; _lp = Vector2.ZERO
	w.pitch_goal = -30.0
	var t0 := 0.0; var hinted := false
	ui.toast("Drag your finger up to look at the sky", 5.0)
	while w.pitch < 5.0:
		await Game.frame(self); t0 += get_process_delta_time()
		if t0 > 5.5 and not hinted: hinted = true; ui.toast("Slide your finger slowly up the screen", 4.0)
		if t0 > 9.0: w.pitch_goal = 12.0
	sky_on = false; Touch.set_capture(false)
	# the glory of the Lord: light, not noise
	Audio.music("wonder", -6.0, 1.0); Audio.sfx("chime", -4.0)
	angel.visible = true; create_tween().tween_property(angel, "scale", Vector3.ONE, 2.2)
	motes.emitting = true
	var sun_e := w.sun.light_energy
	var sun_c := w.sun.light_color
	var tl := create_tween().set_parallel(true)
	tl.tween_property(w.sun, "light_energy", sun_e * 1.9, 2.4); tl.tween_property(w.sun, "light_color", Color(1.0, 0.9, 0.62), 2.4)
	tl.tween_property(w.env, "ambient_light_energy", w.env.ambient_light_energy * 1.4, 2.4)
	var sh: Array = []
	for k in ["sh0", "sh1", "sh2"]: sh.append(w.npcs.get(k))
	for p in sh: p.face(fwd); p.pose = "awe"
	w.player.face(fwd); w.player.pose = "awe"
	await ui.verse("n_lk2_9")
	await ui.line("a_tidings")
	await ui.line("a_sign")
	for i in host.size():
		host[i].visible = true; create_tween().tween_property(host[i], "scale", Vector3.ONE, 1.6).set_delay(i * 0.22)
	await m.wait(3.2)
	await ui.verse("n_lk2_13_14")
	var c: int = await ui.choose(["Kneel", "Praise", "Look up in wonder"])
	var pz: String = ["kneel", "praise", "awe"][c]
	w.player.pose = pz
	for p in sh: p.pose = pz
	await m.wait(4.0)
	motes.emitting = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(angel, "scale", Vector3(1, 0.02, 1), 2.2)
	for hc in host: tw.tween_property(hc, "scale", Vector3(1, 0.02, 1), 1.8)
	tw.tween_property(w.sun, "light_energy", sun_e, 2.6); tw.tween_property(w.sun, "light_color", sun_c, 2.6)
	tw.tween_property(w.env, "ambient_light_energy", e[4], 2.6)
	w.cam_look(goal + Vector3(0, 0.9, 9.5), 14.0, -60.0)
	await m.wait(2.8)
	w.player.pose = "idle"
	for p in sh: p.pose = "idle"
	stars.queue_free(); angel.queue_free(); motes.queue_free()
	for hc in host: hc.queue_free()
	Audio.music("night", -9.0, 1.5)
	# the Memory Stone and the camp
	var who := str(names[0])
	_journal("Glory in the Sky", "An angel stood over the field, and the glory of the Lord shone round about. The flock lay still by the fire. You will remember %s, who did not stir." % who)
	var stone := _keep_stone("n_stone_lk2_11", who, "Glory in the Sky")
	Game.save_meta()
	await m.camp.stone_card(stone)
	await m.camp.open("Walk on")
	await ui.line("sh_go", sh[0])
	m._stage("n3_town"); run("n3_town")

# ================================================================== 3 · Match the Sign
func _next_stable() -> int:
	var best := -1; var bd := 1e9
	for i in 3:
		if i in visited: continue
		var d := w.player.position.distance_to(STABLES[i])
		if d < bd: bd = d; best = i
	return best

func _goal_stable() -> void:
	var i := _next_stable()
	if i < 0: m._nogoal(); return
	m.obj("Look into each stable for the sign", Vector3(STABLES[i].x, -1.0, -4.6), Vector3(STABLES[i].x, 0, -4.6))

func ch3() -> void:
	await _leave()
	m.phase = "n3"; visited.clear()
	w.build_town(false); Audio.music("night", -11.0, 1.5)
	for i in 3:
		var p := w.person(_look("shepherd"), Vector3(-2.2 + i * 2.3, 0, 11.2), 180.0, "sh%d" % i)
		p.rotation.y = p.target_yaw
	for i in 3: w.add_trigger("n_stable_%d" % i, Vector3(STABLES[i].x, 0, -4.7), 1.9, true)
	m.cam_back(14.0); w.cam_snap(); m.cut(true)
	ui.set_clues(-1, -1)
	await ui.fade(0.0, 1.0)
	ui.area_card("Bethlehem", "The city of David")
	await m.wait(2.0)
	await ui.line("sh_town", w.npcs.get("sh1"))
	ui.show_clues(true); m.cut(false); ui.show_clues(true)
	_goal_stable()
	ui.toast("Walk up to a stable and look inside", 5.0)

func _peek(i: int) -> void:
	if m.phase != "n3": return
	w.control = false; w.move_target = null; m._nogoal()
	w.set_trigger("n_stable_%d" % i, false)
	var s: Vector3 = STABLES[i]; var k: Array = STABLE_KIND[i]
	w.player.face_point(s)
	w.cam_look(s + Vector3(0, 1.0, 0.6), 6.5, -26.0)
	await m.wait(1.0)
	ui.set_clues(k[0], k[1])
	if k[0] == 1 and k[1] == 1: await _found(); return
	Audio.sfx("bookFlip2", -8.0)
	ui.toast(["There is hay and a manger here, but no swaddling clothes.", "There are cloths here, but no manger.", ""][i], 3.5)
	await m.wait(3.4)
	m.cam_back(14.0)
	await w.npc_go(w.player, w.player.position + Vector3(0, 0, 3.0), 3.0)
	if not (i in visited): visited.append(i)
	ui.set_clues(-1, -1)
	_rearm(i)                                    # it re-arms once the child has walked clear (the stable stays on the list)
	_goal_stable()
	w.control = true

func _rearm(i: int) -> void:
	await Game.sleep(self, 0.2)
	while m.phase == "n3" and w.player.position.distance_to(Vector3(STABLES[i].x, 0, -4.7)) < 3.2: await Game.frame(self)
	if m.phase == "n3": w.set_trigger("n_stable_%d" % i, true)

func _found() -> void:
	m.phase = "n3done"
	var C: Vector3 = STABLES[2]
	Audio.sfx("complete", -3.0)
	Areas.infant(w.root, Vector3(C.x, 0.86, C.z - 1.1)).rotation.y = PI * 0.5
	var mary := w.person(_look("mary"), Vector3(C.x - 0.6, 0, C.z - 0.1), 0.0, "mary")
	var jos := w.person(_look("joseph"), Vector3(C.x + 0.6, 0, C.z - 0.1), 0.0, "joseph")
	for p in [mary, jos]: p.rotation.y = 0.0; p.target_yaw = 0.0; p.pose = "kneel"; _pop(p)
	w.cam_look(Vector3(C.x, 1.0, C.z + 1.0), 9.5, -30.0)
	var sh: Array = []
	for k in 3: sh.append(w.npcs.get("sh%d" % k))
	var spots := [Vector3(C.x - 1.9, 0, C.z + 2.2), Vector3(C.x + 0.0, 0, C.z + 3.0), Vector3(C.x + 1.9, 0, C.z + 2.2)]
	for k in 3: w.npc_go(sh[k], spots[k], 3.0)
	w.npc_go(w.player, Vector3(C.x - 0.9, 0, C.z + 3.4), 3.0)
	await m.wait(3.6)
	for p in sh: p.face_point(Vector3(C.x, 0, C.z - 1.0)); p.pose = "kneel"
	w.player.face_point(Vector3(C.x, 0, C.z - 1.0)); w.player.pose = "kneel"
	await ui.verse("n_lk2_16")
	await m.wait(0.6)
	ui.show_clues(false)
	m._stage("n4_temple"); run("n4_temple")

# ================================================================== 4 · Catch the Doves
func ch4() -> void:
	await _leave()
	m.phase = "n4"; _caught = 0
	w.build_temple(); Audio.music("temple", -10.0, 1.5)
	var mary := w.person(_look("mary"), Vector3(-2.2, 0, -4.6), 0.0, "mary")
	var jos := w.person(_look("joseph"), Vector3(-3.7, 0, -4.9), 0.0, "joseph")
	var sim := w.person(_look("simeon"), Vector3(1.0, 0, -6.6), 0.0, "simeon")
	var anna := w.person(_look("anna"), Vector3(4.2, 0, -6.4), 0.0, "anna")
	var sell := w.person(_look("seller"), Vector3(8.8, 0, -3.0), 180.0, "seller")
	for p in [mary, jos, sim, anna, sell]: p.rotation.y = p.target_yaw
	_face_now(mary, Vector3(0.6, 0, -6.0)); _face_now(jos, Vector3(-2.2, 0, -4.6)); _face_now(sim, mary.position); _face_now(anna, mary.position)
	var babe := Areas.infant(mary, Vector3(0.0, 0.98, -0.34)); babe.rotation.y = PI * 0.5; mary.pose = "carry"
	w.cam_look(Vector3(-1.4, 0.9, -4.6), 10.0, -32.0); w.cam_snap(); m.cut(true)
	await ui.fade(0.0, 1.0)
	ui.area_card("The Temple", "Jerusalem")
	await m.wait(2.0)
	await ui.verse("n_lk2_24")
	w.cam_look(Vector3(8.0, 0.9, -2.4), 8.0, -30.0)
	await m.wait(0.8)
	await ui.line("dove_seller", sell)
	# the game
	cage = Areas.cage(); w.root.add_child(cage); cage.position = Vector3(1, 0, 0); _ctarget = cage.position
	doves.clear()
	for i in 2:
		var d := Areas.dove(); w.root.add_child(d); d.position = Vector3(-2.5 + i * 6.0, 0, -1.0 + i * 3.0)
		doves.append({"n": d, "dir": Vector2.from_angle(randf() * TAU), "cd": 0.0, "hold": 0.0, "caught": false, "hop": randf() * 3.0})
	w.cam_look(Vector3(1.5, 0.0, -0.4), 17.0, -48.0)
	w.control = false; ui.set_hud(true); Touch.set_capture(true)
	m.obj("Catch the two loose doves"); ui.show_pour(true); ui.set_pour(0, 2, "Doves caught")
	ui.toast("Drag the cage with your finger. Be gentle and slow.", 6.0)
	_dove_t = 0.0; doves_on = true; cage_on = true
	while _caught < 2: await Game.frame(self)
	doves_on = false; cage_on = false; Touch.set_capture(false)
	m.cut(true); ui.show_pour(false); m._nogoal()
	Audio.sfx("complete", -4.0)
	var tw := create_tween(); tw.tween_property(cage, "position", Vector3(8.4, 0, -0.1), 1.4)
	await tw.finished
	await m.wait(0.6)
	# Simeon takes the child
	Audio.music("vigil", -11.0, 2.0)
	w.cam_look(Vector3(-1.0, 1.0, -5.0), 7.5, -26.0)
	await w.npc_go(sim, Vector3(-0.9, 0, -4.9), 1.6)
	_face_now(sim, mary.position)
	await m.wait(0.5)
	babe.reparent(sim, false); babe.position = Vector3(0, 0.98, -0.34); sim.pose = "carry"; mary.pose = "idle"
	Audio.sfx("pickup", -6.0)
	await ui.line("s_depart", sim)
	w.npc_go(anna, Vector3(0.6, 0, -4.2), 1.8)
	await m.wait(1.8)
	await ui.verse("n_lk2_38")
	m._stage("n5_star"); run("n5_star")

func _step_cage(dt: float) -> void:
	var d := _ctarget - cage.position; d.y = 0
	cage.position += d.limit_length(7.0 * dt)
	cage.position.x = clampf(cage.position.x, DOVE_AREA.position.x - 1.0, DOVE_AREA.end.x + 1.0)
	cage.position.z = clampf(cage.position.z, DOVE_AREA.position.y - 1.0, DOVE_AREA.end.y + 1.0)

func _step_doves(dt: float) -> void:
	_dove_t += dt
	var c := Vector2(cage.position.x, cage.position.z)
	var calm := 0.4 if _dove_t > 40.0 else 1.0                       # nothing can fail: they tire after a while
	for D in doves:
		if D.caught: continue
		var n: Node3D = D.n; var p := Vector2(n.position.x, n.position.z); var d := p.distance_to(c)
		D.cd -= dt
		if D.cd <= 0.0: D.cd = randf_range(1.2, 2.6); D.dir = Vector2.from_angle(randf() * TAU)
		var spd := 1.0
		if d < 2.8:
			D.dir = D.dir.lerp((p - c).normalized(), 0.12).normalized(); spd = 2.3
		spd *= calm
		D.hop += dt * (4.0 if spd > 1.5 else 2.5)
		var airborne: float = maxf(0.0, sin(D.hop * PI))
		var move: Vector2 = D.dir * spd * dt * (0.25 + airborne)
		var np := p + move
		if not DOVE_AREA.has_point(np):
			D.dir = (DOVE_AREA.get_center() - p).normalized(); np = p
		n.position = Vector3(np.x, airborne * 0.45, np.y)
		if D.dir.length() > 0.01: n.rotation.y = lerp_angle(n.rotation.y, atan2(-D.dir.x, -D.dir.y), 1.0 - exp(-8.0 * dt))
		var fl: float = sin(_t * 30.0) * 0.8 * airborne
		if n.has_meta("wl"): n.get_meta("wl").rotation.z = fl; n.get_meta("wr").rotation.z = -fl
		D.hold = D.hold + dt if d < 0.9 else maxf(0.0, D.hold - dt * 2.0)
		if D.hold > 0.5 or (_dove_t > 55.0 and d < 3.5):
			D.caught = true; _caught += 1
			n.reparent(cage, false); n.position = Vector3(-0.2 + 0.4 * (_caught - 1), 0.0, 0.0); n.scale = Vector3.ONE * 1.0
			if n.has_meta("wl"): n.get_meta("wl").rotation.z = 0.0; n.get_meta("wr").rotation.z = 0.0
			Audio.sfx("pickup", -4.0, 1.2)
			ui.set_pour(_caught, 2, "Doves caught"); m._save()

# ================================================================== 5 · Trace the Star
func ch5() -> void:
	await _leave()
	m.phase = "n5"
	w.build_town(true); Audio.music("night", -11.0, 1.5)
	var wise: Array = []
	for i in 4:
		var p := w.person(_wise(i), Vector3(-16.0 - (i % 2) * 1.6, 0, 4.6 + i * 0.7), 270.0, "wise%d" % i); p.rotation.y = p.target_yaw; wise.append(p)
	w.cam_look(Vector3(-5.0, 0.9, 5.4), 14.0, -33.0); w.cam_snap(); m.cut(true)
	await ui.fade(0.0, 1.0)
	ui.area_card("The Star", "Matthew 2")
	await m.wait(2.0)
	await ui.verse("n_mt2_1")
	for i in 4: w.npc_go(wise[i], Vector3(-8.2 + (i % 2) * 1.5, 0, 4.4 + i * 0.7), 2.4)
	await m.wait(4.2)
	for p in wise: p.face_point(w.player.position)
	await ui.line("w_ask", wise[0])
	# the trace
	trace = _Trace.new(); trace.font = ui.F_S; ui.mid.add_child(trace); trace.modulate.a = 0.0
	create_tween().tween_property(trace, "modulate:a", 1.0, 0.7)
	Touch.set_capture(true); trace.active = true
	var tr: Control = trace
	var t0 := 0.0
	var hint := false
	while not tr.done:
		await Game.frame(self); t0 += get_process_delta_time()
		if t0 > 6.0 and not hint: hint = true; ui.toast("Put your finger on the star and follow the dotted road", 5.0)
	Touch.set_capture(false)
	Audio.sfx("complete", -4.0)
	await m.wait(0.7)
	var tw := create_tween(); tw.tween_property(tr, "modulate:a", 0.0, 0.8); await tw.finished
	tr.queue_free(); trace = null
	await ui.line("wise_thank", wise[0])
	# the star leads them, and the road is drawn in gold dots
	var route := [Vector3(-6.5, 0.06, 5.6), Vector3(-1.5, 0.06, 5.7), Vector3(2.0, 0.06, 5.0), Vector3(6.0, 0.06, 4.6), Vector3(9.3, 0.06, 6.2), Vector3(10.6, 0.06, 6.9)]
	var dots := _road_dots(route)
	var star := Areas.star(0.9); star.position = Vector3(-10.0, 8.0, 3.0); w.root.add_child(star); _pop(star)
	Anim.make(star, "pulse", 0.1, 3.0)
	w.cam_look(Vector3(-1.0, 1.0, 5.0), 16.0, -35.0)
	await ui.verse("n_mt2_9")
	create_tween().tween_property(dots.multimesh, "visible_instance_count", dots.multimesh.instance_count, 2.2)
	create_tween().tween_property(star, "position", Vector3(10.6, 7.0, 3.0), 9.0).set_trans(Tween.TRANS_SINE)
	var done := [0]
	for i in 4:
		_walk(wise[i], route, Vector3(0, 0, [-0.5, 0.3, -0.2, 0.6][i]), [Vector3(8.3, 0, 7.6), Vector3(9.7, 0, 8.1), Vector3(11.5, 0, 8.1), Vector3(12.9, 0, 7.6)][i], done)
	w.cam_follow(wise[1], 12.0, -33.0)
	while done[0] < 4: await Game.frame(self)
	w.cam_look(Vector3(10.6, 1.0, 6.0), 9.0, -30.0)
	var mary := w.person(_look("mary"), Vector3(11.3, 0, 6.3), 180.0, "mary"); mary.rotation.y = mary.target_yaw
	var kid := w.person(_look("toddler"), Vector3(10.4, 0, 6.35), 180.0, "toddler"); kid.rotation.y = kid.target_yaw
	for p in wise: p.face_point(Vector3(10.7, 0, 6.3)); p.pose = "kneel"
	w.player.pose = "idle"
	await m.wait(1.0)
	var gifts := [[Color(1.0, 0.82, 0.35), Vector3(9.5, 0.1, 7.1), P.box(0.34, 0.2, 0.26)], [Color(0.96, 0.95, 0.88), Vector3(10.5, 0.12, 7.25), P.cyl(0.13, 0.16, 0.24, 8)], [Color(0.5, 0.3, 0.2), Vector3(11.5, 0.12, 7.1), P.cyl(0.16, 0.12, 0.24, 8)]]
	for g in gifts:
		var mi := P.mk(w.root, g[2], g[0], g[1]); _pop(mi)
	Audio.sfx("complete", -4.0)
	await ui.verse("n_mt2_10_11")
	await ui.verse("n_mt2_12")
	m._stage("jump"); run("jump")

func _road_dots(route: Array) -> MultiMeshInstance3D:
	var xfs: Array = []
	for i in route.size() - 1:
		var a: Vector3 = route[i]; var b: Vector3 = route[i + 1]; var n := int(a.distance_to(b) / 0.7)
		for k in n: xfs.append(Transform3D(Basis().scaled(Vector3(1, 0.3, 1)), a.lerp(b, k / float(n))))
	var mi := Areas.multi_mesh(w.root, P.sphere(0.14, 6, 3), xfs, Areas.glow(Color(1.0, 0.82, 0.35)), false)
	mi.multimesh.visible_instance_count = 0
	return mi

func _walk(p: Person, route: Array, off: Vector3, end: Vector3, done: Array) -> void:
	for pt in route:
		if not is_instance_valid(p): return
		await w.npc_go(p, pt + off, 2.1)
	if is_instance_valid(p): await w.npc_go(p, end, 2.0)
	done[0] += 1

# ================================================================== the first age jump
func ch_jump() -> void:
	await _leave()
	m.phase = "jump"; Game.age_stage = "child"
	w.build_home(); Audio.music("village", -12.0, 1.5)
	var marks: Array = w.get_meta("marks", [])
	for i in range(1, marks.size()): marks[i].visible = false
	w.cam_look(Vector3(0.6, 1.0, -1.2), 7.5, -22.0); w.cam_snap(); m.cut(true)
	await ui.fade(0.0, 1.2)
	ui.area_card("Years Pass", "Home at Nazareth")
	await m.wait(2.2)
	await ui.verse("n_lk2_40")
	for i in 2:
		await _grow(i, marks)
		await ui.verse(["n_lk2_52", "n_lk3_23"][i])
	await m.wait(0.6)
	m._intro()

func _grow(i: int, marks: Array) -> void:
	var y: float = Areas.MARK_Y[i + 1]
	jump_pos = Vector3(Areas.POST_X + 0.12, y, Areas.POST_Z + 0.1)
	var ring := Anim.make(w.root, "pulse", 0.2, 5.0, jump_pos)
	var tm := MeshInstance3D.new(); var t := TorusMesh.new(); t.inner_radius = 0.17; t.outer_radius = 0.26; t.rings = 18; t.ring_segments = 4; tm.mesh = t
	tm.material_override = Areas.glow(Color(1.0, 0.85, 0.4), 0.95); tm.rotation.x = PI * 0.5; ring.add_child(tm)
	jump_tapped = false; jump_wait = true
	ui.toast("Tap the glowing mark on the doorpost", 5.0)
	var t0 := 0.0; var hinted := false
	while not jump_tapped and t0 < 12.0:
		await Game.frame(self); t0 += get_process_delta_time()
		if t0 > 6.0 and not hinted: hinted = true; ui.toast("Tap the shining ring beside the door", 5.0)
	jump_wait = false; ring.queue_free()
	# a soft flash while the child grows
	var fl := ColorRect.new(); fl.color = Color(0.98, 0.93, 0.76, 0.0); fl.set_anchors_preset(Control.PRESET_FULL_RECT); fl.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.root.add_child(fl)
	var tw := create_tween(); tw.tween_property(fl, "color:a", 1.0, 0.6); await tw.finished
	Game.age_stage = ["teen", "adult"][i]; w.rebuild_player(); w.cam_look(Vector3(0.6, 1.0, -1.2), 7.5, -22.0)
	if i + 1 < marks.size(): marks[i + 1].visible = true
	Audio.sfx("bookFlip2", -6.0)
	await m.wait(0.5)
	var tw2 := create_tween(); tw2.tween_property(fl, "color:a", 0.0, 0.8); await tw2.finished
	fl.queue_free()
