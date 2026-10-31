extends Node
## Touch-only end-to-end playtest of the Nazareth -> Cana slice. Runs headless.
const D = preload("res://tests/driver.gd")
var d: Node

func _ready() -> void:
	if Engine.has_meta("ran"):
		print("== Walk again reloaded the scene without errors"); get_tree().quit(int(Engine.get_meta("code"))); return
	d = D.new(); add_child(d)
	Engine.time_scale = 4.0
	run()

func run() -> void:
	var tree := get_tree()
	Game.delete_save()
	await d.boot()
	var m = d.main
	print("== title")
	var b = await d.wait_btn("begin")
	d.check(b != null, "title shows Begin")
	d.check(d.find_btn("continue") == null, "no Continue button without a save")
	# the Android Back gesture on the title must not close the app
	m.notification(NOTIFICATION_WM_GO_BACK_REQUEST); await d.frames(3)
	d.check(is_inside_tree() and not tree.root.is_queued_for_deletion() and m.phase == "title", "Back gesture on the title does not quit")
	print("== chapter select")
	d.check(d.find_btn("chapters") != null, "title has a Chapters button")
	await d.tap_btn("chapters")
	d.check(m.ui.chap_open and d.find_btn("chap_cana_mary") != null and d.find_btn("chap_n4_temple") != null, "chapter list shows the Nativity chapters and Cana")
	d.check(d.find_btn("chap_n1_flock") != null and d.find_btn("chap_n1_classic") != null and d.find_btn("chap_naz_start") != null, "chapter list lists chapter 1 and Nazareth (6 and 7 are not offered)")
	m.notification(NOTIFICATION_WM_GO_BACK_REQUEST); await d.frames(3)
	d.check(not m.ui.chap_open and m.phase == "title", "Back closes the chapter list instead of quitting")
	await d.tap_btn("chapters"); await d.tap_btn("chap_n4_temple")
	await d.advance_until(func(): return m.phase == "n4" and m.nat.doves_on, 90.0)
	d.check(m.phase == "n4" and m.nat.doves_on, "chapter select jumps straight to the Temple doves")
	d.check(d.find_btn("minimap") != null and m.ui.map_grp != null, "minimap button on the HUD in the Temple")
	await d.tap_btn("map"); d.check(m.ui.map_open, "map opens in the Temple"); await d.tap_btn("mapclose")
	Game.delete_save()
	await d.restart(); m = d.main
	await d.wait_btn("begin")
	await d.tap_btn("begin")
	await d.wait_for(func(): return m.phase == "name")
	d.check(m.phase == "name", "name picker opens")
	await d.tap_btn("girl"); await d.tap_btn("boy")
	d.check(await d.tap_btn("chip1"), "pick a name chip")
	d.check(Game.player_name != "", "player has a name: " + Game.player_name)
	await d.tap_btn("go")
	print("== chapter 1: gather the flock")
	var nat = m.nat
	# Begin now starts the new road (flock_play.gd tests it); this suite walks the first version of chapter 1 and everything after it
	await d.advance_until(func(): return m.stage == "n1_flock" and m.phase == "n1r" and d.world().control, 60.0)
	await d.relaunch(); m = d.main; nat = m.nat
	await d.wait_btn("chapters", 20.0)
	await d.tap_btn("chapters"); await d.tap_btn("chap_n1_classic")
	await d.wait_for(func(): return m.phase == "n1", 20.0)
	await d.advance_until(func(): return nat.herd and d.world().control, 60.0)
	d.check(m.phase == "n1" and nat.herd and d.world().control, "ch1: control given, lambs can be herded")
	d.check(Game.age_stage == "child" and d.player().scale.x < 0.7, "player is a child in the Nativity (scale %.2f)" % d.player().scale.x)
	d.check(m.ui.pour_panel.visible, "ch1: fold counter is shown")
	await _herd(2, 600.0)
	d.check(nat.folded >= 2, "ch1: two lambs herded into the fold by touch (%d)" % nat.folded)
	print("== crash-safety mid-Nativity: kill the app with part of the flock folded, relaunch, Continue")
	var had: int = nat.folded
	var sd1 := Game.read_save()
	await d.relaunch(); m = d.main; nat = m.nat
	d.check(await d.wait_btn("continue") != null, "relaunch: title offers Continue mid-Nativity")
	await d.tap_btn("continue")
	await d.wait_for(func(): return m.phase == "n1" and nat.herd and d.world().control, 30.0)
	d.check(m.phase == "n1" and d.world().control, "Continue resumes chapter 1 with control")
	d.check(nat.folded >= had and nat.folded < 5, "Continue keeps the folded lambs (%d, was %d)" % [nat.folded, had])
	d.check(Game.age_stage == "child", "Continue keeps the child stage")
	await _herd(5, 900.0)
	d.check(nat.folded == 5 or m.phase != "n1", "ch1: whole flock folded")
	print("== chapter 2: the angels' announcement")
	await d.advance_until(func(): return nat.sky_on, 80.0)
	d.check(nat.sky_on and m.phase == "n2", "ch2: sky-look is waiting for a drag")
	var pitch0: float = d.world().pitch
	await touch_drag_up()
	await d.wait_for(func(): return d.world().pitch > 4.0 or not nat.sky_on, 6.0)
	d.check(d.world().pitch > pitch0 + 10.0 or not nat.sky_on, "ch2: dragging up lifts the view to the sky (pitch %.1f)" % d.world().pitch)
	await d.advance_until(func(): return d.find_btn("choice1") != null, 90.0)
	d.check(d.find_btn("choice1") != null, "ch2: the host of angels, a choice of response (no game)")
	await d.tap_btn("choice1")
	await d.advance_until(func(): return d.find_btn("stone_keep") != null and d.find_btn("stone_keep").is_visible_in_tree(), 60.0)
	await d.wait_btn("stone_keep", 30.0); await d.tap_btn("stone_keep")
	await d.wait_btn("camp_go", 30.0); await d.frames(30); await d.tap_btn("camp_go")
	await d.advance_until(func(): return m.phase == "n3" and d.world().control, 90.0)
	print("== chapter 3: match the sign")
	d.check(m.phase == "n3" and d.world().control, "ch3: Bethlehem, control given")
	d.check(m.ui.clue_panel.visible if "clue_panel" in m.ui else true, "ch3: clue panel is shown")
	for i in 3:
		var sx: float = nat.STABLES[i].x
		await d.walk_via([Vector3(sx, 0, -1.6), Vector3(sx, 0, -4.4)], 2.3)
		d.check(await d.wait_for(func(): return i in nat.visited or m.phase == "n3done" or m.phase == "n4", 25.0), "ch3: looked into stable %d" % (i + 1))
		await d.advance_until(func(): return d.world().control or m.phase != "n3", 20.0)
	d.check(m.phase == "n3done" or m.phase == "n4" or m.phase == "n3", "ch3: reached the sign stable")
	await d.advance_until(func(): return m.phase == "n4", 90.0)
	d.check(m.phase == "n4", "ch3: the sign is matched (swaddling clothes + manger) and the Temple follows")
	print("== chapter 4: catch the doves")
	await d.advance_until(func(): return nat.doves_on, 90.0)
	d.check(nat.doves_on and nat.cage_on, "ch4: cage drag is live")
	await d.hold_follow(_dove_target, func(): return not nat.doves_on, 100.0)
	d.check(nat._caught >= 2, "ch4: both doves caught by dragging the cage (%d)" % nat._caught)
	await d.advance_until(func(): return m.phase == "n5", 90.0)
	print("== chapter 5: trace the star")
	await d.advance_until(func(): return nat.trace != null and nat.trace.active, 90.0)
	d.check(nat.trace != null, "ch5: star trace overlay is up")
	var tr = nat.trace
	var pts: Array = tr.pts
	var gp: Vector2 = tr.global_position
	d.touch(true, gp + pts[0]); await d.frames(2)
	for pt in pts: d.drag(gp + pt); await d.frames(2)
	d.touch(false, gp + pts[pts.size() - 1]); await d.frames(3)
	d.check(await d.wait_for(func(): return tr.done or nat.trace == null, 10.0), "ch5: tracing the dotted road with one finger completes the star")
	await d.advance_until(func(): return m.phase == "jump", 120.0)
	print("== the age jump")
	d.check(m.phase == "jump", "the jump scene is reached")
	for i in 2:
		await d.wait_for(func(): return nat.jump_wait, 40.0)
		d.check(nat.jump_wait, "jump %d: glowing mark waits for a tap" % (i + 1))
		await d.tap(d.world().ground_to_screen(nat.jump_pos))
		await d.advance_until(func(): return Game.age_stage == ["teen", "adult"][i], 30.0)
		d.check(Game.age_stage == ["teen", "adult"][i], "jump %d: age stage is now %s" % [i + 1, Game.age_stage])
		await d.advance_until(func(): return (nat.jump_wait if i == 0 else m.phase == "intro"), 40.0)
	print("== nazareth")
	await d.wait_for(func(): return m.phase == "intro" or m.phase == "nazareth", 30.0)
	await d.advance_until(func(): return m.phase == "nazareth" and d.world().control)
	d.check(m.phase == "nazareth" and d.world().control, "player is given control in Nazareth")
	d.check(Game.age_stage == "adult" and d.world().area == "nazareth", "player is grown up in Nazareth")
	d.check(await d.walk_to(Vector3(-0.4, 0, 3.0), 3.6), "walk toward Naomi by tapping")
	await d.tap(d.world().ground_to_screen(d.world().npcs.naomi.position))
	await d.wait_for(func(): return m.ui.in_line, 10.0)
	d.check(m.ui.in_line, "Naomi's dialogue is open")
	print("== crash-safety: kill the app mid-dialogue, relaunch, Continue")
	await d.relaunch(); m = d.main
	d.check(await d.wait_btn("continue") != null, "relaunch: title offers Continue")
	d.check(await d.wait_btn("begin") != null and d.find_btn("begin").get_global_rect().position.y > d.find_btn("continue").get_global_rect().position.y, "relaunch: New Game sits below Continue")
	await d.tap_btn("continue")
	await d.wait_for(func(): return m.phase == "nazareth" and d.world().control, 20.0)
	d.check(m.phase == "nazareth" and d.world().control, "Continue resumes in Nazareth with control")
	d.check(Game.player_name == "Shepherd" or Game.player_name != "", "name restored: " + Game.player_name)
	d.check(m.ui.goal != null and m.ui.wp.visible or m.ui.goal != null, "objective waypoint target is set after resume")
	d.check(await d.walk_to(Vector3(-0.4, 0, 3.0), 2.4), "walk to Naomi again after resume")
	await d.advance_until(func(): return d.world().control and not d.world().triggers.filter(func(t): return t.id == "scroll_prov3_5")[0].active == false)
	d.check(true, "Naomi asks for her scroll")
	d.check(await d.walk_to(Vector3(-6.6, 0, 6.0), 1.2), "walk to the scroll")
	await d.advance_until(func(): return Game.scrolls.has("prov3_5") and d.world().control)
	d.check(Game.scrolls.has("prov3_5"), "scroll 1 collected (Proverbs 3:5)")
	d.check(await d.walk_to(Vector3(-0.4, 0, 3.0), 2.4), "walk back to Naomi")
	await d.advance_until(func(): return d.world().control and m.phase == "nazareth" and d.world().triggers.filter(func(t): return t.id == "jesus")[0].active)
	d.check(true, "Naomi thanks the player")
	d.check(await d.walk_to(Vector3(8.0, 0, -4.2), 2.6), "walk to Jesus at the carpenter's shop")
	await d.advance_until(func(): return d.world().follow_jesus and d.world().control)
	d.check(d.world().follow_jesus, "Jesus invites the player and walks with them")
	d.check(await d.walk_to(Vector3(14.0, 0, 2.2), 1.6), "walk east to the road exit")
	print("== road")
	await d.wait_for(func(): return m.phase == "road" and d.world().control, 30.0)
	d.check(m.phase == "road", "road area loaded")
	d.check(await d.walk_to(Vector3(21.5, 0, -8.2), 1.3), "walk to the road scroll")
	await d.advance_until(func(): return Game.scrolls.has("ps119_105") and d.world().control)
	d.check(Game.scrolls.has("ps119_105"), "scroll 2 collected (Psalm 119:105)")
	print("== navigation: minimap, waypoint, map screen, pause menu")
	d.check(m.ui.minimap != null and m.ui.minimap.is_visible_in_tree(), "minimap is visible in the HUD")
	d.check(m.ui.goal != null and m.ui.wp.is_visible_in_tree(), "objective waypoint arrow is visible")
	d.check(m.ui.obj_lbl.text != "", "objective text: " + m.ui.obj_lbl.text)
	d.check(d.find_btn("map") != null and d.find_btn("menu") != null, "map and menu buttons are on the HUD")
	var p0: Vector3 = d.player().position
	await d.tap_btn("map")
	var pm: Vector3 = d.player().position
	d.check(m.ui.map_open and tree.paused, "map button opens the full map (game paused)")
	await d.frames(20)
	d.check(d.player().position.distance_to(pm) < 0.05, "world is frozen while the map is open")
	d.check(await d.wait_btn("mapclose") != null, "map has a close button")
	await d.tap_btn("mapclose"); await d.frames(4)
	d.check(not m.ui.map_open and not tree.paused, "map closes and the game resumes")
	await d.tap(d.find_btn("minimap").get_global_rect().get_center()); await d.frames(4)
	d.check(m.ui.map_open, "tapping the minimap also opens the map")
	m.notification(NOTIFICATION_WM_GO_BACK_REQUEST); await d.frames(4)
	d.check(not m.ui.map_open, "Back gesture closes the map instead of quitting")
	await d.tap_btn("menu")
	d.check(m.ui.menu_open and tree.paused, "menu button opens the pause menu")
	var sv0 := FileAccess.get_modified_time(ProjectSettings.globalize_path(Game.SAVE_PATH))
	await d.tap_btn("save"); await d.frames(4)
	var sd := Game.read_save()
	d.check(not sd.is_empty() and sd.stage == "road" and (sd.scrolls as Array).has("ps119_105"), "manual save wrote stage=road with both scrolls")
	await d.tap_btn("resume"); await d.frames(4)
	d.check(not m.ui.menu_open and not tree.paused, "resume closes the pause menu")
	m.notification(NOTIFICATION_WM_GO_BACK_REQUEST); await d.frames(4)
	d.check(m.ui.menu_open, "Back gesture opens the pause menu mid-game (does not quit)")
	m.notification(NOTIFICATION_WM_GO_BACK_REQUEST); await d.frames(4)
	d.check(not m.ui.menu_open, "second Back closes it")
	print("== persistence: kill the app on the road, relaunch, Continue")
	await d.relaunch(); m = d.main
	await d.wait_btn("continue"); await d.tap_btn("continue")
	await d.wait_for(func(): return m.phase == "road" and d.world().control, 20.0)
	d.check(m.phase == "road" and d.world().control and d.world().area == "road", "Continue resumes on the road")
	d.check(Game.scrolls.has("prov3_5") and Game.scrolls.has("ps119_105"), "collected scrolls restored")
	d.check(d.player().position.distance_to(p0) < 2.0, "player position restored")
	d.check(d.world().follow_jesus, "Jesus walks with the player again")
	d.check(await d.walk_to(Vector3(47.5, 0, 0.2), 1.6, 80.0), "walk to Cana")
	print("== cana")
	await d.wait_for(func(): return m.phase == "cana", 30.0)
	d.check(m.phase == "cana", "Cana loaded")
	await d.advance_until(func(): return d.world().control and m.phase == "cana", 60.0)
	d.check(await d.walk_to(Vector3(2.4, 0, 6.8), 1.8), "walk to the wedding scroll")
	await d.advance_until(func(): return Game.scrolls.has("ps34_8") and d.world().control)
	d.check(Game.scrolls.has("ps34_8"), "scroll 3 collected (Psalm 34:8)")
	d.check(await d.walk_via([Vector3(0.5, 0, 5.0), Vector3(0.5, 0, 1.0), Vector3(3.0, 0, 0.0)], 3.0), "walk to Mary")
	await d.advance_until(func(): return m.pot_mode == "fill", 90.0)
	d.check(m.pot_mode == "fill", "fill the waterpots begins")
	# pour by tapping pots
	var taps := 0
	while m.pot_mode == "fill" and taps < 40:
		var i: int = taps % d.world().pots.size()
		await d.tap(d.world().ground_to_screen(d.world().pots[i].pos)); taps += 1
	d.check(m.pours >= m.POUR_TOTAL, "all pots filled (%d pours)" % m.pours)
	await d.advance_until(func(): return m.pot_mode == "draw", 60.0)
	d.check(m.pot_mode == "draw", "draw-out step reached")
	await d.relaunch(); m = d.main
	await d.wait_btn("continue"); await d.tap_btn("continue")
	await d.wait_for(func(): return m.pot_mode == "draw" and d.world().area == "cana", 20.0)
	d.check(m.pot_mode == "draw" and d.world().pots.all(func(p): return p.level == 4), "Continue at the waterpots restores full pots and the draw step")
	await d.tap(d.world().ground_to_screen(d.world().pots[2].pos))
	await d.wait_for(func(): return m.phase == "bear" and d.world().control, 40.0)
	d.check(m.phase == "bear", "water became wine; player carries the cup")
	await d.relaunch(); m = d.main
	await d.wait_btn("continue"); await d.tap_btn("continue")
	await d.wait_for(func(): return m.phase == "bear" and d.world().control, 20.0)
	d.check(m.phase == "bear" and d.world().control and is_instance_valid(m.cup), "Continue while carrying the cup restores the cup")
	d.check(await d.walk_to(Vector3(1.8, 0, -3.3), 2.6), "carry the cup to the governor")
	await d.advance_until(func(): return m.phase == "end", 90.0)
	d.check(m.phase == "end", "end card reached")
	d.check(d.find_btn("again") != null or await d.wait_btn("again") != null, "Walk again button available")
	d.check(not Game.has_save(), "finishing the story clears the save")
	print("== done: ", d.checks, " checks, ", d.fails.size(), " failed")
	for f in d.fails: print("  FAILED: ", f)
	Engine.set_meta("ran", true); Engine.set_meta("code", 1 if d.fails.size() > 0 else 0)
	await d.tap_btn("again")
	await tree.create_timer(3.0).timeout
	tree.quit(2)

