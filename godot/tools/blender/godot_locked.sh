#!/bin/sh
# Run one Godot command under the shared AeroSim lock (RWJ Coding Projects/godot-run.lock): wait while another session holds
# a fresh lock (under 10 minutes old), take it, run, give it back. Usage: godot_locked.sh <timeout seconds> <godot args...>
LOCK="/c/Users/Robert Walter-Joseph/Documents/RWJ Coding Projects/godot-run.lock"
GODOT="/c/Users/Robert Walter-Joseph/Documents/RWJ Coding Projects/_tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
T=$1; shift
while [ -f "$LOCK" ]; do
  age=$(( $(date +%s) - $(stat -c %Y "$LOCK") ))
  [ $age -ge 600 ] && break
  echo "waiting for godot-run.lock (age ${age}s)" >&2
  sleep 20
done
echo "lane/drones $(date)" > "$LOCK"
timeout "$T" "$GODOT" "$@"
rc=$?
rm -f "$LOCK"
exit $rc
