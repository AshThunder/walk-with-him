extends "res://tests/driver.gd"
## Screenshot tour (needs a real display):  godot --path . res://tests/shots.tscn --resolution 1080x1920
var seen := {}
var n_line := 0
var n_verse := 0
var tour_done := false

func _ready() -> void:
	Engine.time_scale = 2.0
	await boot(); run()

func sec(t: float) -> void: await get_tree().create_timer(t).timeout

func ui() -> UI: return main.ui

## Watcher: captures each dialogue line and scripture card once it is fully readable.
func watcher() -> void:
	while not tour_done:
		await frames(3)
		if not is_instance_valid(main) or main.get("ui") == null: continue
		var u := ui()
		if u.in_line and u.dlg_text.visible_ratio > 0.97 and u.dlg.modulate.a > 0.95:
			var k := u.dlg_text.text
			if not seen.has(k):
				seen[k] = true; n_line += 1
				await shot("line%02d_%s_%s" % [n_line, main.phase, u.dlg_name.text.to_lower().replace(" ", "_")])
		if u.verse_card.visible and u.verse_card.modulate.a > 0.97:
			var k2 := u.verse_text.text
			if not seen.has(k2):
				seen[k2] = true; n_verse += 1
				await shot("verse%02d" % n_verse)

func read_ok() -> bool:
	var u := ui()
	if u.in_line: return seen.has(u.dlg_text.text)
	if u.verse_card.visible: return seen.has(u.verse_text.text)
	return true

func adv(done: Callable, timeout_s := 120.0) -> bool:
	var t := 0.0
	while t < timeout_s:
		if done.call(): return true
		var b = find_btn("advance")
		if b != null and read_ok() and (ui().in_line or ui().verse_card.visible): await tap_btn("advance")
		await frames(6); t += get_process_delta_time() * 6.0
	return done.call()

func map_shot(tag: String) -> void:
	await tap_btn("map"); await sec(1.2); await shot(tag)
	await tap_btn("mapclose"); await frames(4)

func run() -> void:
	watcher()
	var m = main
	await wait_btn("begin"); await sec(2.0); await shot("01_title")
	await tap_btn("begin"); await wait_for(func(): return m.phase == "name"); await sec(1.0); await shot("02_name_picker")
	await tap_btn("girl"); await sec(0.5); await shot("02b_name_picker_girl")
	await tap_btn("boy"); await tap_btn("chip3"); await sec(0.5)
	await tap_btn("go")
	await wait_for(func(): return m.phase == "intro"); await sec(0.5)
	await adv(func(): return m.phase == "nazareth" and world().control)
	await sec(1.5); await shot("03_nazareth_start")
	await walk_to(Vector3(-0.4, 0, 3.0), 2.4)
	await adv(func(): return world().control and world().triggers.filter(func(t): return t.id == "scroll_prov3_5")[0].active)
	await sec(1.0); await shot("04_nazareth_find_scroll")
	await map_shot("21_map_nazareth")
	await tap_btn("menu"); await sec(1.0); await shot("24_pause_menu"); await tap_btn("resume"); await frames(4)
	await walk_to(Vector3(-6.6, 0, 6.0), 1.2)
	await adv(func(): return Game.scrolls.has("prov3_5") and world().control)
	await walk_to(Vector3(-0.4, 0, 3.0), 2.4)
	await adv(func(): return world().control and m.phase == "nazareth" and world().triggers.filter(func(t): return t.id == "jesus")[0].active)
	await walk_to(Vector3(8.0, 0, -4.2), 2.6)
	await adv(func(): return world().follow_jesus and world().control)
	await walk_via([Vector3(12.0, 0, -1.0)], 1.0)
	await shot("05_walking_with_jesus")
	await walk_to(Vector3(14.0, 0, 2.2), 1.6)
	await wait_for(func(): return m.phase == "road" and world().control, 30.0)
	await sec(2.5); await shot("06_road_start")
	await walk_to(Vector3(21.5, 0, -8.2), 1.3)
	await adv(func(): return Game.scrolls.has("ps119_105") and world().control)
	await walk_to(Vector3(34.0, 0, 2.2), 1.5)
	await shot("07_road_middle")
	await map_shot("22_map_road")
	await relaunch(); m = main
	await wait_btn("continue"); await sec(1.5); await shot("23_title_continue")
	await tap_btn("continue")
	await wait_for(func(): return m.phase == "road" and world().control, 20.0)
	await sec(2.0); await shot("25_after_continue")
	await walk_to(Vector3(47.5, 0, 0.2), 1.6, 80.0)
	await wait_for(func(): return m.phase == "cana", 30.0)
	await sec(1.0); await shot("08_cana_arrival")
	await adv(func(): return world().control and m.phase == "cana", 60.0)
	await sec(1.0); await shot("09_cana_feast")
	await map_shot("26_map_cana")
	await walk_to(Vector3(2.4, 0, 6.8), 1.8)
	await adv(func(): return Game.scrolls.has("ps34_8") and world().control)
	await walk_via([Vector3(0.5, 0, 5.0), Vector3(0.5, 0, 1.0), Vector3(3.0, 0, 0.0)], 3.0)
	await adv(func(): return m.pot_mode == "fill", 90.0)
	await sec(1.0); await shot("10_fill_pots_start")
	var taps := 0
	while m.pot_mode == "fill" and taps < 60:
		var i: int = taps % world().pots.size()
		await tap(world().ground_to_screen(world().pots[i].pos)); taps += 1
		if taps == 10: await shot("11_fill_pots_midway")
	await adv(func(): return m.pot_mode == "draw", 60.0)
	await sec(1.0); await shot("12_draw_prompt")
	await tap(world().ground_to_screen(world().pots[2].pos))
	await sec(2.5); await shot("13_miracle_a")
	await sec(2.5); await shot("14_miracle_b")
	await sec(2.5); await shot("15_miracle_c")
	await wait_for(func(): return m.phase == "bear" and world().control, 40.0)
	await sec(1.0); await shot("16_bear_the_cup")
	await walk_to(Vector3(1.8, 0, -3.3), 2.6)
	await adv(func(): return m.phase == "end", 120.0)
	await wait_btn("again"); await sec(1.5); await shot("20_end_card")
	tour_done = true
	print("tour done: ", n_line, " lines, ", n_verse, " verses")
	get_tree().quit(0)
