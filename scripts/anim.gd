class_name Anim
extends Node3D
## Tiny per-node animation so scene builders do not need their own scripts. Modes: flicker (flames + a light), bob, spin, pulse.
var mode := "pulse"
var base_scale := Vector3.ONE
var base_y := 0.0
var amp := 0.1
var spd := 1.0
var light: Light3D = null
var light_base := 1.0
var _t := randf() * 10.0

static func make(parent: Node, m: String, a := 0.1, s := 1.0, pos := Vector3.ZERO) -> Anim:
	var n := Anim.new(); n.mode = m; n.amp = a; n.spd = s; n.position = pos; n.base_y = pos.y; parent.add_child(n); return n

func _process(dt: float) -> void:
	_t += dt
	match mode:
		"flicker":
			var f := 1.0 + sin(_t * 13.0) * 0.07 + sin(_t * 7.3) * 0.06 + sin(_t * 23.0) * 0.03
			scale = Vector3(base_scale.x * (2.0 - f), base_scale.y * f, base_scale.z * (2.0 - f))
			if light != null: light.light_energy = light_base * (0.92 + (f - 1.0) * 1.4)
		"bob": position.y = base_y + sin(_t * spd) * amp
		"spin": rotation.y += dt * spd
		"pulse": scale = base_scale * (1.0 + sin(_t * spd) * amp)
