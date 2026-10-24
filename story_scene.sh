#!/bin/bash
# usage: story_scene.sh <label> <name+name> <hour> <distance> [extra tokens e.g. sky3] ; screenshot of the models in the real scene
cd "C:/Users/Robert Walter-Joseph/Documents/RWJ Coding Projects/AeroSim-models8/godot"
G="../../_tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
LOCK="../../godot-run.lock"
for i in $(seq 1 40); do if [ -e "$LOCK" ] && [ -n "$(find "$LOCK" -mmin -10 2>/dev/null)" ]; then sleep 15; else break; fi; done
echo lock > "$LOCK"
OUT="C:/Users/Robert Walter-Joseph/Documents/RWJ Coding Projects/AeroSim-models8/godot/docs/realism/models/scene_$1.png"
EXTRA=""; [ -n "$5" ] && EXTRA=",$5"
timeout 300 $G --path . -- "shot=$OUT,260,fpv,clock$3,at-18_2.6_36_${6:-190}_-6,story$4_$2$EXTRA" 2>&1 | grep -E "ERROR|SCRIPT|missing" | head
rm -f "$LOCK"; ls -la "$OUT" 2>&1 | tail -1
