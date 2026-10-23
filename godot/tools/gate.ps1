# One-command gate: does the game load, fly, and render in all modes? Prints GATE PASS or GATE FAIL.
# Usage (from the godot folder):  powershell -ExecutionPolicy Bypass -File tools\gate.ps1 -Tag stagename
param([string]$Tag = "gate")
$ErrorActionPreference = "Continue"
$godot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe")).Path
$proj = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$shots = Join-Path $env:LOCALAPPDATA "Temp\shots"
New-Item -ItemType Directory -Force $shots | Out-Null
$fail = @()
$bs = [string][char]92

function Run($label, $argList, $timeoutSec) {
  $p = Start-Process -FilePath $godot -ArgumentList $argList -PassThru -NoNewWindow -RedirectStandardOutput "$shots\gate_$label.txt" -RedirectStandardError "$shots\gate_$label.err"
  if (-not $p.WaitForExit($timeoutSec * 1000)) { Stop-Process -Id $p.Id -Force; return "TIMEOUT" }
  return "OK"
}

& $godot --headless --path $proj --import 2>&1 | Out-Null

$modes = @(
  @{n="full";   a=@();                              t="fpv,clock16.0,at-18_20_36_190_-20"},
  @{n="simple"; a=@();                              t="fpv,simple,clock16.0,at-18_20_36_190_-20"},
  @{n="mobile"; a=@("--rendering-method","mobile"); t="fpv,clock16.0,at-18_20_36_190_-20"},
  @{n="chase";  a=@();                              t="chase,clock13.0,armed,dronefreestyle,cd2,at-18_3_36_150_-20"}
)
foreach ($m in $modes) {
  $png = "$shots\$($Tag)_$($m.n).png"
  if (Test-Path $png) { Remove-Item $png }
  $pngFwd = $png.Replace($bs, "/")
  $argList = @("--path", "`"$proj`"") + $m.a + @("--", "`"shot=$pngFwd,300,$($m.t)`"")
  $r = Run $m.n $argList 150
  $log = (Get-Content "$shots\gate_$($m.n).txt", "$shots\gate_$($m.n).err" -ErrorAction SilentlyContinue) -join "`n"
  if ($r -eq "TIMEOUT") { $fail += "$($m.n): timed out" }
  elseif ($log -match "SCRIPT ERROR|Parse Error|Failed to load script") { $fail += "$($m.n): script error" }
  elseif (-not (Test-Path $png)) { $fail += "$($m.n): no screenshot" }
}

$r = Run "apstest" @("--path", "`"$proj`"", "--", "apstest") 240
$ap = (Get-Content "$shots\gate_apstest.txt" -ErrorAction SilentlyContinue) -join "`n"
if ($ap -notmatch "after takeoff agl" -or $ap -notmatch "rth finished.*crashed=false") { $fail += "apstest failed" }
if ($ap -match "SCRIPT ERROR") { $fail += "apstest: script error" }

if ($fail.Count -eq 0) { Write-Output "GATE PASS ($Tag). Shots: $shots\$($Tag)_*.png" }
else { Write-Output "GATE FAIL ($Tag): $($fail -join '; ')" }
