# Sets up the PC runner for this brain, or sets it up again: GitHub's Actions runner, registered with
# this brain's repo under the label my-pc (and gpu with an NVIDIA card), started hidden each time you
# sign in to Windows, under your own account, so AI agents can run jobs on this PC while you're signed in
# (a locked screen is fine).
#   powershell -ExecutionPolicy Bypass -File skills\my-pc\setup-runner.ps1 [-Repo owner/name]
# It needs no password and no admin rights. Only on a PC set up before, with the runner as a Windows
# service, it asks for admin rights once, to take that service off. Safe to run again.
# How agents use the runner: skills/my-pc/SKILL.md. Works in Windows PowerShell 5.1.
param([string]$Repo = '', [string]$Root = 'C:\AI-Brain-Link')
$ErrorActionPreference = 'Stop'

function Find-First($paths) { foreach ($p in $paths) { if ($p -and (Test-Path $p)) { return $p } }; return $null }
function Find-Gh {
  $c = Get-Command gh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($c) { return $c.Source }
  return Find-First @("$env:ProgramFiles\GitHub CLI\gh.exe", "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe")
}
# Runs a program without Windows PowerShell 5.1 turning what it writes to stderr into errors.
function Native([scriptblock]$Block) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { & $Block } finally { $ErrorActionPreference = $old }
}
function Yes($q) { $a = Read-Host "$q [Y/n]"; return -not ($a -match '^\s*[Nn]') }
# Adds a folder to your own PATH (no admin needed), which the runner reads each time it starts, and to this window's.
function Add-UserPath($dir) {
  $all = @(([Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')) -split ';' | ForEach-Object { $_.TrimEnd('\') })
  if ($all -contains $dir.TrimEnd('\')) { return $false }
  $p = [Environment]::GetEnvironmentVariable('Path', 'User')
  [Environment]::SetEnvironmentVariable('Path', ((@($p.TrimEnd(';'), $dir) | Where-Object { $_ }) -join ';'), 'User')
  $env:Path = "$env:Path;$dir"
  return $true
}
function Quote($s) { "'" + "$s".Replace("'", "''") + "'" }

if (-not $Repo) {
  $brain = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
  $url = "$(Native { git -C $brain remote get-url origin 2>$null })"
  if ($url -match 'github\.com[/:]([^/\s]+/[^/\s]+?)(\.git)?\s*$') { $Repo = $Matches[1] }
}
if (-not $Repo) { $Repo = (Read-Host "Your brain's repo on GitHub, as owner/name").Trim() }

$code = 0
$runner = Join-Path $Root '_runner'
$account = [Security.Principal.WindowsIdentity]::GetCurrent().Name
# One name per runner folder, so a second runner in another folder gets its own.
$taskName = 'AI Brain Link runner - ' + (Split-Path $Root -Leaf)
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$starter = Join-Path $runner 'start-runner.ps1'
$launcher = Join-Path $runner 'start-runner.js'

# Stops this folder's runner if it's going (from an earlier run of this setup), so it can be registered again.
function Stop-ThisRunner {
  Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Stop-ScheduledTask -ErrorAction SilentlyContinue
  $mine = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    ("$($_.CommandLine)" -like "*$starter*") -or ("$($_.ExecutablePath)" -like "$runner\bin\*")
  })
  foreach ($p in $mine) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
  if ($mine) { Start-Sleep -Seconds 2 }
}
function Old-Services { @(Get-CimInstance Win32_Service -Filter "Name LIKE 'actions.runner.%'" -ErrorAction SilentlyContinue | Where-Object { "$($_.PathName)" -like "*$runner\bin\*" }) }

try {
  $gh = Find-Gh
  if (-not $gh) { throw "GitHub's command line tool (gh) isn't installed. Run the brain's installer first, or: winget install --id GitHub.cli -e" }
  foreach ($d in $Root, $runner, (Join-Path $Root '_logs'), (Join-Path $Root 'Tools')) { New-Item -ItemType Directory -Force -Path $d | Out-Null }

  # A PC set up before ran the runner as a Windows service, with the owner's password. Taking the service
  # off needs admin rights, so they're asked for here, once, and only then. If they're refused, nothing
  # has changed and the old runner goes on as it was.
  $old = Old-Services
  if ($old) {
    Write-Host 'This PC runs its runner the older way, as a Windows service with your password. This moves it to starting when you sign in, with no password: Windows asks for admin rights once, to take the old service off.' -ForegroundColor Cyan
    $names = ($old | ForEach-Object { Quote $_.Name }) -join ','
    # The service's files belong to Administrators, so they're given back to the owner: the runner can
    # then update itself, and git doesn't call its checkouts "dubious ownership".
    $cmd = "foreach (`$s in @($names)) { Stop-Service `$s -Force -ErrorAction SilentlyContinue; sc.exe delete `$s | Out-Null }; " +
      "Remove-Item -LiteralPath $(Quote (Join-Path $runner '.service')) -Force -ErrorAction SilentlyContinue; " +
      "icacls $(Quote $runner) /setowner $(Quote $account) /T /C /Q | Out-Null; " +
      "icacls $(Quote $runner) /grant $(Quote ($account + ':(OI)(CI)F')) /T /C /Q | Out-Null"
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    try { Start-Process powershell -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $enc" }
    catch { throw "Admin rights weren't given, so nothing changed: the runner goes on as it was. Paste the same command again when you're ready." }
    Start-Sleep -Seconds 2
    if (Old-Services) { throw "The old runner service couldn't be taken off, so it goes on as it was. Ask an agent, and say what this window showed." }
    Write-Host 'The old service is off.'
  }
  Stop-ThisRunner

  # Git's installer can leave Git off the PATH (an owner's PC, 22 Oct 2026). Jobs and gh need Git, so
  # it's added to your own PATH, which the runner reads when it starts.
  $gitCmd = Join-Path $env:ProgramFiles 'Git\cmd'
  if (Test-Path (Join-Path $gitCmd 'git.exe')) {
    if (Add-UserPath $gitCmd) { Write-Host "Added Git to your PATH." }
  }

  Write-Host 'Letting your account run scripts (RemoteSigned), which the runner needs...'
  # It saves the setting, then throws "Security error." whenever a narrower scope overrides it, which
  # this script's own -ExecutionPolicy Bypass always does; -ErrorAction can't stop that kind of error,
  # so it's caught, and only the check below counts (an owner's PC, 22 Oct 2026).
  try { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop } catch { }
  if ((Get-ExecutionPolicy -Scope CurrentUser) -notin 'RemoteSigned', 'Unrestricted', 'Bypass') {
    Write-Host "  It didn't change (a policy on this PC may set it). If jobs fail with a script policy error, tell an agent." -ForegroundColor Yellow
  }

  if (-not (Test-Path (Join-Path $runner 'bin\Runner.Listener.exe'))) {
    $tag = "$(Native { & $gh api repos/actions/runner/releases/latest --jq .tag_name })".Trim()
    if ($tag -notmatch '^v(\d+\.\d+\.\d+)$') { throw "Couldn't find the latest version of GitHub's runner ('$tag'). Check the internet connection and run this again." }
    $ver = $Matches[1]
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    $zip = Join-Path $env:TEMP "actions-runner-win-$arch-$ver.zip"
    Write-Host "Downloading GitHub's runner $ver..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue' # the progress bar makes downloads very slow in PowerShell 5.1
    # Through gh first: GitHub's plain release-download links can answer 504 for hours while gh's route, through
    # its API, works (8 Nov 2026). The plain link is the fallback.
    Native { & $gh release download "v$ver" --repo actions/runner --pattern "actions-runner-win-$arch-$ver.zip" --clobber --dir $env:TEMP 2>&1 } | Out-Null
    if ($LASTEXITCODE -ne 0) { Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/actions/runner/releases/download/v$ver/actions-runner-win-$arch-$ver.zip" -OutFile $zip }
    Expand-Archive -Path $zip -DestinationPath $runner -Force
    Remove-Item $zip -Force
  }
  Set-Location $runner
  # Called directly rather than through config.cmd, so cmd.exe can't trip on anything in an argument.
  $listener = Join-Path $runner 'bin\Runner.Listener.exe'

  function Remove-OldRegistration {
    if (-not (Test-Path '.runner')) { return }
    Write-Host 'Removing the old registration first...'
    $rt = "$(Native { & $gh api -X POST "repos/$Repo/actions/runners/remove-token" --jq .token })".Trim()
    if ($rt) { Native { & $listener remove --token $rt } | Out-Host }
    if (Test-Path '.runner') { # GitHub had already forgotten it, or the removal failed: clear it here
      Remove-Item '.runner', '.credentials', '.credentials_rsaparams', '.service' -Force -ErrorAction SilentlyContinue
    }
  }

  $name = $env:COMPUTERNAME
  $labels = 'my-pc'
  if (Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA' }) { $labels = 'my-pc,gpu' }
  $ok = $false
  for ($try = 1; $try -le 2 -and -not $ok; $try++) {
    Remove-OldRegistration
    $token = "$(Native { & $gh api -X POST "repos/$Repo/actions/runners/registration-token" --jq .token })".Trim()
    if (-not $token) { throw "GitHub didn't hand over a runner token for $Repo. Check the repo is yours and that gh is signed in (gh auth status)." }
    Native { & $listener configure --unattended --url "https://github.com/$Repo" --token $token --name $name --labels $labels --work _work --replace } | Out-Host
    $ok = ($LASTEXITCODE -eq 0) -and (Test-Path '.runner')
  }
  if (-not $ok) { throw "The runner couldn't be registered. Ask an agent, and say what the window showed." }

  # The runner runs from start-runner.ps1, which starts it again a minute after it ever stops, with the
  # PATH read fresh. A one-line script for Windows' script host starts that with no window: a PowerShell
  # window can't be hidden from the start by PowerShell itself.
  Copy-Item (Join-Path $PSScriptRoot 'start-runner.ps1') $starter -Force
  $js = "new ActiveXObject('WScript.Shell').Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -File " +
    '"' + $starter.Replace('\', '\\').Replace("'", "\'") + '"' + "', 0, false);"
  Set-Content -LiteralPath $launcher -Value $js -Encoding ASCII
  $wscript = Join-Path $env:SystemRoot 'System32\wscript.exe'
  $startArgs = '//B //Nologo "' + $launcher + '"'

  Write-Host 'Making it start, hidden, each time you sign in...'
  $how = 'task'
  try {
    $action = New-ScheduledTaskAction -Execute $wscript -Argument $startArgs -WorkingDirectory $runner
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $account
    $principal = New-ScheduledTaskPrincipal -UserId $account -LogonType Interactive -RunLevel Limited
    # On battery too, and at normal priority: a task's default, below normal, would slow every job.
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -Priority 4
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Starts the PC runner for your AI brain, hidden, when you sign in. Set up by skills\my-pc\setup-runner.ps1 in your brain.' -Force | Out-Null
    Remove-ItemProperty -Path $runKey -Name $taskName -ErrorAction SilentlyContinue
  } catch {
    # Where Windows won't let an account make a sign-in task without admin rights, its own startup list does the same.
    Set-ItemProperty -Path $runKey -Name $taskName -Value ('"' + $wscript + '" ' + $startArgs)
    $how = 'startup'
  }
  if ($how -eq 'task') { Start-ScheduledTask -TaskName $taskName } else { Start-Process $wscript -ArgumentList $startArgs }

  Write-Host 'Adding the "AI Brain Link - live jobs" window to your desktop...'
  $watch = Join-Path $Root 'Tools\watch-jobs.ps1'
  Copy-Item (Join-Path $PSScriptRoot 'watch-jobs.ps1') $watch -Force
  # A runner in another folder (a second one, or a test) gets its own shortcut, so the first one's stays.
  $lnkName = if ((Split-Path $Root -Leaf) -eq 'AI-Brain-Link') { 'AI Brain Link - live jobs.lnk' } else { "AI Brain Link - live jobs ($(Split-Path $Root -Leaf)).lnk" }
  $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) $lnkName))
  $lnk.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $lnk.Arguments = '-NoExit -ExecutionPolicy Bypass -File "' + $watch + '"'
  $lnk.Save()

  Write-Host ''
  if (Yes "Keep this PC awake while it's plugged in, so Claude can do what you ask when you're away from it? The screen still turns off as usual.") {
    Native { powercfg /change standby-timeout-ac 0 } | Out-Null
    $awake = $LASTEXITCODE -eq 0
    Native { powercfg /change hibernate-timeout-ac 0 } | Out-Null
    if ($awake -and $LASTEXITCODE -eq 0) { Write-Host 'Done: it no longer sleeps while plugged in.' }
    else { Write-Host "Windows didn't let that change here. To do it, open PowerShell as administrator and paste: powercfg /change standby-timeout-ac 0; powercfg /change hibernate-timeout-ac 0" -ForegroundColor Yellow }
  }

  # Done only once GitHub sees the runner online, so nobody is told it worked when it didn't.
  $state = ''
  for ($i = 0; $i -lt 18 -and $state -ne 'online'; $i++) {
    Start-Sleep -Seconds 5
    try { $list = Native { & $gh api "repos/$Repo/actions/runners" } | Out-String | ConvertFrom-Json } catch { $list = $null }
    $state = "$(($list.runners | Where-Object { $_.name -eq $name } | Select-Object -First 1).status)"
  }
  if ($state -ne 'online') { throw "The runner is installed, but GitHub doesn't see it online yet ($(if ($state) { "it says $state" } else { 'it isn''t listed' })). Run this again, or ask an agent, and say what this window showed." }
  Write-Host ''
  Write-Host "The PC runner '$name' is set up, and GitHub sees it online." -ForegroundColor Green
  Write-Host "It starts by itself, hidden, whenever you sign in to Windows, so agents can run jobs while you're signed in (a locked screen is fine)."
} catch {
  Write-Host ''
  Write-Host "Something went wrong: $($_.Exception.Message)" -ForegroundColor Red
  $code = 1
}
exit $code
