# Sets up your own second brain on this Windows PC, from the AnIdeaLab brain kit. It asks you to accept
# AnIdeaLab's terms of use (TERMS.md, at the kit repo's root) first, and stops if you don't. It opens Claude
# in the browser, to sign in or sign up for a paid plan (S skips it), and asks whether you'd like Obsidian.
# Then it installs Git and GitHub's command line (gh) if they're missing, and Obsidian if you said yes, signs
# you in to GitHub, makes your brain's private repo (inviting AnIdeaLab's testing account to it, as the terms
# say) and puts the brain in it, puts your copy in C:\AI-Brain-Link, with Obsidian's syncing on if you chose
# Obsidian, adds the upload point if the brain has one, sets up the PC runner if you say yes to it, so AI
# agents can run jobs on this PC, and opens Obsidian last. Obsidian and the runner are extras: your brain
# works without either, and pasting the same command again adds one later.
# Safe to run again: it skips what's already done. It ends with a list of which steps finished, and
# keeps it in C:\AI-Brain-Link\_logs\install.log, which the setup check reads.
# Where the brain comes from, first found:
# - -Brain <a brain folder or a .bundle file>;
# - a .bundle file next to this script (the zip tools\kit.py makes);
# - the kit repo's brain\ folder beside this script's install\ folder. install.ps1, at the kit repo's
#   root, downloads the repo as a zip and runs this from it, with -Zip <that zip>, which says which of
#   the brain's files are programs (a mark Windows' files don't keep).
# START-HERE.txt has the one command that runs it. It's part of the kit's repo, AnIdeaLab/brain-kit.
# Works in Windows PowerShell 5.1.
param([string]$Brain = '', [string]$Zip = '')
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$check = $env:BRAIN_KIT_CHECK # a test folder: nothing is installed, and GitHub and Obsidian aren't touched
$root = if ($check) { $check } else { 'C:\AI-Brain-Link' }
# AnIdeaLab's set-up (the brain set up for you): BRAIN_KIT_SETUP=1, in the command its set-up page gives. It
# lets AnIdeaLab's set-up account in to the brain even when the brain was made already (from the template),
# says what the runner is for in the set-up, and ends with "we'll take it from here" instead of the chat steps.
$setup = [bool]$env:BRAIN_KIT_SETUP
$noBom = New-Object Text.UTF8Encoding $false # Obsidian can't read JSON that starts with a byte-order mark

function Say($t) { Write-Host ''; Write-Host $t -ForegroundColor Cyan }
# Each question in yellow on its own line, so it can't be missed among the installs' output.
function Ask($q, $default) {
  if ($check) { return $default }
  Write-Host ''
  Write-Host $q -ForegroundColor Yellow
  $a = Read-Host "Type your answer, or press Enter for $default"
  if ([string]::IsNullOrWhiteSpace($a)) { return $default }
  return $a.Trim()
}

# The steps and how each went, kept in C:\AI-Brain-Link\_logs\install.log as it goes and listed at the end,
# so if the setup stops, or its window is closed, the brain's agent and the setup check can see how far it
# got. On an owner's PC (31 Oct 2026) it stopped after Obsidian with nothing on screen or on the PC to say why.
$steps = [ordered]@{}
$logFile = Join-Path (Join-Path $root '_logs') 'install.log'
function Log($t) { try { [IO.File]::AppendAllText($logFile, ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + "  $t`r`n"), $noBom) } catch { } }
function Step($name, $state) { $steps[$name] = $state; Log "$state  $name" }
function Show-Steps {
  Write-Host ''
  Write-Host 'The setup, step by step:' -ForegroundColor Cyan
  foreach ($k in $steps.Keys) {
    $s = $steps[$k]
    $colour = if ($s -eq 'done') { 'Green' } elseif ($s -eq 'skipped') { 'Gray' } else { 'Yellow' }
    $shown = if ($s -eq 'started') { 'stopped here' } else { $s }
    Write-Host ('  {0,-12} {1}' -f $shown, $k) -ForegroundColor $colour
  }
  Write-Host "  (also kept in $logFile)"
}

# Clicking inside a Windows 10 PowerShell window starts a selection, which pauses the setup until a key is
# pressed, with only "Select" in the title bar to say so. So QuickEdit is off while it runs, then put back.
$script:consoleMode = $null
function Set-QuickEdit([bool]$on) {
  try {
    if (-not ('KitConsole.Mode' -as [type])) {
      Add-Type -Namespace KitConsole -Name Mode -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int n);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint m);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint m);
'@
    }
    $h = [KitConsole.Mode]::GetStdHandle(-10)
    if ($on) {
      if ($null -ne $script:consoleMode) { [void][KitConsole.Mode]::SetConsoleMode($h, $script:consoleMode) }
      return
    }
    $m = [uint32]0
    if (-not [KitConsole.Mode]::GetConsoleMode($h, [ref]$m)) { return }
    $script:consoleMode = $m
    $new = [int64]$m
    if ($new -band 0x40) { $new -= 0x40 }
    [void][KitConsole.Mode]::SetConsoleMode($h, [uint32]($new -bor 0x80))
  } catch { }
}

