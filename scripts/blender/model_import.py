"""Bring a downloaded car model into the roster render scene (used by roster_cars.py).

The model is imported (FBX, OBJ, glTF/GLB, or .blend), its cameras and lights removed,
badges and logos hidden, then it is turned so its length runs along +Y with the nose
forward, scaled to the car's real length, centered, and set on the ground. Body paint,
glass, tyres, and plates are swapped for the shared render materials so every car is lit
and recolored the same way; lamps, trim, and interiors keep their own materials.
"""

import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

EXTENSIONS = (".blend", ".glb", ".gltf", ".fbx", ".obj")
# Material roles by name, checked in order; the first keyword found wins. Colored or clear
# lamp glass keeps its own material.
LAMP_WORDS = ("red", "orange", "amber", "clear", "light", "lamp", "stop", "fara", "povorot")
NAME_RULES = (
	("glass", ("glass", "window", "windscreen", "windshield", "steklo")),
	("plate", ("plate", "license", "licence", "registration", "nomer")),
	("rubber", ("tire", "tyre", "rubber", "shina")),
	("paint", ("carpaint", "car_paint", "paint", "body", "kuzov", "exterior", "shell")),
)
HIDDEN_WORDS = ("logo", "emblem", "badge", "decal", "sticker", "watermark")
# Badges and model lettering: small separate pieces in the middle of the rear face, above
# the bumper (metres, after placement).
BADGE_SIZE = 0.25
BADGE_HALF_WIDTH = 0.5
BADGE_DEPTH = 0.5
BADGE_MIN_HEIGHT = 0.72


def find_model(model_dir, car_id):
	"""<car_id>.<ext> in the folder, or a model inside a <car_id>/ folder (Sketchfab glTF)."""
	for extension in EXTENSIONS:
		path = Path(model_dir) / f"{car_id}{extension}"
		if path.exists():
			return path
	folder = Path(model_dir) / car_id
	if folder.is_dir():
		for extension in EXTENSIONS:
			found = sorted(folder.rglob(f"*{extension}"))
			if found:
				return found[0]
	return None


def _import(path):
	before = set(bpy.data.objects)
	suffix = path.suffix.lower()
	if suffix == ".fbx":
		bpy.ops.import_scene.fbx(filepath=str(path))
	elif suffix == ".obj":
		bpy.ops.wm.obj_import(filepath=str(path))
	elif suffix in (".glb", ".gltf"):
		bpy.ops.import_scene.gltf(filepath=str(path))
	else:
		with bpy.data.libraries.load(str(path)) as (source, target):
			target.objects = source.objects
		for obj in target.objects:
			if obj is not None:
				bpy.context.scene.collection.objects.link(obj)
	return [obj for obj in bpy.data.objects if obj not in before]


def _bounds(meshes):
	bpy.context.view_layer.update()
	corners = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
	low = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
	high = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
	return low, high


def _face_areas(meshes):
	"""Total face area per material, for picking the body paint when names do not say."""
	areas = {}
	for obj in meshes:
		scale = obj.matrix_world.to_scale()
		factor = abs(scale.x * scale.y * scale.z) ** (2.0 / 3.0)
		for poly in obj.data.polygons:
			if poly.material_index < len(obj.material_slots):
				mat = obj.material_slots[poly.material_index].material
				if mat is not None:
					areas[mat.name] = areas.get(mat.name, 0.0) + poly.area * factor
	return areas


def _role(name, overrides):
	if name in overrides:
		return overrides[name]
	lower = name.lower()
	lamp_glass = lower.startswith(("r_", "o_")) or any(word in lower for word in LAMP_WORDS)
	if "glass" in lower and lamp_glass:
		return None
	for role, words in NAME_RULES:
		if any(word in lower for word in words):
			return role
	return None


def load(path, car, mats):
	"""Import, clean, place, and re-material the model at path for the given CARS entry."""
	objects = _import(Path(path))
	exact = set(car.get("hide", ()))
	for obj in list(objects):
		base = obj.name.rsplit(".", 1)[0] if obj.name[-4:-3] == "." else obj.name
		hidden = obj.name in exact or base in exact
		hidden = hidden or any(word in obj.name.lower() for word in HIDDEN_WORDS)
		if obj.type in ("CAMERA", "LIGHT") or hidden:
			objects.remove(obj)
			bpy.data.objects.remove(obj, do_unlink=True)
	meshes = [obj for obj in objects if obj.type == "MESH"]
	if not meshes:
		raise RuntimeError(f"{path} has no meshes")
	root = bpy.data.objects.new("car_root", None)
	bpy.context.scene.collection.objects.link(root)
	for obj in objects:
		if obj.parent is None:
			matrix = obj.matrix_world.copy()
			obj.parent = root
			obj.matrix_world = matrix
	# Models built lying down (length along Z) are stood up first by rotate_x from CARS.
	root.rotation_euler.x = math.radians(car.get("rotate_x", 0.0))
	# Length along +Y: an explicit yaw from CARS, otherwise turn the longer side onto Y.
	low, high = _bounds(meshes)
	yaw = car.get("yaw")
	if yaw is None:
		yaw = 90.0 if (high.x - low.x) > (high.y - low.y) else 0.0
	root.rotation_euler.z = math.radians(yaw)
	low, high = _bounds(meshes)
	root.scale *= car["L"] / (high.y - low.y)
	low, high = _bounds(meshes)
	root.location -= Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
	_strip_badges(meshes, car)
	_rematerial(meshes, car, mats)
	if car.get("fix_normals"):
		_fix_normals(meshes, mats["paint"])
	if "plate_z" in car:
		_add_plate(meshes, car["plate_z"], mats["plate"])
	low, high = _bounds(meshes)
	print(f"Placed {Path(path).name}: {high - low} m (yaw {yaw})")


