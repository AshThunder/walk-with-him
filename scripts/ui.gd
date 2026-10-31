class_name UI
extends CanvasLayer
## All 2D: HUD, dialogue, verse cards, title, name picker, fades. Designed for 1080x1920; wrappers shift with taller screens.
signal begin_pressed
signal name_chosen
signal again_pressed
signal skip
signal continue_pressed
signal save_pressed
signal title_pressed
signal chapter_chosen(stage_id: String)
const _Minimap = preload("res://scripts/minimap.gd")
const _Waypoint = preload("res://scripts/waypoint.gd")
const _MapScreen = preload("res://scripts/mapscreen.gd")
var world: World                 # set by main: the minimap, map and waypoint read the live world from here
var goal = null                  # Vector3 of the current objective, or null
var ovl: Control
var minimap: Control
var wp: Control
var map_btn: TButton
var menu_btn: TButton
var menu_grp: Control
var map_grp: Control
var menu_open := false
var map_open := false
var cont_btn: TButton
var begin_btn: TButton
var cont_info: Label
var credit_lbl: Label
var root: Control
var top: Control
var mid: Control
var bot: Control
var F_T: Font
var F_I: Font
var F_U: Font
var F_S: Font
# hud
var obj_panel: Panel
var obj_lbl: Label
var scroll_lbl: Label
var snd_btn: TButton
var joy: Control
# dialogue
var dlg: Panel
var dlg_name: Label
var dlg_text: Label
var dlg_ref: Label
var adv: TButton
var _skip_ok := false
# verse
var verse_card: Panel
var verse_text: Label
var verse_ref: Label
# misc
var fade_rect: ColorRect
var area_lbl: Label
var area_sub: Label
var toast_lbl: Label
var toast_tw: Tween
var toast_panel: Panel
var pour_panel: Panel
var pour_lbl: Label
var pour_bar: ColorRect
var pour_fill: ColorRect
var title_grp: Control
var name_grp: Control
var end_grp: Control
var chips: Array = []
var boy_btn: TButton
var girl_btn: TButton
var name_idx := 0
var hud_on := false
var in_line := false
var chap_grp: Control
var chap_open := false
var chap_btn: TButton
var choice_grp: Control
var _choice := -1
var clue_panel: Panel
var clue_dots: Array = []
var clue_lbls: Array = []
## Chapters on offer in the chapter-select. Chapters 6 (Egypt) and 7 (the Temple at twelve) are not built yet.
const CHAPTERS := [
	["n1_flock", "1   The Night Field"], ["n2_sky", "2   Glory in the Sky"], ["n3_town", "3   The Manger"], ["n4_temple", "4   The Presentation"],
	["n5_star", "5   The Star"], ["naz_start", "8   Nazareth"], ["cana_mary", "10   Cana of Galilee"]]

func _ready() -> void:
	layer = 10
	F_T = load("res://fonts/ZillaSlab-Bold.ttf"); F_I = load("res://fonts/ZillaSlab-MediumItalic.ttf"); F_U = load("res://fonts/BarlowCondensed-Bold.ttf"); F_S = load("res://fonts/BarlowCondensed-SemiBold.ttf")
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	top = _wrap(); mid = _wrap(); bot = _wrap()
	get_viewport().size_changed.connect(_layout); _layout()
	_build_hud(); _build_dialogue(); _build_verse(); _build_misc(); _build_title(); _build_chapters(); _build_name(); _build_end()
	ovl = _wrap(); _layout(); _build_overlays()
	process_mode = Node.PROCESS_MODE_ALWAYS      # the UI keeps running while the world is paused (pause menu, map)
	set_hud(false)

func _wrap() -> Control:
	var c := Control.new(); c.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.size = Vector2(1080, 1920); root.add_child(c); return c

func _layout() -> void:
	var h: float = get_viewport().get_visible_rect().size.y
	if mid: mid.position.y = (h - 1920.0) * 0.5
	if bot: bot.position.y = h - 1920.0
	if ovl: ovl.position.y = (h - 1920.0) * 0.5

