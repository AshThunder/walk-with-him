extends "res://tests/shots.gd"
## Lead the Flock: touch-only playtest AND screenshot tour of the new slice (road, angels, Memory Stone, camp, Road of the Day, save, Back).
## Headless:  godot --headless --path . res://tests/flock_play.tscn        With screenshots:  xvfb-run godot --path . res://tests/flock_play.tscn --resolution 1080x1920
var shots_on := false
var road_stats := {}

func _ready() -> void:
	shots_on = DisplayServer.get_name() != "headless"
	Engine.time_scale = 2.0 if shots_on else 4.0
	await boot()
	if Engine.has_meta("flock_after"): after_daily()
	else: run()

func fl() -> Flock: return main.nat.fl
func finish_run() -> void:
	tour_done = true
	print("== done: ", checks, " checks, ", fails.size(), " failed")
	for f in fails: print("  FAILED: ", f)
	get_tree().quit(1 if fails.size() > 0 else 0)

## Lead the road with one finger (the floating stick, index 1) and staff taps (index 0). Strays near the path are recruited, wolves are driven off.
func drive(timeout_s: float, tag := "") -> void:
	var f := fl(); var w := world()
	var s := Vector2(540, 1400)
	touch(true, s, 1); await frames(1)
	var t := 0.0; var tap_cd := 0.0; var snap := 0; var stuck := 0.0; var last := f.pp; var tapped := 0
	while t < timeout_s and f.mode == "road" and not f.arrived():
		var pp: Vector2 = f.pp
		var tgt := Vector2(Roads.road_x(f.lay, pp.y - 5.0), pp.y - 5.0)
		var best = null; var bd := 7.5
		for l in f.lambs:
			if l.state == Flock.S.STRAY:
				var dd: float = l.p.distance_to(pp)
				if dd < bd and absf(l.p.x - Roads.road_x(f.lay, l.p.y)) < 7.5 and l.p.y < pp.y + 3.0: bd = dd; best = l
		if best != null and stuck < 1.2: tgt = best.p
		var dir: Vector2 = tgt - pp
		if stuck > 1.2: dir = Vector2(Roads.road_x(f.lay, pp.y - 3.0) - pp.x, -3.0).rotated(0.9 if int(t) % 2 == 0 else -0.9)
		dir = dir.normalized()
		drag(s + dir * 110.0, 1)
		tap_cd -= get_process_delta_time() * 2.0
		if tap_cd <= 0.0:
			for wf in f.wolves:
				if (wf.state == Flock.W.STALK or wf.state == Flock.W.PAUSE) and wf.p.distance_to(pp) < 9.0:
					await tap(w.ground_to_screen(Vector3(wf.p.x, 0, wf.p.y))); tap_cd = 0.8; tapped += 1; break
		await frames(2); var dt := get_process_delta_time() * 2.0; t += dt
		if pp.distance_to(last) < 0.25: stuck += dt
		else: stuck = 0.0; last = pp
		if tag != "" and snap == 0 and t > 7.0: snap = 1; await shot(tag + "_mid")
		if tag != "" and snap == 1 and f.nf >= 24: snap = 2; await shot(tag + "_big_flock")
	touch(false, s, 1); await frames(2)
	road_stats = {"t": t, "tapped": tapped}

func to_title_and_play(daily := false) -> void:
	await wait_btn("daily" if daily else "begin")
	if daily: await tap_btn("daily")
	else:
		await tap_btn("begin"); await wait_btn("go"); await tap_btn("go")

