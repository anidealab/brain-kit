# Checks why a PC can't download what the kit's Windows installer needs, mostly GitHub's release files (Git,
# GitHub's command line, Obsidian), which winget fetches from GitHub. Paste into PowerShell on the PC:
#   irm https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/testing/network-check.ps1 | iex
#
# It changes nothing. It prints what it finds: Windows and PowerShell, the antivirus Windows knows about and
# any drivers or services an uninstalled one left behind, the proxy and VPN settings, the hosts file, DNS
# answers, and timed downloads of the gh installer through two routes (PowerShell's and curl.exe's), then
# saves it all to brain-kit-network-check.txt on the Desktop and copies it, so it can be pasted back to
# whoever is helping. It holds no passwords or keys. Made for an owner's PC on 8 Nov 2026, when GitHub's
# release downloads answered 504. Windows PowerShell 5.1, plain ASCII.
& {
  $ErrorActionPreference = 'Continue'
  $ProgressPreference = 'SilentlyContinue'
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
  $gh = 'https://github.com/cli/cli/releases/download/v2.103.3/gh_2.103.3_windows_amd64.msi'
  $lines = New-Object Collections.Generic.List[string]
  function Out-Line($t) { $lines.Add("$t"); Write-Host $t }
  function Section($t) { Out-Line ''; Out-Line "== $t" }
  function Try-Run([scriptblock]$b) { try { (& $b | Out-String -Width 200).TrimEnd() -split "`r?`n" | ForEach-Object { Out-Line $_ } } catch { Out-Line "  (couldn't: $($_.Exception.Message))" } }
  # One request, not following redirects, timed: its code, seconds and where it points.
  function Probe($url, [switch]$follow, [switch]$range) {
    $sw = [Diagnostics.Stopwatch]::StartNew(); $code = ''; $loc = ''; $extra = ''
    try {
      $r = [Net.HttpWebRequest]::Create($url)
      $r.AllowAutoRedirect = [bool]$follow; $r.Timeout = 60000; $r.UserAgent = 'brain-kit-network-check'
      if ($range) { $r.AddRange(0, 1023) }
      $x = $r.GetResponse(); $code = [int]$x.StatusCode; $loc = $x.Headers['Location']
      if ($follow) { $extra = " (ended at $($x.ResponseUri.Host))" }
      $x.Close()
    } catch [Net.WebException] {
      $resp = $_.Exception.Response
      if ($resp) { $code = [int]$resp.StatusCode; $loc = $resp.Headers['Location']; $gid = $resp.Headers['X-GitHub-Request-Id']; if ($gid) { $extra = " (GitHub request id $gid)" } }
      else { $code = "$($_.Exception.Status): $($_.Exception.Message)" }
    } catch { $code = $_.Exception.Message }
    if ($loc) { $loc = " -> $(([uri]$loc).Host)" }
    Out-Line ("  {0}  {1:N1}s  {2}{3}{4}" -f $code, $sw.Elapsed.TotalSeconds, $url, $loc, $extra)
  }

  Out-Line "Brain kit network check, $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))"
  Section 'Windows and PowerShell'
  Try-Run { $o = Get-CimInstance Win32_OperatingSystem; "  $($o.Caption) $($o.Version), PowerShell $($PSVersionTable.PSVersion), admin: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators'))" }
  Try-Run { "  winget: $(winget --version 2>&1)   tar: $((tar --version 2>&1 | Select-Object -First 1))" }
  Try-Run { $p = @("$env:ProgramFiles\GitHub CLI\gh.exe", "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe", "$env:ProgramFiles\Git\cmd\git.exe") | ForEach-Object { "  $(Test-Path $_)  $_" }; $p }

  Section 'Antivirus Windows knows about, and leftovers of one that was removed'
  Try-Run { Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct | ForEach-Object { "  $($_.displayName)  (state $('{0:X}' -f $_.productState))" } }
  Try-Run { $m = Get-MpComputerStatus; "  Defender: antivirus on $($m.AntivirusEnabled), real-time $($m.RealTimeProtectionEnabled)" }
  Try-Run { Get-Service | Where-Object { $_.Name + $_.DisplayName -match 'norton|symantec|gen digital|avast|avg|mcafee|kaspersky|bitdefender|eset|sophos|webroot|malwarebytes|zonealarm|vpn' } | ForEach-Object { "  service: $($_.Name) ($($_.DisplayName)) $($_.Status)" } }
  Try-Run { Get-CimInstance Win32_SystemDriver | Where-Object { $_.Name + $_.DisplayName + $_.PathName -match 'norton|symantec|symnet|bhdrv|srtsp|idsvia|eectrl|nllink|ccsetx|avast|aswsp|avg|mcafee|mfe|klif|bdfndisf|vsdatant|wfp' } | ForEach-Object { "  driver: $($_.Name) ($($_.DisplayName)) $($_.State)" } }
  Try-Run { Get-ChildItem "$env:ProgramFiles", "${env:ProgramFiles(x86)}", "$env:ProgramData" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'norton|symantec|gen digital' } | ForEach-Object { "  folder: $($_.FullName)" } }

  Section 'Proxy, VPN and network adapters'
  Try-Run { netsh winhttp show proxy }
  Try-Run { $i = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'; "  user proxy on: $($i.ProxyEnable)  server: $($i.ProxyServer)  script: $($i.AutoConfigURL)" }
  Try-Run { "  .NET sends github.com via: $([Net.WebRequest]::DefaultWebProxy.GetProxy('https://github.com'))" }
  Try-Run { "  HTTP(S)_PROXY: $env:HTTP_PROXY $env:HTTPS_PROXY" }
  Try-Run { Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object { "  up: $($_.Name) - $($_.InterfaceDescription)" } }
  Try-Run { Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object ServerAddresses | ForEach-Object { "  DNS on $($_.InterfaceAlias): $($_.ServerAddresses -join ', ')" } }

  Section 'Hosts file lines (other than comments)'
  Try-Run { Get-Content "$env:WINDIR\System32\drivers\etc\hosts" | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' } | ForEach-Object { "  $_" } }

  Section 'DNS answers'
  foreach ($h in 'github.com', 'raw.githubusercontent.com', 'release-assets.githubusercontent.com', 'objects.githubusercontent.com', 'conda.anaconda.org') {
    Try-Run { "  $h -> $((Resolve-DnsName $h -Type A -ErrorAction Stop | Where-Object IPAddress | ForEach-Object IPAddress) -join ', ')" }
  }

  Section 'Can it connect (port 443)'
  foreach ($h in 'github.com', 'release-assets.githubusercontent.com') {
    Try-Run { $t = Test-NetConnection $h -Port 443 -WarningAction SilentlyContinue; "  $h  $($t.RemoteAddress)  open: $($t.TcpTestSucceeded)" }
  }

  Section 'Web requests through PowerShell (code, seconds, address, where it points)'
  Probe 'https://github.com/'
  Probe 'https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/README.md'
  Probe 'https://github.com/cli/cli/releases/latest/download/gh_2.103.3_windows_amd64.msi'
  Probe $gh
  Probe $gh
  Probe $gh -follow -range
  Probe 'https://github.com/git-for-windows/git/releases/download/v2.47.0.windows.1/Git-2.47.0-64-bit.exe'
  Probe 'https://conda.anaconda.org/conda-forge/win-64/gh-2.103.3-h11686cb_1.conda' -range

  Section "The gh installer through curl.exe (Windows' own, a different route)"
  Try-Run { curl.exe -sS -L -o NUL --max-time 120 -w "  code %{http_code}  %{size_download} bytes  %{time_total}s  ended at %{url_effective}`n" $gh 2>&1 | ForEach-Object { "$_".Substring(0, [Math]::Min(160, "$_".Length)) } }
  Try-Run { curl.exe -sS -v -o NUL --max-time 60 $gh 2>&1 | Select-String -Pattern '^\* (Trying|Connected|schannel|SSL)|^< HTTP|^< (x-github|server|via|location)' | ForEach-Object { "  $($_.Line.Substring(0, [Math]::Min(150, $_.Line.Length)))" } }

  Section 'winget on its own'
  Try-Run { winget source list 2>&1 }
  Try-Run { winget show --id GitHub.cli -e 2>&1 | Select-String 'Version|Installer Url|Installer Type' }

  $file = Join-Path ([Environment]::GetFolderPath('Desktop')) 'brain-kit-network-check.txt'
  try { [IO.File]::WriteAllLines($file, $lines) ; $saved = "Saved to $file" } catch { $saved = "Couldn't save the file: $($_.Exception.Message)" }
  try { ($lines -join "`r`n") | Set-Clipboard; $copied = ' and copied, so you can paste it straight into a message' } catch { $copied = '' }
  Write-Host ''
  Write-Host "Done. $saved$copied." -ForegroundColor Green
}
