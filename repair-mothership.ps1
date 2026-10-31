param([switch]$AuditOnly)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Existing enrollment and application files are never copied, deleted, or re-enrolled.
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$taskName = 'InfinityComputer-' + $identity.User.Value
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $task) { throw "No Infinity task for Windows account $($identity.Name). Sign in as the enrolled owner." }
if ($task.State -eq 'Disabled') { throw 'Infinity task is deliberately disabled; nothing changed.' }
if (@($task.Actions).Count -ne 1) { throw 'Unexpected task action count; nothing changed.' }
if ($task.Principal.UserId -and @($identity.Name, $identity.User.Value, $env:USERNAME) -notcontains $task.Principal.UserId) {
  throw 'Infinity task belongs to another Windows account; nothing changed.'
}

$action = $task.Actions[0]
$oldExe = ([string]$action.Execute).Trim('"')
if ($oldExe -notmatch '(?i)(^|\\)node\.exe$') { throw "Expected a Node-based Infinity task, found: $oldExe" }
$argsText = [string]$action.Arguments
$settingsMatch = [regex]::Match($argsText, '(?i)--settings\s+(?:"(?<path>[^"]+)"|(?<path>\S+))')
$cliMatch = [regex]::Match($argsText, '(?i)"(?<path>[A-Z]:\\[^"]+\\dist\\cli\.(?:js|mjs))"|(?<path>[A-Z]:\\[^\s]+\\dist\\cli\.(?:js|mjs))')
if (-not $settingsMatch.Success -or -not $cliMatch.Success) {
  throw 'Could not locate the original settings and CLI paths in the scheduled task; nothing changed.'
}
$settings = $settingsMatch.Groups['path'].Value
$cli = $cliMatch.Groups['path'].Value
if (-not (Test-Path -LiteralPath $settings -PathType Leaf)) { throw "Original enrollment file missing: $settings. Nothing changed." }
if (-not (Test-Path -LiteralPath $cli -PathType Leaf)) { throw "Original Infinity CLI missing: $cli. Nothing changed." }
$agentDir = Split-Path -Parent (Split-Path -Parent $cli)
$nativeModule = Join-Path $agentDir 'node_modules\better-sqlite3'
if (-not (Test-Path -LiteralPath $nativeModule -PathType Container)) { throw 'Existing better-sqlite3 package missing; nothing changed.' }
if (-not ([Environment]::Is64BitOperatingSystem) -or $env:PROCESSOR_ARCHITECTURE -notin @('AMD64','x86')) {
  throw 'This pinned recovery is for Windows x64 only; nothing changed.'
}

$version = 'v24.22.1'
$expectedSha = 'd702daa815eabbff763c7d3808e235cf031cf2ca70211b56847bc72f51e240e5'
$nodeDir = Join-Path $env:LOCALAPPDATA "Infinity\Runtime\node-$version-win-x64"
$node = Join-Path $nodeDir 'node.exe'
Write-Host "Infinity owner: $($identity.Name)"
Write-Host "Enrollment exists: True; CLI exists: True; task state: $($task.State)"
Write-Host "System Node unchanged: $oldExe"
Write-Host "Pinned Infinity runtime: $node"
if ($AuditOnly) { return }

New-Item -ItemType Directory -Path $nodeDir -Force | Out-Null
$valid = (Test-Path -LiteralPath $node -PathType Leaf) -and
  ((Get-FileHash -LiteralPath $node -Algorithm SHA256).Hash -ieq $expectedSha)
