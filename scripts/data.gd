extends Node
## Game data + session state (autoload "Game").
var kjv := {}
var lines := {}
var player_name := "Eli"
var player_girl := false
var scrolls := {}                 # key -> true
var age_stage := "adult"          # child (ch 1-6) | teen (ch 7) | adult (ch 8+); an old save without the field is an adult
var settings := {"music": true, "sfx": true, "voice": true}
const BOY_NAMES := ["Eli", "Asher", "Micah", "Jonah", "Reuben", "Levi", "Amos", "Nathan"]
const GIRL_NAMES := ["Tamar", "Ruth", "Leah", "Miriam", "Hannah", "Salome", "Talia", "Abigail"]
const SCROLL_KEYS := ["prov3_5", "ps119_105", "ps34_8"]
const DISPLAY := {"jesus": "Jesus", "mary": "Mary", "naomi": "Naomi", "steward": "Governor of the feast", "servant": "Servant", "guest": "Guest", "guestf": "Guest", "narrator": "", "shepherd": "Shepherd", "angel": "The angel of the Lord", "host": "The heavenly host", "seller": "Dove seller", "simeon": "Simeon", "anna": "Anna", "wise": "Wise man", "joseph": "Joseph"}

func _ready() -> void:
	kjv = _load_json("res://data/kjv.json")
	lines = _load_json("res://data/lines.json")

func _load_json(p: String) -> Dictionary:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null: push_error("missing " + p); return {}
	return JSON.parse_string(f.get_as_text())

func reset_progress() -> void:
	scrolls.clear(); age_stage = "child"

# ------------------------------------------------------------------ save file (user://, JSON, written atomically)
const SAVE_PATH := "user://walk_with_him_save.json"
const SAVE_TMP := "user://walk_with_him_save.tmp"
const SAVE_VERSION := 1
signal never                      # never emitted: a coroutine whose owner is gone parks here instead of resuming into a freed object

func read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH): return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null: return {}
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or int(d.get("v", 0)) != SAVE_VERSION or not d.has("stage") or not d.has("px") or not d.has("pz"): return {}
	return d

func has_save() -> bool:
	return not read_save().is_empty()

func write_save(d: Dictionary) -> bool:
	d["v"] = SAVE_VERSION
	var f := FileAccess.open(SAVE_TMP, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(d)); f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_TMP), ProjectSettings.globalize_path(SAVE_PATH)) == OK

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

# ------------------------------------------------------------------ coroutine helpers that are safe when the owner is freed (scene reload, return to title)
func alive(o: Variant) -> bool:
	return o != null and is_instance_valid(o) and (not (o is Node) or (o.is_inside_tree() and not o.is_queued_for_deletion()))

func sleep(owner: Variant, secs: float) -> void:
	await get_tree().create_timer(secs, false).timeout
	if not alive(owner): await never

func frame(owner: Variant) -> void:
	await get_tree().process_frame
	while get_tree().paused and alive(owner): await get_tree().process_frame
	if not alive(owner): await never

func names() -> Array:
	return GIRL_NAMES if player_girl else BOY_NAMES
