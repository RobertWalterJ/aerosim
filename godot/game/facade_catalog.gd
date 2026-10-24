class_name FacadeCatalog
extends RefCounted
## The listings on Facade, the valley's classifieds board (session B). MugShot Motors is the slightly dodgy drone
## seller; the rest are farmers, students and people clearing out a garage.
##
## Prices are in channel money, the same pot VidTube Studio shows. Items are deliberately modest: the good drones cost
## several favours, the parts are one or two.

const ITEMS := [
	{
		"id": "drone_raptor", "kind": "drone", "target": "raptor",
		"title": "Raptor Race quad", "seller": "MugShot Motors", "place": "Ridge road",
		"condition": "Used, raced once", "price": 220,
		"desc": "Six cells, race-spec motors, no gimbal, no manners. Goes like a thrown brick and stops like one too. Spare props included.",
	},
	{
		"id": "drone_nightowl", "kind": "drone", "target": "nightowl",
		"title": "Night Owl long-range", "seller": "MugShot Motors", "place": "Ridge road",
		"condition": "Used, quiet", "price": 180,
		"desc": "A steady gimbal ship with a big battery and low-noise props. Made for the hours after the valley goes dark.",
	},
	{
		"id": "night_vision", "kind": "camera", "target": "night_vision",
		"title": "Night vision module", "seller": "MugShot Motors", "place": "Ridge road",
		"condition": "Tested, boxed", "price": 90,
		"desc": "A small low-light sensor for the gimbal. It turns the valley green. Grainy, but it sees.",
	},
	{
		"id": "thermal_camera", "kind": "camera", "target": "thermal_camera",
		"title": "Thermal camera module", "seller": "Alex", "place": "Halloway",
		"condition": "Calibrated", "price": 120,
		"desc": "A heat camera for the gimbal. It shows warm bodies through the dark. Riley's pasture job will show you how to use it, and the last flight needs it.",
	},
	{
		"id": "battery", "kind": "part", "target": "battery",
		"title": "High-capacity battery pack", "seller": "Alex", "place": "Halloway",
		"condition": "New cells", "price": 55,
		"desc": "A bigger pack that fits every airframe in the kit. More time in the air, a little more weight. Alex will not ask what it is for.",
	},
	{
		"id": "motor_mini", "kind": "motor", "target": "mini",
		"title": "Sport motors, Mini", "seller": "MugShot Motors", "place": "Ridge road",
		"condition": "Pulled, tested", "price": 55,
		"desc": "A set of motors out of a crashed sport quad. Quicker off the mark and a little faster flat out. Fits the Gimbal Mini.",
	},
	{
		"id": "motor_freestyle", "kind": "motor", "target": "freestyle",
		"title": "Freestyle race motors", "seller": "MugShot Motors", "place": "Ridge road",
		"condition": "Used, matched", "price": 75,
		"desc": "Four matched motors with a lot of punch left. The 5-inch will flip faster and climb harder.",
	},
	{
		"id": "motor_race", "kind": "motor", "target": "race",
		"title": "Race-spec motors", "seller": "MugShot Motors", "place": "Ridge road",
		"condition": "Race take-offs", "price": 95,
		"desc": "The fastest set on the board. More top end, less mercy. Fits the Race quad.",
	},
	{
		"id": "motor_raptor", "kind": "motor", "target": "raptor",
		"title": "Raptor tune", "seller": "MugShot Motors", "place": "Ridge road",
		"condition": "Bench tested", "price": 120, "requires": "raptor",
		"desc": "Motors and props for the Raptor, matched on the bench. You need the Raptor first.",
	},
	{
		"id": "motor_cinema", "kind": "motor", "target": "cinema",
		"title": "Heavy-lift motors", "seller": "Alex", "place": "Halloway",
		"condition": "New", "price": 85,
		"desc": "Stronger motors for the Cinema drone. Better climb and a little more speed, without making it nervous.",
	},
]

static func item(id: String) -> Dictionary:
	for it in ITEMS:
		if str(it["id"]) == id:
			return it
	return {}

static func by_kind(kind: String) -> Array:
	var out: Array = []
	for it in ITEMS:
		if kind == "" or str(it["kind"]) == kind:
			out.append(it)
	return out
