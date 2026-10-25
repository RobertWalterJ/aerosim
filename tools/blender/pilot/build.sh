#!/usr/bin/env bash
# Rebuild public/models/pilot.glb from scratch with Blender 4.2 + MPFB2 + MakeHuman system assets (CC0).
# Usage: BLENDER=/path/to/blender tools/blender/pilot/build.sh [work_dir]
# See tools/blender/pilot/README.md for one-time setup.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BLENDER="${BLENDER:-blender}"
export PILOT_WORK="${1:-$ROOT/assets/blender/pilot_work}"
mkdir -p "$PILOT_WORK"; cd "$PILOT_WORK"
run() { "$BLENDER" -b "$@" -noaudio 2>&1 | grep -E "Error|Traceback|EXPORTED|TRIS" || true; }
run --factory-startup --python "$HERE/stageA.py"          # base character -> A.blend
run A.blend --python "$HERE/stageB.py"                    # beard, hairline, white top textures -> tex/
run A.blend --python "$HERE/stageC.py"                    # beard shells, cap, glasses -> C.blend
run C.blend --python "$HERE/stageD.py"                    # transmitter + holding pose -> D_posed.blend
OUT="$ROOT/public/models/pilot.glb" run D_posed.blend --python "$HERE/stageE.py"   # rest pose, export
echo "done: $ROOT/public/models/pilot.glb (editable scene: $PILOT_WORK/E_rest.blend)"
