#!/bin/bash
# Runs one Godot command under the shared godot-run.lock (one Godot at a time on Robert's PC).
# Usage: godot_locked.sh <timeout-seconds> <godot args...>
# Waits while the lock exists and is younger than 10 minutes, then writes it, runs Godot, and removes it.
LOCK="/c/Users/Robert Walter-Joseph/Documents/RWJ Coding Projects/godot-run.lock"
GODOT="/c/Users/Robert Walter-Joseph/Documents/RWJ Coding Projects/_tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
TO=$1; shift
while [ -f "$LOCK" ]; do
  m=$(stat -c %Y "$LOCK" 2>/dev/null) || break
  age=$(( $(date +%s) - m ))
  if [ $age -gt 600 ]; then echo "stale lock ($age s), taking it"; break; fi
  sleep 15
done
echo "claude buildings $(date)" > "$LOCK"
timeout "$TO" "$GODOT" "$@"
rc=$?
rm -f "$LOCK"
exit $rc
