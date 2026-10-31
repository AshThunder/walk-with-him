extends Node
## Game data + session state (autoload "Game").
var kjv := {}
var lines := {}
var player_name := "Eli"
var player_girl := false
var scrolls := {}                 # key -> true
var settings := {"music": true, "sfx": true, "voice": true}
const BOY_NAMES := ["Eli", "Asher", "Micah", "Jonah", "Reuben", "Levi", "Amos", "Nathan"]
const GIRL_NAMES := ["Tamar", "Ruth", "Leah", "Miriam", "Hannah", "Salome", "Talia", "Abigail"]
const SCROLL_KEYS := ["prov3_5", "ps119_105", "ps34_8"]
const DISPLAY := {"jesus": "Jesus", "mary": "Mary", "naomi": "Naomi", "steward": "Governor of the feast", "servant": "Servant", "guest": "Guest", "guestf": "Guest", "narrator": ""}

func _ready() -> void:
	kjv = _load_json("res://data/kjv.json")
	lines = _load_json("res://data/lines.json")

func _load_json(p: String) -> Dictionary:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null: push_error("missing " + p); return {}
	return JSON.parse_string(f.get_as_text())

func reset_progress() -> void:
	scrolls.clear()

func names() -> Array:
	return GIRL_NAMES if player_girl else BOY_NAMES
