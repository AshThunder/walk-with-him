class_name Roads
extends RefCounted
## The roads you lead the flock along: one hand-set road for the story and a date-seeded Road of the Day. A road is a config (Dictionary);
## build() lays the land for it and returns the layout that Flock needs. Flat colours only.
const P = preload("res://scripts/person.gd")
const PR = preload("res://scripts/props.gd")
const NIGHT := Color(0.05, 0.07, 0.16)
const Z0 := 30.0              # where the road starts
const Z1 := -34.0             # the camp at its end is a little beyond this
const NAMES := ["The Olive Road", "The Dry Ford", "The Terraces", "The Wheat Road", "The High Pasture", "The Cedar Lane", "The Spring Road"]

## Light moods: a = start of the road, b = just before dusk, end = when the flock arrives. [sun colour, energy, rotation, ambient, ambient energy, background]
static func pal(n: String) -> Dictionary:
	match n:
		"dawn": return {"a": [Color(1.0, 0.78, 0.65), 0.95, Vector3(-18, -70, 0), Color(0.62, 0.55, 0.62), 0.9, Color(0.9, 0.72, 0.7)],
			"b": [Color(1.0, 0.9, 0.75), 1.2, Vector3(-38, -70, 0), Color(0.66, 0.64, 0.62), 0.95, Color(0.85, 0.82, 0.74)],
			"end": [Color(1.0, 0.95, 0.82), 1.3, Vector3(-52, -50, 0), Color(0.7, 0.68, 0.65), 1.0, Color(0.8, 0.85, 0.8)],
			"ground": Color(0.95, 0.9, 0.82), "path": Color(0.98, 0.9, 0.78), "hill": Color(0.45, 0.4, 0.42), "stone": Color(0.95, 0.88, 0.8)}
		"noon": return {"a": [Color(1.0, 0.97, 0.88), 1.35, Vector3(-58, -40, 0), Color(0.66, 0.68, 0.7), 1.0, Color(0.64, 0.78, 0.9)],
			"b": [Color(1.0, 0.9, 0.72), 1.2, Vector3(-40, -45, 0), Color(0.64, 0.62, 0.6), 0.95, Color(0.8, 0.76, 0.68)],
			"end": [Color(1.0, 0.76, 0.5), 1.1, Vector3(-20, -55, 0), Color(0.58, 0.48, 0.46), 0.9, Color(0.9, 0.62, 0.45)],
			"ground": Color(1.0, 1.0, 0.92), "path": Color(1.0, 0.94, 0.82), "hill": Color(0.5, 0.5, 0.4), "stone": Color(1.0, 0.96, 0.88)}
	return {"a": [Color(1.0, 0.84, 0.6), 1.25, Vector3(-30, -60, 0), Color(0.6, 0.52, 0.5), 0.95, Color(0.93, 0.7, 0.5)],
		"b": [Color(1.0, 0.62, 0.38), 1.0, Vector3(-14, -60, 0), Color(0.5, 0.4, 0.45), 0.85, Color(0.7, 0.4, 0.35)],
		"end": [Color(0.55, 0.66, 1.0), 0.7, Vector3(-55, -30, 0), Color(0.3, 0.36, 0.6), 0.95, NIGHT],
		"ground": Color(1.0, 0.84, 0.66), "path": Color(1.0, 0.86, 0.68), "hill": Color(0.42, 0.3, 0.3), "stone": Color(1.0, 0.84, 0.72)}

static func story_cfg() -> Dictionary:
	return {"id": "road_field", "title": "The Night Field", "sub": "Bethlehem  \u00B7  Luke 2", "seed": 7, "pal": "dusk", "start": 12, "strays": 26, "wolves": 2,
		"need": 28, "daylight": 190.0, "bend": 2.4, "walls": 1, "trees": 1.0}

static func daily_cfg(date: String) -> Dictionary:
	var sd := int(date.replace("-", ""))
	var r := RandomNumberGenerator.new(); r.seed = sd
	var strays := r.randi_range(16, 26)
	var start := clampi(Game.roster.size(), 8, 20)
	var wolves: int = [0, 1, 1, 2][r.randi() % 4]
	var pl: String = ["dawn", "noon", "dusk"][r.randi() % 3]
	return {"id": "daily", "title": NAMES[sd % NAMES.size()], "sub": "Road of the Day  \u00B7  " + date, "seed": sd, "pal": pl, "start": start, "strays": strays, "wolves": wolves,
		"need": int(round((start + strays) * 0.72)), "daylight": float(r.randi_range(140, 190)), "bend": r.randf_range(1.4, 3.4), "walls": r.randi_range(0, 2), "trees": r.randf_range(0.6, 1.4)}

static func road_x(l: Dictionary, z: float) -> float:
	var fade := clampf((z - float(l.goal.z)) / 12.0, 0.0, 1.0)
	return float(l.bend) * sin(z * float(l.freq) + float(l.phase)) * fade

