class_name RoadPath
extends RefCounted
## Spawn checks shared by road objects that move with the road (money, power-ups, hazards).


## Whether an object spawned at (x, spawn_y) can travel down to target_y without meeting an
## obstacle moving at obstacle_speed (a share of road speed). half_size is the room to keep
## clear around the object's path. Slower obstacles behind a new object can never catch it,
## so only the relative path up to target_y is checked.
static func is_clear(
	x: float,
	spawn_y: float,
	half_size: Vector2,
	target_y: float,
	obstacles: Array[Rect2],
	obstacle_speed: float,
	clearance: float
) -> bool:
	var travel := maxf(0.0, target_y - spawn_y)
	for obstacle in obstacles:
		if obstacle.end.x < x - half_size.x or obstacle.position.x > x + half_size.x:
			continue
		var start_gap := obstacle.get_center().y - spawn_y
		var end_gap := start_gap - travel * (1.0 - obstacle_speed)
		var needed := clearance + obstacle.size.y * 0.5 + half_size.y
		if minf(start_gap, end_gap) < needed and maxf(start_gap, end_gap) > -needed:
			return false
	return true
