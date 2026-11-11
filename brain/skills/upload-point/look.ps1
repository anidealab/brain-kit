# Upload point: a look at what's waiting, for an agent sorting it (SKILL.md in this folder), and the way
# to take what's been dealt with off the list. From a cloud session, run it as a job on the PC runner with
# checkout on (the my-pc skill), with this command:
#   & "$env:GITHUB_WORKSPACE\skills\upload-point\look.ps1"
# It reads the list Send to, My brain writes on the PC, _upload\waiting.txt in the folder that holds the
# brain's copy (C:\AI-Brain-Link\_upload\waiting.txt): one line per thing, the time it was sent, a tab,
# and its path. For each path it says whether it's there, its kind and size, and a peek inside: a
# folder's top two levels, a text file's first lines, and for a code repo its remote, latest commits,
# what isn't committed, and the start of its README and CLAUDE.md. A look changes nothing.
#   & "$env:GITHUB_WORKSPACE\skills\upload-point\look.ps1" -Done 'C:\a path','D:\another'
# takes those paths' lines off the list instead (an apostrophe in a path is written twice), and says
# what's left. -List <file> names the list when the brain's copy isn't in C:\AI-Brain-Link.
# Windows PowerShell 5.1, plain ASCII.
param([string]$List = '', [string[]]$Done = @())
$ErrorActionPreference = 'Continue'
if (-not $List) {
  # Up from this folder to the one that has the list: from the brain's copy, or from the runner's checkout.
  $d = $PSScriptRoot
  while ($d) {
    $try = Join-Path $d '_upload\waiting.txt'
    if (Test-Path -LiteralPath $try) { $List = $try; break }
    $d = Split-Path $d -Parent
  }
  if (-not $List) { $List = 'C:\AI-Brain-Link\_upload\waiting.txt' }
}
$inv = [Globalization.CultureInfo]::InvariantCulture

function Size-Text([double]$b) {
  if ($b -ge 1GB) { return ($b / 1GB).ToString('0.0', $inv) + ' GB' }
  if ($b -ge 1MB) { return ($b / 1MB).ToString('0.0', $inv) + ' MB' }
  if ($b -ge 1KB) { return ($b / 1KB).ToString('0', $inv) + ' KB' }
  return $b.ToString('0', $inv) + ' bytes'
}
function Measure-Folder([string]$p, [int]$ms) {
  # Files and bytes under a folder, counted for $ms milliseconds at most, then marked with a +.
  $files = 0; $bytes = 0.0; $more = $false
  $clock = [Diagnostics.Stopwatch]::StartNew()
  $todo = New-Object 'Collections.Generic.Stack[string]'
  $todo.Push($p)
  while ($todo.Count -gt 0) {
    if ($clock.ElapsedMilliseconds -gt $ms) { $more = $true; break }
    $d = New-Object IO.DirectoryInfo $todo.Pop()
    try { foreach ($f in $d.GetFiles()) { $files++; $bytes += $f.Length } } catch { }
    try {
      foreach ($s in $d.GetDirectories()) {
        if (-not ($s.Attributes -band [IO.FileAttributes]::ReparsePoint)) { $todo.Push($s.FullName) }
      }
    } catch { }
  }
  $plus = if ($more) { '+' } else { '' }
  $word = if ($files -eq 1 -and -not $more) { ' file' } else { ' files' }
  return (Size-Text $bytes) + $plus + ' in ' + $files.ToString('N0', $inv) + $plus + $word
}
function Peek([string]$file, [int]$count) {
  Get-Content -LiteralPath $file -TotalCount $count -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object { '    | ' + $_ }
}
function Path-Of([string]$line) {
  # A line of the list is the time it was sent, a tab, and the path.
  $at = $line.IndexOf("`t")
  if ($at -lt 0) { return $line.Trim() }
  return $line.Substring($at + 1).Trim()
}

$lines = @()
if (Test-Path -LiteralPath $List) { $lines = @([IO.File]::ReadAllLines($List) | Where-Object { $_.Trim() }) }

if ($Done.Count) {
  $gone = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach ($p in $Done) { if ("$p".Trim()) { [void]$gone.Add("$p".Trim().TrimEnd('\')) } }
  $keep = @($lines | Where-Object { -not $gone.Contains((Path-Of $_).TrimEnd('\')) })
  if ($keep.Count -eq $lines.Count) { 'None of those paths is on the list, ' + $List + ': nothing taken off.' }
  else {
    [IO.File]::WriteAllLines($List, [string[]]$keep, (New-Object Text.UTF8Encoding $true))
    'Taken off the list: ' + ($lines.Count - $keep.Count) + '.'
  }
  if ($keep.Count) { 'Still waiting:'; $keep | ForEach-Object { '  ' + $_ } } else { 'Nothing waiting.' }
  exit 0
}

if (-not $lines.Count) { 'Nothing waiting. (The list: ' + $List + ')'; exit 0 }
'The list: ' + $List
$git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$readable = '^\.(txt|md|markdown|csv|tsv|json|ya?ml|xml|html?|css|js|ts|py|ps1|sh|ini|cfg|conf|toml|log|sql)$'
foreach ($line in $lines) {
  $p = Path-Of $line
  $at = $line.IndexOf("`t")
  $when = if ($at -gt 0) { '   (sent ' + $line.Substring(0, $at).Trim() + ')' } else { '' }
  ''
  '== ' + $p + $when
  if (-not (Test-Path -LiteralPath $p)) { '  not there: moved, deleted, or on a drive that is unplugged'; continue }
  $i = Get-Item -LiteralPath $p -Force
  if (-not $i.PSIsContainer) {
    '  file, ' + (Size-Text $i.Length) + ', changed ' + $i.LastWriteTime.ToString('d MMM yyyy', $inv)
    if ($i.Extension -match $readable -and $i.Length -lt 5MB) { Peek $i.FullName 20 }
    continue
  }
  $isRepo = Test-Path -LiteralPath (Join-Path $p '.git')
  $kind = if ($isRepo) { 'git repo' } else { 'folder' }
  '  ' + $kind + ', ' + (Measure-Folder $p 5000) + ', changed ' + $i.LastWriteTime.ToString('d MMM yyyy', $inv)
  foreach ($c in @(Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue | Sort-Object { -not $_.PSIsContainer }, Name | Select-Object -First 40)) {
    if (-not $c.PSIsContainer) { '  ' + $c.Name + '  ' + (Size-Text $c.Length); continue }
    '  ' + $c.Name + '\  (' + (Measure-Folder $c.FullName 1500) + ')'
    if ($isRepo) { continue }
    foreach ($cc in @(Get-ChildItem -LiteralPath $c.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 12)) {
      if ($cc.PSIsContainer) { '    ' + $cc.Name + '\' } else { '    ' + $cc.Name + '  ' + (Size-Text $cc.Length) }
    }
  }
  if ($isRepo -and $git) {
    '  -- remote:'
    & $git.Source -C $p remote -v 2>&1 | ForEach-Object { '    ' + $_ }
    '  -- latest commits:'
    & $git.Source -C $p log --oneline -15 2>&1 | ForEach-Object { '    ' + $_ }
    '  -- not committed:'
    & $git.Source -C $p status --short 2>&1 | Select-Object -First 15 | ForEach-Object { '    ' + $_ }
  }
  foreach ($n in 'README.md', 'README.txt', 'README', 'CLAUDE.md') {
    $f = Join-Path $p $n
    if (Test-Path -LiteralPath $f -PathType Leaf) { '  -- ' + $n + ':'; Peek $f 30 }
  }
}
exit 0
