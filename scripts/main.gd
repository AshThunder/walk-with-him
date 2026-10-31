extends Node
## Story flow: the Nativity (chapters 1-5, nativity.gd), the age jump, then Nazareth -> Cana (John 2:1-11).
var world: World
var ui: UI
var nat: Nativity
var _chapter_pick := ""
var phase := "boot"
var pot_mode := ""            # "" | "fill" | "draw"
var pours := 0
var POUR_TOTAL := 24
var cup: Node3D
var _busy := false
var stage := ""               # the last checkpoint reached ("" = none yet); what the save file resumes from
var _cp_pos := Vector3.ZERO
var _cp_yaw := 0.0
var _save_cd := 15.0
var _back_t := -10.0
var _continue_flag := false
var _closing := false

## Checkpoints. Each one knows its area, the HUD phase, the objective text and where the objective is.
const STAGES := {
	"n1_flock": {"nat": true, "area": "fields", "phase": "n1", "text": "Gather the lambs into the fold", "title": "The Night Field", "ch": "Chapter 1"},
	"n2_sky": {"nat": true, "area": "fields", "phase": "n2", "text": "", "title": "Glory in the Sky", "ch": "Chapter 2"},
	"n3_town": {"nat": true, "area": "town", "phase": "n3", "text": "", "title": "Bethlehem", "ch": "Chapter 3"},
	"n4_temple": {"nat": true, "area": "temple", "phase": "n4", "text": "", "title": "The Temple", "ch": "Chapter 4"},
	"n5_star": {"nat": true, "area": "town", "phase": "n5", "text": "", "title": "The Star", "ch": "Chapter 5"},
	"jump": {"nat": true, "area": "home", "phase": "jump", "text": "", "title": "Years Pass", "ch": "Chapter 5"},
	"naz_start": {"ch": "Chapter 8", "area": "nazareth", "phase": "nazareth", "text": "Look for Naomi near the well", "title": "Nazareth"},
	"naz_scroll": {"ch": "Chapter 8", "area": "nazareth", "phase": "nazareth", "text": "Find Naomi's scroll by the olive tree", "title": "Nazareth"},
	"naz_return": {"ch": "Chapter 8", "area": "nazareth", "phase": "nazareth", "text": "Take the scroll back to Naomi", "title": "Nazareth"},
	"naz_jesus": {"ch": "Chapter 8", "area": "nazareth", "phase": "nazareth", "text": "Go and see Jesus at the carpenter's shop", "title": "Nazareth"},
	"naz_walk": {"ch": "Chapter 8", "area": "nazareth", "phase": "nazareth", "text": "Walk the road east with Jesus", "title": "Nazareth"},
	"road": {"ch": "Chapter 9", "area": "road", "phase": "road", "text": "Walk with Jesus to Cana", "title": "The Road to Cana"},
	"cana_mary": {"ch": "Chapter 10", "area": "cana", "phase": "cana", "text": "Greet Mary, the mother of Jesus", "title": "Cana of Galilee"},
	"cana_draw": {"ch": "Chapter 10", "area": "cana", "phase": "cana", "text": "Draw some out: tap a waterpot", "title": "Cana of Galilee"},
	"cana_bear": {"ch": "Chapter 10", "area": "cana", "phase": "bear", "text": "Bear the cup to the governor of the feast", "title": "Cana of Galilee"},
}

func _ready() -> void:
	# Never let the OS close us behind the story's back: Android's Back gesture would otherwise quit the app instantly.
	get_tree().set_auto_accept_quit(false)
	get_tree().quit_on_go_back = false
	world = World.new(); add_child(world)
	ui = UI.new(); add_child(ui)
	ui.world = world
	nat = Nativity.new(); add_child(nat); nat.setup(self)
	ui.chapter_chosen.connect(func(id: String): _chapter_pick = id)
	world.trigger_hit.connect(_on_trigger)
	Touch.world_tap.connect(_on_world_tap)
	ui.begin_pressed.connect(func(): _begin_flag = true)
	ui.continue_pressed.connect(func(): _continue_flag = true)
	ui.name_chosen.connect(func(): _name_flag = true)
	ui.again_pressed.connect(_again)
	ui.save_pressed.connect(_manual_save)
	ui.title_pressed.connect(_to_title)
	Game.reset_progress()
	_title()

