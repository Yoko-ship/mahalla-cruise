class_name WeatherRules
extends RefCounted
## Picks the weather and holiday for a day ("YYYY-MM-DD"). Holidays set their own weather.


## "navruz" (14–28 March), "independence" (30 August – 3 September), "new_year"
## (25 December – 7 January), or "".
static func holiday(day: String) -> String:
	var month := day.substr(5, 2).to_int()
	var date := day.substr(8, 2).to_int()
	if month == 3 and date >= 14 and date <= 28:
		return "navruz"
	if (month == 8 and date >= 30) or (month == 9 and date <= 3):
		return "independence"
	if (month == 12 and date >= 25) or (month == 1 and date <= 7):
		return "new_year"
	return ""


## "clear", "rain", "snow", "leaves", "blossom", or "confetti" for a drive on day; roll in
## [0, 1) decides between the season's chances.
static func pick(settings: WeatherSettings, day: String, roll: float) -> String:
	match holiday(day):
		"navruz":
			return "blossom"
		"independence":
			return "confetti"
		"new_year":
			return "snow"
	var month := day.substr(5, 2).to_int()
	if month == 12 or month <= 2:
		return "snow" if roll < settings.winter_snow_chance else "clear"
	if month <= 5:
		return "rain" if roll < settings.spring_rain_chance else "clear"
	if month >= 9:
		if roll < settings.autumn_rain_chance:
			return "rain"
		if roll < settings.autumn_rain_chance + settings.autumn_leaves_chance:
			return "leaves"
	return "clear"
