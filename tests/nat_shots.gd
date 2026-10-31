extends "res://tests/shots.gd"
## Nativity screenshot tour (needs a real display, e.g. xvfb-run):  godot --path . res://tests/nat_shots.tscn --resolution 1080x1920
## Every chapter is entered through the chapter list, then played with touches only.

func go(id: String) -> void:
	await restart()
	await wait_btn("chapters"); await tap_btn("chapters"); await tap_btn("chap_" + id)

func herd(want: int) -> void:
	var nat = main.nat; var w = world(); var gate := Vector3(7.0, 0, -4.4); var it := 0
	while nat.folded < want and main.phase == "n1" and it < 90:
		it += 1
		var best = null; var bd := 1e9
		for L in nat.lambs:
			if L.state == "free":
				var dd: float = w.player.position.distance_to(L.n.position)
				if dd < bd: bd = dd; best = L
		if best == null: await frames(10); continue
		var lp: Vector3 = best.n.position
		var behind := lp + (lp - gate).normalized() * 4.4
		behind.x = clampf(behind.x, w.bounds.position.x + 1.0, w.bounds.end.x - 1.0); behind.z = clampf(behind.z, w.bounds.position.y + 1.0, w.bounds.end.y - 1.0)
		await walk_to(behind, 1.1, 14.0)
		for k in 5:
			if best.state != "free": break
			var step: Vector3 = (gate - w.player.position); step.y = 0
			await tap(w.ground_to_screen(w.player.position + step.normalized() * minf(step.length(), 4.0))); await frames(6)

func run() -> void:
	watcher()
	var nat
	await wait_btn("begin"); await sec(2.0); await shot("n00_title")
	await tap_btn("chapters"); await sec(0.6); await shot("n00b_chapter_list"); await tap_btn("chap_close")
	# ---- 1
	await go("n1_flock"); nat = main.nat
	await adv(func(): return nat.herd and world().control, 90.0)
	await sec(1.0); await shot("n01a_flock_start")
	await herd(2)
	await shot("n01b_flock_two_folded")
	await map_shot("n01c_map_fields")
	# ---- 2
	await go("n2_sky"); nat = main.nat
	await adv(func(): return nat.sky_on, 90.0)
	await sec(1.0); await shot("n02a_sky_before")
	var s := Vector2(540, 1500)
	touch(true, s); await frames(2)
	for i in 6: drag(s - Vector2(0, 40.0 * (i + 1))); await frames(2)
	await shot("n02b_sky_midlook")
	for i in 8: drag(s - Vector2(0, 240.0 + 60.0 * (i + 1))); await frames(2)
	touch(false, s - Vector2(0, 700)); await frames(2)
	await sec(2.0); await shot("n02c_sky_revealed")
	await adv(func(): return find_btn("choice1") != null, 90.0)
	await sec(1.5); await shot("n02d_sky_host_choice")
	await tap_btn("choice0"); await sec(2.0); await shot("n02e_sky_kneel")
	# ---- 3
	await go("n3_town"); nat = main.nat
	await adv(func(): return main.phase == "n3" and world().control, 90.0)
	await sec(0.8); await shot("n03a_town_start")
	await map_shot("n03b_map_town")
	await walk_via([Vector3(-8.5, 0, -1.6), Vector3(-8.5, 0, -4.4)], 2.3)
	await wait_for(func(): return ui().toast_lbl.text != "" if "toast_lbl" in ui() else true, 5.0)
	await sec(1.8); await shot("n03c_stable0_peek")
	await adv(func(): return world().control, 30.0)
	await walk_via([Vector3(7.2, 0, -1.6), Vector3(7.2, 0, -4.4)], 2.3)
	await sec(1.8); await shot("n03d_stable2_found_a")
	await sec(4.0); await shot("n03e_stable2_found_b")
	# ---- 4
	await go("n4_temple"); nat = main.nat
	await sec(3.5); await shot("n04a_temple_start")
	await adv(func(): return nat.doves_on, 90.0)
	await sec(1.0); await shot("n04b_doves_game")
	await hold_follow(func():
		var tgt := Vector3(1, 0, 0)
		for D in nat.doves:
			if not D.caught: tgt = D.n.position; tgt.y = 0; break
		return world().ground_to_screen(tgt), func(): return nat._caught >= 1, 60.0)
	await shot("n04c_doves_one")
	await hold_follow(func():
		var tgt := Vector3(1, 0, 0)
		for D in nat.doves:
			if not D.caught: tgt = D.n.position; tgt.y = 0; break
		return world().ground_to_screen(tgt), func(): return not nat.doves_on, 80.0)
	await sec(3.0); await shot("n04d_doves_done")
	await sec(4.0); await shot("n04e_simeon")
	# ---- 5
	await go("n5_star"); nat = main.nat
	await sec(4.0); await shot("n05a_wise_arrive")
	await adv(func(): return nat.trace != null and nat.trace.active, 90.0)
	await sec(1.0); await shot("n05b_trace_start")
	var tr = nat.trace; var pts: Array = tr.pts; var gp: Vector2 = tr.global_position
	touch(true, gp + pts[0]); await frames(2)
	for i in pts.size():
		drag(gp + pts[i]); await frames(2)
		if i == 30: await shot("n05c_trace_half")
	touch(false, gp + pts[pts.size() - 1]); await frames(3)
	await sec(2.0); await shot("n05d_trace_done")
	await adv(func(): return main.phase == "n5" and nat.trace == null and not ui().in_line and not ui().verse_card.visible, 60.0)
	await sec(5.0); await shot("n05e_star_road")
	await adv(func(): return main.phase == "jump", 120.0)
	# ---- jump
	await adv(func(): return nat.jump_wait, 60.0)
	await sec(1.0); await shot("n06a_jump_ring")
	await tap(world().ground_to_screen(nat.jump_pos)); await sec(0.5); await shot("n06b_jump_flash")
	await adv(func(): return Game.age_stage == "teen", 30.0)
	await sec(1.5); await shot("n06c_jump_teen")
	await adv(func(): return nat.jump_wait, 60.0)
	await tap(world().ground_to_screen(nat.jump_pos))
	await adv(func(): return Game.age_stage == "adult", 30.0)
	await sec(1.5); await shot("n06d_jump_adult")
	await adv(func(): return main.phase == "nazareth" and world().control, 90.0)
	await sec(1.5); await shot("n07_nazareth_grown")
	tour_done = true
	print("tour done")
	get_tree().quit(0)