func _exit_tree() -> void:
	if get_tree() != null: get_tree().paused = false

# ------------------------------------------------------------------ OS events: back gesture, app paused, window closed
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST: _on_back()
		NOTIFICATION_WM_CLOSE_REQUEST:
			if _closing or ui == null: get_tree().quit(); return
			_closing = true; _save(); get_tree().quit()
		NOTIFICATION_APPLICATION_FOCUS_OUT: _save()
		NOTIFICATION_APPLICATION_PAUSED:
			_save()
			if ui != null and _playing() and not ui.overlay_open(): ui.open_menu(true)     # come back to a pause menu, not mid-walk

func _playing() -> bool:
	return stage != "" and not (phase in ["boot", "title", "name", "intro", "end", "resume", "jump", "n3done"])

func _on_back() -> void:
	if ui == null: return
	if ui.map_open: ui.open_map(false)
	elif ui.chap_open: ui.open_chapters(false)
	elif ui.menu_open: ui.open_menu(false)
	elif _playing(): ui.open_menu(true)
	elif phase == "name": pass
	else:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _back_t < 2.5: _save(); get_tree().quit()
		else: _back_t = now; ui.toast("Press Back again to exit", 2.2)

func _process(dt: float) -> void:
	# periodic autosave of the player's position while walking
	if _playing() and not get_tree().paused:
		_save_cd -= dt
		if _save_cd <= 0.0: _save_cd = 15.0; _save()

# ------------------------------------------------------------------ saving
func _snapshot() -> Dictionary:
	if world.control and is_instance_valid(world.player):
		_cp_pos = world.player.position; _cp_yaw = world.player.rotation.y
	return {"stage": stage, "px": _cp_pos.x, "pz": _cp_pos.z, "yaw": _cp_yaw, "name": Game.player_name, "girl": Game.player_girl,
		"scrolls": Game.scrolls.keys(), "age": Game.age_stage, "extra": nat.extra() if nat != null else 0, "music": Game.settings.music, "saved_at": Time.get_datetime_string_from_system()}

func _save() -> bool:
	if stage == "" or phase == "end" or world == null or not is_instance_valid(world): return false
	return Game.write_save(_snapshot())

func _stage(s: String) -> void:
	stage = s
	if is_instance_valid(world.player): _cp_pos = world.player.position; _cp_yaw = world.player.rotation.y
	_save_cd = 15.0
	_save()

func _manual_save() -> void:
	if _save(): ui.toast("Game saved", 2.0)
	else: ui.toast("Nothing to save yet", 2.0)

func _to_title() -> void:
	_save(); Touch.reset(); Audio.stop_voice()
	ui.open_menu(false); get_tree().paused = false
	get_tree().reload_current_scene()

func _saved_info(d: Dictionary) -> String:
	var i: Dictionary = STAGES[d.stage]
	if i.get("nat", false): return "%s  \u00B7  %s" % [i.ch, i.title]
	return "%s  \u00B7  %s  \u00B7  %d of 3 scrolls" % [i.ch, i.title, (d.get("scrolls", []) as Array).size()]

func _valid_save(d: Dictionary) -> bool:
	return not d.is_empty() and STAGES.has(str(d.get("stage", "")))

var _begin_flag := false
var _name_flag := false

func wait(s: float) -> void:
	await Game.sleep(self, s)

func cut(on: bool) -> void:
	world.control = not on
	if on: world.move_target = null
	ui.set_hud(not on)

