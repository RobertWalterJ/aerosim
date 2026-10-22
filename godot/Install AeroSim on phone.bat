@echo off
rem Installs the latest AeroSim build on an Android phone plugged in by USB (USB debugging on).
set ADB=%~dp0..\..\_tools\android-sdk\platform-tools\adb.exe
set APK=%~dp0build\aerosim-debug.apk
if not exist "%APK%" (echo No build found. Ask Claude to build the Android version first. & pause & exit /b 1)
"%ADB%" devices
echo.
echo Installing... keep the phone unlocked and tap Allow if it asks about USB debugging.
"%ADB%" install -r "%APK%"
echo.
pause