func run() -> void:
	watcher()
	Game.delete_save()
	Game.reset_meta()
	print("== title")
	await wait_btn("begin"); await sec(1.5)
	check(find_btn("daily") != null, "title offers the Road of the Day")
	await shot("f00_title")
	await tap_btn("chapters"); await sec(0.5)
	check(find_btn("chap_n1_classic") != null and find_btn("chap_n1_flock") != null, "chapter list has the new road and the first version of chapter 1")
	await shot("f00b_chapters"); await tap_btn("chap_close")
	print("== chapter 1: the road")
	await tap_btn("begin"); await wait_btn("go"); await tap_btn("go")
	await adv(func(): return main.nat.fl != null and main.nat.fl.mode == "road" and world().control, 120.0)
	var f := fl()
	check(f.mode == "road" and world().control, "the road begins in the player's hands")
	check(main.stage == "n1_flock" and Game.read_save().get("stage", "") == "n1_flock", "road start is a checkpoint and autosaved")
	await frames(4)
	check(f.nf == 12, "the flock starts with twelve named lambs (%d)" % f.nf)
	check(Game.roster.size() >= 0, "meta loaded")
	await sec(1.2); await shot("f01_road_start")
	# the stick moves the player and responds quickly
	var p0 := f.pp
	var s := Vector2(540, 1400)
	touch(true, s, 1); await frames(1); drag(s + Vector2(0, -110), 1)
	var resp := 0.0
	while f.pp.distance_to(p0) < 0.15 and resp < 1.0: await frames(1); resp += get_process_delta_time() * 1.0
	check(f.pp.distance_to(p0) >= 0.15 and resp < 0.35, "thumb-drag moves the shepherd within 0.35 s (%.2f s)" % resp)
	touch(false, s, 1); await frames(2)
	# the staff
	touch(true, Vector2(540, 800)); await frames(1); touch(false, Vector2(540, 800)); await frames(1)
	check(f.staff_cd > 0.0, "a tap swings the staff")
	await drive(120.0, "f02_road")
	check(f.arrived(), "the road can be walked to the fire with touch only (%.0f s, %d staff taps)" % [road_stats.t, road_stats.tapped])
	check(f.nf > 12, "the flock grew on the way (%d)" % f.nf)
	await sec(0.5)
	var nf_end := f.nf
	await adv(func(): return find_btn("road_continue") != null, 90.0)
	await sec(1.0); await shot("f03_arrival_card")
	check(find_btn("road_continue") != null, "arrival shows what came to the fire, no fail screen")
	check(not ("score" in str(f.res).to_lower()), "no score is shown")
	await tap_btn("road_continue")
	await wait_btn("stone_keep", 30.0)
	check(Game.stones.size() == 1 and Game.stones[0].id == "n_ps23_1", "the first Memory Stone (Psalm 23:1) is kept")
	check(Game.roster.size() >= f.nf - 1, "the flock's names are remembered (%d)" % Game.roster.size())
	check(Game.journal.size() == 1, "a journal page was written")
	await sec(1.0); await shot("f04_memory_stone")
	await tap_btn("stone_keep")
	await wait_btn("camp_go", 30.0); await sec(1.0)
	await shot("f05_camp_flock")
	check(find_btn("wool_gold") != null and find_btn("wool_rose") == null, "wool: gold unlocked by one stone, rose still locked")
	await tap_btn("wool_gold")
	check(Game.tint == "gold", "choosing gold wool sticks")
	await sec(0.6); await shot("f05b_camp_gold")
	await tap_btn("camp_tab1"); await sec(0.6); await shot("f06_camp_journal")
	await tap_btn("camp_go")
	print("== chapter 2: the angels")
	await adv(func(): return main.nat.sky_on, 120.0)
	check(main.phase == "n2" and not world().control, "the angels chapter begins (no controls to fail with)")
	await sec(1.0); await shot("f07_sky_before")
	var s2 := Vector2(540, 1500)
	touch(true, s2); await frames(2)
	for i in 14: drag(s2 - Vector2(0, 60.0 * (i + 1))); await frames(2)
	touch(false, s2 - Vector2(0, 840)); await frames(2)
	await sec(3.0); await shot("f08_glory")
	check(true, "looking up reveals the glory")
	await adv(func(): return find_btn("choice1") != null, 90.0)
	await sec(2.0); await shot("f09_glory_choice")
	await tap_btn("choice1"); await sec(4.0)
	await wait_btn("stone_keep", 30.0)
	check(Game.stones.size() == 2 and Game.stones[1].id == "n_stone_lk2_11", "the second Memory Stone (Luke 2:11) is kept")
	await sec(1.0); await shot("f10_stone_luke")
	await tap_btn("stone_keep")
	await wait_btn("camp_go", 30.0); await sec(0.8)
	check(find_btn("wool_rose") != null, "two stones unlock rose wool")
	await shot("f11_camp_after_angels")
	await tap_btn("camp_go")
	await adv(func(): return main.phase == "n3" and world().control, 120.0)
	check(main.phase == "n3" and main.stage == "n3_town", "the story goes on to Bethlehem")
	print("== save, relaunch and the meta")
	var roster_n := Game.roster.size()
	await relaunch()
	await wait_btn("continue")
	check(find_btn("continue") != null, "after a relaunch Continue is offered")
	check(Game.roster.size() == roster_n and Game.stones.size() == 2 and Game.tint == "gold", "flock, stones and wool survive a relaunch (%d lambs)" % Game.roster.size())
	await tap_btn("continue")
	await adv(func(): return main.phase == "n3" and world().control, 120.0)
	check(main.phase == "n3", "Continue resumes at Bethlehem")
	print("== Road of the Day")
	var saved_stage: String = Game.read_save().get("stage", "")
	await restart()
	await wait_btn("daily"); await tap_btn("daily")
	await adv(func(): return main.nat.fl != null and main.nat.fl.mode == "road" and world().control, 120.0)
	f = fl(); await frames(4)
	check(main.stage == "daily" and f.mode == "road", "the Road of the Day starts")
	check(f.nf == clampi(Game.roster.size(), 8, 20), "the daily starts with the named flock (%d of roster %d, cfg %s)" % [f.nf, Game.roster.size(), str(f.cfg.get("start"))])
	await sec(1.0); await shot("f12_daily_start")
	# Back opens the pause menu and the game is paused
	main.notification(NOTIFICATION_WM_GO_BACK_REQUEST); await frames(3)
	check(main.ui.menu_open and get_tree().paused, "Back mid-road opens the pause menu and pauses")
	var t_a: float = f.t; await frames(10)
	check(is_equal_approx(f.t, t_a), "the flock is frozen while paused")
	await shot("f13_back_pause")
	main.notification(NOTIFICATION_WM_GO_BACK_REQUEST); await frames(3)
	check(not main.ui.menu_open and not get_tree().paused, "Back again resumes")
	await drive(120.0, "f14_daily")
	check(f.arrived(), "the Road of the Day can be walked with touch only (%.0f s)" % road_stats.t)
	await adv(func(): return find_btn("road_continue") != null, 90.0)
	await tap_btn("road_continue")
	await wait_btn("camp_go", 30.0); await sec(0.5)
	check(Game.read_save().get("stage", "") == saved_stage, "the daily never overwrites the story save")
	Engine.set_meta("flock_after", true); Engine.set_meta("flock_fails", fails.duplicate()); Engine.set_meta("flock_checks", checks)
	await tap_btn("camp_go")                      # returns to the title by reloading the scene, which restarts this script: it continues in after_daily()
	await sec(5.0)
	check(false, "the daily did not return to the title")
	finish_run()

func after_daily() -> void:
	watcher()
	fails = Engine.get_meta("flock_fails"); checks = int(Engine.get_meta("flock_checks"))
	await wait_btn("daily", 20.0)
	check(Game.daily_done == Game.today() and Game.daily_total == 1, "the day is marked done (no streak is kept)")
	check(find_btn("continue") != null and Game.read_save().get("stage", "") == "n3_town", "back on the title, Continue still points at the story")
	await sec(0.5); await shot("f15_title_after_daily")
	print("== the first version of chapter 1 is still reachable")
	await tap_btn("chapters"); await tap_btn("chap_n1_classic")
	await adv(func(): return main.phase == "n1" and main.nat.herd and world().control, 120.0)
	check(main.phase == "n1" and main.nat.herd, "the old gather-the-lambs chapter is still playable from Chapters")
	finish_run()
