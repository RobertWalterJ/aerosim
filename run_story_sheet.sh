#!/bin/bash
# usage: run_story_sheet.sh <tag> <names or group=...> ; renders golden + overcast
cd "C:/Users/Robert Walter-Joseph/Documents/RWJ Coding Projects/AeroSim-models8/godot"
G="../../_tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
LOCK="../../godot-run.lock"
for i in $(seq 1 40); do if [ -e "$LOCK" ] && [ -n "$(find "$LOCK" -mmin -10 2>/dev/null)" ]; then sleep 15; else break; fi; done
echo lock > "$LOCK"
for L in golden overcast; do timeout 400 $G --path . --resolution 480x270 -s res://test/story_sheet.gd -- tag=$1 light=$L ${@:2} 2>&1 | grep -E "ERROR|contact|SCRIPT"; done
rm -f "$LOCK"