func obj(text: String, marker_pos = null, goal_pos = "same") -> void:
	ui.set_objective(text); world.remove_marker("goal")
	if marker_pos != null: world.add_marker("goal", marker_pos)
	ui.goal = marker_pos if (goal_pos is String) else goal_pos

func _nogoal() -> void:
	world.remove_marker("goal"); ui.goal = null

func cam_back(size := 13.0) -> void:
	world.cam_follow(world.player, size, -35.0)

# ------------------------------------------------------------------ title and name
func _title() -> void:
	phase = "title"
	world.build_fields(); world.control = false
	world.player.visible = false
	world.cam_look(Vector3(-3, 0, 2), 15.0, -33.0); world.cam_snap()
	Audio.music("night", -8.0, 0.1)
	var sv := Game.read_save()
	var can := _valid_save(sv)
	ui.show_title(true, _saved_info(sv) if can else ""); ui.fade_rect.color.a = 1.0
	await ui.fade(0.0, 1.0)
	while not _begin_flag and not _continue_flag and _chapter_pick == "": await Game.frame(self)
	if _chapter_pick != "":
		Audio.sfx("select", -3.0)
		ui.show_title(false)
		Game.reset_progress()
		var id := _chapter_pick; _chapter_pick = ""
		if id == "naz_start": Game.age_stage = "adult"; _intro()
		else:
			await _resume({"stage": id, "name": Game.player_name, "girl": Game.player_girl, "fresh": true, "age": "adult" if not STAGES[id].get("nat", false) else "child"})
		return
	if _continue_flag:
		Audio.sfx("select", -3.0)
		ui.show_title(false)
		await _resume(sv)
		return
	Audio.sfx("select", -3.0)
	ui.show_title(false); ui.show_name(true); phase = "name"
	while not _name_flag: await Game.frame(self)
	Audio.sfx("select", -3.0)
	ui.show_name(false)
	var nm := Game.player_name; var gl := Game.player_girl
	Game.reset_progress(); Game.player_name = nm; Game.player_girl = gl
	nat.run("n1_flock")

func _intro() -> void:
	phase = "intro"; cut(true)
	if ui.fade_rect.color.a < 0.99: await ui.fade(1.0, 0.8)
	Audio.music("village", -9.0, 1.0)
	if world.area != "nazareth":
		world.build_nazareth(); world.markers["scroll"].visible = false
	world.rebuild_player(); cam_back(11.0); world.cam_snap()
	await ui.fade(0.0, 0.9)
	ui.area_card("Nazareth", "Galilee")
	await wait(1.2)
	await ui.verse("n_lk4_16")
	world.cam_follow(world.player, 13.0)
	phase = "nazareth"
	obj("Look for Naomi near the well", world.npcs.naomi.position)
	ui.update_scrolls(); cut(false)
	ui.toast("Tap the ground to walk, or drag to steer", 6.0)
	world.set_trigger("jesus", false)
	_stage("naz_start")

# ------------------------------------------------------------------ triggers
func _on_trigger(id: String) -> void:
	match id:
		"naomi": await _naomi_ask()
		"scroll_prov3_5": await _pickup("prov3_5"); _after_scroll1()
		"naomi_back": await _naomi_thanks()
		"jesus": await _jesus_invite()
		"scroll_ps119_105": await _pickup("ps119_105")
		"scroll_ps34_8": await _pickup("ps34_8")
		"exit": await _leave_area()
		"mary": await _mary_scene()
		"steward": await _steward_scene()
		_: await nat.on_trigger(id)

func _pickup(key: String) -> void:
	cut(true)
	Audio.sfx("pickup", -2.0)
	world.remove_marker("scroll")
	if world.scrolls.has(key): world.scrolls[key].queue_free(); world.scrolls.erase(key)
	Game.scrolls[key] = true
	ui.update_scrolls()
	await ui.verse("n_" + key)
	cut(false)
	_save()

