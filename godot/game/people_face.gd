class_name PeopleFace
extends Node
## Small face driver for a Blender 2 person: natural blinks at random intervals, and while the clip is a talking or
## singing one, the mouth moves through a few shapes. Uses the head_LOD0 blend shapes (blink, smile, mouth_open, mouth_o,
## mouth_e, mouth_mbp, brow_up). Stops working on its own when the LOD0 head is not visible (far away).

var _head: MeshInstance3D
var _idx := {}
var _rng := RandomNumberGenerator.new()
var _next_blink := 1.0
var _blink_t := -1.0
var _talk := false
var _mouth_t := 0.0
var _mouth := {"mouth_open": 0.0, "mouth_o": 0.0, "mouth_e": 0.0, "mouth_mbp": 0.0}
var _target := {"mouth_open": 0.0, "mouth_o": 0.0, "mouth_e": 0.0, "mouth_mbp": 0.0}
var _smile := 0.0

func setup(root: Node, clip: String, seed: int) -> void:
	_rng.seed = seed + 17
	_head = root.find_child("head_LOD0", true, false) as MeshInstance3D
	if _head != null and _head.mesh is ArrayMesh:
		var am := _head.mesh as ArrayMesh
		for i in am.get_blend_shape_count():
			_idx[String(am.get_blend_shape_name(i))] = i
	_talk = clip in ["talk", "sing"]
	_smile = 0.35 if clip in ["wave", "wave_up", "cheer", "clap", "flag_wave", "sing"] else (0.12 if clip in ["idle", "sit_mug", "talk"] else 0.0)
	_next_blink = _rng.randf_range(0.5, 4.0)

func _bs(nm: String, v: float) -> void:
	if _idx.has(nm):
		_head.set_blend_shape_value(_idx[nm], v)

func _process(dt: float) -> void:
	if _head == null or _idx.is_empty() or not _head.is_visible_in_tree():
		return
	_next_blink -= dt
	if _next_blink <= 0.0 and _blink_t < 0.0:
		_blink_t = 0.0
		_next_blink = _rng.randf_range(2.0, 6.0)
	var b := 0.0
	if _blink_t >= 0.0:
		_blink_t += dt
		b = clampf(1.0 - absf(_blink_t - 0.07) / 0.07, 0.0, 1.0)
		if _blink_t > 0.16:
			_blink_t = -1.0
	_bs("blink", b)
	_bs("smile", _smile)
	if _talk:
		_mouth_t -= dt
		if _mouth_t <= 0.0:
			_mouth_t = _rng.randf_range(0.07, 0.16)
			for k in _target: _target[k] = 0.0
			var pick := _rng.randi_range(0, 5)
			match pick:
				0, 1: _target["mouth_open"] = _rng.randf_range(0.4, 0.9)
				2: _target["mouth_o"] = _rng.randf_range(0.5, 0.9)
				3: _target["mouth_e"] = _rng.randf_range(0.5, 0.9)
				4: _target["mouth_mbp"] = 0.8
				_: pass
		for k in _mouth:
			_mouth[k] = lerpf(_mouth[k], _target[k], clampf(dt * 22.0, 0.0, 1.0))
			_bs(k, _mouth[k])
