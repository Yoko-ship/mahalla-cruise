"""Render traffic with the Cobalt's orthographic camera and coated materials.

Run Blender -b -P scripts/blender/traffic_cars.py [-- matiz spark ...].
Uses existing imported models; outputs ignored build/traffic_renders/*.png.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import model_import
import roster_cars as roster


def render(car_id, output):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    car = dict(roster.CARS[car_id], **roster.IMPORTS[car_id])
    mats = roster.materials()
    mats['paint'] = roster.material('coated_paint', (0.57, 0.58, 0.59),
                                    roughness=0.24, metallic=0.1, coat=0.7)
    mats['solid_glass'] = roster.material('reflective_windows', (0.008, 0.014, 0.022),
                                          roughness=0.18, metallic=0.15, coat=0.8)
    mats['red'] = roster.material('rear_lens', (0.28, 0.008, 0.012),
                                  roughness=0.24, metallic=0.15, coat=0.65)
    if car_id == 'nexia':
        car['materials'] = dict(car.get('materials', {}), redglass='red')
    mats['plate'] = roster.material('blank_plate', (0.6, 0.63, 0.61), roughness=0.7)
    model = model_import.find_model(Path('art_sources/car_models'), car_id)
    if model is None:
        raise RuntimeError(f'Missing source model: {car_id}')
    model_import.load(model, car, mats)
    # Daytime cars are cruising, so remove baked brake-light glow.
    for material in bpy.data.materials:
        if material.use_nodes:
            for node in material.node_tree.nodes:
                if node.type == 'BSDF_PRINCIPLED':
                    node.inputs['Emission Strength'].default_value = 0.0
    roster.RESOLUTION = (1000, 1500)
    roster.SAMPLES = 64
    roster.scene_setup(car)
    scene = bpy.context.scene
    scene.view_settings.view_transform = 'AgX'
    scene.view_settings.look = 'AgX - Medium High Contrast'
    scene.view_settings.exposure = 0.25
    scene.camera.data.type = 'ORTHO'
    scene.camera.data.ortho_scale = 5.8
    angle = math.radians(38)
    target = Vector((0, 0, 0.55))
    scene.camera.location = target + Vector((0, -math.cos(angle), math.sin(angle))) * 12
    scene.camera.rotation_euler = (target - scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
    for name, location, power, size in [('softbox', (-4, -5, 7), 1400, 5),
                                        ('fill', (4, 0, 5), 650, 4)]:
        data = bpy.data.lights.new(name, 'AREA')
        data.energy = power
        data.shape = 'DISK'
        data.size = size
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.location = location
        obj.rotation_euler = (target - obj.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str((output / f'{car_id}.png').resolve())
    bpy.ops.render.render(write_still=True)
    print(f'Rendered realistic traffic: {car_id}', flush=True)


def main():
    output = Path('build/traffic_renders')
    output.mkdir(parents=True, exist_ok=True)
    (output / '.gdignore').touch()
    cars = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    for car_id in cars or ['matiz', 'spark', 'nexia', 'gentra', 'malibu']:
        render(car_id, output)


if __name__ == '__main__':
    main()
