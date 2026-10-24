class_name ClipLibrary
extends Node
## The rushes bin (session B): every video-mode recording becomes a small representative clip instead of a video file.
##
## A clip is a 480 x 270 JPEG thumbnail, a duration, the flight metadata and a short auto title. There is no video file,
## no frame sequence and no large buffer on disk. VidTube Studio shows the rushes as YouTube-like cards; Maya can cut one
## clip or string all the waiting rushes into a single polished video, which is also represented by its best thumbnail
## and a clip count. That keeps the channel fiction without filling user:// with gigabytes of footage.

const DIR := "user://clips"
const INDEX := "user://clips/index.json"
const MAX_CLIPS := 80

signal clip_saved(rec: Dictionary)

var _index: Array = []
var _next_id := 1
var _textures := {}

func setup() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_load_index()

func add_clip(img: Image, meta: Dictionary, duration: float) -> Dictionary:
	if img == null:
		return {}
	DirAccess.make_dir_recursive_absolute(DIR)
	var id := _next_id
	_next_id += 1
	var thumb := "%s/c%05d.jpg" % [DIR, id]
	var t := img.duplicate() as Image
	var w := 480
	var h := maxi(1, int(round(float(w) * float(img.get_height()) / maxf(float(img.get_width()), 1.0))))
	t.resize(w, h, Image.INTERPOLATE_LANCZOS)
	t.save_jpg(thumb, 0.82)
	var subjects: Array = meta.get("subjects", [])
	var title := "A clip from the valley"
	if not subjects.is_empty():
		title = str(subjects[0].get("name", title)).capitalize()
	var quality := 1.0 + minf(0.35, 0.08 * float(subjects.size()))
	if bool(meta.get("fireworks", false)) or bool(meta.get("storm", false)):
		quality += 0.12
	if bool(meta.get("night", false)):
		quality += 0.05
	var rec := {
		"id": id, "thumb": thumb, "duration": snappedf(maxf(duration, 0.4), 0.1),
		"title": title, "quality": snappedf(quality, 0.01), "meta": meta,
		"published": false, "used": false,
	}
	_index.append(rec)
	while _index.size() > MAX_CLIPS:
		var old: Dictionary = _index.pop_front()
		_remove_file(old)
	_save_index()
	clip_saved.emit(rec)
	return rec

func rushes() -> Array:
	var out: Array = []
	for rec in _index:
		if not bool(rec.get("published", false)):
			out.append(rec)
	return out

func all() -> Array:
	return _index.duplicate()

func mark_published(ids: Array, video_title := "") -> void:
	for rec in _index:
		if int(rec.get("id", -1)) in ids:
			rec["published"] = true
			rec["used"] = true
			if video_title != "":
				rec["used_in"] = video_title
	_save_index()

func texture_for(rec: Dictionary) -> Texture2D:
	var path := str(rec.get("thumb", ""))
	if path == "":
		return null
	if _textures.has(path):
		return _textures[path]
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null:
		return null
	var tex := ImageTexture.create_from_image(img)
	_textures[path] = tex
	return tex

func best_thumbnail(recs: Array) -> Dictionary:
	var best: Dictionary = {}
	var score := -1.0
	for r in recs:
		var q := float(r.get("quality", 1.0))
		if q > score:
			score = q
			best = r
	return best

func _remove_file(rec: Dictionary) -> void:
	var path := str(rec.get("thumb", ""))
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _save_index() -> void:
	var f := FileAccess.open(INDEX, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"next": _next_id, "clips": _index}))

func _load_index() -> void:
	_index = []
	_next_id = 1
	if not FileAccess.file_exists(INDEX):
		return
	var f := FileAccess.open(INDEX, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_next_id = int(parsed.get("next", 1))
		_index = parsed.get("clips", [])

func stats() -> Dictionary:
	return {"clips": _index.size(), "rushes": rushes().size()}
