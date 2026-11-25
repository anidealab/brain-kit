# Index my computer, on Windows. The installer runs it last when BRAIN_KIT_SETUP=1 is set (AnIdeaLab's set-up
# command), as a file from the kit's folder, with -Root C:\AI-Brain-Link. It also runs on its own, anywhere:
#   powershell -ExecutionPolicy Bypass -File set-up\index-computer.ps1 -Root C:\AI-Brain-Link
#   (as a runner job: download it to a file first, set $env:INDEX_KIT_REF to the kit commit, and run it with -Root;
#   away from the kit's folder it downloads its Python files from the kit at that commit.)
# It gets uv (Astral's, MIT/Apache) into a folder of its own, and uv a Python and MarkItDown (Microsoft's,
# MIT), then runs index-computer.py with the brain's file-intake tool, and takes uv and the rest off again.
# The work folder, _intake\computer in the root, holds files.txt, survey.md, index.md and text\. Nothing else on
# the PC is changed. Exits 0 when the index is made. Works in Windows PowerShell 5.1.
param([string]$Root = '')
& {
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
  $ref = if ($env:INDEX_KIT_REF) { $env:INDEX_KIT_REF } else { 'main' }
  $kit = "https://raw.githubusercontent.com/AnIdeaLab/brain-kit/$ref"
  $uvVersion = '0.11.32'
  $markitdown = 'markitdown[pdf,docx,pptx,xlsx,xls,outlook]==0.1.9'
  $base = if ($Root) { $Root } else { (Get-Location).Path }
  $work = Join-Path $base '_intake\computer'
  $tools = Join-Path $env:LOCALAPPDATA 'AnIdeaLab\index-tools'
  if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $work, $tools | Out-Null

  Write-Output "Getting the tools (uv $uvVersion, then Python and MarkItDown through it)..."
  $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'aarch64' } else { 'x86_64' }
  $zip = Join-Path $tools 'uv.zip'
  Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/astral-sh/uv/releases/download/$uvVersion/uv-$arch-pc-windows-msvc.zip" -OutFile $zip
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $uvDir = Join-Path $tools 'uv'
  if (Test-Path -LiteralPath $uvDir) { Remove-Item -LiteralPath $uvDir -Recurse -Force }
  [IO.Compression.ZipFile]::ExtractToDirectory($zip, $uvDir)
  $uv = @(Get-ChildItem -LiteralPath $uvDir -Recurse -Filter 'uv.exe')[0].FullName
  # Its Python files: beside it in the kit's folder when run as a file, else from the kit on GitHub.
  $py = Join-Path $tools 'index-computer.py'
  $intake = Join-Path $tools 'intake.py'
  $here = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { '' }
  $localIntake = if ($here) { Join-Path (Split-Path -Parent $here) 'brain\skills\file-intake\intake.py' } else { '' }
  if ($here -and (Test-Path (Join-Path $here 'index-computer.py')) -and (Test-Path $localIntake)) {
    Copy-Item (Join-Path $here 'index-computer.py') $py -Force
    Copy-Item $localIntake $intake -Force
  } else {
    Invoke-WebRequest -UseBasicParsing -Uri "$kit/set-up/index-computer.py" -OutFile $py
    Invoke-WebRequest -UseBasicParsing -Uri "$kit/brain/skills/file-intake/intake.py" -OutFile $intake
  }

  # Where Windows keeps the owner's own folders: often inside OneDrive, which this then searches whole.
  $env:INDEX_DESKTOP = [Environment]::GetFolderPath('Desktop')
  $env:INDEX_DOCUMENTS = [Environment]::GetFolderPath('MyDocuments')
  try {
    $dl = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders').'{374DE290-123F-4565-9164-39C4925E467B}'
    if ($dl) { $env:INDEX_DOWNLOADS = [Environment]::ExpandEnvironmentVariables($dl) }
  } catch { }
  $env:INDEX_BRAIN_ROOT = $base
  $env:UV_CACHE_DIR = Join-Path $tools 'cache'
  $env:UV_PYTHON_INSTALL_DIR = Join-Path $tools 'python'
  $env:UV_NO_PROGRESS = '1'
  $env:PYTHONUTF8 = '1'

  Write-Output 'Searching the computer and reading the documents. A big computer takes a while.'
  $ErrorActionPreference = 'Continue'   # uv and Python write their notes to stderr, which 5.1 would treat as errors
  # Its PROGRESS| lines become Windows' own progress bar at the top of the window; the rest is printed as it comes.
  $env:INDEX_PROGRESS = 'ps'
  $ProgressPreference = 'Continue'
  & $uv run --quiet --no-project --python 3.12 --with $markitdown python -I $py --work $work --intake $intake 2>&1 | ForEach-Object {
    $line = "$_"
    if ($line.StartsWith('PROGRESS|')) {
      $p = $line.Split('|', 4)
      if ($p[1] -eq 'done') { Write-Progress -Activity 'Reading your documents' -Completed }
      else {
        $pct = [int]$p[2]
        if ($pct -ge 0) { Write-Progress -Activity $p[1] -Status $p[3] -PercentComplete ([Math]::Min(100, $pct)) }
        else { Write-Progress -Activity $p[1] -Status $p[3] }
      }
    } else { $line }
  }
  $code = $LASTEXITCODE
  Write-Progress -Activity 'Reading your documents' -Completed
  $ProgressPreference = 'SilentlyContinue'
  Remove-Item -LiteralPath $tools -Recurse -Force -ErrorAction SilentlyContinue
  if ($code -ne 0) { Write-Output "The index stopped (exit $code). What went wrong is above."; exit $code }
  Write-Output "The work folder: $work"
  exit 0
}