# ---------- helpers
func panel(parent: Control, r: Rect2, bg: Color, border := Color(0.93, 0.74, 0.34), rad := 30, bw := 3) -> Panel:
	var p := Panel.new(); p.position = r.position; p.size = r.size; p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new(); sb.bg_color = bg; sb.border_color = border; sb.set_border_width_all(bw); sb.set_corner_radius_all(rad)
	sb.shadow_color = Color(0, 0, 0, 0.35); sb.shadow_size = 10; p.add_theme_stylebox_override("panel", sb); parent.add_child(p); return p

func lbl(parent: Control, t: String, f: Font, fs: int, col: Color, r: Rect2, align := HORIZONTAL_ALIGNMENT_LEFT, wrap := false, outline := 0) -> Label:
	var l := Label.new(); if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = t; l.position = r.position; l.size = r.size; l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", f); l.add_theme_font_size_override("font_size", fs); l.add_theme_color_override("font_color", col)
	if outline > 0: l.add_theme_constant_override("outline_size", outline); l.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.95))
	l.horizontal_alignment = align
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l); return l

func btn(parent: Control, id: String, t: String, r: Rect2, style := "gold", fs := 54) -> TButton:
	var b := TButton.new(id, t, style); b.position = r.position; b.size = r.size; b.font_size = fs; parent.add_child(b); return b

func tw_alpha(n: CanvasItem, a: float, t := 0.4) -> void:
	create_tween().tween_property(n, "modulate:a", a, t)

# ---------- HUD
func _build_hud() -> void:
	obj_panel = panel(top, Rect2(28, 56, 760, 120), Color(0.1, 0.06, 0.04, 0.78), Color(0.93, 0.74, 0.34, 0.8), 28)
	lbl(obj_panel, "GOAL", F_U, 28, Color(0.93, 0.74, 0.34), Rect2(26, 8, 200, 34))
	obj_lbl = lbl(obj_panel, "", F_S, 38, Color(1, 0.95, 0.82), Rect2(26, 40, 710, 76), HORIZONTAL_ALIGNMENT_LEFT, true)
	scroll_lbl = lbl(top, "Scrolls 0 / 3", F_U, 36, Color(1, 0.92, 0.65), Rect2(28, 186, 400, 44), HORIZONTAL_ALIGNMENT_LEFT, false, 8)
	map_btn = btn(top, "map", "Map", Rect2(806, 56, 120, 120), "dark", 40); map_btn.pressed.connect(func(): open_map(true))
	menu_btn = btn(top, "menu", "Menu", Rect2(936, 56, 118, 120), "dark", 38); menu_btn.pressed.connect(func(): open_menu(true))
	minimap = Control.new(); minimap.set_script(_Minimap); minimap.ui = self; minimap.position = Vector2(826, 196); minimap.size = Vector2(228, 228); minimap.clip_contents = true; minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE; top.add_child(minimap)
	var mb := btn(top, "minimap", "", Rect2(826, 196, 228, 228), "ghost"); mb.pressed.connect(func(): open_map(true))
	joy = Control.new(); joy.set_script(_JoyDraw); joy.size = Vector2(1080, 1920); joy.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(joy)
	wp = Control.new(); wp.set_script(_Waypoint); wp.ui = self; wp.set_anchors_preset(Control.PRESET_FULL_RECT); wp.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(wp)

func _toggle_sound() -> void:
	var on: bool = not Game.settings.music
	Game.settings.music = on; Game.settings.sfx = on; Game.settings.voice = on
	if snd_btn: snd_btn.set_label("Sound: On" if on else "Sound: Off")
	if on: Audio.music_vol(Audio.MUSIC_DB, 0.3)
	else: Audio.music_vol(-80.0, 0.3); Audio.stop_voice()

func set_hud(v: bool) -> void:
	hud_on = v; top.visible = v; joy.visible = v; wp.visible = v
	if v: update_scrolls()

func set_objective(t: String) -> void:
	obj_lbl.text = t
	obj_panel.modulate = Color(1.6, 1.4, 1.0); create_tween().tween_property(obj_panel, "modulate", Color.WHITE, 0.8)

