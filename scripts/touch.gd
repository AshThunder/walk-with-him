extends Node
## Touch-first input router. Everything is driven by InputEventScreenTouch / ScreenDrag only.
## (emulate_mouse_from_touch=false, emulate_touch_from_mouse=true: a desktop mouse becomes a touch, a finger never double-fires.)
## - A short press-and-release = world_tap(pos)
## - Press, then drag past TAP_SLOP = floating virtual joystick (stick vector, -1..1 in screen space, y down)
## - Presses that start on a registered TButton never reach the world.
signal world_tap(pos: Vector2)
const TAP_SLOP := 36.0
const STICK_R := 130.0
var buttons: Array = []
var enabled := true
var stick := Vector2.ZERO
var stick_active := false
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var _t := {}

func register(b: Node) -> void:
	if not buttons.has(b): buttons.append(b)
func unregister(b: Node) -> void:
	buttons.erase(b)

func _input(e: InputEvent) -> void:
	if not enabled: return
	if e is InputEventScreenTouch:
		if e.pressed: _down(e.index, e.position)
		else: _up(e.index, e.position)
	elif e is InputEventScreenDrag:
		var d = _t.get(e.index)
		if d == null: return
		if d.target and is_instance_valid(d.target):
			d.target.set_down(d.target.hit_test(e.position))
		else:
			if not d.dragging and e.position.distance_to(d.start) > TAP_SLOP:
				d.dragging = true; stick_active = true; stick_origin = d.start
			if d.dragging:
				stick_pos = e.position
				stick = ((e.position - stick_origin) / STICK_R).limit_length(1.0)

func hit(pos: Vector2) -> Node:
	for i in range(buttons.size() - 1, -1, -1):
		var b = buttons[i]
		if not is_instance_valid(b) or not b.is_visible_in_tree() or b.disabled: continue
		if b.hit_test(pos): return b
	return null

func _down(idx: int, pos: Vector2) -> void:
	var t = hit(pos)
	_t[idx] = {"start": pos, "target": t, "dragging": false}
	if t: t.set_down(true)

func _up(idx: int, pos: Vector2) -> void:
	var d = _t.get(idx); _t.erase(idx)
	if d == null: return
	var t = d.target
	if t and is_instance_valid(t):
		t.set_down(false)
		if t.hit_test(pos) and t.is_visible_in_tree() and not t.disabled: t.fire()
		return
	if d.dragging:
		stick = Vector2.ZERO; stick_active = false
		return
	world_tap.emit(pos)

func reset() -> void:
	_t.clear(); stick = Vector2.ZERO; stick_active = false
