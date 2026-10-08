class_name HazardSettings
extends Resource
## Potholes and road works near the centre line. Hitting one costs points, never the run.

const KINDS: Array[String] = ["pothole", "works"]

@export_range(0.0, 20000.0) var first_metres: float = 250.0
@export_range(20.0, 5000.0) var spawn_metres_min: float = 120.0
@export_range(20.0, 5000.0) var spawn_metres_max: float = 260.0
@export_range(0.0, 1.0) var works_chance: float = 0.35
@export_range(0, 1000) var pothole_penalty: int = 10
@export_range(0, 1000) var works_penalty: int = 20
@export var pothole_half_size := Vector2(15, 9)
@export var works_half_size := Vector2(22, 12)
## Potholes vary this far either side of the centre line; road works sit on it.
@export_range(0.0, 60.0) var centre_spread: float = 16.0
## Free road kept around traffic on a barrier's way to the player.
@export_range(0.0, 300.0) var traffic_clearance: float = 40.0
## A hazard never spawns this close (vertically) to a note or power-up.
@export_range(0.0, 300.0) var item_gap: float = 70.0
@export var spawn_y: float = -40.0
@export var despawn_y: float = 830.0


func penalty(kind: String) -> int:
	return works_penalty if kind == "works" else pothole_penalty


func half_size(kind: String) -> Vector2:
	return works_half_size if kind == "works" else pothole_half_size