# A step that stops the setup: list the steps and where it stopped, then let the error show as before.
trap {
  Log "stopped: $($_.Exception.Message)"
  Show-Steps
  if (-not $check) { Set-QuickEdit $true }
  break
}
function Yes($q) { return (Ask $q 'Y') -match '^\s*[Yy]' }
# Runs a program without Windows PowerShell 5.1 turning what it writes to stderr into errors.
function Native([scriptblock]$Block) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { & $Block } finally { $ErrorActionPreference = $old }
}
function Refresh-Path { $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') }
function Find-First($paths) { foreach ($p in $paths) { if ($p -and (Test-Path $p)) { return $p } }; return $null }
function Find-Git {
  $c = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($c) { return $c.Source }
  return Find-First @("$env:ProgramFiles\Git\cmd\git.exe", "${env:ProgramFiles(x86)}\Git\cmd\git.exe", "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe")
}
function Find-Gh {
  $c = Get-Command gh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($c) { return $c.Source }
  return Find-First @("$env:ProgramFiles\GitHub CLI\gh.exe", "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe")
}
function Find-Obsidian { return Find-First @("$env:LOCALAPPDATA\Programs\Obsidian\Obsidian.exe", "$env:LOCALAPPDATA\Obsidian\Obsidian.exe", "$env:ProgramFiles\Obsidian\Obsidian.exe") }
# Installs an app with winget, up to three tries, and stops with what went wrong if it's still missing.
# GitHub, where winget downloads Git and gh from, can answer 504 for a while (an owner's PC, 8 Nov 2026):
# a try a few seconds later usually gets through, and before this the installer blamed the window.
# $find says whether it's there now; an optional app ($optional) that won't install is logged, not stopped on.
function Install-App($id, $what, [scriptblock]$find, [switch]$optional) {
  $out = ''; $code = 0
  for ($try = 1; $try -le 3; $try++) {
    if ($try -eq 1) { Say "Installing $what (Windows may ask you to allow it)..." }
    else { Say "Installing $what didn't finish. Trying again in 15 seconds ($try of 3)..."; Start-Sleep -Seconds 15 }
    $seen = @()
    Native { winget install --id $id -e --silent --accept-source-agreements --accept-package-agreements 2>&1 } | Tee-Object -Variable seen | Out-Host
    $code = $LASTEXITCODE; $out = ($seen | Out-String)
    Refresh-Path
    if (& $find) { return }
    Log "winget couldn't install $what (try $try, code $code): $((@($out -split "`n" | Where-Object { $_ -match '\w' }) | Select-Object -Last 2) -join ' / ')"
  }
  $why = if ($out -match 'Download request status is not success|Gateway|timed? ?out|0x8019|0x80072') {
    "$what's download didn't come through: the server it comes from (GitHub) didn't answer, three times. That's on their side and usually passes. Wait a few minutes, then paste the same command again."
  } elseif ($code -eq 0 -or $out -match 'already installed|No available upgrade') {
    "$what is installed, but this window can't see it yet. Close PowerShell, open it again and paste the same command."
  } else {
    "Installing $what didn't finish (winget stopped with code $code; what it said is above). Paste the same command again. If it stops here again, send C:\AI-Brain-Link\_logs\install.log to whoever is helping you."
  }
  if ($optional) { Log "carried on without ${what}: $why"; return }
  throw $why
}
# Downloads files from a GitHub release with gh, up to three tries, and says whether it worked. GitHub's plain
# release-download links can answer 504 for hours while gh's route, through its API, works (8 Nov 2026).
# An empty $tag means the latest release.
function Get-Release($from, $tag, $names, $dir) {
  $a = @('release', 'download')
  if ($tag) { $a += $tag }
  $a += @('--repo', $from, '--clobber', '--dir', $dir)
  foreach ($n in $names) { $a += @('--pattern', $n) }
  for ($try = 1; $try -le 3; $try++) {
    if ($try -gt 1) { Say "That download didn't finish. Trying again in 15 seconds ($try of 3)..."; Start-Sleep -Seconds 15 }
    $out = Native { & $gh @a 2>&1 } | Out-String
    if ($LASTEXITCODE -eq 0) { return $true }
    Log "gh couldn't download from $from (try $try): $($out.Trim())"
  }
  return $false
}
# A path inside a folder, one name at a time, so it works with either slash.
function Inside($base) { foreach ($p in $args) { $base = Join-Path $base $p }; return $base }
# The brain's files the kit's zip marks as programs, as paths inside brain\. GitHub's zip keeps each
# file's Unix mode, which .NET 4.7.2 and later read; anything else, and there are none.
function Programs-In($zipPath) {
  $out = @()
  if (-not $zipPath -or -not (Test-Path -LiteralPath $zipPath)) { return $out }
  try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $z = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
      foreach ($e in $z.Entries) {
        if ((($e.ExternalAttributes -shr 16) -band 0x49) -and $e.FullName -cmatch '^[^/]+/brain/(.*[^/])$') { $out += $Matches[1] }
      }
    } finally { $z.Dispose() }
  } catch { }
  return $out
}
# Makes the new brain from a brain folder, as tools\kit.py makes its zip's bundle: a copy, with today's date
# (UTC) in for the kit's {KIT_DATE} and {KIT_ISO} in file names and in its text files, written as UTF-8
# without a byte-order mark, and one commit. Returns the folder, a git repo to clone the brain from.
function New-BrainRepo($from) {
  $work = if ($check) { Join-Path $root 'new-brain' } else { Join-Path $env:TEMP 'brain-kit-new' }
  if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $work | Out-Null
  Get-ChildItem -LiteralPath $from -Force | Copy-Item -Destination $work -Recurse -Force
  $now = [DateTime]::UtcNow
  $day = $now.ToString('d MMM yyyy', [Globalization.CultureInfo]::InvariantCulture)
  $iso = $now.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
  $textTypes = '.md', '.py', '.ps1', '.yml', '.json', '.txt', '.css', '.js', '.mjs', '.sh' # tools\kit.py's TEXT
  foreach ($f in @(Get-ChildItem -LiteralPath $work -Recurse -Force -File)) {
    if ($textTypes -cnotcontains $f.Extension) { continue }
    $t = [IO.File]::ReadAllText($f.FullName, $noBom)
    $n = $t.Replace('{KIT_DATE}', $day).Replace('{KIT_ISO}', $iso)
    if ($n -cne $t) { [IO.File]::WriteAllText($f.FullName, $n, $noBom) }
  }
  # Deepest first, so a folder is renamed after what's in it.
  $named = @(Get-ChildItem -LiteralPath $work -Recurse -Force | Where-Object { $_.Name -cmatch '\{KIT_(DATE|ISO)\}' } | Sort-Object { $_.FullName.Length } -Descending)
  foreach ($i in $named) { Rename-Item -LiteralPath $i.FullName -NewName $i.Name.Replace('{KIT_DATE}', $day).Replace('{KIT_ISO}', $iso) }
  # The brain has every brain update in the kit's updates\ folder beside brain\, so its note says the newest,
  # in the form brain_update.py reads and writes; otherwise it would go by the start date, and on the day an
  # update goes out, offer the brain an update it already has.
  $newest = 0
  $updates = Join-Path (Split-Path $from -Parent) 'updates'
  if (Test-Path -LiteralPath $updates) {
    foreach ($u in @(Get-ChildItem -LiteralPath $updates -File)) { if ($u.Name -cmatch '^(\d{4})-[a-z0-9-]+\.md$' -and [int]$Matches[1] -gt $newest) { $newest = [int]$Matches[1] } }
  }
  $note = Inside $work 'knowledge' 'systems' 'brain-updates' 'README.md'
  if ($newest -gt 0 -and (Test-Path -LiteralPath $note)) {
    $line = "**On kit update:** $newest (in the kit this brain started from, made on $day)"
    $re = New-Object Text.RegularExpressions.Regex '(?m)^\*\*On kit update:\*\* [^\r\n]*'
    $t = [IO.File]::ReadAllText($note, $noBom)
    $t = if ($re.IsMatch($t)) { $re.Replace($t, $line.Replace('$', '$$'), 1) } else { $t.TrimEnd() + "`n`n$line`n" }
    [IO.File]::WriteAllText($note, $t, $noBom)
  }
  Native { & $git -c init.defaultBranch=main init -q $work } | Out-Null
  Native { & $git -C $work symbolic-ref HEAD refs/heads/main } | Out-Null
  Native { & $git -C $work config core.autocrlf false } | Out-Null # the kit's bytes as they are, line endings too
  Native { & $git -C $work add -A } | Out-Null
  $programs = @(Programs-In $Zip | ForEach-Object { $_.Replace('{KIT_DATE}', $day).Replace('{KIT_ISO}', $iso) } | Where-Object { Test-Path -LiteralPath (Join-Path $work $_) })
  if ($programs.Count) { Native { & $git -C $work update-index --chmod=+x -- $programs } | Out-Null }
  $who = 'AnIdeaLab brain kit', 'brain-kit@anidealab.com'
  foreach ($k in 'AUTHOR', 'COMMITTER') {
    [Environment]::SetEnvironmentVariable("GIT_${k}_NAME", $who[0], 'Process'); [Environment]::SetEnvironmentVariable("GIT_${k}_EMAIL", $who[1], 'Process')
  }
  try { Native { & $git -C $work commit -q -m "Started this brain from the AnIdeaLab brain kit, $day" } | Out-Null }
  finally { foreach ($k in 'AUTHOR', 'COMMITTER') { foreach ($v in 'NAME', 'EMAIL') { [Environment]::SetEnvironmentVariable("GIT_${k}_$v", $null, 'Process') } } }
  if ($LASTEXITCODE -ne 0) { throw "Making the brain from $from failed." }
  return $work
}

# Where the brain comes from (the notes at the top).
if (-not $Brain) {
  $b = Get-ChildItem -LiteralPath $here -Filter '*.bundle' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $Brain = if ($b) { $b.FullName } else { Join-Path (Split-Path $here -Parent) 'brain' }
}
if (-not (Test-Path -LiteralPath $Brain)) { throw "There's no brain to set up: no .bundle file next to this script ($here), and no $Brain." }
$Brain = (Resolve-Path -LiteralPath $Brain).ProviderPath
$fromFolder = (Get-Item -LiteralPath $Brain).PSIsContainer
if ($fromFolder -and -not (Test-Path -LiteralPath (Join-Path $Brain 'CLAUDE.md'))) { throw "$Brain isn't a brain: it has no CLAUDE.md." }
try { New-Item -ItemType Directory -Force -Path (Split-Path $logFile -Parent) | Out-Null } catch { }
Log "== The installer started, from $Brain (Windows PowerShell $($PSVersionTable.PSVersion))"
Say 'Connecting this PC to your brain: the runner and Obsidian, if you''d like them. Questions show in yellow.'

# AnIdeaLab's terms of use, before anything is installed or made. No default: Enter alone asks again, V opens
# the terms in the browser, and anything else but Y stops here. Asked before QuickEdit goes off, so the link
# can still be selected and copied in a Windows 10 window, where it can't be clicked.
$terms = 'https://github.com/AnIdeaLab/brain-kit/blob/main/TERMS.md'
if (-not $check) {
  Write-Host ''
  Write-Host "AnIdeaLab's terms of use for the brain kit: $terms" -ForegroundColor Yellow
  Write-Host "Do you accept AnIdeaLab's terms of use? (Y/N)" -ForegroundColor Yellow
  $answer = ''
  while (-not $answer) {
    $answer = "$(Read-Host 'Type Y or N, or V to read them in your browser')".Trim()
    if ($answer -match '^[Vv]') { try { Start-Process $terms } catch { }; $answer = '' }
  }
  if ($answer -notmatch '^[Yy]') {
    Log 'the terms of use were not accepted, so nothing was set up'
    Write-Host ''
    Write-Host "You didn't accept the terms, so nothing was set up. To set up later, paste the same line again." -ForegroundColor Yellow
    exit 0
  }
  Log 'the terms of use were accepted'
}
if (-not $check) { Set-QuickEdit $false }

# Claude isn't asked about here: nearly everyone runs this from their brain's first chat, so they're in Claude
# already, and a brain made here gets the plan's line in the last step below (22 Nov 2026).

# Obsidian is an extra, so it's asked about, here, before anything is installed: the answer covers the app, its
# Git plugin, the brain in its list of vaults and opening it at the end, and a no leaves an Obsidian that's
# already on the PC alone. Enter is yes. The kit's check answers yes, so it still tries Obsidian's steps.
$wantObsidian = Yes 'Would you like Obsidian too? It''s a free app that shows your brain as a map on this PC, where you can read and edit your notes. Your brain works without it, and you can add it later by pasting the same command again.'
Log $(if ($wantObsidian) { 'Obsidian: wanted' } else { 'Obsidian: not wanted, so its steps are skipped' })

# 1. The tools
$toolsStep = if ($wantObsidian) { "The tools (Git, GitHub's command line, Obsidian)" } else { "The tools (Git, GitHub's command line)" }
Step $toolsStep 'started'
if (-not $check) {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "winget (Windows' app installer) isn't on this PC. Install 'App Installer' from the Microsoft Store, then paste the same command again." }
  if (-not (Find-Git)) { Install-App 'Git.Git' 'Git' { Find-Git } }
  if (-not (Find-Gh)) { Install-App 'GitHub.cli' "GitHub's command line" { Find-Gh } }
  if ($wantObsidian -and -not (Find-Obsidian)) { Install-App 'Obsidian.Obsidian' 'Obsidian' { Find-Obsidian } -optional }
}
$git = Find-Git
if (-not $git) { throw "Git is installed, but this window can't see it yet. Close PowerShell, open it again and paste the same command." }
# Git's installer can leave Git off the PATH, and gh needs it there (an owner's PC, 22 Oct 2026).
# This window gets it now; setup-runner.ps1 adds it for the whole PC.
if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) { $env:Path = "$env:Path;$(Split-Path $git -Parent)" }
$gh = Find-Gh
if (-not $check -and -not $gh) { throw "GitHub's command line is installed, but this window can't see it yet. Close PowerShell, open it again and paste the same command." }
Step $toolsStep 'done'