if (-not $valid) {
  $tempFile = Join-Path $nodeDir ('node-download-' + [guid]::NewGuid().ToString('N') + '.tmp')
  try {
    $uri = "https://nodejs.org/dist/v24.22.1/win-x64/node.exe"
    Write-Host "Downloading official Node.js $version Windows x64 executable..."
    Invoke-WebRequest -Uri $uri -UseBasicParsing -OutFile $tempFile -TimeoutSec 180
    $actual = (Get-FileHash -LiteralPath $tempFile -Algorithm SHA256).Hash
    if ($actual -ine $expectedSha) { throw "Node.js checksum mismatch: refusing installation." }
    Move-Item -LiteralPath $tempFile -Destination $node -Force
  } finally {
    if (Test-Path -LiteralPath $tempFile -PathType Leaf) { Remove-Item -LiteralPath $tempFile -Force }
  }
}
if ((Get-FileHash -LiteralPath $node -Algorithm SHA256).Hash -ine $expectedSha) {
  throw 'Pinned Node executable verification failed. Scheduled task unchanged.'
}

# Check the runtime and native SQLite ABI before changing any startup entry.
$reported = & $node -p 'process.version+"|"+process.versions.modules'
if ($LASTEXITCODE -ne 0 -or $reported -ne 'v24.22.1|137') {
  throw "Pinned runtime ABI check failed: $reported. Scheduled task unchanged."
}
$smoke = 'const Database=require(process.argv[1]);const db=new Database(":memory:");const value=db.prepare("SELECT 137 AS abi").get().abi;db.close();if(value!==137){process.exit(9)};console.log("BETTER_SQLITE3_ABI_OK");'
$nativeResult = & $node -e $smoke $nativeModule
if ($LASTEXITCODE -ne 0 -or $nativeResult -notcontains 'BETTER_SQLITE3_ABI_OK') {
  throw 'Native SQLite in-memory smoke test failed. Scheduled task unchanged.'
}
Write-Host "Node.js $version, ABI 137, and better-sqlite3: verified."

# Preserve the exact original task (triggers, principal, settings, arguments).
$backups = Join-Path $env:LOCALAPPDATA 'Infinity\RecoveryBackups'
New-Item -ItemType Directory -Path $backups -Force | Out-Null
$backup = Join-Path $backups ('mothership-task-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.xml')
Export-ScheduledTask -TaskName $taskName | Set-Content -LiteralPath $backup -Encoding UTF8
$workDir = if ($action.WorkingDirectory) { [string]$action.WorkingDirectory } else { $agentDir }
$newAction = New-ScheduledTaskAction -Execute $node -Argument $argsText -WorkingDirectory $workDir
Set-ScheduledTask -TaskName $taskName -Action $newAction -ErrorAction Stop | Out-Null

# Keep the existing fallback mechanisms pointing to the same tested runtime.
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
New-ItemProperty -Path $runKey -Name $taskName -Value ('"' + $node + '" ' + $argsText) -PropertyType String -Force | Out-Null
$startup = [Environment]::GetFolderPath('Startup')
if ($startup) {
  $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $startup 'InfinityComputer.lnk'))
  $shortcut.TargetPath = $node
  $shortcut.Arguments = $argsText
  $shortcut.WorkingDirectory = $workDir
  $shortcut.WindowStyle = 7
  $shortcut.Description = 'Infinity connection for the signed-in Windows account'
  $shortcut.Save()
}

Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
Start-Sleep -Seconds 12
$current = Get-ScheduledTask -TaskName $taskName
$info = Get-ScheduledTaskInfo -TaskName $taskName
$running = @(Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.ExecutablePath -ieq $node -and ([string]$_.CommandLine).IndexOf($cli,[StringComparison]::OrdinalIgnoreCase) -ge 0 })
Write-Host '--- INFINITY MOTHERSHIP ABI RECOVERY ---'
Write-Host "Pinned runtime: $reported"
Write-Host 'better-sqlite3 in-memory query: PASS'
Write-Host "Task state: $($current.State)"
Write-Host "Task result: 0x$('{0:X8}' -f [uint32]$info.LastTaskResult)"
Write-Host "Matching Infinity process count: $($running.Count)"
Write-Host "Enrollment retained: $(Test-Path -LiteralPath $settings)"
Write-Host "Task backup created: $backup"
if ($running.Count -eq 0) {
  throw 'The native module is repaired, but the agent is not running. Do not re-enroll; inspect the next application error.'
}
Write-Host 'Local Infinity agent running. Independent gateway verification is still required.'