func overlay_open() -> bool:
	return menu_open or map_open

func _sync_pause() -> void:
	get_tree().paused = menu_open or map_open
	Touch.reset()

func open_menu(v: bool) -> void:
	if v: map_open = false; map_grp.visible = false
	menu_open = v; menu_grp.visible = v; _sync_pause()
	if v: snd_btn.set_label("Sound: On" if Game.settings.music else "Sound: Off")

func open_map(v: bool) -> void:
	if v: menu_open = false; menu_grp.visible = false
	map_open = v; map_grp.visible = v; _sync_pause()

func _build_overlays() -> void:
	# pause menu (the block button is first so it swallows every touch that misses a menu button)
	menu_grp = Control.new(); menu_grp.mouse_filter = Control.MOUSE_FILTER_IGNORE; menu_grp.size = Vector2(1080, 1920); ovl.add_child(menu_grp)
	var sh := ColorRect.new(); sh.color = Color(0.05, 0.03, 0.02, 0.72); sh.position = Vector2(-300, -1200); sh.size = Vector2(1680, 4400); sh.mouse_filter = Control.MOUSE_FILTER_IGNORE; menu_grp.add_child(sh)
	btn(menu_grp, "block", "", Rect2(-300, -1200, 1680, 4400), "ghost")
	var p := panel(menu_grp, Rect2(130, 380, 820, 1100), Color(0.1, 0.06, 0.04, 0.95), Color(0.93, 0.74, 0.34), 40)
	lbl(p, "Paused", F_T, 90, Color(1, 0.92, 0.7), Rect2(0, 30, 820, 120), HORIZONTAL_ALIGNMENT_CENTER)
	var rb := btn(p, "resume", "Resume", Rect2(80, 180, 660, 130), "gold", 68); rb.pressed.connect(func(): open_menu(false))
	var sv := btn(p, "save", "Save game", Rect2(80, 340, 660, 120), "dark", 58); sv.pressed.connect(func(): save_pressed.emit())
	var mp := btn(p, "menu_map", "Open map", Rect2(80, 490, 660, 120), "dark", 58); mp.pressed.connect(func(): open_map(true))
	snd_btn = btn(p, "sound", "Sound: On", Rect2(80, 640, 660, 120), "dark", 58); snd_btn.pressed.connect(_toggle_sound)
	var tt := btn(p, "title", "Save and go to title", Rect2(80, 790, 660, 120), "dark", 54); tt.pressed.connect(func(): title_pressed.emit())
	lbl(p, "The game saves by itself at each step of the story,\nand whenever you leave the app.", F_S, 34, Color(0.8, 0.68, 0.45), Rect2(40, 940, 740, 110), HORIZONTAL_ALIGNMENT_CENTER, true)
	menu_grp.visible = false
	# full map
	map_grp = Control.new(); map_grp.mouse_filter = Control.MOUSE_FILTER_IGNORE; map_grp.size = Vector2(1080, 1920); ovl.add_child(map_grp)
	var sh2 := ColorRect.new(); sh2.color = Color(0.05, 0.03, 0.02, 0.8); sh2.position = Vector2(-300, -1200); sh2.size = Vector2(1680, 4400); sh2.mouse_filter = Control.MOUSE_FILTER_IGNORE; map_grp.add_child(sh2)
	btn(map_grp, "block2", "", Rect2(-300, -1200, 1680, 4400), "ghost")
	var ms := Control.new(); ms.set_script(_MapScreen); ms.ui = self; ms.size = Vector2(1080, 1920); ms.mouse_filter = Control.MOUSE_FILTER_IGNORE; map_grp.add_child(ms)
	var cb := btn(map_grp, "mapclose", "Close", Rect2(290, 1660, 500, 120), "gold", 66); cb.pressed.connect(func(): open_map(false))
	map_grp.visible = false

func update_scrolls() -> void:
	scroll_lbl.text = "Scrolls %d / 3" % Game.scrolls.size(); scroll_lbl.visible = Game.age_stage == "adult"