# 2. GitHub
Step 'Signed in to GitHub' 'started'
if ($check) { $owner = 'example' } else {
  $status = Native { & $gh auth status --hostname github.com 2>&1 } | Out-String
  if ($LASTEXITCODE -ne 0) {
    Say 'Signing in to GitHub. Your one-time code is copied for you: press Enter, and in the page that opens in your browser, press Ctrl+V to paste it. No GitHub account yet? Make one on that page first (it''s free).'
    Native { & $gh auth login --hostname github.com --git-protocol https --web --scopes workflow --clipboard }
    if ($LASTEXITCODE -ne 0) { throw "GitHub sign-in didn't finish. Paste the same command again to retry." }
  } elseif ($status -notmatch 'workflow') {
    Say 'GitHub needs one more permission (to add the PC workflow). Your code is copied for you: press Enter, and press Ctrl+V in the page that opens.'
    Native { & $gh auth refresh --hostname github.com --scopes workflow --clipboard }
  }
  Native { & $gh auth setup-git --hostname github.com } | Out-Null
  $owner = "$(Native { & $gh api user --jq .login })".Trim()
  if (-not $owner) { throw "Couldn't read your GitHub user name. Paste the same command again." }
  # Git signs each commit with a name and email. GitHub's private address keeps your real email out of the history.
  if (-not "$(Native { & $git config --global user.name })".Trim()) {
    $display = "$(Native { & $gh api user --jq '.name // .login' })".Trim()
    Native { & $git config --global user.name $display }
  }
  if (-not "$(Native { & $git config --global user.email })".Trim()) {
    $userId = "$(Native { & $gh api user --jq .id })".Trim()
    Native { & $git config --global user.email "$userId+$owner@users.noreply.github.com" }
  }
}
Step 'Signed in to GitHub' 'done'
Log "signed in as $owner"