func _naomi_ask() -> void:
	cut(true); _nogoal()
	var n: Person = world.npcs.naomi
	world.player.face_point(n.global_position); n.face_point(world.player.global_position)
	world.cam_look((n.position + world.player.position) * 0.5 + Vector3(0, 0.8, 0), 6.5, -26.0)
	await ui.line("naomi_ask", n)
	cam_back()
	world.markers["scroll"].visible = true
	world.set_trigger("scroll_prov3_5", true)
	obj("Find Naomi's scroll by the olive tree", null, Vector3(-6.6, 0, 6.0))
	cut(false)
	_stage("naz_scroll")

func _after_scroll1() -> void:
	obj("Take the scroll back to Naomi", world.npcs.naomi.position)
	world.set_trigger("naomi_back", true)
	_stage("naz_return")

func _naomi_thanks() -> void:
	cut(true); _nogoal()
	var n: Person = world.npcs.naomi
	world.player.face_point(n.global_position); n.face_point(world.player.global_position)
	world.cam_look((n.position + world.player.position) * 0.5 + Vector3(0, 0.8, 0), 6.5, -26.0)
	await ui.line("naomi_thanks", n)
	cam_back()
	obj("Go and see Jesus at the carpenter's shop", world.npcs.jesus.position)
	world.set_trigger("jesus", true)
	cut(false)
	_stage("naz_jesus")

func _jesus_invite() -> void:
	cut(true); _nogoal()
	var j: Person = world.jesus
	world.player.face_point(j.global_position)
	j.face(Vector3(1, 0, 1))
	world.cam_look(j.position + Vector3(0, 1.25, 0), 3.6, -16.0)
	await wait(1.2)
	await ui.line("j_invite", j)
	cam_back()
	world.follow_jesus = true
	world.set_trigger("exit", true)
	obj("Walk the road east with Jesus", Vector3(14.0, 0, 2.2))
	cut(false)
	_stage("naz_walk")

func _leave_area() -> void:
	cut(true); _nogoal(); world.follow_jesus = false
	await ui.fade(1.0, 0.9)
	if world.area == "nazareth":
		world.build_road(); phase = "road"
		Audio.music("road", -9.0, 0.5)
		cam_back(); world.cam_snap()
		await ui.fade(0.0, 0.9)
		ui.area_card("The Road to Cana", "Galilee")
		obj("Walk with Jesus to Cana", Vector3(47.5, 0, 0.2))
		world.set_trigger("exit", true)
		cut(false)
		_stage("road")
	else:
		world.build_cana(); phase = "cana"
		Audio.music("feast", -10.0, 0.5)
		cam_back(); world.cam_snap()
		await ui.fade(0.0, 0.9)
		ui.area_card("Cana of Galilee", "A wedding feast")
		await wait(1.0)
		await ui.verse("n_j2_1")
		await ui.verse("n_j2_2")
		world.follow_jesus = true
		world.set_trigger("mary", true)
		obj("Greet Mary, the mother of Jesus", world.npcs.mary.position)
		cut(false)
		_stage("cana_mary")
		ui.toast("A wedding scroll lies by the long table", 4.0)

