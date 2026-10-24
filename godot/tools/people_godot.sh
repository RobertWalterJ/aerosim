#!/bin/bash
# Run Godot headless for the people lane under the shared lock: people_godot.sh [extra Godot args...]
# e.g.  people_godot.sh --import      or      people_godot.sh -s res://test/people_blender_test.gd
cd "$(dirname "$0")/.."
G="../../_tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
LOCK="../../godot-run.lock"
for i in $(seq 1 60); do if [ -e "$LOCK" ] && [ -n "$(find "$LOCK" -mmin -10 2>/dev/null)" ]; then sleep 15; else break; fi; done
echo "claude people $(date)" > "$LOCK"
timeout 600 $G --headless --path . "$@" 2>&1
rm -f "$LOCK"
