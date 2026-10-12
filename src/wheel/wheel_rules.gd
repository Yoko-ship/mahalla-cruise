class_name WheelRules
extends RefCounted
## The daily lucky wheel: whether today's spin is free, the spin itself (one write), and the
## power-up it may leave for the next drive. Main passes the settings and the store.


static func can_spin(store: LocalProgressStore, day: String) -> bool:
	return store.wheel_day != day


## Spins once for day: points go to the wallet, a power-up waits for the next drive (it
## replaces one already waiting). Returns whether a spin happened.
static func spin(
	settings: WheelSettings, store: LocalProgressStore, day: String, roll: float
) -> bool:
	if settings == null or settings.size() == 0 or not can_spin(store, day):
		return false
	var index := settings.pick(roll)
	store.update(
		func() -> void:
			store.wheel_day = day
			store.wheel_prize = index
			if settings.kinds[index] == "points":
				store.wallet = mini(store.wallet + settings.amounts[index], ProgressData.MAX_SCORE)
			else:
				store.next_boost = settings.kinds[index]
	)
	return true


## Takes the waiting power-up for a drive that is starting ("" when none), in one write.
static func take_boost(store: LocalProgressStore) -> String:
	var kind := store.next_boost
	if not kind.is_empty():
		store.update(func() -> void: store.next_boost = "")
	return kind


## For the start screen and the wheel: available (today's spin is free), prize (today's
## segment, or -1), and boost (the power-up waiting for the next drive, or "").
static func view(store: LocalProgressStore, day: String) -> Dictionary:
	return {
		"available": can_spin(store, day),
		"prize": store.wheel_prize if store.wheel_day == day else -1,
		"boost": store.next_boost,
	}