# 3. Your brain's repo on GitHub
Step "Your brain's private repo on GitHub" 'started'
# Every brain has the same name, so there's no question: a new brain from AnIdeaLab's template link gets it
# too, and this finds that one. A brain made before the name was set (or renamed) passes its own name in
# BRAIN_KIT_NAME, in the command its first chat gives: $env:BRAIN_KIT_NAME='<name>'; irm ... | iex
$name = if ($env:BRAIN_KIT_NAME) { $env:BRAIN_KIT_NAME.Trim() } else { 'my-brain-ail' }
if ($name -notmatch '^[A-Za-z0-9._-]+$') { throw "BRAIN_KIT_NAME has to be your brain's name on GitHub: letters, numbers, dashes, dots and underscores only." }
$repo = "$owner/$name"
$vault = Join-Path $root $name
$fresh = $true
if (-not $check) {
  $info = Native { & $gh repo view $repo --json isEmpty,visibility 2>$null } | Out-String
  if ($LASTEXITCODE -ne 0) {
    Say "Making your brain, the private repo $repo on GitHub..."
    Write-Host "(Already have a brain with another name? Close this window and ask that brain's chat for its command.)"
    Native { & $gh repo create $repo --private --description "My second brain, started from the AnIdeaLab brain kit" } | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Couldn't make $repo on GitHub." }
  } else {
    $j = $info | ConvertFrom-Json
    if ($j.visibility -ne 'PRIVATE') { throw "$repo is public. A brain has to be private, because the PC runner lets the repo run commands on this PC. Make it private on GitHub (its Settings, at the bottom), then paste the command again." }
    $fresh = [bool]$j.isEmpty
  }
}
Step "Your brain's private repo on GitHub" 'done'
Log "the repo is $repo"