static func build(w: World, c: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed = int(c.seed)
	var pa := pal(c.pal)
	w.clear_area(); w.area = "fields"; w.yaw = 0.0; w.bounds = Rect2(-10.5, -46.0, 21.0, 80.0)
	w.rng.seed = int(c.seed) + 3
	var a: Array = pa.a
	w.mood(a[0], a[1], a[2], a[3], a[4], a[5])
	w.ground("dry_grass", pa.ground, 260.0, 7.0)
	var hc: Color = pa.hill
	w.hill(Vector3(-24, -1, -56), 20, 7, hc); w.hill(Vector3(22, -1, -58), 22, 8, hc.darkened(0.1)); w.hill(Vector3(0, -2, -66), 32, 9, hc.lightened(0.05))
	w.hill(Vector3(-34, -1, 10), 16, 5, hc.darkened(0.06)); w.hill(Vector3(34, -1, -10), 18, 6, hc)
	var lay := {"bend": c.bend, "freq": rng.randf_range(0.16, 0.22), "phase": rng.randf() * TAU, "goal": Vector3(0, 0, -37.0)}
	lay["start"] = Vector3(road_x(lay, Z0), 0, Z0)
	var pts: Array = []
	var z := Z0 + 4.0
	while z > -46.0:
		pts.append(Vector3(road_x(lay, z), 0, z)); z -= 5.0
	lay["road"] = PR.ribbon(w.root, pts, 3.6, "path", pa.path)
	# the camp at the end of the road: a patch of trodden ground, a low fence with a wide gap, two lanterns, the fire and the shepherds
	PR.tbox(w.root, Vector3(13.0, 0.04, 11.0), Vector3(0, 0.02, -38.0), "dry_grass", Color(0.8, 0.72, 0.52).lerp(pa.ground, 0.4), 0.5)
	Areas.fence(w, Vector3(-9.8, 0, -30.0), Vector3(-3.6, 0, -30.0)); Areas.fence(w, Vector3(3.6, 0, -30.0), Vector3(9.8, 0, -30.0))
	Areas.lantern(w, Vector3(-3.4, 0, -29.2), 2.6); Areas.lantern(w, Vector3(3.4, 0, -29.2), 2.6)
	w.add_circle(Vector3(-3.4, 0, -29.2), 0.25); w.add_circle(Vector3(3.4, 0, -29.2), 0.25)
	Areas.campfire(w, Vector3(0, 0, -38.0))
	var shep := {"robe": Color(0.5, 0.4, 0.3), "sash": Color(0.35, 0.2, 0.12), "cloth": Color(0.78, 0.72, 0.6), "beard": true, "hair": Color(0.3, 0.25, 0.2), "scale": 0.98, "staff": true, "label": false}
	var i := 0
	for p in [Vector3(-2.3, 0, -39.4), Vector3(2.2, 0, -39.6), Vector3(0.2, 0, -41.4)]:
		w.person(shep, p, Areas.rad2yaw(Vector3(0, 0, -38.0) - p), "sh%d" % i); i += 1
	# walls with a wide gap the flock has to be led through
	var gz := -8.0
	var wl: int = int(c.walls)
	if wl >= 1:
		var gx := road_x(lay, gz)
		Areas.fence(w, Vector3(-10.2, 0, gz), Vector3(gx - 2.7, 0, gz)); Areas.fence(w, Vector3(gx + 2.7, 0, gz), Vector3(10.2, 0, gz))
		w.rocks([Vector3(gx - 3.4, 0, gz + 0.2), Vector3(gx + 3.4, 0, gz - 0.2)], pa.stone)
	if wl >= 2:
		var gz2 := -21.0
		var gx2 := -5.5 if road_x(lay, gz2) > 0.0 else 5.5
		Areas.fence(w, Vector3(-10.2, 0, gz2), Vector3(gx2 - 2.7, 0, gz2)); Areas.fence(w, Vector3(gx2 + 2.7, 0, gz2), Vector3(10.2, 0, gz2))
	# trees and rocks standing in the field (the flock goes round them)
	var nt := int(round(9.0 * float(c.trees)))
	var tried := 0; var placed := 0
	while placed < nt and tried < 200:
		tried += 1
		var zz := rng.randf_range(Z0 - 6.0, -27.0); var side := -1.0 if rng.randi() % 2 == 0 else 1.0
		var xx := road_x(lay, zz) + side * rng.randf_range(4.8, 7.6)
		if absf(zz - gz) < 3.0 or absf(zz + 21.0) < 3.0 or absf(xx) > 9.6: continue
		w.add_tree("olive" if rng.randf() < 0.65 else "cypress", Vector3(xx, 0, zz), rng.randf_range(0.8, 1.1)); placed += 1
	var rk: Array = []
	for k in 8:
		var zz := rng.randf_range(Z0 - 6.0, -27.0); var xx := road_x(lay, zz) + (-1.0 if k % 2 == 0 else 1.0) * rng.randf_range(3.2, 7.0)
		if absf(zz - gz) < 3.0 or absf(xx) > 9.6: continue
		rk.append(Vector3(xx, 0, zz))
	w.rocks(rk, pa.stone)
	w.ring_scenery(w.bounds, 26, ["olive", "cypress"])
	# ground cover that stays off the road
	var gp: Array = []; var bp: Array = []
	for k in 150:
		var zz := rng.randf_range(Z0 + 2.0, -44.0); var xx := rng.randf_range(-10.3, 10.3)
		if absf(xx - road_x(lay, zz)) < 2.1: continue
		(gp if k % 6 != 0 else bp).append(Vector3(xx, 0, zz))
	w.scatter("res://assets/nature/grass_large.glb", gp, Color(0.78, 0.8, 0.6).lerp(pa.ground, 0.5), 0.8, 1.4)
	w.scatter("res://assets/nature/plant_bushSmall.glb", bp, Color(0.7, 0.75, 0.55).lerp(pa.ground, 0.4), 0.8, 1.3)
	w.flowers(Rect2(-10, -44, 20, 72), 36)
	w.player = w._make_player(lay.start, 0.0)
	return lay
