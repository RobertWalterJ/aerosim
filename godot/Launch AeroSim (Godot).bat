@echo off
rem Starts the Godot version of AeroSim. Close this window to quit.
cd /d "%~dp0"
start "" "%~dp0..\..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --path "%~dp0" --fullscreen