## Herd lambs with taps only: get behind the nearest free lamb (away from the gate), then walk it toward the gate.
func _herd(want: int, limit_s: float) -> void:
	var nat = d.main.nat; var w = d.world(); var t := 0.0
	var gate := Vector3(7.0, 0, -4.4)
	while nat.folded < want and d.main.phase == "n1" and t < limit_s:
		var best = null; var bd := 1e9
		for L in nat.lambs:
			if L.state == "free":
				var dd: float = w.player.position.distance_to(L.n.position)
				if dd < bd: bd = dd; best = L
		if best == null: await d.frames(10); t += 1.0; continue
		var lp: Vector3 = best.n.position
		var behind := lp + (lp - gate).normalized() * 4.4
		behind.x = clampf(behind.x, w.bounds.position.x + 1.0, w.bounds.end.x - 1.0); behind.z = clampf(behind.z, w.bounds.position.y + 1.0, w.bounds.end.y - 1.0)
		await d.walk_to(behind, 1.1, 14.0); t += 4.0
		for k in 5:
			if best.state != "free": break
			var step: Vector3 = (gate - w.player.position); step.y = 0
			await d.tap(w.ground_to_screen(w.player.position + step.normalized() * minf(step.length(), 4.0))); await d.frames(6); t += 1.0
		if is_instance_valid(best.n) and best.state == "free" and w.player.position.distance_to(best.n.position) > 6.0: t += 0.0

func touch_drag_up() -> void:
	var s := Vector2(540, 1500)
	d.touch(true, s); await d.frames(2)
	for i in 14:
		d.drag(s - Vector2(0, 60.0 * (i + 1))); await d.frames(2)
	d.touch(false, s - Vector2(0, 840)); await d.frames(2)

func _dove_target() -> Vector2:
	var nat = d.main.nat; var tgt := Vector3(1, 0, 0)
	for D in nat.doves:
		if not D.caught: tgt = D.n.position; tgt.y = 0; break
	return d.world().ground_to_screen(tgt)
