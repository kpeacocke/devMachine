<#
Surface (ARM64) — Auto power plan toggle on AC/battery
- AC power (AcOnline=1)   -> Ultimate Performance
- Battery (AcOnline=0)    -> Balanced
Creates two scheduled tasks that trigger on Kernel-Power Event ID 105.

Run:
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\32-powerplan-auto-toggle.ps1
#>

$ErrorActionPreference = 'Stop'

# GUIDs
$GUID_Ultimate = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
$GUID_Balanced = '381b4222-f694-41f0-9685-ff5bb260df2e'  # built-in Balanced

Write-Host "Ensuring Ultimate Performance plan exists…"
try { powercfg -duplicatescheme $GUID_Ultimate | Out-Null } catch {}

# XML queries for System log → Microsoft-Windows-Kernel-Power, Event ID 105, AcOnline 1/0
$Q_AC = @"
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">
      *[System[Provider[@Name='Microsoft-Windows-Kernel-Power'] and (EventID=105)]]
      and
      *[EventData[Data[@Name='AcOnline']='1']]
    </Select>
  </Query>
</QueryList>
"@

$Q_DC = @"
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">
      *[System[Provider[@Name='Microsoft-Windows-Kernel-Power'] and (EventID=105)]]
      and
      *[EventData[Data[@Name='AcOnline']='0']]
    </Select>
  </Query>
</QueryList>
"@

# Action commands
$Cmd_AC = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "powercfg -setactive ' + $GUID_Ultimate + '"'
$Cmd_DC = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "powercfg -setactive ' + $GUID_Balanced + '"'

# Create/replace tasks
$T1 = "PowerPlan-ACon-Ultimate"
$T2 = "PowerPlan-DC-Balanced"

Write-Host "Creating scheduled task for AC → Ultimate Performance…"
schtasks /Delete /TN $T1 /F 2>$null | Out-Null
schtasks /Create /TN $T1 /SC ONEVENT /EC System /MO $Q_AC /TR $Cmd_AC /RL HIGHEST /F | Out-Null

Write-Host "Creating scheduled task for Battery → Balanced…"
schtasks /Delete /TN $T2 /F 2>$null | Out-Null
schtasks /Create /TN $T2 /SC ONEVENT /EC System /MO $Q_DC /TR $Cmd_DC /RL HIGHEST /F | Out-Null

Write-Host "✅ Auto power plan toggle is configured."
Write-Host "Tip: unplug/plug AC to test. Current plan:"
powercfg -getactivescheme
