# Keeps this PC's runner going while its owner is signed in. setup-runner.ps1 copies it beside the
# runner and makes it start, hidden, at sign-in. It runs the runner, and starts it again a minute after
# it ever stops, with the PATH read fresh each time, so a program installed since is found: ending the
# Runner.Listener process is how to restart the runner. Only one copy runs per runner folder.
# Works in Windows PowerShell 5.1.
$ErrorActionPreference = 'Continue'
$dir = $PSScriptRoot
$mutex = New-Object Threading.Mutex($false, ('Local\ai-brain-link-runner-' + ($dir -replace '[^A-Za-z0-9]', '-')))
if (-not $mutex.WaitOne(0)) { exit 0 }
$log = Join-Path (Split-Path $dir -Parent) '_logs\runner-starts.log'
function Log($t) { try { Add-Content -LiteralPath $log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $t" } catch { } }
Set-Location $dir
while ($true) {
  $env:Path = (@([Environment]::GetEnvironmentVariable('Path', 'Machine'), [Environment]::GetEnvironmentVariable('Path', 'User')) | Where-Object { $_ }) -join ';'
  Log 'starting the runner'
  & (Join-Path $dir 'run.cmd') *> $null
  Log "the runner stopped (exit $LASTEXITCODE); starting it again in a minute"
  Start-Sleep -Seconds 60
}