# 3b. AnIdeaLab's testing account, as the terms of use say. Only for a brain made now, so a run again
# doesn't add it back after you've taken it off. A personal repo has no read-only option.
# Never on the accounts of AnIdeaLab's own people, the members of its GitHub organisation: the testing
# account mustn't reach their repos, or their PCs through a runner.
$tester = 'diagnostics-anidealab'
$ours = $false
if (-not $check) {
  $state = Native { & $gh api user/memberships/orgs/AnIdeaLab --jq .state 2>$null } | Out-String
  $ours = ($LASTEXITCODE -eq 0 -and $state.Trim() -eq 'active')
}
function Invite-Tester {
  if ($check -or $ours -or $owner -eq $tester) { return }
  Native { & $gh api -X PUT "repos/$repo/collaborators/$tester" --silent 2>&1 } | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Host "Couldn't invite AnIdeaLab's testing account just now. Your brain doesn't need it; to do it later, paste: gh api -X PUT repos/$repo/collaborators/$tester" -ForegroundColor Yellow }
  else { Log 'the testing account was invited' }
}
if ($fresh -or $setup) { Invite-Tester }

# 4. The brain on this PC, and on GitHub
Step "Your brain on GitHub, and your copy in $vault" 'started'
New-Item -ItemType Directory -Force -Path $root | Out-Null
if (Test-Path (Join-Path $vault '.git')) {
  Say "Your brain is already on this PC, in $vault."
  # Brought up to date first, where that changes nothing of yours (a fast-forward only): the runner's setup
  # and the upload point run from this copy, and without Obsidian nothing else on the PC syncs it.
  if (-not $check) {
    Native { & $git -C $vault pull --ff-only -q origin main 2>&1 } | Out-Null
    Native { & $git -C $vault push -u origin main 2>&1 } | Out-Null
  }
} elseif ($fresh) {
  Say "Putting the brain in $vault, and on GitHub..."
  $source = if ($fromFolder) { New-BrainRepo $Brain } else { $Brain }
  Native { & $git -c core.longpaths=true clone -q -b main $source $vault }
  if ($LASTEXITCODE -ne 0) { throw 'Unpacking the brain failed.' }
  if ($fromFolder) { Remove-Item -LiteralPath $source -Recurse -Force -ErrorAction SilentlyContinue }
  Native { & $git -C $vault config core.longpaths true }
  Native { & $git -C $vault remote set-url origin "https://github.com/$repo.git" }
  if (-not $check) {
    Native { & $git -C $vault push -u origin main }
    if ($LASTEXITCODE -ne 0) { throw 'Sending the brain to GitHub failed. Paste the same command again to retry.' }
    # A setup report, so AnIdeaLab can count new brains: the brain's "Send brain update reports" workflow sends
    # it to the kit's inbox, as it does an update's report. It holds the day it was set up, nothing else.
    Say 'Sending AnIdeaLab a setup report (just the date), so it can count new brains...'
    $setupDay = (Get-Date).ToUniversalTime().ToString('d MMM yyyy', [Globalization.CultureInfo]::InvariantCulture)
    $setupReport = Inside $vault 'knowledge' 'systems' 'brain-updates' '0000-report.md'
    $setupText = "---`nabout: `"This brain's setup report: the day it was set up from the AnIdeaLab brain kit. Sent to AnIdeaLab's inbox.`"`ntags: [the-brain]`nupdated: $setupDay`n---`n# Setup report`n`nThis brain was set up from the AnIdeaLab brain kit on $setupDay (UTC).`n"
    [IO.File]::WriteAllText($setupReport, $setupText, $noBom)
    Native { & $git -C $vault add -- $setupReport }
    Native { & $git -C $vault commit -q -m 'Setup report for AnIdeaLab' } | Out-Null
    Native { & $git -C $vault push -q origin main } | Out-Null
  }
} else {
  Say "$repo already has a brain in it, so this PC gets a copy of it..."
  Native { & $git -c core.longpaths=true clone -q "https://github.com/$repo.git" $vault }
  if ($LASTEXITCODE -ne 0) { throw "Copying $repo to this PC failed." }
  Native { & $git -C $vault config core.longpaths true }
  # A brain made from the kit's template, with nothing installed, hasn't invited the testing account: no
  # command ran when it was made. Its first setup on a PC invites it, as the terms say, and only once: the
  # log says when it has, so a run again doesn't add the account back after you've taken it off.
  $madeReport = Inside $vault 'knowledge' 'systems' 'brain-updates' '0000-report.md'
  $fromTemplate = (Test-Path -LiteralPath $madeReport) -and ([IO.File]::ReadAllText($madeReport) -match 'brain kit''s template')
  $invited = (Test-Path -LiteralPath $logFile) -and (Select-String -LiteralPath $logFile -SimpleMatch 'the testing account was invited' -Quiet)
  if ($fromTemplate -and -not $invited) { Invite-Tester }
}
Step "Your brain on GitHub, and your copy in $vault" 'done'