# ------------------------------------------------------------------ the miracle
func _mary_scene() -> void:
	cut(true); _nogoal(); world.follow_jesus = false
	var mary: Person = world.npcs.mary; var j: Person = world.jesus
	world.cam_look(Vector3(3.8, 0.9, -0.3), 7.0, -28.0)
	await world.npc_go(j, Vector3(4.7, 0, -0.5), 3.0)
	mary.face_point(j.global_position); j.face_point(mary.global_position)
	world.player.face_point(mary.global_position)
	Audio.sfx("crowd_murmur", -6.0)
	ui.toast("The wine has run out.", 3.0)
	await wait(0.8)
	await ui.line("m_nowine", mary)
	await ui.line("j_woman", j)
	mary.face_point(world.npcs.servant1.global_position)
	await ui.line("m_servants", mary)
	world.cam_look(Vector3(5, 0.6, -6.2), 12.0, -35.0)
	await wait(0.8)
	await ui.line("j_fill", j)
	# the player helps the servants
	world.npc_go(world.player, Vector3(3.2, 0, -5.0), 3.2)
	await wait(1.2)
	POUR_TOTAL = world.pots.size() * 4; pours = 0; pot_mode = "fill"
	world.cam_look(Vector3(5, 0.5, -5.2), 15.0, -38.0)
	ui.set_objective("Fill all six waterpots to the brim"); ui.set_hud(true)
	ui.show_pour(true); ui.set_pour(0, POUR_TOTAL)
	ui.toast("Help the servants fill each waterpot", 4.0)
	var who := 0
	while pours < POUR_TOTAL:
		await wait(1.4)
		var open: Array = []
		for i in world.pots.size():
			if world.pots[i].level < 4: open.append(i)
		if not open.is_empty(): _pour(open[who % open.size()], true); who += 1
	pot_mode = ""
	await wait(0.5)
	Audio.sfx("pot_full", -2.0)
	ui.show_pour(false)
	await ui.line("sv_brim", world.npcs.servant1)
	await ui.line("j_draw", j)
	world.add_marker("goal", world.pots[2].pos - Vector3(0, 0.4, 0)); ui.goal = world.pots[2].pos
	ui.set_objective("Draw some out: tap a waterpot")
	ui.set_hud(true); pot_mode = "draw"
	_stage("cana_draw")
	ui.toast("Tap a waterpot to draw some out", 5.0)

func _pour(i: int, servant: bool) -> void:
	if world.pots[i].level >= 4: return
	world.pot_set_level(i, world.pots[i].level + 1)
	pours += 1
	Audio.sfx("pour", -4.0 if servant else -1.0, randf_range(0.92, 1.08))
	ui.set_pour(pours, POUR_TOTAL)
	var pp: Vector3 = world.pots[i].pos
	if not servant:
		world.player.face_point(pp)
		world.player.pose = "carry"; _pour_end()

func _pour_end() -> void:
	await wait(0.7)
	if pot_mode != "draw" and is_instance_valid(world.player): world.player.pose = "idle"

func _on_world_tap(sp: Vector2) -> void:
	if pot_mode == "": return
	var i := world.pick_pot(sp)
	if i < 0 or world.ground_to_screen(world.pots[i].pos).distance_to(sp) > 190.0: return
	if pot_mode == "fill": _pour(i, false)
	elif pot_mode == "draw": pot_mode = ""; _miracle(i)

func _miracle(_i: int) -> void:
	_nogoal(); world.control = false; ui.set_hud(false)
	world.player.face_point(world.pots[2].pos); world.player.pose = "idle"
	Audio.music("wonder", -6.0, 1.5)
	Audio.sfx("wine_miracle", 0.0)
	world.cam_look(Vector3(5, 0.8, -7.4), 10.0, -30.0)
	await wait(1.0)
	for k in 3:
		world.npcs["servant%d" % k].pose = "amaze"
	world.pots_to_wine(0.9)
	await wait(3.2)
	Audio.sfx("crowd_murmur", -3.0)
	ui.toast("The water has become wine.", 3.5)
	await wait(2.4)
	for k in 3: world.npcs["servant%d" % k].pose = "idle"
	world.miracle_fade_beams()
	# the cup
	_give_cup()
	await wait(0.6)
	cam_back(); world.set_trigger("steward", true)
	obj("Bear the cup to the governor of the feast", world.npcs.steward.position)
	cut(false)
	phase = "bear"
	_stage("cana_bear")

