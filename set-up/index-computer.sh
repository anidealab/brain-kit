#!/bin/bash
# Index my computer, on a Mac: AnIdeaLab's set-up runs this as a job on the owner's runner (their brain's
# "Run on my Mac" workflow), with ~/AI-Brain-Link as the job's folder:
#   INDEX_KIT_REF=<kit commit> /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/AnIdeaLab/brain-kit/<kit commit>/set-up/index-computer.sh)"
# The same as index-computer.ps1: uv into a folder of its own, a Python and MarkItDown through it,
# index-computer.py with the brain's file-intake tool, then uv and the rest taken off again. The work folder,
# _intake/computer in the job's folder, is what the job attaches. macOS's own bash 3.2.
main() {
  local ref="${INDEX_KIT_REF:-main}"
  local kit="https://raw.githubusercontent.com/AnIdeaLab/brain-kit/$ref"
  local uv_version="0.11.32"
  local markitdown="markitdown[pdf,docx,pptx,xlsx,xls,outlook]==0.1.9"
  local work="$PWD/_intake/computer"
  local tools="${TMPDIR:-/tmp}"; tools="${tools%/}/anidealab-index-tools"
  rm -rf "$work" "$tools"; mkdir -p "$work" "$tools/uv" || return 1
  echo "Getting the tools (uv $uv_version, then Python and MarkItDown through it)..."
  local arch=x86_64; [ "$(uname -m)" = arm64 ] && arch=aarch64
  curl -fsSL --retry 3 "https://github.com/astral-sh/uv/releases/download/$uv_version/uv-$arch-apple-darwin.tar.gz" | tar -xz -C "$tools/uv" || return 1
  local uv; uv=$(find "$tools/uv" -name uv -type f | head -n 1)
  curl -fsSL --retry 3 -o "$tools/index-computer.py" "$kit/set-up/index-computer.py" || return 1
  curl -fsSL --retry 3 -o "$tools/intake.py" "$kit/brain/skills/file-intake/intake.py" || return 1
  echo "Searching the computer and reading the documents. A big computer takes a while."
  INDEX_BRAIN_ROOT="$PWD" UV_CACHE_DIR="$tools/cache" UV_PYTHON_INSTALL_DIR="$tools/python" UV_NO_PROGRESS=1 \
    "$uv" run --quiet --no-project --python 3.12 --with "$markitdown" python -I "$tools/index-computer.py" --work "$work" --intake "$tools/intake.py"
  local code=$?
  rm -rf "$tools"
  [ $code -eq 0 ] || { echo "The index stopped (exit $code). What went wrong is above."; return $code; }
  echo "The work folder: $work"
}
main
