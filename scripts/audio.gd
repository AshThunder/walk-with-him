extends Node
## Audio manager (autoload "Audio"): music with crossfade, pooled SFX, and voice lines by id.
## Voice lines live in audio/voice/<id>.ogg (placeholder Piper voices; overwrite the file to swap in recorded actors).
var _m: Array = []
var _cur := 0
var _sfx_pool: Array = []
var _voice: AudioStreamPlayer
var _cache := {}
var music_name := ""
var voice_id := ""
var _tw := {}
const MUSIC_DB := -9.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new(); p.volume_db = -60; add_child(p); _m.append(p)
	for i in 8:
		var p := AudioStreamPlayer.new(); add_child(p); _sfx_pool.append(p)
	_voice = AudioStreamPlayer.new(); add_child(_voice)

func _load(p: String) -> AudioStream:
	if not _cache.has(p):
		_cache[p] = load(p) if ResourceLoader.exists(p) else null
	return _cache[p]

func music(n: String, db := MUSIC_DB, fade := 1.6) -> void:
	if n == music_name: return
	music_name = n
	var old: AudioStreamPlayer = _m[_cur]
	_cur = 1 - _cur
	var nw: AudioStreamPlayer = _m[_cur]
	var s = _load("res://audio/music/%s.ogg" % n) if n != "" else null
	for pl in [old, nw]:                      # a fade still running on either player would stop the wrong track later
		if _tw.has(pl) and _tw[pl] != null and _tw[pl].is_valid(): _tw[pl].kill()
	var tw := create_tween().set_parallel(true)
	_tw[old] = tw
	tw.tween_property(old, "volume_db", -60.0, fade)
	if s != null:
		if s is AudioStreamOggVorbis: s.loop = true
		nw.stream = s; nw.volume_db = -60.0; nw.play()
		var tn := create_tween(); _tw[nw] = tn
		tn.tween_property(nw, "volume_db", db if Game.settings.music else -80.0, fade)
	tw.chain().tween_callback(old.stop)

func music_vol(db: float, t := 1.0) -> void:
	create_tween().tween_property(_m[_cur], "volume_db", db if Game.settings.music else -80.0, t)

func sfx(n: String, db := 0.0, pitch := 1.0) -> void:
	if not Game.settings.sfx: return
	var s = _load("res://audio/sfx/%s.ogg" % n)
	if s == null: return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = s; p.volume_db = db; p.pitch_scale = pitch; p.play(); return

func play_voice(id: String) -> float:
	stop_voice()
	var d = Game.lines.get(id, null)
	if d == null: return 1.5
	voice_id = id
	var s = _load("res://audio/voice/%s.ogg" % id)
	if s != null and Game.settings.voice:
		_voice.stream = s; _voice.volume_db = 0.0; _voice.play()
	return float(d.get("dur", 2.0))

func stop_voice() -> void:
	voice_id = ""
	if _voice.playing: _voice.stop()
