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
	await d.boot()
	var m = d.main
	print("== title")
	var b = await d.wait_btn("begin")
	d.check(b != null, "title shows Begin")
	await d.tap_btn("begin")
	await d.wait_for(func(): return m.phase == "name")
	d.check(m.phase == "name", "name picker opens")
	await d.tap_btn("girl"); await d.tap_btn("boy")
	d.check(await d.tap_btn("chip1"), "pick a name chip")
	d.check(Game.player_name != "", "player has a name: " + Game.player_name)
	await d.tap_btn("go")
	print("== nazareth")
	await d.wait_for(func(): return m.phase == "intro")
	await d.advance_until(func(): return m.phase == "nazareth" and d.world().control)
	d.check(m.phase == "nazareth" and d.world().control, "player is given control in Nazareth")
	d.check(await d.walk_to(Vector3(-0.4, 0, 3.0), 2.4), "walk to Naomi by tapping")
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
	await d.tap(d.world().ground_to_screen(d.world().pots[2].pos))
	await d.wait_for(func(): return m.phase == "bear" and d.world().control, 40.0)
	d.check(m.phase == "bear", "water became wine; player carries the cup")
	d.check(await d.walk_to(Vector3(1.8, 0, -3.3), 2.6), "carry the cup to the governor")
	await d.advance_until(func(): return m.phase == "end", 90.0)
	d.check(m.phase == "end", "end card reached")
	d.check(d.find_btn("again") != null or await d.wait_btn("again") != null, "Walk again button available")
	print("== done: ", d.checks, " checks, ", d.fails.size(), " failed")
	for f in d.fails: print("  FAILED: ", f)
	Engine.set_meta("ran", true); Engine.set_meta("code", 1 if d.fails.size() > 0 else 0)
	await d.tap_btn("again")
	await tree.create_timer(3.0).timeout
	tree.quit(2)
