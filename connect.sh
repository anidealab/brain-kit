#!/bin/bash
# Connects your Mac to your second brain, from step 4 of anidealab.com/second-brain. Paste into Terminal:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/connect.sh)"
# The same setup as install.sh, which it runs: the runner and, if you'd like it, Obsidian, for the brain you made
# from the template. The one difference: it's run before the brain's first chat, so it ends by sending you back
# to the start page for your first message (BRAIN_KIT_FROM_SITE, which the installer reads), not back to a chat.
# BRAIN_KIT_REF works as in install.sh.

main() {
  local ref="${BRAIN_KIT_REF:-refs/heads/main}"
  local script
  if ! script=$(curl -fsSL --retry 3 "https://raw.githubusercontent.com/AnIdeaLab/brain-kit/$ref/install.sh"); then
    printf '\033[33m%s\033[0m\n' "Couldn't get the setup. Check the Mac is online, then paste the same line again."
    return 1
  fi
  BRAIN_KIT_FROM_SITE=1 /bin/bash -c "$script"
}

main "$@"
