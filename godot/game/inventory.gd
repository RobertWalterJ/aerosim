class_name Inventory
extends RefCounted
## The pilot's kit, bought on Facade (session B): drones, camera add-ons, motor upgrades and parts.
##
## Base airframes are always available; the Raptor and the Night Owl are marketplace drones. Motor upgrades are fitted
## per airframe and applied when the airframe is built, so the physics sees a slightly stronger version rather than the
## shop UI pretending. Everything is saved to user://facade_kit.cfg.

const SAVE := "user://facade_kit.cfg"
const BASE_DRONES := ["mini", "freestyle", "race", "cinewhoop", "cinema", "wing"]

var _drones: Array[String] = []
var _addons: Array[String] = []
var _motors: Dictionary = {}      # airframe id -> item id
var _battery := false

func setup() -> void:
	_load()

func owns_drone(id: String) -> bool:
	return id in BASE_DRONES or id in _drones

func has_addon(id: String) -> bool:
	return id in _addons

func motor_for(id: String) -> String:
	return str(_motors.get(id, ""))

func has_battery() -> bool:
	return _battery

func purchased_drones() -> Array[String]:
	return _drones.duplicate()

func available_drones() -> Array:
	var out: Array = BASE_DRONES.duplicate()
	for d in _drones:
		if not d in out:
			out.append(d)
	return out

func owns_item(item: Dictionary) -> bool:
	match str(item.get("kind", "")):
		"drone":
			return owns_drone(str(item.get("target", "")))
		"camera":
			return has_addon(str(item.get("id", "")))
		"motor":
			return motor_for(str(item.get("target", ""))) == str(item.get("id", ""))
		"part":
			return _battery if str(item.get("target", "")) == "battery" else false
	return false

func add_purchase(item: Dictionary) -> void:
	match str(item.get("kind", "")):
		"drone":
			var d := str(item.get("target", ""))
			if d != "" and not d in _drones:
				_drones.append(d)
		"camera":
			var a := str(item.get("id", ""))
			if a != "" and not a in _addons:
				_addons.append(a)
		"motor":
			_motors[str(item.get("target", ""))] = str(item.get("id", ""))
		"part":
			if str(item.get("target", "")) == "battery":
				_battery = true
	_save()

## Called whenever an airframe is built. Returns the same dictionary with the kit applied.
func apply_airframe(af: Dictionary, id: String) -> Dictionary:
	if not _motors.is_empty() and _motors.has(id):
		af["twr"] = float(af.get("twr", 2.0)) * 1.12
		af["omegaMax"] = float(af.get("omegaMax", 2000.0)) * 1.08
		var lim: Dictionary = af.get("limits", {})
		for mode in lim.keys():
			var m: Dictionary = lim[mode]
			m["vH"] = float(m.get("vH", 10.0)) * 1.12
			m["vUp"] = float(m.get("vUp", 4.0)) * 1.12
			m["vDown"] = float(m.get("vDown", 4.0)) * 1.12
	if _battery:
		af["capacityAh"] = float(af.get("capacityAh", 1.0)) * 1.25
	return af

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("kit", "drones", _drones)
	cf.set_value("kit", "addons", _addons)
	cf.set_value("kit", "motors", _motors)
	cf.set_value("kit", "battery", _battery)
	cf.save(SAVE)

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) != OK:
		return
	_drones = cf.get_value("kit", "drones", [])
	_addons = cf.get_value("kit", "addons", [])
	_motors = cf.get_value("kit", "motors", {})
	_battery = bool(cf.get_value("kit", "battery", false))

func stats() -> Dictionary:
	return {"drones": _drones, "addons": _addons, "motors": _motors, "battery": _battery}