# ---------- dialogue
func _build_dialogue() -> void:
	dlg = panel(bot, Rect2(36, 1320, 1008, 470), Color(0.1, 0.06, 0.04, 0.9), Color(0.93, 0.74, 0.34), 36)
	dlg_name = lbl(dlg, "", F_T, 50, Color(0.97, 0.78, 0.36), Rect2(40, 20, 900, 64))
	dlg_text = lbl(dlg, "", F_S, 46, Color(1, 0.96, 0.86), Rect2(40, 92, 928, 290), HORIZONTAL_ALIGNMENT_LEFT, true)
	dlg_ref = lbl(dlg, "", F_I, 32, Color(0.8, 0.68, 0.45), Rect2(40, 398, 700, 44))
	lbl(dlg, "tap to continue", F_U, 30, Color(0.65, 0.55, 0.4), Rect2(720, 398, 250, 44), HORIZONTAL_ALIGNMENT_RIGHT)
	dlg.visible = false; dlg.modulate.a = 0.0
	adv = btn(root, "advance", "", Rect2(0, 0, 1080, 1920), "ghost"); adv.visible = false; adv.pressed.connect(func(): if _skip_ok: skip.emit())

func _wait_tap_or(secs: float) -> void:
	var t := 0.0; var sk := [false]; var cb := func(): sk[0] = true
	skip.connect(cb)
	_skip_ok = false
	while t < secs and not sk[0]:
		await Game.frame(self)
		t += get_process_delta_time()
		if t > 0.5: _skip_ok = true
	skip.disconnect(cb); _skip_ok = false

func line(id: String, who: Person = null) -> void:
	var d: Dictionary = Game.lines[id]
	var dur: float = Audio.play_voice(id)
	dlg_name.text = Game.DISPLAY.get(d.speaker, "")
	dlg_text.text = d.text; dlg_text.visible_ratio = 0.0; _style_line(d)
	if toast_tw: toast_tw.kill()
	toast_panel.modulate.a = 0.0
	dlg.visible = true; adv.visible = true; in_line = true
	create_tween().tween_property(dlg, "modulate:a", 1.0, 0.2)
	var rd := minf(dur * 0.85, 9.0) if dur > 0.5 else 1.0
	create_tween().tween_property(dlg_text, "visible_ratio", 1.0, maxf(rd, 0.6))
	if who != null: who.talking = true
	await _wait_tap_or(maxf(dur, d.text.length() * 0.035) + 0.7)
	if who != null: who.talking = false
	Audio.stop_voice(); in_line = false
	var tw := create_tween(); tw.tween_property(dlg, "modulate:a", 0.0, 0.2); await tw.finished
	dlg.visible = false; adv.visible = false

## Two inks: Scripture is gold with its reference; invented words are plain ink with a small "Fiction" mark.
func _style_line(d: Dictionary) -> void:
	if d.kind == "kjv":
		dlg_ref.text = d.ref; dlg_ref.add_theme_color_override("font_color", Color(0.8, 0.68, 0.45))
		dlg_text.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	else:
		dlg_ref.text = "Fiction  \u00B7  added for the story"; dlg_ref.add_theme_color_override("font_color", Color(0.62, 0.66, 0.78))
		dlg_text.add_theme_color_override("font_color", Color(1, 0.96, 0.86))

# ---------- scripture card
func _build_verse() -> void:
	verse_card = panel(mid, Rect2(70, 520, 940, 800), Color(0.95, 0.88, 0.7, 0.97), Color(0.55, 0.32, 0.12), 40, 6)
	lbl(verse_card, "SCRIPTURE", F_U, 34, Color(0.55, 0.32, 0.12), Rect2(0, 36, 940, 44), HORIZONTAL_ALIGNMENT_CENTER)
	verse_text = lbl(verse_card, "", F_I, 52, Color(0.2, 0.1, 0.04), Rect2(60, 110, 820, 560), HORIZONTAL_ALIGNMENT_CENTER, true)
	verse_ref = lbl(verse_card, "", F_T, 44, Color(0.45, 0.2, 0.08), Rect2(0, 690, 940, 60), HORIZONTAL_ALIGNMENT_CENTER)
	verse_card.visible = false; verse_card.modulate.a = 0.0

