class_name PlateRules
extends RefCounted
## Uzbek private number plates, stored as codes like "01A777AA" (shown "01 A 777 AA"):
## rarity tiers, the daily auction, and choosing or buying a plate.

const TIERS: Array[String] = ["plate_common", "plate_nice", "plate_special", "plate_legendary"]


static func format(code: String) -> String:
	return "%s %s %s %s" % [code.substr(0, 2), code[2], code.substr(3, 3), code.substr(6, 2)]


## 0 common, 1 nice (mirrored digits or three equal letters), 2 special (three equal
## digits or 001–009), 3 legendary (special digits with three equal letters, or more).
static func tier(code: String) -> int:
	if not ProgressData.is_plate(code):
		return 0
	var digits := code.substr(3, 3)
	var letters := code[2] + code.substr(6, 2)
	var points := 0
	if digits[0] == digits[1] and digits[1] == digits[2]:
		points += 2
	elif digits[0] == digits[2]:
		points += 1
	if int(digits) <= 9:
		points += 2
	if letters[0] == letters[1] and letters[1] == letters[2]:
		points += 1
	return mini(points, 3)


## Today's three plates for a region: one common, one nice, and one special or legendary.
## The same day and region always give the same plates.
static func offers(settings: PlateSettings, region: String, day: String) -> Array[Dictionary]:
	var random := RandomNumberGenerator.new()
	random.seed = hash("plates:%s:%s" % [day, region])
	var result: Array[Dictionary] = []
	var top := 3 if random.randf() < settings.legendary_chance else 2
	for wanted: int in [0, 1, top]:
		var code := _make(random, settings.letters, region, wanted)
		result.append({"plate": code, "tier": tier(code), "price": settings.price_for(tier(code))})
	return result


## Selects an owned plate, or buys one of today's offers (which also selects it).
static func choose(
	settings: PlateSettings, store: LocalProgressStore, region: String, code: String, day: String
) -> bool:
	if code in store.owned_plates:
		if code != store.plate or store.has_unsaved_changes:
			store.update(func() -> void: store.plate = code)
		return true
	for offer in offers(settings, region, day):
		if offer.plate == code:
			return store.spend(
				offer.price,
				func() -> void:
					store.owned_plates.append(code)
					store.plate = code
			)
	return false


static func _make(
	random: RandomNumberGenerator, letters: String, region: String, wanted: int
) -> String:
	var pick := func() -> String: return letters[random.randi_range(0, letters.length() - 1)]
	var first: String = pick.call()
	var rest: String = pick.call() + pick.call()
	var digits := ""
	var same_digit := str(random.randi_range(1, 9))
	match wanted:
		3:
			digits = same_digit.repeat(3)
			rest = first + first
		2:
			digits = same_digit.repeat(3) if random.randf() < 0.6 else "00" + same_digit
		1:
			var outer := random.randi_range(1, 9)
			var middle := (outer + random.randi_range(1, 9)) % 10
			digits = "%d%d%d" % [outer, middle, outer]
		_:
			digits = "%03d" % random.randi_range(10, 999)
	var code := region + first + digits + rest
	# Plain draws can land on a rarer plate by chance; keep each slot at its tier.
	if tier(code) > wanted:
		return _make(random, letters, region, wanted)
	return code
