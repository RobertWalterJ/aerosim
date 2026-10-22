@echo off
rem Starts the Godot version of AeroSim.
cd /d "%~dp0"
if not exist "%~dp0..\..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" (
  echo Godot was not found in the _tools folder.
  pause
  exit /b 1
)
start "" "%~dp0..\..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." --fullscreen
