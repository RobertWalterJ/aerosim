#!/bin/sh
# Run a people script with the private Blender user folder that holds MPFB and the MakeHuman assets.
# Usage: sh run_people.sh people_build.py -- ellis --blend
HERE="$(cd "$(dirname "$0")" && pwd)"
TOOLS="$HERE/../../../../_tools"
export BLENDER_USER_RESOURCES="$(cd "$TOOLS/people/bluser" && pwd -W 2>/dev/null || pwd)"
SCRIPT="$1"; shift
exec "$TOOLS/blender-4.2.3-windows-x64/blender.exe" -b --python "$HERE/$SCRIPT" "$@"
