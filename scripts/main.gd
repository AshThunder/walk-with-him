extends Node
## Story flow for the Nazareth -> Cana slice (John 2:1-11).
var world: World
var ui: UI
var phase := "boot"
var pot_mode := ""            # "" | "fill" | "draw"
var pours := 0
var POUR_TOTAL := 24
var cup: Node3D
var _busy := false

func _ready() -> void:
	world = World.new(); add_child(world)
	ui = UI.new(); add_child(ui)
	world.trigger_hit.connect(_on_trigger)
	Touch.world_tap.connect(_on_world_tap)
	ui.begin_pressed.connect(func(): _begin_flag = true)
	ui.name_chosen.connect(func(): _name_flag = true)
	ui.again_pressed.connect(_again)
	Game.reset_progress()
	_title()

var _begin_flag := false
var _name_flag := false

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func cut(on: bool) -> void:
	world.control = not on
	if on: world.move_target = null
	ui.set_hud(not on)

func obj(text: String, marker_pos = null) -> void:
	ui.set_objective(text); world.remove_marker("goal")
	if marker_pos != null: world.add_marker("goal", marker_pos)

func cam_back(size := 13.0) -> void:
	world.cam_follow(world.player, size, -35.0)

# ------------------------------------------------------------------ title and name
func _title() -> void:
	phase = "title"
	world.build_nazareth(); world.control = false
	world.markers["scroll"].visible = false
	world.cam_look(Vector3(3, 0, 1), 15.0, -33.0); world.cam_snap()
	Audio.music("village", -8.0, 0.1)
	ui.show_title(true); ui.fade_rect.color.a = 1.0
	await ui.fade(0.0, 1.0)
	while not _begin_flag: await get_tree().process_frame
	Audio.sfx("select", -3.0)
	ui.show_title(false); ui.show_name(true); phase = "name"
	while not _name_flag: await get_tree().process_frame
	Audio.sfx("select", -3.0)
	ui.show_name(false); _intro()

func _intro() -> void:
	phase = "intro"
	world.rebuild_player(); cam_back(11.0); world.cam_snap()
	ui.area_card("Nazareth", "Galilee")
	await wait(1.2)
	await ui.verse("n_lk4_16")
	world.cam_follow(world.player, 13.0)
	phase = "nazareth"
	obj("Look for Naomi near the well", world.npcs.naomi.position)
	ui.update_scrolls(); cut(false)
	ui.toast("Tap the ground to walk, or drag to steer", 6.0)
	world.set_trigger("jesus", false)

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

func _pickup(key: String) -> void:
	cut(true)
	Audio.sfx("pickup", -2.0)
	world.remove_marker("scroll")
	if world.scrolls.has(key): world.scrolls[key].queue_free(); world.scrolls.erase(key)
	Game.scrolls[key] = true
	ui.update_scrolls()
	await ui.verse("n_" + key)
	cut(false)

func _naomi_ask() -> void:
	cut(true); world.remove_marker("goal")
	var n: Person = world.npcs.naomi
	world.player.face_point(n.global_position); n.face_point(world.player.global_position)
	world.cam_look((n.position + world.player.position) * 0.5 + Vector3(0, 0.8, 0), 6.5, -26.0)
	await ui.line("naomi_ask", n)
	cam_back()
	world.markers["scroll"].visible = true
	world.set_trigger("scroll_prov3_5", true)
	obj("Find Naomi's scroll by the olive tree")
	cut(false)

func _after_scroll1() -> void:
	obj("Take the scroll back to Naomi", world.npcs.naomi.position)
	world.set_trigger("naomi_back", true)

func _naomi_thanks() -> void:
	cut(true); world.remove_marker("goal")
	var n: Person = world.npcs.naomi
	world.player.face_point(n.global_position); n.face_point(world.player.global_position)
	world.cam_look((n.position + world.player.position) * 0.5 + Vector3(0, 0.8, 0), 6.5, -26.0)
	await ui.line("naomi_thanks", n)
	cam_back()
	obj("Go and see Jesus at the carpenter's shop", world.npcs.jesus.position)
	world.set_trigger("jesus", true)
	cut(false)

func _jesus_invite() -> void:
	cut(true); world.remove_marker("goal")
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

func _leave_area() -> void:
	cut(true); world.remove_marker("goal"); world.follow_jesus = false
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
		ui.toast("A wedding scroll lies by the long table", 4.0)

# ------------------------------------------------------------------ the miracle
func _mary_scene() -> void:
	cut(true); world.remove_marker("goal"); world.follow_jesus = false
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
	world.add_marker("goal", world.pots[2].pos - Vector3(0, 0.4, 0))
	ui.set_objective("Draw some out: tap a waterpot")
	ui.set_hud(true); pot_mode = "draw"
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
		world.player.pose = "carry"; get_tree().create_timer(0.7).timeout.connect(func(): if pot_mode != "draw": world.player.pose = "idle")

func _on_world_tap(sp: Vector2) -> void:
	if pot_mode == "": return
	var i := world.pick_pot(sp)
	if i < 0 or world.ground_to_screen(world.pots[i].pos).distance_to(sp) > 190.0: return
	if pot_mode == "fill": _pour(i, false)
	elif pot_mode == "draw": pot_mode = ""; _miracle(i)

func _miracle(_i: int) -> void:
	world.remove_marker("goal"); world.control = false; ui.set_hud(false)
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
	cup = Person.mk(world.player, Person.cyl(0.09, 0.06, 0.16, 8), Color(0.78, 0.62, 0.3), Vector3(0.0, 0.95, -0.42))
	Person.mk(cup, Person.cyl(0.08, 0.08, 0.02, 8), Color(0.5, 0.05, 0.14), Vector3(0, 0.08, 0)).material_override = Person.mat(Color(0.5, 0.05, 0.14), 0.3, 0.6)
	world.player.pose = "carry"
	await wait(0.6)
	cam_back(); world.set_trigger("steward", true)
	obj("Bear the cup to the governor of the feast", world.npcs.steward.position)
	cut(false)
	phase = "bear"

func _steward_scene() -> void:
	cut(true); world.remove_marker("goal")
	var st: Person = world.npcs.steward; var groom: Person = world.npcs.groom
	st.face_point(world.player.global_position); world.player.face_point(st.global_position)
	world.cam_look(st.position + Vector3(0, 0.9, 0), 6.5, -26.0)
	await wait(0.8)
	Audio.sfx("pour", -6.0, 1.2)
	st.pose = "carry"; await wait(1.0); st.pose = "amaze"; await wait(1.0); st.pose = "idle"
	world.player.pose = "idle"; if cup: cup.queue_free()
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
	ui.show_end()

func _again() -> void:
	Touch.reset(); Audio.stop_voice(); Game.reset_progress()
	get_tree().reload_current_scene()
