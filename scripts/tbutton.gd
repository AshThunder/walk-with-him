class_name TButton
extends Control
## A touch button. Pressed look on finger-down, fires on lift inside. Never uses mouse events.
signal pressed
var label := ""
var disabled := false
var down := false
var on := false            # toggle state / selected state
var style := "gold"        # gold | dark | arrow
var font_size := 44
func _init(n := "", t := "", s := "gold") -> void:
	name = n; label = t; style = s; mouse_filter = Control.MOUSE_FILTER_IGNORE
func _ready() -> void:
	Touch.register(self)
	custom_minimum_size = size
func _exit_tree() -> void:
	Touch.unregister(self)
func hit_test(p: Vector2) -> bool:
	return get_global_rect().grow(14).has_point(p)
func set_down(v: bool) -> void:
	down = v; queue_redraw()
func fire() -> void:
	Audio.sfx("tap", -4.0); pressed.emit()
func set_label(t: String) -> void:
	label = t; queue_redraw()
func set_on(v: bool) -> void:
	on = v; queue_redraw()
func _draw() -> void:
	if style == "ghost": return
	var sb := StyleBoxFlat.new(); sb.set_corner_radius_all(int(minf(size.y * 0.3, 34))); sb.set_border_width_all(3)
	var txt := Color(0.15, 0.09, 0.04)
	if style == "gold":
		sb.bg_color = Color(0.93, 0.74, 0.34) if not down else Color(0.78, 0.58, 0.22); sb.border_color = Color(1, 0.93, 0.7)
		if on: sb.bg_color = Color(1.0, 0.86, 0.45)
	else:
		sb.bg_color = Color(0.12, 0.08, 0.06, 0.85) if not down else Color(0.3, 0.2, 0.1, 0.95); sb.border_color = Color(0.93, 0.74, 0.34, 0.9 if not on else 1.0)
		txt = Color(1.0, 0.9, 0.62)
		if on: sb.bg_color = Color(0.44, 0.28, 0.1, 0.95)
	if disabled: sb.bg_color = sb.bg_color.darkened(0.4)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var f: Font = load("res://fonts/BarlowCondensed-Bold.ttf")
	var fs := font_size
	var ts := f.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(f, Vector2((size.x - ts.x) * 0.5, (size.y + fs * 0.62) * 0.5 - 4), label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, txt)
