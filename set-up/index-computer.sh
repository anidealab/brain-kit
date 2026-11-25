#!/bin/bash
# Index my computer, on a Mac. The installer runs it last with --map when BRAIN_KIT_SETUP=1 is set (AnIdeaLab's
# set-up command), as a file from the kit's folder, with --root ~/AI-Brain-Link: the map, nothing read. Then the
# set-up's agent runs it as a job on the owner's runner with --plan (what to read) and --minutes, and --more for the
# rest. It also runs on its own (no --map or --plan: map and read it all):
#   bash set-up/index-computer.sh --root ~/AI-Brain-Link [--map | --plan <file> | --more] [--minutes 45]
#   (as a runner job: download it to a file first, set INDEX_KIT_REF to the kit commit, and run it with --root;
#   away from the kit's folder it downloads its Python files from the kit at that commit.) In a terminal, its
#   progress is a bar that updates in place.
# The same as index-computer.ps1: uv into a folder of its own, a Python and MarkItDown through it,
# index-computer.py with the brain's file-intake tool, then uv and the rest taken off again. The work folder is
# _intake/computer in the root. macOS's own bash 3.2.
main() {
  local base="$PWD" mode="" plan="" minutes=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --root) base="$2"; shift ;;
      --map) mode=map ;;
      --more) mode=more ;;
      --plan) mode=plan; plan="$2"; shift ;;
      --minutes) minutes="$2"; shift ;;
    esac
    shift
  done
  if [ -n "$plan" ]; then plan=$(cd "$(dirname "$plan")" && pwd)/$(basename "$plan") || return 1; fi
  local ref="${INDEX_KIT_REF:-main}"
  local kit="https://raw.githubusercontent.com/AnIdeaLab/brain-kit/$ref"
  local uv_version="0.11.32"
  local markitdown="markitdown[pdf,docx,pptx,xlsx,xls,outlook]==0.1.9"
  local work="$base/_intake/computer"
  local tools="${TMPDIR:-/tmp}"; tools="${tools%/}/anidealab-index-tools"
  if [ "$mode" = more ] && [ ! -f "$work/left.json" ]; then echo "No read to carry on in $work."; return 1; fi
  if [ "$mode" != more ]; then rm -rf "$work"; fi
  rm -rf "$tools"; mkdir -p "$work" "$tools/uv" || return 1
  echo "Getting the tools (uv $uv_version, then Python and MarkItDown through it)..."
  local arch=x86_64; [ "$(uname -m)" = arm64 ] && arch=aarch64
  curl -fsSL --retry 3 "https://github.com/astral-sh/uv/releases/download/$uv_version/uv-$arch-apple-darwin.tar.gz" | tar -xz -C "$tools/uv" || return 1
  local uv; uv=$(find "$tools/uv" -name uv -type f | head -n 1)
  # Its Python files: beside it in the kit's folder when run as a file, else from the kit on GitHub.
  local here=""
  case "${BASH_SOURCE[0]}" in */*) here=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd) ;; esac
  if [ -n "$here" ] && [ -f "$here/index-computer.py" ] && [ -f "$here/../brain/skills/file-intake/intake.py" ]; then
    cp "$here/index-computer.py" "$tools/index-computer.py" && cp "$here/../brain/skills/file-intake/intake.py" "$tools/intake.py" || return 1
  else
    curl -fsSL --retry 3 -o "$tools/index-computer.py" "$kit/set-up/index-computer.py" || return 1
    curl -fsSL --retry 3 -o "$tools/intake.py" "$kit/brain/skills/file-intake/intake.py" || return 1
  fi
  set --
  case "$mode" in map) set -- --map ;; more) set -- --more ;; plan) set -- --plan "$plan" ;; esac
  if [ -n "$minutes" ]; then set -- "$@" --minutes "$minutes"; fi
  # The map reads nothing, so it needs no MarkItDown: only uv's Python.
  local with="--with=$markitdown"
  if [ "$mode" = map ]; then with=""; echo "Mapping the computer: where things are, nothing read. A big computer takes a few minutes."
  else echo "Searching the computer and reading the documents. A big computer takes a while."; fi
  INDEX_BRAIN_ROOT="$base" UV_CACHE_DIR="$tools/cache" UV_PYTHON_INSTALL_DIR="$tools/python" UV_NO_PROGRESS=1 \
    "$uv" run --quiet --no-build --no-project --python 3.12 ${with:+"$with"} python -I "$tools/index-computer.py" --work "$work" --intake "$tools/intake.py" "$@"
  local code=$?
  rm -rf "$tools"
  [ $code -eq 0 ] || { echo "The index stopped (exit $code). What went wrong is above."; return $code; }
  echo "The work folder: $work"
}
main "$@"