func _give_cup() -> void:
	if is_instance_valid(cup): cup.queue_free()
	cup = Person.mk(world.player, Person.cyl(0.09, 0.06, 0.16, 8), Color(0.78, 0.62, 0.3), Vector3(0.0, 0.95, -0.42))
	Person.mk(cup, Person.cyl(0.08, 0.08, 0.02, 8), Color(0.5, 0.05, 0.14), Vector3(0, 0.08, 0)).material_override = Person.mat(Color(0.5, 0.05, 0.14), 0.3, 0.6)
	world.player.pose = "carry"

func _steward_scene() -> void:
	cut(true); _nogoal()
	var st: Person = world.npcs.steward; var groom: Person = world.npcs.groom
	st.face_point(world.player.global_position); world.player.face_point(st.global_position)
	world.cam_look(st.position + Vector3(0, 0.9, 0), 6.5, -26.0)
	await wait(0.8)
	Audio.sfx("pour", -6.0, 1.2)
	st.pose = "carry"; await wait(1.0); st.pose = "amaze"; await wait(1.0); st.pose = "idle"
	world.player.pose = "idle"; if is_instance_valid(cup): cup.queue_free()
	world.cam_follow(st, 7.5, -28.0)
	world.npc_go(st, Vector3(-2.2, 0, 2.3), 2.0)
	await ui.verse("n_j2_9")
	st.face_point(groom.global_position); groom.face_point(st.global_position)
	await ui.line("s_taste", st)
	# the crowd
	Audio.music("feast", -6.0, 1.0)
	Audio.sfx("crowd_cheer", -2.0)
	world.cam_look(Vector3(3.5, 0.8, 1.5), 12.0, -33.0)
	for g in world.guests: if g is Person and g.pose == "idle": g.pose = "cheer"
	await wait(0.6)
	await ui.line("g1", world.npcs.guest0)
	await ui.line("g2", world.npcs.guest1)
	await ui.line("g3", world.npcs.guest2)
	world.npcs.mary.pose = "pray"
	world.cam_look(world.jesus.position + Vector3(0, 1.3, 0), 4.2, -18.0)
	world.jesus.face(Vector3(1, 0, 1))
	await wait(2.5)
	world.npcs.mary.pose = "idle"
	for g in world.guests: if g is Person and g.pose == "cheer" and g.display_name == "" and not (g == world.npcs.dancer1 or g == world.npcs.dancer2): g.pose = "idle"
	await ui.verse("n_j2_11")
	Audio.sfx("complete", -2.0)
	phase = "end"
	Game.delete_save(); stage = ""
	ui.show_end()

func _again() -> void:
	Touch.reset(); Audio.stop_voice(); Game.reset_progress(); Game.delete_save()
	get_tree().paused = false
	get_tree().reload_current_scene()

# ------------------------------------------------------------------ resuming a save
func _stage_goal(st: String) -> Variant:
	match st:
		"naz_start", "naz_return": return world.npcs.naomi.position
		"naz_scroll": return Vector3(-6.6, 0, 6.0)
		"naz_jesus": return world.npcs.jesus.position
		"naz_walk": return Vector3(14.0, 0, 2.2)
		"road": return Vector3(47.5, 0, 0.2)
		"cana_mary": return world.npcs.mary.position
		"cana_draw": return world.pots[2].pos
		"cana_bear": return world.npcs.steward.position
	return null

func _only_triggers(ids: Array) -> void:
	for t in world.triggers: t.active = ids.has(t.id)

func _drop_scroll(key: String) -> void:
	if world.scrolls.has(key): world.scrolls[key].queue_free(); world.scrolls.erase(key)
	world.remove_marker("scroll")

