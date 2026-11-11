# Sets up the upload point on this PC: "My brain" in File Explorer's Send to menu (right-click files or
# folders, Send to, My brain). It runs upload-point.ps1 from this folder in the brain's copy, so a change
# to it reaches the PC with the next sync. It also takes away the "Upload point" shortcut an earlier
# version put on the desktop, since the window it opened is gone. No admin rights needed, and safe to run
# again. The kit's installer runs it after cloning the brain; otherwise:
#   powershell -ExecutionPolicy Bypass -File "C:\AI-Brain-Link\<repo name>\skills\upload-point\setup-upload-point.ps1"
# It prints one line, and exits 1 if it couldn't. How the upload point works: SKILL.md in this folder.
# Windows PowerShell 5.1, plain ASCII.
$ErrorActionPreference = 'Stop'

try {
  $script = Join-Path $PSScriptRoot 'upload-point.ps1'
  if (-not (Test-Path -LiteralPath $script)) { throw ("upload-point.ps1 isn't next to this script, in " + $PSScriptRoot) }
  $copy = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent   # the brain's copy: <copy>\skills\upload-point
  $sendTo = [Environment]::GetFolderPath('SendTo')
  if (-not $sendTo) { $sendTo = Join-Path $env:APPDATA 'Microsoft\Windows\SendTo' }
  $shell = New-Object -ComObject WScript.Shell
  $lnkPath = Join-Path $sendTo 'My brain.lnk'
  $lnk = $shell.CreateShortcut($lnkPath)
  $lnk.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $lnk.Arguments = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $script + '"'
  $lnk.WorkingDirectory = $copy
  $lnk.Description = 'Send files and folders to your brain'
  $lnk.Save()
  if (-not (Test-Path -LiteralPath $lnkPath)) { throw ("couldn't save " + $lnkPath) }
  # The old desktop shortcut, only if it's the one that opened the upload point's window.
  $old = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Upload point.lnk'
  if (Test-Path -LiteralPath $old) {
    try {
      if ($shell.CreateShortcut($old).Arguments -like '*upload-point.ps1*') { Remove-Item -LiteralPath $old -Force }
    } catch { }
  }
  Write-Host 'Upload point ready: right-click files or folders, then Send to, My brain.'
  exit 0
} catch {
  Write-Host ("The upload point isn't set up: " + $_.Exception.Message)
  exit 1
}
