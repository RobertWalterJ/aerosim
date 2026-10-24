class_name PlayerProfile
extends RefCounted
## The pilot's identity (session B, playtest pass). One small profile saved in user://profile.cfg:
## a callsign for the phone and the credits, and an optional real name for a single minor festival character.
##
## Privacy rules:
## - the callsign is always player-chosen and editable;
## - the computer/account name is only a suggestion, never shown to other characters unless the player opts in;
## - the real name is used as a first name only, for one festival volunteer, and can be turned off again;
## - no network lookup, no analytics, nothing leaves this save.
##
## Detection is deliberately conservative: Windows gives USERNAME, other platforms give USER/LOGNAME. Generic account
## names (user, admin, owner, guest) are ignored, and only the first name is offered as a callsign.

const SAVE := "user://profile.cfg"
const MAX_CALLSIGN := 24
const MAX_REAL_NAME := 40
const GENERIC := ["user", "admin", "administrator", "owner", "guest", "default", "pc", "computer", "root"]

static var loaded := false
static var callsign := ""
static var real_name := ""
static var detected_name := ""
static var use_real_name := false

static func ensure_loaded() -> void:
	if loaded:
		return
	loaded = true
	detected_name = _detect_computer_name()
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK:
		callsign = _clean_callsign(str(cf.get_value("pilot", "callsign", "")))
		real_name = _clean_real_name(str(cf.get_value("pilot", "real_name", "")))
		use_real_name = bool(cf.get_value("pilot", "use_real_name", false))
	if callsign == "":
		callsign = _suggest_callsign()
	if real_name == "":
		real_name = detected_name

static func save() -> void:
	ensure_loaded()
	var cf := ConfigFile.new()
	cf.set_value("pilot", "callsign", callsign)
	cf.set_value("pilot", "use_real_name", use_real_name)
	# Do not persist a detected name until the player has opted in; then only the name they opted into.
	if use_real_name:
		cf.set_value("pilot", "real_name", real_name)
	else:
		cf.set_value("pilot", "real_name", "")
	cf.save(SAVE)

static func set_callsign(value: String) -> void:
	ensure_loaded()
	callsign = _clean_callsign(value)
	if callsign == "":
		callsign = "Pilot"
	save()

static func set_real_name(value: String) -> void:
	ensure_loaded()
	real_name = _clean_real_name(value)
	save()

static func set_use_real_name(on: bool) -> void:
	ensure_loaded()
	use_real_name = on
	if on and real_name == "":
		real_name = detected_name
	save()

static func display_name() -> String:
	ensure_loaded()
	return callsign

static func initials() -> String:
	ensure_loaded()
	var bits := callsign.split(" ", false)
	if bits.is_empty():
		return "YOU"
	if bits.size() == 1:
		return bits[0].substr(0, 2).to_upper()
	return (bits[0].substr(0, 1) + bits[bits.size() - 1].substr(0, 1)).to_upper()

static func has_computer_name() -> bool:
	ensure_loaded()
	return detected_name != ""

## The one-off minor character at the festival. Empty until the player opts in; then first name only.
static func festival_character_name() -> String:
	ensure_loaded()
	if not use_real_name:
		return ""
	var first := _first_name(real_name)
	if first == "":
		first = _first_name(detected_name)
	return first

## A short callsign for a line where a character addresses the pilot directly. Falls back to the old "pilot" wording.
static func address() -> String:
	ensure_loaded()
	if callsign == "" or callsign == "Pilot":
		return "pilot"
	return callsign

static func _detect_computer_name() -> String:
	for key in ["USERNAME", "USER", "LOGNAME"]:
		var raw := OS.get_environment(key).strip_edges()
		if raw == "":
			continue
		var clean := _clean_real_name(raw)
		if clean == "":
			continue
		var first := _first_name(clean).to_lower()
		if first in GENERIC:
			continue
		return clean
	return ""

static func _suggest_callsign() -> String:
	var first := _first_name(detected_name)
	if first == "":
		return "Pilot"
	return _clean_callsign(first)

static func _first_name(value: String) -> String:
	var bits := _clean_real_name(value).split(" ", false)
	return bits[0] if not bits.is_empty() else ""

static func _clean_callsign(value: String) -> String:
	var text := value.strip_edges().replace("\t", " ").replace("\n", " ")
	text = text.replace("  ", " ")
	return text.substr(0, MAX_CALLSIGN).strip_edges()

static func _clean_real_name(value: String) -> String:
	var text := value.strip_edges()
	for sep in ["_", ".", "-", ",", "\\", "/"]:
		text = text.replace(sep, " ")
	text = text.replace("\t", " ").replace("\n", " ")
	while text.contains("  "):
		text = text.replace("  ", " ")
	text = text.strip_edges()
	# Drop anything that is not a normal name character, so a machine name cannot become UI markup.
	var kept := ""
	for ch in text:
		if ch == " " or (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "'":
			kept += ch
	return kept.substr(0, MAX_REAL_NAME).strip_edges()
