param([switch]$AuditOnly)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$expectedMachine = 'SKIBBIDI'
if ($env:COMPUTERNAME -ine $expectedMachine) {
  throw "This recovery is for Skibbidi, not $env:COMPUTERNAME."
}

$who = [Security.Principal.WindowsIdentity]::GetCurrent()
$profile = $env:USERPROFILE
$config = Join-Path $profile '.infinity\computer.json'
$taskName = 'InfinityComputer-' + $who.User.Value
$installDir = if ($env:INFINITY_INSTALL_DIR) { $env:INFINITY_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Infinity\bin' }
$binary = Join-Path $installDir 'infinity.exe'
$logDir = Join-Path $env:LOCALAPPDATA 'Infinity\RecoveryBackups'
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

Write-Host "Infinity recovery for $env:COMPUTERNAME, user $($who.Name)"
Write-Host "Enrollment file present: $(Test-Path -LiteralPath $config -PathType Leaf)"
Write-Host "Compiled executable present: $(Test-Path -LiteralPath $binary -PathType Leaf)"
Write-Host "Scheduled task: $(if ($task) { $task.State } else { 'missing' })"
Write-Host "Windows last boot: $((Get-CimInstance Win32_OperatingSystem).LastBootUpTime)"
Write-Host 'The last remote disconnect reason is not determined from the gateway alone.'

if ($AuditOnly) { return }
if (-not (Test-Path -LiteralPath $config -PathType Leaf)) {
  throw 'The existing enrollment file is absent for this Windows account. No new enrollment will be attempted. Verify you are signed in as the original owner.'
}
if ($task) {
  $owner = [string]$task.Principal.UserId
  $allowed = @($who.Name, $who.User.Value, $env:USERNAME)
  if ($owner -notin $allowed) { throw 'The existing Infinity scheduled task belongs to another account. No changes made.' }
  if ($task.State -eq 'Disabled') { throw 'The Infinity task is intentionally disabled; the script will not silently re-enable it.' }
}

if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) {
  Write-Host 'The compiled Infinity executable is missing. Downloading the official verified Windows release (install only)...'
  $uri = 'https://github.com/isiliconx/infinity-codex-releases/releases/latest/download/install.ps1'
  $installer = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 60
  if ($installer.StatusCode -ne 200) { throw "Official release installer returned HTTP $($installer.StatusCode)." }
  $previousInstallOnly = $env:INFINITY_INSTALL_ONLY
  try {
    $env:INFINITY_INSTALL_ONLY = '1'
    & ([scriptblock]::Create([string]$installer.Content))
  } finally {
    $env:INFINITY_INSTALL_ONLY = $previousInstallOnly
  }
}
if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) { throw "No compiled Infinity executable at $binary after verified installation." }

$version = & $binary --version 2>&1
if ($LASTEXITCODE -ne 0) { throw 'The Infinity executable did not pass its version check. Enrollment preserved.' }
Write-Host "Infinity executable version: $($version | Select-Object -First 1)"

New-Item -ItemType Directory -Path $logDir -Force | Out-Null
if ($task) {
  $backup = Join-Path $logDir ('Skibbidi-task-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.xml')
  Export-ScheduledTask -TaskName $taskName | Set-Content -LiteralPath $backup -Encoding UTF8
}

$arguments = '"agent" "--settings" "' + $config + '" --if-not-running'
$action = New-ScheduledTaskAction -Execute $binary -Argument $arguments -WorkingDirectory $installDir
$logon = New-ScheduledTaskTrigger -AtLogOn -User $who.Name
$repeat = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
$isAdmin = ([Security.Principal.WindowsPrincipal]::new($who)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$runLevel = if ($isAdmin) { 'Highest' } else { 'Limited' }
$principal = New-ScheduledTaskPrincipal -UserId $who.Name -LogonType Interactive -RunLevel $runLevel
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$settings.StartWhenAvailable = $true
$settings.DisallowStartIfOnBatteries = $false
$settings.StopIfGoingOnBatteries = $false
$settings.MultipleInstances = 'IgnoreNew'
$settings.Hidden = $false

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($logon, $repeat) -Principal $principal -Settings $settings -Force | Out-Null
$actual = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
if (@($actual.Triggers).Count -ne 2 -or $actual.Settings.Hidden -or $actual.State -eq 'Disabled') {
  throw 'Windows did not register the expected visible logon and recovery task.'
}

# Prevent the older 1.0.15 self-repair path from reverting the stronger task.
$marker = Join-Path (Split-Path $config -Parent) 'startup.marker'
if (Test-Path -LiteralPath $marker -PathType Leaf) {
  Copy-Item -LiteralPath $marker -Destination (Join-Path $logDir 'Skibbidi-previous-startup-marker.txt') -Force
}
$expected = ConvertTo-Json -InputObject @($binary, 'agent', '--settings', $config) -Compress
[System.IO.File]::WriteAllText($marker, $expected, [Text.UTF8Encoding]::new($false))

$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runValue = '"' + $binary + '" ' + $arguments
New-ItemProperty -Path $runKey -Name $taskName -Value $runValue -PropertyType String -Force | Out-Null

$startup = [Environment]::GetFolderPath('Startup')
if (-not $startup) { throw 'Windows Startup directory unavailable.' }
$shortcutPath = Join-Path $startup 'InfinityComputer.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $binary
$shortcut.Arguments = $arguments
$shortcut.WorkingDirectory = $installDir
$shortcut.WindowStyle = 7
$shortcut.Description = 'Infinity connection for the signed-in Windows account'
$shortcut.Save()

# A sleeping machine cannot maintain its outbound connection; keep AC idle sleep disabled.
& powercfg.exe /change standby-timeout-ac 0 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Warning 'Could not disable AC idle sleep.' }

Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
Start-Sleep -Seconds 8
$after = Get-ScheduledTask -TaskName $taskName
$info = Get-ScheduledTaskInfo -TaskName $taskName
Write-Host '--- RECOVERY RESULT ---'
Write-Host "Task: $($after.TaskName) | State: $($after.State) | Run-level: $($after.Principal.RunLevel)"
Write-Host "Triggers: $(@($after.Triggers).Count) | Next scheduled run: $($info.NextRunTime)"
Write-Host "Last Task Scheduler result: $($info.LastTaskResult)"
Write-Host "Startup folder fallback: $(Test-Path -LiteralPath $shortcutPath)"
Write-Host "Enrollment preserved: $(Test-Path -LiteralPath $config)"
Write-Host 'The agent has been launched. Remote gateway connectivity still requires an independent check.'
Write-Host 'If the computer remains offline, inspect Windows network, gateway reachability and the agent diagnostic logs; do not re-enroll.'
