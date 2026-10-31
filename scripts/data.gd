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
	load_meta()

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

# ------------------------------------------------------------------ the keepsake file: flock, Memory Stones, journal, Road of the Day (kept apart from the checkpoint save, never reset by New Game)
const META_PATH := "user://walk_with_him_meta.json"
const META_TMP := "user://walk_with_him_meta.tmp"
const LAMB_NAMES := ["Pip", "Clover", "Bramble", "Dew", "Fern", "Tansy", "Wren", "Moss", "Juniper", "Sorrel", "Thistle", "Willow", "Posy", "Barley", "Nettle", "Rue", "Saffron", "Hazel", "Linnet", "Cricket", "Mint", "Basil", "Poppy", "Sage",
	"Lark", "Rosemary", "Burdock", "Marigold", "Flax", "Daisy", "Acorn", "Oat", "Primrose", "Wick", "Teasel", "Cobnut", "Rowan", "Bracken", "Tuft", "Snowdrop", "Quill", "Pebble", "Nutmeg", "Dandelion", "Heather", "Plum", "Bluebell", "Sparrow"]
var roster: Array = []            # the named flock, in the order the lambs were met
var stones: Array = []            # the Memory Stones carried: {id, ref, text, lamb, road}
var journal: Array = []           # [{title, text}] one page per camp
var daily_done := ""              # date of the last Road of the Day walked (YYYY-MM-DD); no streak is kept
var daily_total := 0
var tint := "plain"               # flock colour: plain | gold | rose (unlocked by stones)
var best := {}                    # road id -> goals met (0..3), only ever goes up

func reset_meta() -> void:
	roster = []; stones = []; journal = []; daily_done = ""; daily_total = 0; tint = "plain"; best = {}
	save_meta()

func load_meta() -> void:
	roster = []; stones = []; journal = []; daily_done = ""; daily_total = 0; tint = "plain"; best = {}
	if not FileAccess.file_exists(META_PATH): return
	var f := FileAccess.open(META_PATH, FileAccess.READ)
	if f == null: return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY: return
	roster = (d.get("roster", []) as Array).duplicate(); stones = (d.get("stones", []) as Array).duplicate(); journal = (d.get("journal", []) as Array).duplicate()
	daily_done = str(d.get("daily_done", "")); daily_total = int(d.get("daily_total", 0)); tint = str(d.get("tint", "plain")); best = (d.get("best", {}) as Dictionary).duplicate()

func save_meta() -> bool:
	var f := FileAccess.open(META_TMP, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify({"roster": roster, "stones": stones, "journal": journal, "daily_done": daily_done, "daily_total": daily_total, "tint": tint, "best": best})); f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(META_TMP), ProjectSettings.globalize_path(META_PATH)) == OK

## The i-th lamb's name. The first 48 are distinct; after that a number is added so no two lambs share a name.
func lamb_name(i: int) -> String:
	return LAMB_NAMES[i % LAMB_NAMES.size()] + ("" if i < LAMB_NAMES.size() else " %d" % (i / LAMB_NAMES.size() + 1))

func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

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
