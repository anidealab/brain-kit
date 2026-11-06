#!/bin/bash
# Starts your own second brain from the AnIdeaLab brain kit, on a Mac. Paste into Terminal:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/install.sh)"
# It downloads this repo from GitHub (no Git needed yet), unpacks it in a temporary folder and runs the
# installer in it, install/install-mac.sh, which does the rest and says what it's doing: Apple's command
# line tools (they have Git), GitHub's command line and Obsidian, your brain's private repo made from brain/,
# your copy in ~/AI-Brain-Link, and the Mac runner. Safe to run again. macOS's own bash 3.2.
# The Windows one is install.ps1, beside this. BRAIN_KIT_REF, a branch or commit to download instead of main,
# is for the kit's own test on GitHub's Macs (.github/workflows/mac-installer.yml).

# All in a function, so the whole script is read before any of it runs, even when it's piped into bash.
main() {
  local ref="${BRAIN_KIT_REF:-refs/heads/main}"
  local url="https://github.com/AnIdeaLab/brain-kit/archive/$ref.tar.gz"
  local tmp="${TMPDIR:-/tmp}"
  local tgz="${tmp%/}/brain-kit-download.tar.gz"
  local kit="${tmp%/}/brain-kit-download"
  printf '\n\033[36m%s\033[0m\n' "Downloading the AnIdeaLab brain kit..."
  rm -rf "$kit" 2>/dev/null
  if [ -e "$kit" ]; then kit="$kit-$$"; fi
  local installer=""
  if mkdir -p "$kit" && curl -fsSL --retry 3 -o "$tgz" "$url" && tar -xzf "$tgz" -C "$kit"; then
    installer=$(ls "$kit"/*/install/install-mac.sh 2>/dev/null | head -n 1)
  fi
  if [ -z "$installer" ]; then
    printf '\033[33m%s\033[0m\n' "Couldn't get the kit from $url. Check the Mac is online, then paste the same line again."
    return 1
  fi
  # Its questions are read from the keyboard, even when this script came in through a pipe.
  local code=0
  if [ ! -t 0 ] && (exec </dev/tty) 2>/dev/null; then
    /bin/bash "$installer" </dev/tty || code=$?
  else
    /bin/bash "$installer" || code=$?
  fi
  if [ "$code" -eq 0 ]; then
    rm -rf "$kit" "$tgz"
  else
    printf '\n\033[33m%s\033[0m\n' "The setup stopped before the end. What went wrong is just above; once it's sorted, paste the same line again, and it skips what's already done."
  fi
  return "$code"
}

main "$@"