func verse(id: String) -> void:
	var d: Dictionary = Game.lines[id]
	var dur: float = Audio.play_voice(id)
	verse_text.text = d.text
	verse_ref.text = d.ref
	var fs := 52 if d.text.length() < 140 else (44 if d.text.length() < 230 else 38)
	verse_text.add_theme_font_size_override("font_size", fs)
	verse_card.visible = true; adv.visible = true
	verse_card.scale = Vector2(0.94, 0.94); verse_card.pivot_offset = verse_card.size * 0.5
	var tw := create_tween().set_parallel(true); tw.tween_property(verse_card, "modulate:a", 1.0, 0.45); tw.tween_property(verse_card, "scale", Vector2.ONE, 0.45)
	await _wait_tap_or(maxf(dur, 2.5) + 1.2)
	Audio.stop_voice()
	var t2 := create_tween(); t2.tween_property(verse_card, "modulate:a", 0.0, 0.35); await t2.finished
	verse_card.visible = false; adv.visible = false

# ---------- misc overlays
func _build_misc() -> void:
	toast_panel = panel(bot, Rect2(90, 1640, 900, 120), Color(0.1, 0.06, 0.04, 0.82), Color(0.93, 0.74, 0.34, 0.7), 30)
	toast_lbl = lbl(toast_panel, "", F_S, 42, Color(1, 0.95, 0.8), Rect2(20, 10, 860, 100), HORIZONTAL_ALIGNMENT_CENTER, true)
	toast_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; toast_panel.modulate.a = 0.0
	area_lbl = lbl(top, "", F_T, 96, Color(1, 0.93, 0.7), Rect2(0, 450, 1080, 120), HORIZONTAL_ALIGNMENT_CENTER, false, 18)
	area_sub = lbl(top, "", F_S, 44, Color(1, 0.88, 0.62), Rect2(0, 570, 1080, 60), HORIZONTAL_ALIGNMENT_CENTER, false, 10)
	area_lbl.modulate.a = 0.0; area_sub.modulate.a = 0.0
	pour_panel = panel(top, Rect2(60, 250, 680, 150), Color(0.1, 0.06, 0.04, 0.85), Color(0.93, 0.74, 0.34), 30)
	pour_lbl = lbl(pour_panel, "", F_U, 46, Color(1, 0.95, 0.8), Rect2(0, 14, 680, 56), HORIZONTAL_ALIGNMENT_CENTER)
	pour_bar = ColorRect.new(); pour_bar.color = Color(0.25, 0.18, 0.12); pour_bar.position = Vector2(50, 92); pour_bar.size = Vector2(580, 34); pour_panel.add_child(pour_bar)
	pour_fill = ColorRect.new(); pour_fill.color = Color(0.4, 0.68, 0.92); pour_fill.position = Vector2(50, 92); pour_fill.size = Vector2(0, 34); pour_panel.add_child(pour_fill)
	pour_panel.visible = false
	clue_panel = panel(top, Rect2(60, 250, 680, 190), Color(0.1, 0.06, 0.04, 0.85), Color(0.93, 0.74, 0.34), 30)
	lbl(clue_panel, "THE SIGN  \u00B7  Luke 2:12", F_U, 32, Color(0.93, 0.74, 0.34), Rect2(28, 8, 620, 40))
	for i in 2:
		var dot := ColorRect.new(); dot.size = Vector2(34, 34); dot.position = Vector2(34, 62 + i * 58); dot.color = Color(0.3, 0.24, 0.18); clue_panel.add_child(dot); clue_dots.append(dot)
		clue_lbls.append(lbl(clue_panel, ["Swaddling clothes", "A manger"][i], F_S, 42, Color(1, 0.95, 0.82), Rect2(90, 54 + i * 58, 560, 50)))
	clue_panel.visible = false
	choice_grp = Control.new(); choice_grp.mouse_filter = Control.MOUSE_FILTER_IGNORE; choice_grp.size = Vector2(1080, 1920); bot.add_child(choice_grp); choice_grp.visible = false
	fade_rect = ColorRect.new(); fade_rect.color = Color(0.05, 0.03, 0.02, 1.0); fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT); fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)

