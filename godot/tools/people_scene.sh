#!/bin/bash
# Blender 2 people in the real scene: people_scene.sh <out.png> <name+name...> <hour> <distance> [extra tokens] [yaw]
# Uses the story<distance>_<names> dev hook (StoryAssets routes the story names to PeopleAssets). Takes the shared Godot lock.
cd "$(dirname "$0")/.."
G="../../_tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
LOCK="../../godot-run.lock"
for i in $(seq 1 60); do if [ -e "$LOCK" ] && [ -n "$(find "$LOCK" -mmin -10 2>/dev/null)" ]; then sleep 15; else break; fi; done
echo "claude people $(date)" > "$LOCK"
EXTRA=""; [ -n "$5" ] && EXTRA=",$5"
timeout 300 $G --path . -- "shot=$1,260,fpv,clock$3,at-18_${7:-1.6}_36_${6:-190}_${8:--4},story$4_$2$EXTRA" 2>&1 | grep -E "ERROR|SCRIPT|missing" | head
rm -f "$LOCK"; ls -la "$1" 2>&1 | tail -1
