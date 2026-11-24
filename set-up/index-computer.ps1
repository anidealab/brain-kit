# Index my computer, on Windows: AnIdeaLab's set-up runs this as a job on the owner's runner (their brain's
# "Run on my PC" workflow), with the folder the brain's copy lives in (C:\AI-Brain-Link) as the job's folder:
#   $env:INDEX_KIT_REF='<kit commit>'; irm https://raw.githubusercontent.com/AnIdeaLab/brain-kit/<kit commit>/set-up/index-computer.ps1 | iex
# It gets uv (Astral's, MIT/Apache) into a folder of its own, and uv a Python and MarkItDown (Microsoft's,
# MIT), then runs index-computer.py with the brain's file-intake tool, and takes uv and the rest off again.
# The work folder, _intake\computer in the job's folder, is what the job attaches for the agent: files.txt,
# survey.md, index.md and text\. Nothing else on the PC is changed. Works in Windows PowerShell 5.1.
& {
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
  $ref = if ($env:INDEX_KIT_REF) { $env:INDEX_KIT_REF } else { 'main' }
  $kit = "https://raw.githubusercontent.com/AnIdeaLab/brain-kit/$ref"
  $uvVersion = '0.11.32'
  $markitdown = 'markitdown[pdf,docx,pptx,xlsx,xls,outlook]==0.1.9'
  $work = Join-Path (Get-Location).Path '_intake\computer'
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
  Invoke-WebRequest -UseBasicParsing -Uri "$kit/set-up/index-computer.py" -OutFile (Join-Path $tools 'index-computer.py')
  Invoke-WebRequest -UseBasicParsing -Uri "$kit/brain/skills/file-intake/intake.py" -OutFile (Join-Path $tools 'intake.py')

  # Where Windows keeps the owner's own folders: often inside OneDrive, which this then searches whole.
  $env:INDEX_DESKTOP = [Environment]::GetFolderPath('Desktop')
  $env:INDEX_DOCUMENTS = [Environment]::GetFolderPath('MyDocuments')
  try {
    $dl = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders').'{374DE290-123F-4565-9164-39C4925E467B}'
    if ($dl) { $env:INDEX_DOWNLOADS = [Environment]::ExpandEnvironmentVariables($dl) }
  } catch { }
  $env:INDEX_BRAIN_ROOT = (Get-Location).Path
  $env:UV_CACHE_DIR = Join-Path $tools 'cache'
  $env:UV_PYTHON_INSTALL_DIR = Join-Path $tools 'python'
  $env:UV_NO_PROGRESS = '1'
  $env:PYTHONUTF8 = '1'

  Write-Output 'Searching the computer and reading the documents. A big computer takes a while.'
  $ErrorActionPreference = 'Continue'   # uv and Python write their notes to stderr, which 5.1 would treat as errors
  & $uv run --quiet --no-project --python 3.12 --with $markitdown python -I (Join-Path $tools 'index-computer.py') --work $work --intake (Join-Path $tools 'intake.py') 2>&1 | ForEach-Object { "$_" }
  $code = $LASTEXITCODE
  Remove-Item -LiteralPath $tools -Recurse -Force -ErrorAction SilentlyContinue
  if ($code -ne 0) { Write-Output "The index stopped (exit $code). What went wrong is above."; exit $code }
  Write-Output "The work folder: $work"
}
