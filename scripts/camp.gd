class_name Camp
extends Node
## The camp: what you keep from a road. A result card, the Memory Stone, and a small camp with the flock (names and wool) and the journal.
## All flat colour. Selected things are a solid fill plus a tick. Nothing here is timed or scored.
var m
var ui: UI
const BG := Color(0.11, 0.075, 0.05)
const EDGE := Color(0.93, 0.74, 0.34)
const GOLD := Color(0.93, 0.74, 0.34)
const CREAM := Color(1.0, 0.92, 0.72)
const INK := Color(0.15, 0.09, 0.04)
const SWATCH := {"plain": Color(0.95, 0.92, 0.84), "gold": Color(1.0, 0.82, 0.45), "rose": Color(0.97, 0.7, 0.76)}
const WOOLS := [["plain", "Plain", 0], ["gold", "Gold", 1], ["rose", "Rose", 2]]

var _done := false
var _grp: Control
var _tab := 0
var _body: Control
var _tab_btns: Array = []
var _wool_btns: Array = []

## A choice button: solid gold fill + tick when selected, dark when not. Optionally a wool swatch and a small sub-label ("1 stone").
class Choice extends TButton:
	var swatch = null
	var sub := ""
	func _draw() -> void:
		var sb := StyleBoxFlat.new(); sb.set_corner_radius_all(26); sb.set_border_width_all(3)
		var txt := Color(0.15, 0.09, 0.04) if on else Color(1.0, 0.9, 0.62)
		sb.bg_color = (Color(0.93, 0.74, 0.34) if not down else Color(0.78, 0.58, 0.22)) if on else (Color(0.17, 0.12, 0.09) if not down else Color(0.3, 0.2, 0.1))
		sb.border_color = Color(1, 0.93, 0.7) if on else Color(0.93, 0.74, 0.34, 0.7)
		if disabled: sb.bg_color = Color(0.13, 0.1, 0.08); sb.border_color = Color(0.5, 0.4, 0.25, 0.6); txt = Color(0.6, 0.5, 0.35)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var f: Font = load("res://fonts/BarlowCondensed-Bold.ttf")
		var x := 28.0
		if swatch != null:
			draw_circle(Vector2(x + 24, size.y * 0.5), 24, swatch); draw_arc(Vector2(x + 24, size.y * 0.5), 24, 0, TAU, 28, Color(0.1, 0.06, 0.03), 3.0); x += 66
		var ty := (size.y + font_size * 0.62) * 0.5 - (12 if sub != "" else 4)
		draw_string(f, Vector2(x, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, txt)
		if sub != "": draw_string(f, Vector2(x, ty + 34), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, txt)
		if on:
			var c := Vector2(size.x - 40, size.y * 0.5)
			draw_polyline(PackedVector2Array([c + Vector2(-14, 1), c + Vector2(-4, 12), c + Vector2(15, -12)]), Color(0.15, 0.09, 0.04), 6.0)

class GoalRow extends Control:
	var ok := false
	var text := ""
	func _draw() -> void:
		var f: Font = load("res://fonts/BarlowCondensed-SemiBold.ttf")
		var c := Vector2(34, size.y * 0.5)
		if ok:
			draw_circle(c, 28, Color(0.93, 0.74, 0.34))
			draw_polyline(PackedVector2Array([c + Vector2(-12, 1), c + Vector2(-4, 10), c + Vector2(13, -10)]), Color(0.15, 0.09, 0.04), 6.0)
		else:
			draw_arc(c, 26, 0, TAU, 32, Color(0.93, 0.74, 0.34, 0.6), 4.0)
		draw_string(f, Vector2(88, size.y * 0.5 + 15), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(1.0, 0.92, 0.72) if ok else Color(0.85, 0.75, 0.55))

class Pebble extends Control:
	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			pts.append(size * 0.5 + Vector2(cos(a) * size.x * 0.5, sin(a) * size.y * 0.5) * (1.0 + 0.05 * sin(a * 3.0 + 1.0)))
		draw_colored_polygon(pts, Color(0.62, 0.58, 0.52))
		var hl := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			hl.append(size * Vector2(0.38, 0.38) + Vector2(cos(a) * size.x * 0.17, sin(a) * size.y * 0.1))
		draw_colored_polygon(hl, Color(0.74, 0.7, 0.64))

func setup(main) -> void:
	m = main; ui = main.ui

func _new_group() -> Control:
	var g := Control.new(); g.mouse_filter = Control.MOUSE_FILTER_IGNORE; g.size = Vector2(1080, 1920); ui.ovl.add_child(g); ui.ovl.move_child(g, 0); g.modulate.a = 0.0
	create_tween().tween_property(g, "modulate:a", 1.0, 0.5)
	return g

func _flat(parent: Control, r: Rect2) -> Panel:
	var p := Panel.new(); p.position = r.position; p.size = r.size; p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new(); sb.bg_color = BG; sb.border_color = EDGE; sb.set_border_width_all(3); sb.set_corner_radius_all(34)
	p.add_theme_stylebox_override("panel", sb); parent.add_child(p); return p

func _close_group() -> void:
	if _grp != null and is_instance_valid(_grp):
		var g := _grp; _grp = null
		var tw := create_tween(); tw.tween_property(g, "modulate:a", 0.0, 0.35); await tw.finished
		g.queue_free()
		Touch.reset()

func _wait_done() -> void:
	_done = false
	while not _done: await Game.frame(self)

# ------------------------------------------------------------------ the road is over: what came to the fire
func result_card(res: Dictionary, cfg: Dictionary) -> void:
	_grp = _new_group()
	var p := _flat(_grp, Rect2(110, 400, 860, 880))
	ui.lbl(p, "The flock is at the fire", ui.F_T, 62, CREAM, Rect2(30, 34, 800, 80), HORIZONTAL_ALIGNMENT_CENTER)
	ui.lbl(p, "%d lambs came in from %d" % [res.followers, res.total], ui.F_S, 48, GOLD, Rect2(30, 126, 800, 64), HORIZONTAL_ALIGNMENT_CENTER)
	var rows := [
		["Bring %d lambs" % res.need, res.goals[0]],
		["Lose none", res.goals[1]],
		["Reach the fire by dusk", res.goals[2]]]
	for i in rows.size():
		var r := GoalRow.new(); r.position = Vector2(80, 230 + i * 92); r.size = Vector2(700, 80); r.ok = rows[i][1]; r.text = rows[i][0]; p.add_child(r)
	var lost: Array = res.lost
	var msg := "Every one of them is here." if lost.is_empty() else "%s wandered in the dark. They are finding the fire." % _names(lost, 3)
	ui.lbl(p, msg, ui.F_I, 44, CREAM, Rect2(60, 540, 740, 150), HORIZONTAL_ALIGNMENT_CENTER, true)
	var b := ui.btn(p, "road_continue", "Go to camp", Rect2(180, 710, 500, 120), "gold", 64)
	b.pressed.connect(func(): _done = true)
	await _wait_done()
	await _close_group()

func _names(list: Array, n: int) -> String:
	var s: Array = list.slice(0, n)
	var out := ", ".join(s)
	if list.size() > n: out += " and %d more" % (list.size() - n)
	return out

# ------------------------------------------------------------------ a Memory Stone: a verse and the lamb you remember it by
func stone_card(stone: Dictionary) -> void:
	_grp = _new_group()
	var dim := ColorRect.new(); dim.color = Color(0.03, 0.02, 0.05, 0.55); dim.position = Vector2(-300, -400); dim.size = Vector2(1680, 2800); dim.mouse_filter = Control.MOUSE_FILTER_IGNORE; _grp.add_child(dim)
	var p := _flat(_grp, Rect2(90, 400, 900, 1020))
	var peb := Pebble.new(); peb.position = Vector2(390, 40); peb.size = Vector2(120, 84); p.add_child(peb)
	ui.lbl(p, "MEMORY STONE", ui.F_U, 38, GOLD, Rect2(0, 142, 900, 50), HORIZONTAL_ALIGNMENT_CENTER)
	var txt: String = stone.text
	var fs := 56 if txt.length() < 110 else (48 if txt.length() < 190 else 40)
	ui.lbl(p, txt, ui.F_I, fs, CREAM, Rect2(60, 210, 780, 440), HORIZONTAL_ALIGNMENT_CENTER, true)
	ui.lbl(p, str(stone.ref), ui.F_T, 46, GOLD, Rect2(0, 670, 900, 60), HORIZONTAL_ALIGNMENT_CENTER)
	ui.lbl(p, "You will remember this by %s." % stone.lamb, ui.F_S, 42, Color(0.85, 0.75, 0.55), Rect2(60, 760, 780, 60), HORIZONTAL_ALIGNMENT_CENTER, true)
	var b := ui.btn(p, "stone_keep", "Keep it", Rect2(200, 860, 500, 110), "gold", 62)
	b.pressed.connect(func(): _done = true)
	Audio.sfx("stone", -2.0); Audio.play_voice(str(stone.id))
	await _wait_done()
	Audio.stop_voice()
	await _close_group()

# ------------------------------------------------------------------ camp: the flock and the journal
func open(go_label := "Walk on") -> void:
	_grp = _new_group()
	var p := _flat(_grp, Rect2(40, 930, 1000, 950))
	ui.lbl(p, "Camp", ui.F_T, 64, CREAM, Rect2(30, 14, 300, 90), HORIZONTAL_ALIGNMENT_LEFT)
	_tab_btns.clear()
	for i in 2:
		var b := Choice.new("camp_tab%d" % i, ["Flock", "Journal"][i], "dark"); b.position = Vector2(400 + i * 290, 20); b.size = Vector2(270, 84); b.font_size = 48; p.add_child(b)
		var idx := i
		b.pressed.connect(func(): _set_tab(idx))
		_tab_btns.append(b)
	_body = Control.new(); _body.mouse_filter = Control.MOUSE_FILTER_IGNORE; _body.position = Vector2(0, 120); _body.size = Vector2(1000, 680); p.add_child(_body)
	var go := ui.btn(p, "camp_go", go_label, Rect2(250, 820, 500, 100), "gold", 62)
	go.pressed.connect(func(): _done = true)
	_set_tab(0)
	await _wait_done()
	_tab_btns.clear(); _wool_btns.clear()
	await _close_group()

func _set_tab(i: int) -> void:
	_tab = i
	for k in _tab_btns.size(): _tab_btns[k].set_on(k == i)
	for c in _body.get_children(): c.queue_free()
	_wool_btns.clear()
	if i == 0: _flock_tab()
	else: _journal_tab()

func _flock_tab() -> void:
	var names: Array = Game.roster
	ui.lbl(_body, "%d lambs in your flock" % names.size(), ui.F_T, 46, GOLD, Rect2(30, 0, 940, 64))
	var fs := 40 if names.size() <= 24 else (34 if names.size() <= 44 else 30)
	ui.lbl(_body, ", ".join(names) + ("." if not names.is_empty() else ""), ui.F_S, fs, CREAM, Rect2(30, 72, 940, 300), HORIZONTAL_ALIGNMENT_LEFT, true)
	ui.lbl(_body, "Wool", ui.F_U, 36, GOLD, Rect2(30, 400, 300, 44))
	var stones: int = Game.stones.size()
	for k in WOOLS.size():
		var w: Array = WOOLS[k]
		var b := Choice.new("wool_" + w[0], w[1], "dark"); b.position = Vector2(30 + k * 316, 450); b.size = Vector2(300, 120); b.font_size = 50; b.swatch = SWATCH[w[0]]
		b.disabled = stones < int(w[2])
		if b.disabled: b.sub = "%d stone%s" % [w[2], "" if int(w[2]) == 1 else "s"]
		_body.add_child(b); b.set_on(Game.tint == w[0])
		var id: String = w[0]
		b.pressed.connect(func(): _pick_wool(id))
		_wool_btns.append(b)
	ui.lbl(_body, "Memory Stones carried: %d" % stones, ui.F_S, 38, Color(0.85, 0.75, 0.55), Rect2(30, 600, 940, 50))

func _pick_wool(id: String) -> void:
	Game.tint = id; Game.save_meta()
	for k in _wool_btns.size(): _wool_btns[k].set_on(WOOLS[k][0] == id)
	if m.nat != null and m.nat.fl != null: m.nat.fl.retint()
	Audio.sfx("pop", -6.0)

func _journal_tab() -> void:
	var j: Array = Game.journal
	if j.is_empty():
		ui.lbl(_body, "Nothing written yet.", ui.F_I, 44, CREAM, Rect2(30, 20, 940, 60)); return
	var n := mini(j.size(), 3)
	for k in n:
		var e: Dictionary = j[j.size() - 1 - k]
		var y := k * 224
		ui.lbl(_body, str(e.get("title", "")), ui.F_T, 44, GOLD, Rect2(30, y, 940, 56))
		ui.lbl(_body, str(e.get("text", "")), ui.F_S, 37, CREAM, Rect2(30, y + 58, 940, 156), HORIZONTAL_ALIGNMENT_LEFT, true)
