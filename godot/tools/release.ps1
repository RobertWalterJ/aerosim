# Build the Android package and publish it as a GitHub release, in one command. No Claude needed.
# Usage (from the godot folder):  powershell -ExecutionPolicy Bypass -File tools\release.ps1 -Version 0.8 -Notes "What changed, in plain words"
# Needs: the gate to pass first (this script runs it), git signed in, the gh tool signed in (it is).
param([Parameter(Mandatory=$true)][string]$Version, [string]$Notes = "New build.")
$ErrorActionPreference = "Stop"
$godotDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$repo = (Resolve-Path (Join-Path $godotDir "..")).Path
$godot = (Resolve-Path (Join-Path $godotDir "..\..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe")).Path

# 1. refuse to release unless we are on main with nothing half-done in godot/
$branch = (git -C $repo rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne "main") { throw "Release only from the main branch (you are on $branch)." }
$dirty = git -C $repo status --short -- godot
if ($dirty) { throw "There are uncommitted changes in godot/. Commit or stash them first:`n$dirty" }

# 2. the gate must pass
$g = & powershell -ExecutionPolicy Bypass -File (Join-Path $godotDir "tools\gate.ps1") -Tag release
Write-Output $g
if (($g -join "`n") -notmatch "GATE PASS") { throw "The gate did not pass. Not releasing." }

# 3. bump the version in the export preset (code = last number, name = Version)
$preset = Join-Path $godotDir "export_presets.cfg"
$txt = Get-Content $preset -Raw
$m = [regex]::Match($txt, 'version/code=(\d+)')
$code = [int]$m.Groups[1].Value + 1
$txt = $txt -replace 'version/code=\d+', "version/code=$code"
$txt = $txt -replace 'version/name="[^"]*"', "version/name=`"$Version`""
Set-Content $preset $txt -NoNewline

# 4. export the debug-signed APK
New-Item -ItemType Directory -Force (Join-Path $godotDir "build") | Out-Null
& $godot --headless --path $godotDir --export-debug "Android" (Join-Path $godotDir "build\aerosim-debug.apk")
$apk = Join-Path $godotDir "build\aerosim-debug.apk"
if (-not (Test-Path $apk)) { throw "The export failed: no APK was made." }

# 5. commit the version bump, tag, push, publish
git -C $repo add godot/export_presets.cfg
git -C $repo commit -m "Godot: Android $Version`n`nCo-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
git -C $repo push
git -C $repo tag -f "android-v$Version"
git -C $repo push origin "android-v$Version"
gh release create "android-v$Version" "$apk#AeroSim-android-debug.apk" --repo RobertWalterJ/aerosim --title "AeroSim Android (Godot) v$Version" --notes $Notes
Write-Output "Published: https://github.com/RobertWalterJ/aerosim/releases/tag/android-v$Version"