func _resume(d: Dictionary) -> void:
	phase = "resume"; _busy = true
	Game.reset_progress()
	Game.age_stage = str(d.get("age", "adult"))                  # a save from before the age stages is an adult
	Game.player_name = str(d.get("name", Game.player_name)); Game.player_girl = bool(d.get("girl", false))
	for k in d.get("scrolls", []): Game.scrolls[str(k)] = true
	var st: String = d.stage; var info: Dictionary = STAGES[st]
	await ui.fade(1.0, 0.25)
	if info.get("nat", false):
		Game.age_stage = "child"; stage = st; _busy = false
		var np = null
		if d.has("px"): np = Vector3(float(d.px), 0, float(d.pz))
		if np != null: _cp_pos = np
		_cp_yaw = float(d.get("yaw", 0.0)); _save_cd = 15.0
		nat.run(st, not d.get("fresh", false), int(d.get("extra", 0)), np, _cp_yaw)
		return
	match info.area:
		"nazareth": world.build_nazareth()
		"road": world.build_road()
		"cana": world.build_cana()
	world.rebuild_player()
	var pos: Vector3 = world.player.position
	if d.has("px"):
		pos = Vector3(float(d.px), 0, float(d.pz))
		var b: Rect2 = world.bounds
		pos.x = clampf(pos.x, b.position.x + 0.8, b.end.x - 0.8); pos.z = clampf(pos.z, b.position.y + 0.8, b.end.y - 0.8)
		world.player.position = pos; world.player.rotation.y = float(d.get("yaw", 0.0)); world.player.target_yaw = world.player.rotation.y
	world.control = false; world.move_target = null; world.follow_jesus = false
	var follow := false
	var live: Array = []                       # trigger ids that are live at this checkpoint
	match st:
		"naz_start": live = ["naomi"]
		"naz_scroll": live = ["scroll_prov3_5"]
		"naz_return": live = ["naomi_back"]
		"naz_jesus": live = ["jesus"]
		"naz_walk": live = ["exit"]; follow = true
		"road": live = ["exit"]; follow = true
		"cana_mary": live = ["mary"]; follow = true
		"cana_draw": live = []
		"cana_bear": live = ["steward"]
	for key in ["prov3_5", "ps119_105", "ps34_8"]:
		if Game.scrolls.has(key): _drop_scroll(key)
	if info.area == "road" and not Game.scrolls.has("ps119_105"): live.append("scroll_ps119_105")
	if info.area == "cana" and not Game.scrolls.has("ps34_8"): live.append("scroll_ps34_8")
	_only_triggers(live)
	world.follow_jesus = follow
	if world.markers.has("scroll"): world.markers["scroll"].visible = (st != "naz_start")
	if follow and is_instance_valid(world.jesus):
		world.jesus.position = world.player.position + Vector3(-1.4, 0, 0.9); world.jesus.target_yaw = world.player.rotation.y; world.jesus.rotation.y = world.player.rotation.y
	match st:
		"cana_draw", "cana_bear":
			world.pots_wine_now() if st == "cana_bear" else world.pots_fill_now()
			world.jesus.position = Vector3(4.7, 0, -0.5)
			world.jesus.face_point(world.npcs.mary.global_position); world.npcs.mary.face_point(world.jesus.global_position)
	if st == "cana_bear": _give_cup()
	cam_back(info.get("cam", 13.0)); world.cam_snap()
	phase = info.phase; stage = st
	Audio.music({"nazareth": "village", "road": "road", "cana": "feast"}[info.area], -9.0, 0.5)
	ui.update_scrolls()
	if st == "cana_draw":
		world.cam_look(Vector3(5, 0.5, -5.2), 15.0, -38.0); world.cam_snap()
		pot_mode = "draw"; world.add_marker("goal", world.pots[2].pos - Vector3(0, 0.4, 0)); ui.goal = world.pots[2].pos; ui.set_objective(info.text); ui.set_hud(true)
	else:
		var g = _stage_goal(st)
		obj(info.text, g if st != "naz_scroll" else null, g)
		cut(false)
	_cp_pos = pos; _cp_yaw = world.player.rotation.y; _save_cd = 15.0
	_busy = false
	await ui.fade(0.0, 0.7)
	ui.area_card(info.title, "Welcome back")
	ui.toast("Game resumed", 2.5)