def _strip_badges(meshes, car):
	"""Delete small loose pieces on the rear face's middle: badges, logos, and lettering."""
	low, _high = _bounds(meshes)
	rear = low.y + BADGE_DEPTH
	removed = 0
	for obj in meshes:
		corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
		xs = [c.x for c in corners]
		if min(c.y for c in corners) > rear or min(xs) > BADGE_HALF_WIDTH or max(xs) < -BADGE_HALF_WIDTH:
			continue
		if obj.data.users > 1:
			obj.data = obj.data.copy()
		bm = bmesh.new()
		bm.from_mesh(obj.data)
		doomed = []
		seen = set()
		for face in bm.faces:
			if face.index in seen:
				continue
			island, stack = [], [face]
			seen.add(face.index)
			while stack:
				current = stack.pop()
				island.append(current)
				for edge in current.edges:
					for other in edge.link_faces:
						if other.index not in seen:
							seen.add(other.index)
							stack.append(other)
			points = [obj.matrix_world @ v.co for f in island for v in f.verts]
			lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
			hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
			small = max(hi - lo) < BADGE_SIZE
			centred = abs((lo.x + hi.x) / 2) < BADGE_HALF_WIDTH
			if small and centred and hi.y < rear and lo.z > BADGE_MIN_HEIGHT:
				doomed.extend(island)
		if doomed:
			bmesh.ops.delete(bm, geom=doomed, context="FACES")
			bm.to_mesh(obj.data)
			removed += 1
		bm.free()
	print(f"  badges: trimmed pieces from {removed} parts")


def _fix_normals(meshes, paint):
	"""Recompute broken imported normals on painted parts (dark triangles in renders)."""
	for obj in meshes:
		if paint.name not in [slot.material.name for slot in obj.material_slots if slot.material]:
			continue
		with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
			bpy.ops.mesh.customdata_custom_splitnormals_clear()
		for poly in obj.data.polygons:
			poly.use_smooth = True
		obj.data.set_sharp_from_angle(angle=math.radians(35))
		bm = bmesh.new()
		bm.from_mesh(obj.data)
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		bm.to_mesh(obj.data)
		bm.free()


def _add_plate(meshes, z, plate):
	"""Add a blank plate on the rear surface at height z, for models that have none."""
	depsgraph = bpy.context.evaluated_depsgraph_get()
	low, _high = _bounds(meshes)
	hit, location, _n, _i, _o, _m = bpy.context.scene.ray_cast(
		depsgraph, Vector((0.0, low.y - 1.0, z)), Vector((0.0, 1.0, 0.0)))
	if not hit:
		return
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, location.y - 0.012, z))
	obj = bpy.context.active_object
	obj.name = "added_plate"
	obj.scale = (0.52, 0.02, 0.11)
	obj.data.materials.append(plate)


def _rematerial(meshes, car, mats):
	overrides = car.get("materials", {})
	areas = _face_areas(meshes)
	roles = {name: _role(name, overrides) for name in areas}
	if "paint" not in roles.values() and areas:
		# No body material by name: the largest unassigned surface is the body.
		free = [name for name in areas if roles[name] is None]
		if free:
			roles[max(free, key=areas.get)] = "paint"
	for name in sorted(areas, key=areas.get, reverse=True):
		print(f"  material {name!r}: {areas[name]:.2f} m2 -> {roles[name] or 'kept'}")
	# Imported cars may have no interior, so their windows are solid dark glass.
	replacements = dict(mats, glass=mats.get("solid_glass", mats["glass"]))
	painted = set(car.get("paint_parts", ()))
	for obj in meshes:
		if obj.name in painted:
			for slot in obj.material_slots:
				slot.material = mats["paint"]
			continue
		for slot in obj.material_slots:
			role = roles.get(slot.material.name) if slot.material is not None else None
			if role in replacements:
				slot.material = replacements[role]
			elif slot.material is not None:
				_make_solid(slot.material)


def _make_solid(mat):
	"""Kept materials become opaque, except colored lamp lenses, so no pixel of the sprite
	lets the road show through the car."""
	if not mat.use_nodes:
		return
	for node in mat.node_tree.nodes:
		if node.type != "BSDF_PRINCIPLED" or node.inputs["Alpha"].is_linked:
			continue
		r, g, b, _a = node.inputs["Base Color"].default_value
		high, low = max(r, g, b), min(r, g, b)
		lamp = high > 0.2 and (high - low) / high > 0.5
		alpha = node.inputs["Alpha"].default_value
		node.inputs["Alpha"].default_value = max(alpha, 0.85) if lamp else 1.0
