# Upload point: what "My brain" in File Explorer's Send to menu runs. The owner selects files or folders,
# right-clicks, and picks Send to, then My brain; this adds each one's path to a plain text list on the PC
# and says so in a small box. An agent reads the list and sorts them into the brain when the owner says
# what to do (SKILL.md in this folder).
# The list is _upload\waiting.txt in the folder that holds the brain's copy (C:\AI-Brain-Link\_upload\
# waiting.txt): one line per thing, the time it was sent, a tab, and its path. UTF-8.
# Paths only, no copies, except anything on a USB stick or other removable drive, which is copied to
# _upload\<date>\ first, since the stick may be gone by the time the agent looks; the copy is what's listed.
# A first argument of -Quiet prints the message instead of showing the box (for an agent or a test).
# setup-upload-point.ps1 makes the Send to entry. Windows PowerShell 5.1, plain ASCII. Windows only.

$given = @($args | ForEach-Object { "$_".Trim().Trim('"') } | Where-Object { $_ })
$quiet = $false
if ($given.Count -and $given[0] -eq '-Quiet') { $quiet = $true; $given = @($given | Select-Object -Skip 1) }
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$ErrorActionPreference = 'Continue'

# Where the list is, from where this script sits: <the brain's copy>\skills\upload-point.
$copy = Split-Path (Split-Path $here -Parent) -Parent
$upload = Join-Path (Split-Path $copy -Parent) '_upload'
$list = Join-Path $upload 'waiting.txt'
$utf8 = New-Object Text.UTF8Encoding $true

function Tell([string[]]$lines) {
  $text = ($lines | Where-Object { $_ }) -join "`r`n`r`n"
  if ($quiet) { Write-Output $text; return }
  Add-Type -AssemblyName System.Windows.Forms
  [void][Windows.Forms.MessageBox]::Show($text, 'My brain')
}
function On-Removable([string]$p) {
  try {
    $r = [IO.Path]::GetPathRoot($p)
    if (-not $r -or $r.StartsWith('\\')) { return $false }
    $t = (New-Object IO.DriveInfo $r).DriveType
    return ($t -eq [IO.DriveType]::Removable -or $t -eq [IO.DriveType]::CDRom)
  } catch { return $false }
}
function Copy-In([string]$p) {
  # A copy in _upload\<date>\, under a name nothing there has yet.
  $item = Get-Item -LiteralPath $p -Force -ErrorAction Stop
  $dir = Join-Path $upload (Get-Date).ToString('yyyy-MM-dd')
  [void](New-Item -ItemType Directory -Force -Path $dir -ErrorAction Stop)
  $name = $item.Name
  if (-not $name -or $name.Contains(':')) { $name = 'drive-' + $p.Substring(0, 1) }
  $dest = Join-Path $dir $name
  $n = 2
  while (Test-Path -LiteralPath $dest) {
    if ($item.PSIsContainer) { $dest = Join-Path $dir ($name + ' (' + $n + ')') }
    else { $dest = Join-Path $dir ($item.BaseName + ' (' + $n + ')' + $item.Extension) }
    $n++
  }
  Copy-Item -LiteralPath $item.FullName -Destination $dest -Recurse -Force -ErrorAction Stop
  return $dest
}

if (-not $given.Count) {
  Tell @('Nothing was sent. To give your brain files or folders, select them in File Explorer, right-click, and pick Send to, then My brain.')
  exit 0
}

# What's on the list already, so the same path isn't listed twice.
$have = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
if (Test-Path -LiteralPath $list) {
  foreach ($line in [IO.File]::ReadAllLines($list)) {
    $at = $line.IndexOf("`t")
    if ($at -ge 0) { [void]$have.Add($line.Substring($at + 1).Trim()) }
  }
}

$new = New-Object 'Collections.Generic.List[string]'
$trouble = New-Object 'Collections.Generic.List[string]'
$sent = 0
foreach ($p in $given) {
  try { $p = [IO.Path]::GetFullPath($p) } catch { }
  if ($p.Length -gt 3) { $p = $p.TrimEnd('\') }
  if (-not (Test-Path -LiteralPath $p)) { $trouble.Add("Couldn't find " + $p); continue }
  if (On-Removable $p) {
    try { $p = Copy-In $p } catch { $trouble.Add("Couldn't copy " + [IO.Path]::GetFileName($p) + " off the drive, so it's listed where it is.") }
  }
  $sent++
  if ($have.Add($p)) { $new.Add((Get-Date).ToString('yyyy-MM-dd HH:mm') + "`t" + $p) }
}

if ($new.Count) {
  try {
    [void](New-Item -ItemType Directory -Force -Path $upload -ErrorAction Stop)
    [IO.File]::AppendAllText($list, (($new -join "`r`n") + "`r`n"), $utf8)
  } catch {
    Tell (@("Not sent: couldn't write the list, " + $list + '. ' + $_.Exception.Message) + $trouble)
    exit 1
  }
}
$msg = @()
if ($sent) { $msg += 'Sent to your brain: ' + $sent + '. Tell Claude what to do with them.' }
Tell ($msg + $trouble)
exit 0
