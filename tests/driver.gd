extends Node
## Shared helpers for the touch-only playtest and the screenshot tour.
## Every interaction goes through InputEventScreenTouch / ScreenDrag pushed into the viewport, exactly what a finger produces.
var main: Node
var fails: Array = []
var checks := 0

func boot() -> void:
	Game.reset_progress()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)

## Simulate the OS killing the app and the player opening it again: Android pauses (autosave), the process dies, a new one boots.
func relaunch() -> void:
	main.notification(NOTIFICATION_APPLICATION_PAUSED)
	main.queue_free(); await frames(3)
	Touch.reset(); get_tree().paused = false
	Game.reset_progress(); Game.player_name = "Shepherd"; Game.player_girl = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(2)

func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond: print("  ok   ", msg)
	else: fails.append(msg); print("  FAIL ", msg)

func frames(n := 1) -> void:
	for i in n:
		if not is_inside_tree(): await Game.never      # the test scene itself was reloaded
		await get_tree().process_frame

func touch(pressed: bool, pos: Vector2, idx := 0) -> void:
	var e = InputEventScreenTouch.new(); e.index = idx; e.pressed = pressed; e.position = pos
	get_viewport().push_input(e, true)

func drag(pos: Vector2, idx := 0) -> void:
	var e = InputEventScreenDrag.new(); e.index = idx; e.position = pos
	get_viewport().push_input(e, true)

func tap(pos: Vector2) -> void:
	touch(true, pos); await frames(2); touch(false, pos); await frames(2)

func find_btn(n: String) -> Node:
	for b in Touch.buttons:
		if is_instance_valid(b) and b.name == n and b.is_visible_in_tree() and not b.disabled: return b
	return null

func tap_btn(n: String) -> bool:
	var b = find_btn(n)
	if b == null: return false
	await tap(b.get_global_rect().get_center()); return true

## wait (in game seconds) until a button with this name can be pressed
func wait_btn(n: String, timeout_s := 12.0) -> Node:
	var t = 0.0
	while t < timeout_s:
		var b = find_btn(n)
		if b != null and b.get_global_rect().size.x > 10 and (b.modulate.a > 0.9 if n != "advance" else true): return b
		await frames(2); t += get_process_delta_time() * 2.0
	return null

func world() -> World: return main.world
func player() -> Person: return main.world.player

func wait_for(cond: Callable, timeout_s := 20.0) -> bool:
	var t := 0.0
	while t < timeout_s:
		if cond.call(): return true
		await frames(2); t += get_process_delta_time() * 2.0
	return false

## Skip through dialogue / verse cards by tapping the full-screen advance button until `done` is true.
func advance_until(done: Callable, timeout_s := 60.0) -> bool:
	var t := 0.0
	while t < timeout_s:
		if done.call(): return true
		var b = find_btn("advance")
		if b != null and b.is_visible_in_tree(): await tap_btn("advance")
		await frames(6); t += get_process_delta_time() * 6.0
	return done.call()

func in_control() -> bool:
	return main.world.control

## Walk to a ground point using only taps (waypoints of <= 5 units).
func walk_via(pts: Array, radius := 1.0) -> bool:
	for i in pts.size():
		if not await walk_to(pts[i], radius if i == pts.size() - 1 else 1.0): return false
	return true

func walk_to(goal: Vector3, radius := 1.0, timeout_s := 40.0) -> bool:
	var w := world()
	var area0: String = w.area
	var t := 0.0; var stuck := 0.0
	var last := w.player.position
	while t < timeout_s:
		if w.area != area0: return true
		var d := goal - w.player.position; d.y = 0
		if d.length() <= radius: return true
		if w.control:
			var step := d.normalized() * minf(d.length(), 5.0)
			var tgt := w.player.position + step
			# if stuck, sidestep by tapping a point rotated to the side
			if stuck > 1.2:
				tgt = w.player.position + step.rotated(Vector3.UP, deg_to_rad(70.0 if int(t) % 2 == 0 else -70.0))
				stuck = 0.0
			var sp: Vector2 = w.ground_to_screen(tgt)
			var vs := get_viewport().get_visible_rect().size
			sp = sp.clamp(Vector2(60, 470), vs - Vector2(60, 330))
			await tap(sp)
		await frames(8); var dt := get_process_delta_time() * 10.0; t += dt
		if w.player.position.distance_to(last) < 0.15: stuck += dt
		else: stuck = 0.0
		last = w.player.position
	return false

## Joystick drag for `secs` game seconds, direction in screen space.
func stick(dir: Vector2, secs := 1.0) -> void:
	var s := Vector2(540, 1400)
	touch(true, s, 1); await frames(1)
	drag(s + dir.normalized() * 60.0, 1); await frames(1)
	drag(s + dir.normalized() * 110.0, 1)
	var t := 0.0
	while t < secs:
		drag(s + dir.normalized() * 110.0, 1)
		await frames(2); t += get_process_delta_time() * 2.0
	touch(false, s + dir.normalized() * 110.0, 1); await frames(2)

func shot(n: String) -> void:
	await frames(3)
	if DisplayServer.get_name() == "headless": return
	var img = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://shots/%s.png" % n)); print("shot ", n, " ", img.get_size()); stats(n)

func stats(tag: String) -> void:
	var P := Performance
	print("STATS %s objs=%d nodes=%d draws=%d prims=%d texMB=%.1f vidMB=%.1f bufMB=%.1f staticMB=%.1f" % [tag, P.get_monitor(P.OBJECT_COUNT), P.get_monitor(P.OBJECT_NODE_COUNT), P.get_monitor(P.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), P.get_monitor(P.RENDER_TOTAL_PRIMITIVES_IN_FRAME), P.get_monitor(P.RENDER_TEXTURE_MEM_USED)/1048576.0, P.get_monitor(P.RENDER_VIDEO_MEM_USED)/1048576.0, P.get_monitor(P.RENDER_BUFFER_MEM_USED)/1048576.0, P.get_monitor(P.MEMORY_STATIC)/1048576.0])
