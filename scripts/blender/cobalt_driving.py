"""Render consistent Cobalt steering views from the existing licensed model."""
import sys, math, json
from pathlib import Path
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
sys.path.insert(0, str(Path('scripts/blender').resolve()))
import roster_cars as roster
import model_import

def rear_lens():
    mat = roster.material('segmented_rear_lenses', (0.55, 0.015, 0.01), roughness=0.2, metallic=0.25, coat=0.6)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    geometry = nodes.new('ShaderNodeNewGeometry')
    separate = nodes.new('ShaderNodeSeparateXYZ')
    links.new(geometry.outputs['Position'], separate.inputs[0])
    mapping = nodes.new('ShaderNodeMapRange')
    mapping.inputs['From Min'].default_value = 0.69
    mapping.inputs['From Max'].default_value = 1.0
    links.new(separate.outputs['Z'], mapping.inputs[0])
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.interpolation = 'CONSTANT'
    stops = [(0, (0.5, 0.008, 0.012, 1)), (0.24, (0.55, 0.59, 0.61, 1)), (0.45, (0.3, 0.006, 0.008, 1)), (0.53, (0.55, 0.59, 0.61, 1)), (0.76, (0.5, 0.008, 0.012, 1))]
    ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1])
    for (i, (position, color)) in enumerate(stops):
        e = ramp.color_ramp.elements[0] if i == 0 else ramp.color_ramp.elements.new(position)
        e.position = position
        e.color = color
    links.new(mapping.outputs[0], ramp.inputs[0])
    links.new(ramp.outputs[0], nodes['Principled BSDF'].inputs['Base Color'])
    return mat
bpy.ops.wm.read_factory_settings(use_empty=True)
c = dict(roster.CARS['cobalt'], **roster.IMPORTS['cobalt'])
c['plate_z'] = 0.46
m = roster.materials()
m['paint'] = roster.material('real_paint', (0.57, 0.58, 0.59), roughness=0.24, metallic=0.1, coat=0.7)
m['solid_glass'] = roster.material('real_windows', (0.008, 0.014, 0.022), roughness=0.18, metallic=0.15, coat=0.8)
m['plate'] = roster.material('blank_plate', (0.6, 0.63, 0.61), roughness=0.7)
model_import.load(model_import.find_model(Path('art_sources/car_models'), 'cobalt'), c, m)
lens = rear_lens()
hub = roster.material('stock_alloy', (0.16, 0.17, 0.18), roughness=0.28, metallic=0.8)
for obj in list(bpy.data.objects):
    if obj.type == 'MESH' and obj.name.startswith('roda'):
        group = obj.name.split('_')[0]
        if group not in ('roda.002', 'roda.004', 'roda.008', 'roda.012'):
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        for slot in obj.material_slots:
            if slot.material and slot.material.name.startswith('roda.'):
                slot.material = hub
            elif slot.material and slot.material.name.startswith('bump_front'):
                slot.material = m['rubber']
for obj in bpy.data.objects:
    if obj.type != 'MESH':
        continue
    if obj.name.startswith(('lanterna_glass', 'lanternaa_', 'ascende_left rear', 'ascende_right rear')):
        for slot in obj.material_slots:
            slot.material = lens
roster.RESOLUTION = (1000, 1500)
roster.SAMPLES = 64
roster.scene_setup(c)
s = bpy.context.scene
s.view_settings.view_transform = 'AgX'
s.view_settings.look = 'AgX - Medium High Contrast'
s.view_settings.exposure = 0.25
s.camera.data.type = 'ORTHO'
s.camera.data.ortho_scale = 5.8
angle = math.radians(38)
target = Vector((0, 0, 0.55))
s.camera.location = target + Vector((0, -math.cos(angle), math.sin(angle))) * 12
s.camera.rotation_euler = (target - s.camera.location).to_track_quat('-Z', 'Y').to_euler()
for (name, loc, power, size) in [('softbox', (-4, -5, 7), 1400, 5), ('fill', (4, 0, 5), 650, 4)]:
    data = bpy.data.lights.new(name, 'AREA')
    data.energy = power
    data.shape = 'DISK'
    data.size = size
    obj = bpy.data.objects.new(name, data)
    s.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = (target - obj.location).to_track_quat('-Z', 'Y').to_euler()
root = bpy.data.objects['car_root']
plate = bpy.data.objects['added_plate']
matrix = plate.matrix_world.copy()
plate.parent = root
plate.matrix_world = matrix
out = Path('build/cobalt_driving')
out.mkdir(exist_ok=True)
(out / '.gdignore').touch()
frames = []
for (index, yaw) in enumerate([-10, -5, 0, 5, 10]):
    root.rotation_euler.z = math.radians(-yaw)
    bpy.context.view_layer.update()
    s.render.filepath = str((out / f'{index}.png').resolve())
    bpy.ops.render.render(write_still=True)
    quad = []
    for (x, z) in [(-0.5, 0.5), (0.5, 0.5), (0.5, -0.5), (-0.5, -0.5)]:
        p = world_to_camera_view(s, s.camera, plate.matrix_world @ Vector((x, -0.55, z)))
        quad.append([p.x * s.render.resolution_x, (1 - p.y) * s.render.resolution_y])
    frames.append({'yaw': yaw, 'plate': quad})
(out / 'frames.json').write_text(json.dumps(frames, indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str((out / 'cobalt.blend').resolve()))
