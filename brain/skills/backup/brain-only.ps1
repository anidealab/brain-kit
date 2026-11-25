# The brain-only backup for a Windows PC with no runner: one command the owner pastes into PowerShell.
# It opens the brain's download link in their browser (where they're signed in to GitHub), waits for the zip,
# and copies it to their external drive as "Brain backup\brain-snapshots\<repo>-<date>.zip". Nothing on the drive
# is ever deleted or overwritten. Needs nothing installed.
#   $env:BRAIN='owner/repo'; irm https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/brain/skills/backup/brain-only.ps1 | iex
# BACKUP_DRIVE (a drive like E:\) skips finding the drive; BACKUP_ZIP (a zip already downloaded) skips the browser.
$ErrorActionPreference = 'Stop'
& {
  $brain = $env:BRAIN
  if (-not $brain -or $brain -notmatch '^[\w.-]+/[\w.-]+$') { Write-Host "Say which brain first, like `$env:BRAIN='your-name/my-brain-ail'"; return }
  $repo = $brain.Split('/')[1]

  $drive = $env:BACKUP_DRIVE
  if (-not $drive) {
    $usb = @(Get-Partition | Where-Object DriveLetter | Where-Object {
        $d = Get-Disk -Number $_.DiskNumber; $d.BusType -eq 'USB' -and -not $d.IsSystem -and -not $d.IsBoot })
    if ($usb.Count -eq 0) { Write-Host "No external drive is plugged in. Plug your cold storage drive in, then paste the same command again."; return }
    if ($usb.Count -gt 1) {
      Write-Host "More than one external drive is plugged in:"
      $usb | ForEach-Object { $v = Get-Volume -DriveLetter $_.DriveLetter; Write-Host ("  {0}:  {1}" -f $_.DriveLetter, $v.FileSystemLabel) }
      $letter = (Read-Host "Type the letter of your cold storage drive").Trim().TrimEnd(':')
      if ($letter -notin ($usb | ForEach-Object { [string]$_.DriveLetter })) { Write-Host "That isn't one of them. Nothing was copied."; return }
    } else { $letter = [string]$usb[0].DriveLetter }
    $drive = "${letter}:\"
  }
  if (-not (Test-Path -LiteralPath $drive)) { Write-Host "The drive $drive isn't there. Nothing was copied."; return }

  $zip = $env:BACKUP_ZIP
  if (-not $zip) {
    $downloads = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
    if (-not $downloads) { $downloads = Join-Path $env:USERPROFILE 'Downloads' }
    $since = Get-Date
    Write-Host "Your browser is opening your brain's download. If it asks you to sign in to GitHub, do, and the download starts."
    Start-Process "https://github.com/$brain/archive/refs/heads/main.zip"
    $deadline = (Get-Date).AddMinutes(10)
    while (-not $zip -and (Get-Date) -lt $deadline) {
      Start-Sleep -Seconds 2
      $zip = Get-ChildItem -LiteralPath $downloads -Filter "$repo-main*.zip" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $since.AddSeconds(-5) } | Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
      if ($zip) { $size = -1; while ((Get-Item -LiteralPath $zip).Length -ne $size) { $size = (Get-Item -LiteralPath $zip).Length; Start-Sleep -Seconds 2 } }
    }
    if (-not $zip) { Write-Host "The download didn't show up in $downloads in 10 minutes. Nothing was copied; paste the same command to try again."; return }
  }

  $dir = Join-Path $drive 'Brain backup\brain-snapshots'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $name = "$repo-$(Get-Date -Format yyyy-MM-dd)"
  $dest = Join-Path $dir "$name.zip"; $n = 2
  while (Test-Path -LiteralPath $dest) { $dest = Join-Path $dir "$name-$n.zip"; $n++ }
  Copy-Item -LiteralPath $zip -Destination $dest
  $free = (Get-PSDrive -Name $drive.Substring(0,1)).Free / 1GB
  Write-Host ("Done: your brain is on the drive as {0} ({1:N1} MB). The drive has {2:N1} GB free. You can unplug it now." -f $dest, ((Get-Item -LiteralPath $dest).Length / 1MB), $free)
}