func fade(to: float, t := 0.8) -> void:
	var tw := create_tween(); tw.tween_property(fade_rect, "color:a", to, t); await tw.finished

func toast(t: String, secs := 3.0) -> void:
	toast_lbl.text = t
	if toast_tw: toast_tw.kill()
	var tw := create_tween(); toast_tw = tw; tw.tween_property(toast_panel, "modulate:a", 1.0, 0.3); tw.tween_interval(secs); tw.tween_property(toast_panel, "modulate:a", 0.0, 0.5)

func area_card(t: String, sub: String) -> void:
	area_lbl.text = t; area_sub.text = sub
	var tw := create_tween().set_parallel(true)
	tw.tween_property(area_lbl, "modulate:a", 1.0, 0.8); tw.tween_property(area_sub, "modulate:a", 1.0, 1.0)
	tw.chain().tween_interval(2.4)
	tw.chain().tween_property(area_lbl, "modulate:a", 0.0, 1.0); tw.parallel().tween_property(area_sub, "modulate:a", 0.0, 1.0)

func show_clues(on: bool) -> void:
	clue_panel.visible = on
## What this stable has: 1 = here, 0 = not here, -1 = not looked at yet.
func set_clues(cloth: int, manger: int) -> void:
	for i in 2:
		var v: int = [cloth, manger][i]
		clue_dots[i].color = [Color(0.3, 0.24, 0.18), Color(0.55, 0.2, 0.16), Color(0.95, 0.78, 0.3)][v + 1]
		clue_lbls[i].add_theme_color_override("font_color", Color(1, 0.95, 0.82) if v != 0 else Color(0.78, 0.6, 0.55))
		clue_lbls[i].text = ["Swaddling clothes", "A manger"][i] + ("" if v != 0 else "  \u2014 not here")

## A few big buttons; none is wrong. Returns the index tapped.
func choose(opts: Array) -> int:
	_choice = -1
	for c in choice_grp.get_children(): c.queue_free()
	for i in opts.size():
		var idx := i
		var b := btn(choice_grp, "choice%d" % i, opts[i], Rect2(150, 1320 + i * 150, 780, 130), "gold", 64)
		b.pressed.connect(func(): _choice = idx)
	choice_grp.visible = true
	while _choice < 0: await Game.frame(self)
	choice_grp.visible = false
	for c in choice_grp.get_children(): c.queue_free()
	return _choice

func show_pour(on: bool) -> void:
	pour_panel.visible = on
func set_pour(n: int, total: int, label := "Tap a waterpot to pour") -> void:
	pour_lbl.text = "%s   %d / %d" % [label, n, total]; pour_fill.size.x = 580.0 * float(n) / total

# ---------- title / name / end
func _build_title() -> void:
	title_grp = Control.new(); title_grp.mouse_filter = Control.MOUSE_FILTER_IGNORE; title_grp.size = Vector2(1080, 1920); mid.add_child(title_grp)
	var shade := ColorRect.new(); shade.color = Color(0.1, 0.05, 0.02, 0.38); shade.size = Vector2(1080, 1920); shade.position = Vector2(0, 0); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE; title_grp.add_child(shade)
	lbl(title_grp, "A JOURNEY WITH JESUS", F_U, 44, Color(1, 0.86, 0.5), Rect2(0, 330, 1080, 56), HORIZONTAL_ALIGNMENT_CENTER, false, 10)
	lbl(title_grp, "Walk With Him", F_T, 150, Color(1, 0.94, 0.76), Rect2(0, 390, 1080, 190), HORIZONTAL_ALIGNMENT_CENTER, false, 24)
	lbl(title_grp, "Bethlehem to Cana", F_S, 50, Color(1, 0.88, 0.62), Rect2(0, 590, 1080, 66), HORIZONTAL_ALIGNMENT_CENTER, false, 12)
	cont_info = lbl(title_grp, "", F_S, 40, Color(1, 0.9, 0.66), Rect2(0, 1160, 1080, 56), HORIZONTAL_ALIGNMENT_CENTER, false, 10)
	cont_btn = btn(title_grp, "continue", "Continue", Rect2(290, 1230, 500, 150), "gold", 78); cont_btn.pressed.connect(func(): continue_pressed.emit())
	begin_btn = btn(title_grp, "begin", "Begin", Rect2(290, 1280, 500, 150), "gold", 78); begin_btn.pressed.connect(func(): begin_pressed.emit())
	chap_btn = btn(title_grp, "chapters", "Chapters", Rect2(340, 1450, 400, 100), "dark", 54); chap_btn.pressed.connect(func(): open_chapters(true))
	credit_lbl = lbl(title_grp, "Scripture: King James Version", F_U, 32, Color(1, 0.9, 0.7), Rect2(0, 1470, 1080, 44), HORIZONTAL_ALIGNMENT_CENTER, false, 8)
	title_grp.visible = false

