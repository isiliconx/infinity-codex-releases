& {
  $ErrorActionPreference = 'Stop'
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $taskName = 'InfinityComputer-' + $identity.User.Value
  $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

  if (!$task) { throw 'No Infinity task for this Windows account. Sign in as the original enrolled user.' }
  if ($task.State -eq 'Disabled') { throw 'Infinity task is disabled; no changes made.' }
  if (@($task.Actions).Count -ne 1) { throw 'Unexpected task actions; no changes made.' }
  if ($task.Principal.UserId -and @($identity.Name,$identity.User.Value,$env:USERNAME) -notcontains $task.Principal.UserId) {
    throw 'Task belongs to a different Windows account; no changes made.'
  }

  $old = $task.Actions[0]
  $oldExe = ([string]$old.Execute).Trim('"')
  if ($oldExe -notmatch '(?i)(^|\\)node\.exe$') { throw "Unexpected task executable: $oldExe" }
  $arguments = [string]$old.Arguments
  $match = [regex]::Match($arguments, '(?i)--settings\s+(?:"(?<path>[^"]+)"|(?<path>\S+))')
  if (!$match.Success) { throw 'Cannot identify existing Infinity enrollment; no changes made.' }
  $config = $match.Groups['path'].Value
  if (!(Test-Path -LiteralPath $config -PathType Leaf)) {
    throw "Existing enrollment file unavailable: $config. Check the signed-in account."
  }

  $found = Get-Command node.exe -ErrorAction SilentlyContinue
  $candidates = @(
    $(if ($found) { $found.Source }),
    (Join-Path $env:ProgramFiles 'nodejs\node.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\nodejs\node.exe'),
    (Join-Path $env:APPDATA 'npm\node.exe'),
    $oldExe
  )
  $node = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1

  if (!$node) {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (!$winget) { throw 'Node.js is missing and WinGet is unavailable. No task changes made.' }
    Write-Host 'Installing official Node.js LTS to restore the missing runtime...'
    & $winget.Source install --id OpenJS.NodeJS.LTS --exact --source winget --scope machine --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "Node.js installer failed with exit code $LASTEXITCODE." }
    $node = Join-Path $env:ProgramFiles 'nodejs\node.exe'
    if (!(Test-Path -LiteralPath $node -PathType Leaf)) { throw 'Node.js installer completed but node.exe was not found. No task changes made.' }
  }

  $previousWarnings = $env:NODE_NO_WARNINGS
  try {
    $env:NODE_NO_WARNINGS = '1'
    $version = & $node --version
    if ($LASTEXITCODE -ne 0) { throw 'Node runtime validation failed.' }
  } finally {
    if ($null -eq $previousWarnings) { Remove-Item Env:\NODE_NO_WARNINGS -ErrorAction SilentlyContinue }
    else { $env:NODE_NO_WARNINGS = $previousWarnings }
  }

  $backupDir = Join-Path $env:LOCALAPPDATA 'Infinity\RecoveryBackups'
  New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
  Export-ScheduledTask -TaskName $taskName |
    Set-Content -LiteralPath (Join-Path $backupDir ('task-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.xml')) -Encoding UTF8

  if ($oldExe -ine $node) {
    $params = @{ Execute = $node; Argument = $arguments }
    if ($old.WorkingDirectory) { $params.WorkingDirectory = [string]$old.WorkingDirectory }
    $newAction = New-ScheduledTaskAction @params
    Set-ScheduledTask -TaskName $taskName -Action $newAction -ErrorAction Stop | Out-Null
  }

  $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
  $runValue = '"' + $node + '" ' + $arguments
  New-ItemProperty -Path $runKey -Name $taskName -Value $runValue -PropertyType String -Force | Out-Null

  $startup = [Environment]::GetFolderPath('Startup')
  if ($startup) {
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $startup 'InfinityComputer.lnk'))
    $shortcut.TargetPath = $node
    $shortcut.Arguments = $arguments
    if ($old.WorkingDirectory) { $shortcut.WorkingDirectory = [string]$old.WorkingDirectory }
    $shortcut.Save()
  }

  Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
  Start-Sleep -Seconds 10

  $current = Get-ScheduledTask -TaskName $taskName
  $info = Get-ScheduledTaskInfo -TaskName $taskName
  Write-Host '--- MOTHERSHIP INFINITY RECOVERY ---'
  Write-Host "Node: $node ($version)"
  Write-Host "Task: $($current.State)"
  Write-Host "Last result: 0x$('{0:X8}' -f [uint32]$info.LastTaskResult)"
  Write-Host "Enrollment preserved: $(Test-Path -LiteralPath $config)"
  Write-Host 'Local restart attempted; gateway connectivity must be checked separately.'
}