# 5. Obsidian, if it's wanted, with the Git plugin that syncs your edits (its code isn't kept in the repo). It
# opens at the end: opened here, it came up in front of this window while the runner's question waited behind
# it. Without Obsidian, the PC runner brings this copy up to date at the start of each job, so the upload
# point and the setup scripts in it stay current (the brain's pc-run.yml does it: a brain made from the
# template has that now, and one made from brain\ gets it with the next brain update).
if (-not $wantObsidian) { Step 'Obsidian, with syncing on' 'skipped' } else {
  Step 'Obsidian, with syncing on' 'started'
  # winget gets Obsidian from GitHub's plain release link at the tools step, and the setup carries on if that
  # answers 504 (see Get-Release). gh is signed in by here, so Obsidian gets a second try through it.
  if (-not $check -and -not (Find-Obsidian)) {
    Say "Installing Obsidian through GitHub's command line, about 340 MB..."
    $dl = Join-Path $env:TEMP 'brain-kit-obsidian'
    try {
      $obsTag = "$(Native { & $gh api repos/obsidianmd/obsidian-releases/releases/latest --jq .tag_name })".Trim()
      $obsExe = "Obsidian-$($obsTag.TrimStart('v')).exe"
      if ($obsTag -and (Get-Release 'obsidianmd/obsidian-releases' $obsTag @($obsExe) $dl)) {
        $obsPath = Join-Path $dl $obsExe
        if ((Get-AuthenticodeSignature -LiteralPath $obsPath).Status -eq 'Valid') { Start-Process -FilePath $obsPath -ArgumentList '/S' -Wait }
        else { Log "Obsidian's download isn't validly signed, so it wasn't run" }
      }
    } catch { Log "couldn't install Obsidian through gh: $($_.Exception.Message)" }
    Remove-Item -LiteralPath $dl -Recurse -Force -ErrorAction SilentlyContinue
  }
  $plugin = Join-Path (Join-Path (Join-Path $vault '.obsidian') 'plugins') 'obsidian-git'
  if (-not $check -and -not (Test-Path (Join-Path $plugin 'main.js'))) {
    Say 'Adding the Obsidian Git plugin, which syncs your edits with GitHub...'
    New-Item -ItemType Directory -Force -Path $plugin | Out-Null
    if (-not (Get-Release 'Vinzent03/obsidian-git' '' @('main.js', 'manifest.json', 'styles.css') $plugin)) {
      Remove-Item -LiteralPath (Join-Path $plugin 'main.js') -Force -ErrorAction SilentlyContinue # so a run again doesn't take a part-download for done
      throw "The Obsidian Git plugin's download didn't come through: GitHub didn't answer, three times. That's on their side and usually passes. Wait a few minutes, then paste the same command again."
    }
  }
  # Add the brain to Obsidian's list of vaults, so it opens straight into it.
  if (-not $check) {
    Get-Process Obsidian -ErrorAction SilentlyContinue | ForEach-Object { [void]$_.CloseMainWindow() }
    Start-Sleep -Seconds 2
  }
  $cfgDir = if ($check) { Join-Path $root 'obsidian' } else { Join-Path $env:APPDATA 'obsidian' }
  $cfg = Join-Path $cfgDir 'obsidian.json'
  New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
  $data = [pscustomobject]@{}
  if (Test-Path $cfg) { Copy-Item $cfg "$cfg.bak" -Force; $data = Get-Content $cfg -Raw | ConvertFrom-Json }
  if (-not $data.PSObject.Properties['vaults']) { $data | Add-Member -NotePropertyName vaults -NotePropertyValue ([pscustomobject]@{}) }
  if (-not ($data.vaults.PSObject.Properties | Where-Object { $_.Value.path -eq $vault })) {
    $id = -join ((1..16) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
    $ts = [long]([DateTime]::UtcNow - [DateTime]'1970-01-01').TotalMilliseconds
    $data.vaults | Add-Member -NotePropertyName $id -NotePropertyValue ([pscustomobject]@{ path = $vault; ts = $ts; open = $true })
  }
  [IO.File]::WriteAllText($cfg, ($data | ConvertTo-Json -Depth 10 -Compress), $noBom)
  Step 'Obsidian, with syncing on' 'done'
}

# 5b. The upload point, if this brain has one (from the kit after brain update 3): your brain is fine without it.
$uploadSetup = Inside $vault 'skills' 'upload-point' 'setup-upload-point.ps1'
if (Test-Path -LiteralPath $uploadSetup) {
  Step 'The upload point' 'started'
  Say 'Adding the upload point: My brain in Send to, for giving your brain files with a right-click...'
  if (-not $check) {
    $uploadOk = $false
    try { Native { & powershell -NoProfile -ExecutionPolicy Bypass -File $uploadSetup }; $uploadOk = $LASTEXITCODE -eq 0 } catch { }
    if (-not $uploadOk) { Write-Host "The upload point didn't set up; your brain works without it. To try again later, paste: powershell -ExecutionPolicy Bypass -File `"$uploadSetup`"" -ForegroundColor Yellow }
    Step 'The upload point' $(if ($uploadOk) { 'done' } else { 'not done' })
  } else { Step 'The upload point' 'done' }
}

# Once the runner is online, the brain records this PC itself: its row in knowledge/systems/devices.md and what
# it has in the PC's note, in a commit of their own. Without it, a brain whose owner ran this after their session
# ended said no computer had a runner, though this one worked, until an agent happened to test it.
function Record-PC($vault) {
  try {
    $today = (Get-Date).ToUniversalTime().ToString('d MMM yyyy', [Globalization.CultureInfo]::InvariantCulture)
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $gpu = (@(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name }) -join ', ')
    $disks = (@(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { '{0} {1:N0} GB free of {2:N0} GB' -f $_.DeviceID, ($_.FreeSpace / 1GB), ($_.Size / 1GB) }) -join ', ')
    $facts = ("{0}, {1} {2}, {3}, {4:N0} GB RAM, GPU {5}, disks {6}" -f $os.Caption, $cs.Manufacturer, $cs.Model, ((Get-CimInstance Win32_Processor | Select-Object -First 1).Name).Trim(), ($cs.TotalPhysicalMemory / 1GB), $gpu, $disks) -replace '\|', '/'
    $devices = Join-Path $vault 'knowledge\systems\devices.md'
    if (Test-Path $devices) {
      $lines = [Collections.Generic.List[string]]([IO.File]::ReadAllText($devices) -split "`n")
      $rows = @(for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].TrimStart().StartsWith('|')) { $i } })
      if ($rows.Count -and -not ($rows | Where-Object { $lines[$_] -match '`my-pc`' })) {
        $last = $rows[0]
        while ($last + 1 -lt $lines.Count -and $lines[$last + 1].TrimStart().StartsWith('|')) { $last++ }
        $lines.Insert($last + 1, "| [This PC, $env:COMPUTERNAME](my-pc.md) | The ``my-pc`` runner (``pc-run.yml``), added by the installer on $today | While the owner is signed in and it's awake | $facts | ``my-pc`` | ``$env:COMPUTERNAME`` |")
        [IO.File]::WriteAllText($devices, ($lines -join "`n"), $noBom)
      }
    }
    $note = Join-Path $vault 'knowledge\systems\my-pc.md'
    if (Test-Path $note) {
      $text = [IO.File]::ReadAllText($note)
      $new = [regex]::Replace($text, '(?m)^\*Not checked yet:.*\*\r?$', "Recorded by the installer on $today, when the runner first came online: $env:COMPUTERNAME, $facts. A first job adds what's installed (the getting-started skill, step 4).", 1)
      if ($new -ne $text) { [IO.File]::WriteAllText($note, $new, $noBom) }
    }
    Native { & $git -C $vault add -A knowledge/systems } | Out-Null
    Native { & $git -C $vault diff --cached --quiet } | Out-Null
    if ($LASTEXITCODE -eq 0) { return }
    Native { & $git -C $vault commit -q -m "This PC's runner is set up: added it to the brain's devices" } | Out-Null
    Native { & $git -C $vault push -q origin HEAD } | Out-Null
  } catch { Log "couldn't record this PC in devices.md: $($_.Exception.Message)" }
}