## `info` non-empty = a saved game exists: show Continue (with that text) above New Game.
func show_title(v: bool, info := "") -> void:
	title_grp.visible = v
	var has := info != ""
	cont_btn.visible = has; cont_info.visible = has; cont_info.text = info
	if has:
		begin_btn.position = Vector2(290, 1410); begin_btn.size = Vector2(500, 120); begin_btn.set_label("New Game"); begin_btn.style = "dark"; begin_btn.font_size = 60; chap_btn.position.y = 1560; credit_lbl.position.y = 1710
	else:
		begin_btn.position = Vector2(290, 1280); begin_btn.size = Vector2(500, 150); begin_btn.set_label("Begin"); begin_btn.style = "gold"; begin_btn.font_size = 78; chap_btn.position.y = 1460; credit_lbl.position.y = 1620
	begin_btn.queue_redraw()

func _build_chapters() -> void:
	chap_grp = Control.new(); chap_grp.mouse_filter = Control.MOUSE_FILTER_IGNORE; chap_grp.size = Vector2(1080, 1920); mid.add_child(chap_grp)
	var sh := ColorRect.new(); sh.color = Color(0.05, 0.03, 0.02, 0.85); sh.position = Vector2(-300, -1200); sh.size = Vector2(1680, 4400); sh.mouse_filter = Control.MOUSE_FILTER_IGNORE; chap_grp.add_child(sh)
	btn(chap_grp, "chap_block", "", Rect2(-300, -1200, 1680, 4400), "ghost")
	var p := panel(chap_grp, Rect2(90, 190, 900, 1500), Color(0.1, 0.06, 0.04, 0.95), Color(0.93, 0.74, 0.34), 40)
	lbl(p, "Chapters", F_T, 84, Color(1, 0.92, 0.7), Rect2(0, 24, 900, 110), HORIZONTAL_ALIGNMENT_CENTER)
	for i in CHAPTERS.size():
		var sid: String = CHAPTERS[i][0]
		var b := btn(p, "chap_" + sid, CHAPTERS[i][1], Rect2(70, 150 + i * 150, 760, 130), "dark", 58)
		b.pressed.connect(func(): open_chapters(false); chapter_chosen.emit(sid))
	lbl(p, "Chapters 6 and 7 are still to come.", F_S, 34, Color(0.8, 0.68, 0.45), Rect2(40, 1230, 820, 50), HORIZONTAL_ALIGNMENT_CENTER)
	var cb := btn(p, "chap_close", "Close", Rect2(200, 1320, 500, 120), "gold", 64); cb.pressed.connect(func(): open_chapters(false))
	chap_grp.visible = false

func open_chapters(v: bool) -> void:
	chap_open = v; chap_grp.visible = v; Touch.reset()

