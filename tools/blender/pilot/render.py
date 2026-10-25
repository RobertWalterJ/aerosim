import os
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import render_setup, shoot
import bpy
render_setup(samples=int(os.environ.get('SAMPLES', '24')))
for spec in os.environ['SHOTS'].split(';'):
    name, a = spec.split('=')
    v = [float(x) for x in a.split(',')]
    shoot(os.path.join(os.environ.get('PILOT_WORK', os.getcwd()), f'{name}.png'), v[0:3], v[3:6], v[6] if len(v) > 6 else 50)
