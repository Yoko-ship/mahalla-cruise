"""Model and render the garage cars in Blender (Cycles), matching the Damas sprite camera.

Run from the repository root (Blender 4.2 LTS):
    ~/Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/blender/roster_cars.py -- \
        build/roster_renders [--models=art_sources/car_models] [car_id ...]

A car whose model file (<car_id>.blend/.glb/.gltf/.fbx/.obj) is in the models folder is
imported and placed by model_import.py; otherwise it is built from simple beveled parts
(body, cabin with inset glass, lamps, bumper, wheels, mirrors, plate, seats). Either way it
is rendered from behind and above with a perspective camera on a transparent background. Body paint is neutral white so the game's paint shader can
recolor it; lamps, glass, trim, tyres, chrome (bluish), and the cream plate keep their colors.
scripts/render_roster_cars.gd packs the renders into assets/cars/roster_cars.png.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

sys.path.append(str(Path(__file__).resolve().parent))
import model_import  # noqa: E402

MODEL_DIR = Path("art_sources/car_models")

# Perspective camera behind and above, like the painted Damas: look-down angle below the
# horizon, distance to the car, and lens. Renders are cropped to the car afterwards.
VIEW_DEGREES = 34.0
CAMERA_DISTANCE = 12.0
LENS_MM = 85.0
RESOLUTION = (1400, 1900)
SAMPLES = 160

# Dimensions in metres. belt: top of the lower body; deck: rear deck height (sedan trunk);
# hood/trunk: lengths in front of and behind the cabin; ws/rw: windshield and rear-glass run;
# roof: roof width share; nose/tail: width share at each end (top view taper).
CARS = {
	"matiz": dict(L=3.50, W=1.50, H=1.50, belt=0.86, deck=0.86, hood=0.70, trunk=0.10, ws=0.62,
		rw=0.22, roof=0.84, nose=0.82, tail=0.94, round=0.16, lamps="pillar_round",
		bumper="body"),
	"spark": dict(L=3.64, W=1.60, H=1.52, belt=0.88, deck=0.88, hood=0.74, trunk=0.10, ws=0.66,
		rw=0.26, roof=0.84, nose=0.84, tail=0.94, round=0.13, lamps="pillar_sharp",
		bumper="dark", spoiler=True),
	"nexia": dict(L=4.48, W=1.66, H=1.39, belt=0.84, deck=0.86, hood=1.18, trunk=0.95, ws=0.62,
		rw=0.46, roof=0.84, nose=0.90, tail=0.97, round=0.09, lamps="band", bumper="dark"),
	"cobalt": dict(L=4.48, W=1.73, H=1.51, belt=0.90, deck=1.00, hood=1.10, trunk=0.86, ws=0.70,
		rw=0.48, roof=0.82, nose=0.88, tail=0.96, round=0.12, lamps="wrap", bumper="body",
		chrome=True),
	"gentra": dict(L=4.52, W=1.73, H=1.45, belt=0.88, deck=0.92, hood=1.14, trunk=0.88, ws=0.72,
		rw=0.56, roof=0.80, nose=0.86, tail=0.95, round=0.15, lamps="cluster", bumper="body",
		chrome=True),
	"malibu": dict(L=4.92, W=1.85, H=1.46, belt=0.90, deck=0.94, hood=1.30, trunk=0.92, ws=0.80,
		rw=0.70, roof=0.78, nose=0.86, tail=0.95, round=0.16, lamps="slim", bumper="body",
		chrome=True, exhaust=True),
}

# Fixes for downloaded models (see model_import.py): rotate_x stands up a model built lying
# down, yaw turns it nose-forward, hide lists part names to drop (badges, lettering),
# paint_parts lists parts painted with the body color whatever their material, materials
# maps a material name to a role ("paint", "glass", "plate", "rubber", "red" lamp lens,
# "chrome", or "keep"), fix_normals recomputes broken normals on painted parts, and plate_z
# adds a blank plate at that height to a model that has none.
IMPORTS = {
	"matiz": dict(yaw=180.0, materials={"material_1": "paint", "material_7": "keep"},
		paint_parts=("Object_69", "Object_144")),
	"spark": dict(rotate_x=-90.0, hide=("Object_17", "Object_21", "Object_65"),
		materials={"r_glass": "red", "glass.001": "red"}),
	"nexia": dict(yaw=180.0),
	"malibu": dict(yaw=180.0),
	"cobalt": dict(hide=("boot_ok_escape.0_0_escape.008_0",)),
	"gentra": dict(materials={"glass": "keep", "glass.001": "keep", "glass.002": "keep",
		"chassis.4": "chrome"}, hide=("boot_unnamed.1_0", "boot_boot.2_0"), fix_normals=True,
		plate_z=0.66),
}

CLEARANCE = 0.26
WHEEL_RADIUS = 0.30


def material(name, color, roughness=0.4, metallic=0.0, coat=0.0, transmission=0.0,
		emission=None, strength=0.0, alpha=1.0):
	mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	mat.use_nodes = True
	mat.blend_method = "BLEND"
	bsdf = mat.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Roughness"].default_value = roughness
	bsdf.inputs["Metallic"].default_value = metallic
	bsdf.inputs["Coat Weight"].default_value = coat
	bsdf.inputs["Transmission Weight"].default_value = transmission
	bsdf.inputs["Alpha"].default_value = alpha
	if emission:
		bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
		bsdf.inputs["Emission Strength"].default_value = strength
	return mat


def materials():
	return {
		"paint": material("paint", (0.78, 0.78, 0.78), roughness=0.3, coat=0.3),
		"glass": material("glass", (0.02, 0.022, 0.025), roughness=0.05, coat=1.0, alpha=0.72),
		"solid_glass": material("solid_glass", (0.025, 0.028, 0.032), roughness=0.06, coat=1.0),
		"interior": material("interior", (0.04, 0.038, 0.036), roughness=0.85),
		"seat": material("seat", (0.24, 0.23, 0.22), roughness=0.7),
		"rubber": material("rubber", (0.02, 0.02, 0.02), roughness=0.55),
		"plastic": material("plastic", (0.035, 0.037, 0.04), roughness=0.4, coat=0.2),
		"hub": material("hub", (0.30, 0.31, 0.33), roughness=0.35, metallic=0.8),
		"red": material("red", (0.55, 0.015, 0.01), roughness=0.12, coat=1.0,
			emission=(1.0, 0.06, 0.03), strength=0.8),
		"amber": material("amber", (0.85, 0.36, 0.02), roughness=0.12, coat=1.0,
			emission=(1.0, 0.45, 0.05), strength=0.5),
		"reverse": material("reverse", (0.85, 0.72, 0.58), roughness=0.1, coat=1.0),
		"chrome": material("chrome", (0.70, 0.82, 1.0), roughness=0.08, metallic=1.0),
		"plate": material("plate", (1.0, 0.92, 0.66), roughness=0.5),
	}


def mesh_object(name, verts, faces, mats, face_mats=None, bevel=0.0, segments=4):
	mesh = bpy.data.meshes.new(name)
	mesh.from_pydata(verts, [], faces)
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.collection.objects.link(obj)
	for mat in mats:
		obj.data.materials.append(mat)
	if face_mats:
		for poly, index in zip(obj.data.polygons, face_mats):
			poly.material_index = index
	if bevel > 0:
		mod = obj.modifiers.new("bevel", "BEVEL")
		mod.width = bevel
		mod.segments = segments
		mod.limit_method = "ANGLE"
		mod.harden_normals = True
	for poly in obj.data.polygons:
		poly.use_smooth = True
	return obj


def box(name, x0, x1, y0, y1, z0, z1, mat, bevel=0.02, segments=3):
	verts = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
		(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
	faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
	return mesh_object(name, verts, faces, [mat], bevel=bevel, segments=segments)


def frustum(name, bottom, top, mats, face_mats, bevel):
	"""Eight-vertex solid: bottom and top are (x0, x1, y0, y1, z) rectangles."""
	bx0, bx1, by0, by1, bz = bottom
	tx0, tx1, ty0, ty1, tz = top
	verts = [(bx0, by0, bz), (bx1, by0, bz), (bx1, by1, bz), (bx0, by1, bz),
		(tx0, ty0, tz), (tx1, ty0, tz), (tx1, ty1, tz), (tx0, ty1, tz)]
	# Faces: bottom, top, rear (-y), right, front (+y), left.
	faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
	return mesh_object(name, verts, faces, mats, face_mats, bevel=bevel, segments=5)


def lower_body(c, m):
	"""Body below the windows: tapered nose and tail, hood sloping down, deck at the back."""
	L, W = c["L"], c["W"]
	y_rear, y_front = -L / 2, L / 2
	hw, nose, tail = W / 2, W / 2 * c["nose"], W / 2 * c["tail"]
	z0, belt, deck = CLEARANCE, c["belt"], c["deck"]
	hood_drop = 0.10
	verts = [(-tail, y_rear, z0), (tail, y_rear, z0), (hw, y_rear + 0.5, z0), (hw, y_front - 0.7, z0),
		(nose, y_front, z0), (-nose, y_front, z0), (-hw, y_front - 0.7, z0), (-hw, y_rear + 0.5, z0),
		(-tail, y_rear, deck), (tail, y_rear, deck), (hw, y_rear + 0.5, deck),
		(hw, y_front - 0.7, belt - hood_drop * 0.3), (nose, y_front, belt - hood_drop),
		(-nose, y_front, belt - hood_drop), (-hw, y_front - 0.7, belt - hood_drop * 0.3),
		(-hw, y_rear + 0.5, deck)]
	faces = [tuple(range(7, -1, -1)), tuple(range(8, 16))]
	faces += [(i, (i + 1) % 8, (i + 1) % 8 + 8, i + 8) for i in range(8)]
	return mesh_object("body", verts, faces, [m["paint"]], bevel=c["round"], segments=8)


def cabin(c, m):
	"""Greenhouse: paint roof and pillars, inset glass on the rear, sides, and front."""
	L, W, H = c["L"], c["W"], c["H"]
	y0 = -L / 2 + c["trunk"]
	y1 = L / 2 - c["hood"]
	hw, rw = W / 2 * 0.93, W / 2 * c["roof"]
	z0 = min(c["belt"], c["deck"]) - 0.02
	obj = frustum("cabin", (-hw, hw, y0, y1, z0), (-rw, rw, y0 + c["rw"], y1 - c["ws"], H),
		[m["paint"], m["glass"]], [0, 0, 0, 0, 0, 0], bevel=0.05)
	bm = bmesh.new()
	bm.from_mesh(obj.data)
	bm.faces.ensure_lookup_table()
	sides = [bm.faces[i] for i in (2, 3, 4, 5)]
	result = bmesh.ops.inset_individual(bm, faces=sides, thickness=0.07, depth=-0.012)
	for face in sides:
		face.material_index = 1
	bm.to_mesh(obj.data)
	bm.free()
	for poly in obj.data.polygons:
		poly.use_smooth = True
	# Dark interior shell, open at the back, and seats seen through the rear glass.
	inner = 0.06
	shell = frustum("interior", (-hw + inner, hw - inner, y0 + inner, y1 - inner, z0 - 0.05),
		(-rw + inner, rw - inner, y0 + c["rw"] + inner, y1 - c["ws"] - inner, H - inner),
		[m["interior"]], [0] * 6, bevel=0.0)
	bm = bmesh.new()
	bm.from_mesh(shell.data)
	bm.faces.ensure_lookup_table()
	bmesh.ops.delete(bm, geom=[bm.faces[2]], context="FACES_ONLY")
	bm.to_mesh(shell.data)
	bm.free()
	glow = bpy.data.lights.new("cabin_light", "AREA")
	glow.energy, glow.size = (5.0 if c["trunk"] > 0.3 else 1.5), 0.9
	glow_obj = bpy.data.objects.new("cabin_light", glow)
	glow_obj.location = (0.0, (y0 + y1) / 2, H - 0.12)
	bpy.context.collection.objects.link(glow_obj)
	seat_y = y0 + c["rw"] * 0.6 + 0.12
	top = H - 0.2
	box("bench", -hw + 0.14, hw - 0.14, seat_y, seat_y + 0.22, z0, top - 0.2, m["seat"], 0.07, 4)
	for side in (-1, 1):
		x = side * hw * 0.48
		box("headrest", x - 0.14, x + 0.14, seat_y + 0.04, seat_y + 0.14, top - 0.17, top,
			m["seat"], 0.05, 4)
	return result


def wheels(c, m):
	L, W = c["L"], c["W"]
	for sx in (-1, 1):
		for y in (-L / 2 + 0.78, L / 2 - 0.85):
			bpy.ops.mesh.primitive_cylinder_add(radius=WHEEL_RADIUS, depth=0.2,
				location=(sx * (W / 2 - 0.13), y, WHEEL_RADIUS), rotation=(0, math.pi / 2, 0),
				vertices=32)
			tyre = bpy.context.active_object
			tyre.data.materials.append(m["rubber"])
			bev = tyre.modifiers.new("bevel", "BEVEL")
			bev.width, bev.segments = 0.05, 3
			bpy.ops.object.shade_smooth()


def rear(c, m):
	"""Bumper, plate, lamps, reflectors, chrome, exhausts on the rear face."""
	L, W = c["L"], c["W"]
	yr = -L / 2
	hw = W / 2 * c["tail"]
	bumper_mat = m["paint"] if c["bumper"] == "body" else m["plastic"]
	box("bumper", -hw - 0.02, hw + 0.02, yr - 0.05, yr + 0.45, 0.22, 0.52, bumper_mat, 0.09, 5)
	box("lip", -hw + 0.1, hw - 0.1, yr - 0.06, yr + 0.3, 0.2, 0.3, m["plastic"], 0.04)
	box("plate_recess", -0.27, 0.27, yr - 0.012, yr + 0.05, 0.53, 0.68, m["plastic"], 0.02)
	box("plate", -0.24, 0.24, yr - 0.02, yr + 0.05, 0.55, 0.66, m["plate"], 0.01)
	for side in (-1, 1):
		x = side * (hw - 0.22)
		box("reflector", x - 0.07, x + 0.07, yr - 0.065, yr, 0.36, 0.4, m["red"], 0.01)
	lamps(c, m, yr, hw)
	if c.get("chrome"):
		z = c["deck"] - 0.2
		box("chrome", -0.36, 0.36, yr - 0.02, yr + 0.05, z, z + 0.035, m["chrome"], 0.012)
	if c.get("exhaust"):
		for side in (-1, 1):
			x = side * hw * 0.55
			box("exhaust", x - 0.13, x + 0.13, yr - 0.08, yr, 0.24, 0.31, m["chrome"], 0.025)


def lamps(c, m, yr, hw):
	kind, deck = c["lamps"], c["deck"]

	def pair(x_in, x_out, z0, z1, mat, wrap=0.12, bevel=0.03):
		for side in (-1, 1):
			a, b = sorted((side * x_in, side * x_out))
			box("lamp", a, b, yr - 0.03, yr + wrap, z0, z1, mat, bevel)

	if kind == "pillar_round":
		pair(hw - 0.14, hw + 0.01, deck - 0.2, deck + 0.24, m["red"], 0.12, 0.06)
		pair(hw - 0.12, hw - 0.02, deck - 0.17, deck - 0.07, m["reverse"], 0.04, 0.02)
	elif kind == "pillar_sharp":
		pair(hw - 0.15, hw + 0.01, deck - 0.16, deck + 0.26, m["red"], 0.14, 0.025)
		pair(hw - 0.13, hw - 0.03, deck - 0.13, deck - 0.04, m["reverse"], 0.04, 0.015)
	elif kind == "band":
		pair(hw - 0.44, hw + 0.01, deck - 0.2, deck - 0.1, m["red"], 0.1, 0.015)
		pair(hw - 0.44, hw + 0.01, deck - 0.3, deck - 0.2, m["amber"], 0.1, 0.015)
		pair(hw - 0.54, hw - 0.44, deck - 0.3, deck - 0.1, m["reverse"], 0.05, 0.015)
	elif kind == "wrap":
		pair(hw - 0.5, hw + 0.02, deck - 0.26, deck - 0.04, m["red"], 0.3, 0.04)
		pair(hw - 0.42, hw - 0.22, deck - 0.22, deck - 0.12, m["reverse"], 0.06, 0.02)
	elif kind == "cluster":
		pair(hw - 0.46, hw + 0.01, deck - 0.3, deck - 0.06, m["red"], 0.2, 0.08)
		for side in (-1, 1):
			for offset, mat in ((0.14, m["amber"]), (0.33, m["reverse"])):
				bpy.ops.mesh.primitive_cylinder_add(radius=0.07, depth=0.04, vertices=24,
					location=(side * (hw - offset), yr - 0.045, deck - 0.18),
					rotation=(math.pi / 2, 0, 0))
				light = bpy.context.active_object
				light.data.materials.append(mat)
				bpy.ops.object.shade_smooth()
	elif kind == "slim":
		pair(hw - 0.6, hw + 0.02, deck - 0.12, deck - 0.04, m["red"], 0.32, 0.03)


def extras(c, m):
	L, W, H = c["L"], c["W"], c["H"]
	y_mirror = L / 2 - c["hood"] - 0.12
	for side in (-1, 1):
		x0 = side * W / 2 * 0.93
		x1 = side * (W / 2 + 0.14)
		a, b = sorted((x0, x1))
		box("mirror", a, b, y_mirror - 0.08, y_mirror + 0.04, c["belt"] + 0.05, c["belt"] + 0.2,
			m["plastic"], 0.04)
	if c.get("spoiler"):
		y0 = -L / 2 + c["trunk"] + c["rw"] - 0.08
		rw = W / 2 * c["roof"] + 0.02
		box("spoiler", -rw, rw, y0 - 0.1, y0 + 0.12, H - 0.06, H + 0.02, m["paint"], 0.04)


def scene_setup(c):
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	prefs = bpy.context.preferences.addons["cycles"].preferences
	prefs.compute_device_type = "METAL"
	prefs.get_devices()
	for device in prefs.devices:
		device.use = True
	scene.cycles.device = "GPU"
	scene.cycles.samples = SAMPLES
	scene.cycles.use_denoising = True
	scene.render.film_transparent = True
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "None"
	world = bpy.data.worlds.new("sky")
	world.use_nodes = True
	nodes = world.node_tree.nodes
	sky = nodes.new("ShaderNodeTexSky")
	sky.sky_type = "NISHITA"
	sky.sun_elevation = math.radians(38)
	sky.sun_rotation = math.radians(215)
	sky.sun_disc = False
	world.node_tree.links.new(sky.outputs["Color"], nodes["Background"].inputs["Color"])
	nodes["Background"].inputs["Strength"].default_value = 0.07
	scene.view_settings.exposure = -0.2
	scene.world = world
	# Warm sun from the upper left, slightly behind the camera, so the rear face is lit.
	sun_data = bpy.data.lights.new("sun", "SUN")
	sun_data.energy = 4.2
	sun_data.color = (1.0, 0.9, 0.78)
	sun_data.angle = math.radians(8)
	sun = bpy.data.objects.new("sun", sun_data)
	scene.collection.objects.link(sun)
	direction = Vector((0.55, 0.75, -0.9)).normalized()
	sun.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
	angle = math.radians(VIEW_DEGREES)
	cam_data = bpy.data.cameras.new("camera")
	cam_data.lens = LENS_MM
	cam = bpy.data.objects.new("camera", cam_data)
	scene.collection.objects.link(cam)
	centre = Vector((0.0, 0.0, c["H"] * 0.45))
	offset = Vector((0.0, -math.cos(angle), math.sin(angle))) * CAMERA_DISTANCE
	cam.location = centre + offset
	cam.rotation_euler = (math.pi / 2 - angle, 0.0, 0.0)
	scene.camera = cam
	scene.render.resolution_x, scene.render.resolution_y = RESOLUTION
	scene.render.resolution_percentage = 100


def build(car_id, out_dir, model_dir):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	c = dict(CARS[car_id], **IMPORTS.get(car_id, {}))
	m = materials()
	model = model_import.find_model(model_dir, car_id)
	if model:
		model_import.load(model, c, m)
	else:
		lower_body(c, m)
		cabin(c, m)
		wheels(c, m)
		rear(c, m)
		extras(c, m)
	scene_setup(c)
	path = out_dir / f"{car_id}.png"
	bpy.context.scene.render.filepath = str(path)
	bpy.ops.render.render(write_still=True)
	print(f"Rendered {path}")


def main():
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	model_dir = MODEL_DIR
	for arg in list(args):
		if arg.startswith("--models="):
			model_dir = Path(arg.split("=", 1)[1])
			args.remove(arg)
	out_dir = Path(args[0] if args else "build/roster_renders").resolve()
	out_dir.mkdir(parents=True, exist_ok=True)
	# Godot need not import the raw renders; render_roster_cars.gd reads them from disk.
	(out_dir / ".gdignore").touch()
	for car_id in args[1:] or list(CARS):
		build(car_id, out_dir, model_dir.resolve())


if __name__ == "__main__":
	main()