func _build_name() -> void:
	name_grp = Control.new(); name_grp.mouse_filter = Control.MOUSE_FILTER_IGNORE; name_grp.size = Vector2(1080, 1920); mid.add_child(name_grp)
	var p := panel(name_grp, Rect2(50, 330, 980, 1260), Color(0.1, 0.06, 0.04, 0.9), Color(0.93, 0.74, 0.34), 40)
	lbl(p, "Who walks with Him?", F_T, 74, Color(1, 0.92, 0.7), Rect2(0, 36, 980, 100), HORIZONTAL_ALIGNMENT_CENTER)
	lbl(p, "You are a shepherd's child of Bethlehem.", F_S, 38, Color(0.85, 0.75, 0.55), Rect2(0, 130, 980, 50), HORIZONTAL_ALIGNMENT_CENTER)
	boy_btn = btn(p, "boy", "Boy", Rect2(110, 210, 350, 110), "dark", 56); girl_btn = btn(p, "girl", "Girl", Rect2(520, 210, 350, 110), "dark", 56)
	boy_btn.pressed.connect(func(): _set_girl(false)); girl_btn.pressed.connect(func(): _set_girl(true))
	for i in 8:
		var c := btn(p, "chip%d" % i, "", Rect2(70 + (i % 2) * 450, 370 + (i / 2) * 124, 410, 104), "dark", 54)
		var idx := i; c.pressed.connect(func(): _pick_name(idx)); chips.append(c)
	var go := btn(p, "go", "Walk", Rect2(240, 1090, 500, 130), "gold", 74); go.pressed.connect(func(): name_chosen.emit())
	name_grp.visible = false

func show_name(v: bool) -> void:
	name_grp.visible = v
	if v: _set_girl(Game.player_girl)

func _set_girl(g: bool) -> void:
	Game.player_girl = g; boy_btn.set_on(not g); girl_btn.set_on(g)
	var nm: Array = Game.names()
	for i in 8: chips[i].set_label(nm[i])
	_pick_name(0)

func _pick_name(i: int) -> void:
	name_idx = i; Game.player_name = Game.names()[i]
	for j in 8: chips[j].set_on(j == i)

func _build_end() -> void:
	end_grp = Control.new(); end_grp.mouse_filter = Control.MOUSE_FILTER_IGNORE; end_grp.size = Vector2(1080, 1920); mid.add_child(end_grp)
	var sh := ColorRect.new(); sh.color = Color(0.08, 0.04, 0.02, 0.62); sh.size = Vector2(1080, 1920); sh.mouse_filter = Control.MOUSE_FILTER_IGNORE; end_grp.add_child(sh)
	var p := panel(end_grp, Rect2(60, 400, 960, 1020), Color(0.95, 0.88, 0.7, 0.98), Color(0.55, 0.32, 0.12), 40, 6)
	lbl(p, "The Beginning of Miracles", F_T, 66, Color(0.4, 0.18, 0.06), Rect2(0, 44, 960, 90), HORIZONTAL_ALIGNMENT_CENTER)
	var d: Dictionary = Game.lines.get("n_j2_11", {"text": "", "ref": ""})
	lbl(p, d.text, F_I, 46, Color(0.2, 0.1, 0.04), Rect2(70, 170, 820, 340), HORIZONTAL_ALIGNMENT_CENTER, true)
	lbl(p, d.ref, F_T, 40, Color(0.45, 0.2, 0.08), Rect2(0, 520, 960, 56), HORIZONTAL_ALIGNMENT_CENTER)
	end_grp.set_meta("scrolls", lbl(p, "", F_U, 44, Color(0.4, 0.18, 0.06), Rect2(0, 620, 960, 60), HORIZONTAL_ALIGNMENT_CENTER))
	lbl(p, "End of this part of the journey. Thank you for walking.", F_S, 36, Color(0.4, 0.25, 0.12), Rect2(40, 700, 880, 100), HORIZONTAL_ALIGNMENT_CENTER, true)
	var b := btn(p, "again", "Walk again", Rect2(230, 840, 500, 130), "gold", 70); b.pressed.connect(func(): again_pressed.emit())
	end_grp.visible = false

func show_end() -> void:
	end_grp.get_meta("scrolls").text = "Scrolls kept: %d of 3" % Game.scrolls.size()
	end_grp.visible = true; end_grp.modulate.a = 0.0; create_tween().tween_property(end_grp, "modulate:a", 1.0, 0.8)

# ---------- joystick drawing
const _JoyDraw = preload("res://scripts/joydraw.gd")