# 6. The PC runner
$runnerSetup = Join-Path (Join-Path (Join-Path $vault 'skills') 'my-pc') 'setup-runner.ps1'
$runnerOk = $true
Step 'The PC runner' 'started'
if (-not $check) {
  # A brain from the template has the newer runner setup, which needs no password; one made from this kit's
  # main branch has the older one until the update that brings it, so the question says what this brain's does.
  $runnerAsks = if ((Test-Path $runnerSetup) -and (Select-String -LiteralPath $runnerSetup -Pattern 'windowslogonpassword' -Quiet)) { 'It asks for admin rights, then your Windows password, in a second window.' } else { "It runs while you're signed in to Windows, and needs no password." }
  $runnerQ = if ($setup) { "Set up the PC runner now? It's how we bring the documents you've worked on this past year into your brain for you, and after that it lets you ask Claude to do things on this PC from any chat, even your phone. $runnerAsks" } else { "Set up the PC runner now, so you can ask Claude to do things on this PC from any chat, even your phone? It only does what you ask. $runnerAsks" }
  if (Yes $runnerQ) {
    # The runner's setup downloads the runner from GitHub's plain release link, which can answer 504 (see
    # Get-Release). Put in place here, through gh, the setup finds it and skips that; if this fails, it still tries.
    $runnerDir = Join-Path $root '_runner'
    if (-not (Test-Path (Inside $runnerDir 'bin' 'Runner.Listener.exe'))) {
      Say "Downloading GitHub's runner, about 100 MB..."
      $dl = Join-Path $env:TEMP 'brain-kit-runner'
      try {
        $runnerTag = "$(Native { & $gh api repos/actions/runner/releases/latest --jq .tag_name })".Trim()
        $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
        $runnerZip = "actions-runner-win-$arch-$($runnerTag.TrimStart('v')).zip"
        if ($runnerTag -and (Get-Release 'actions/runner' $runnerTag @($runnerZip) $dl)) {
          Expand-Archive -Path (Join-Path $dl $runnerZip) -DestinationPath $runnerDir -Force
        }
      } catch { Log "couldn't put the runner in place first: $($_.Exception.Message)" }
      Remove-Item -LiteralPath $dl -Recurse -Force -ErrorAction SilentlyContinue
    }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $runnerSetup -Repo $repo -Root $root
    # "All done" only once GitHub sees the runner online: on an owner's PC it said so after the
    # runner setup had stopped partway (22 Oct 2026).
    $runnerOk = $LASTEXITCODE -eq 0
    try { $list = Native { & $gh api "repos/$repo/actions/runners" } | Out-String | ConvertFrom-Json } catch { $list = $null }
    if (-not ($list.runners | Where-Object { $_.status -eq 'online' })) { $runnerOk = $false }
    if ($runnerOk) { Record-PC $vault }
    Step 'The PC runner' $(if ($runnerOk) { 'done' } else { 'not done' })
  } else {
    Step 'The PC runner' 'skipped'
    Write-Host "Skipped. To set it up later, paste: powershell -ExecutionPolicy Bypass -File `"$runnerSetup`""
  }
} else { Step 'The PC runner' 'skipped' }

# 7. Obsidian opens last, so it can't hide a question in this window.
$hasObsidian = $false
if (-not $wantObsidian) { Step 'Obsidian opened on your brain' 'skipped' } else {
  Step 'Obsidian opened on your brain' 'started'
  # Without Obsidian, the link only gets Windows asking which app should open it (a friend's PC, 8 Nov 2026).
  $hasObsidian = $check -or (Find-Obsidian)
  if (-not $check -and $hasObsidian) {
    try { Start-Process ('obsidian://open?path=' + [uri]::EscapeDataString($vault)) } catch { $o = Find-Obsidian; if ($o) { Start-Process $o } }
    Start-Sleep -Seconds 3
  }
  Step 'Obsidian opened on your brain' $(if ($hasObsidian) { 'done' } else { 'not done' })
}

Show-Steps
if (-not $check) { Set-QuickEdit $true }
if (-not $wantObsidian) { Say 'No Obsidian, as you chose. To add it later, paste the same command again and answer Y to the Obsidian question.' }
elseif ($hasObsidian) { Say 'Obsidian is opening your brain. If it asks, choose "Trust author and enable plugins". Then come back to this window for the last step, below.' }
else {
  Write-Host ''
  Write-Host "Obsidian didn't install, because its download didn't come through. That's usually GitHub, and it usually passes. Your brain is fine without it for now: wait a few minutes, then paste the same command again." -ForegroundColor Yellow
}
if ($runnerOk) { Say 'All done on this PC.' } else {
  Write-Host ''
  Write-Host "Your brain is set up, but the PC runner isn't working yet, so agents can't run jobs on this PC." -ForegroundColor Yellow
  Write-Host "To try it again, paste: powershell -ExecutionPolicy Bypass -File `"$runnerSetup`""
  Write-Host 'Or carry on below, and ask Claude to help get the runner working.'
}
Write-Host "Your brain on GitHub: https://github.com/$repo"
Write-Host "Your copy on this PC: $vault$(if ($wantObsidian) { ' (open in Obsidian)' })"
Write-Host ''
if ($setup) {
  Write-Host "That's everything on your side. We'll take it from here, and email you when your brain is ready." -ForegroundColor Cyan
  if (-not $runnerOk) { Write-Host "(The runner isn't working yet, so we can't bring your documents in. Reply to our email and we'll sort it with you.)" }
} elseif (-not $fresh) {
  # The brain was on GitHub already: made from AnIdeaLab's template, with this run from its first chat (or any
  # chat since), or a run again. So the chat is open, and that's where they go back to.
  Write-Host 'Last step: go back to your chat with your brain and say it''s finished.' -ForegroundColor Cyan
} else {
Write-Host 'Last step, in Claude:' -ForegroundColor Cyan
Write-Host '  1. Go to https://claude.ai/code. It needs a paid plan (Pro or above). If it asks, connect GitHub and let Claude see your brain repo.'
Write-Host "  2. Start a new session with $repo selected."
Write-Host '  3. Send this message:'
Write-Host '       This is my new second brain. Read CLAUDE.md and get me set up.' -ForegroundColor Green

# Last, AnIdeaLab's tutorials page opens in the browser: these steps, and the rest, with a video each.
$tutorials = 'https://anidealab.com/second-brain/tutorials'
Write-Host ''
Write-Host "The tutorials are opening in your browser: these steps with a video, then Obsidian and connecting Google. $tutorials" -ForegroundColor Cyan
if (-not $check) { try { Start-Process $tutorials } catch { } }
}
