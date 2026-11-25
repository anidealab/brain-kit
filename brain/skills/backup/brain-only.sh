#!/bin/bash
# The brain-only backup for a Mac with no runner: one command the owner pastes into Terminal.
# It opens the brain's download link in their browser (where they're signed in to GitHub), waits for the zip
# (or the folder Safari unzips it to), and copies it to their external drive as
# "Brain backup/brain-snapshots/<repo>-<date>.zip". Nothing on the drive is ever deleted or overwritten.
# Needs nothing installed. macOS's own bash 3.2.
#   curl -fsSL https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/brain/skills/backup/brain-only.sh | bash -s owner/repo
# BACKUP_DRIVE (a folder like /Volumes/My Drive) skips finding the drive; BACKUP_ZIP (a zip already downloaded)
# skips the browser.
brain="$1"
case "$brain" in
  */*) ;;
  *) echo "Say which brain, like: ... | bash -s your-name/my-brain-ail"; exit 1 ;;
esac
repo="${brain#*/}"

drive="$BACKUP_DRIVE"
if [ -z "$drive" ]; then
  list=""
  count=0
  for v in /Volumes/*; do
    [ -d "$v" ] || continue
    [ "$(cd "$v" 2>/dev/null && pwd -P)" = "/" ] && continue
    info="$(diskutil info "$v" 2>/dev/null)"
    printf '%s' "$info" | grep -Eq 'Protocol: +Disk Image' && continue
    if printf '%s' "$info" | grep -Eq 'Internal: +No|Device Location: +External'; then
      count=$((count + 1))
      list="$list$v
"
    fi
  done
  if [ "$count" -eq 0 ]; then
    echo "No external drive is plugged in. Plug your cold storage drive in, then paste the same command again."
    exit 3
  elif [ "$count" -eq 1 ]; then
    drive="${list%?}"
  else
    echo "More than one external drive is plugged in:"
    i=0
    printf '%s' "$list" | while IFS= read -r v; do i=$((i + 1)); echo "  $i: ${v#/Volumes/}"; done
    printf 'Type the number of your cold storage drive: '
    read -r pick < /dev/tty
    drive="$(printf '%s' "$list" | sed -n "${pick}p")"
    [ -n "$drive" ] || { echo "That isn't one of them. Nothing was copied."; exit 3; }
  fi
fi
[ -d "$drive" ] || { echo "The drive $drive isn't there. Nothing was copied."; exit 3; }

got="$BACKUP_ZIP"
if [ -z "$got" ]; then
  downloads="$HOME/Downloads"
  mark="$(mktemp)"
  echo "Your browser is opening your brain's download. If it asks you to sign in to GitHub, do, and the download starts."
  open "https://github.com/$brain/archive/refs/heads/main.zip"
  tries=0
  while [ -z "$got" ] && [ $tries -lt 300 ]; do
    sleep 2
    tries=$((tries + 1))
    for f in "$downloads/$repo-main"*; do
      [ -e "$f" ] && [ "$f" -nt "$mark" ] || continue
      case "$f" in *.download|*.crdownload|*.part) continue ;; esac
      got="$f"
    done
  done
  rm -f "$mark"
  [ -n "$got" ] || { echo "The download didn't show up in $downloads in 10 minutes. Nothing was copied; paste the same command to try again."; exit 1; }
  sleep 3
fi

dir="$drive/Brain backup/brain-snapshots"
mkdir -p "$dir" || { echo "Couldn't write to $drive. Nothing was copied."; exit 1; }
name="$repo-$(date +%Y-%m-%d)"
dest="$dir/$name.zip"
n=2
while [ -e "$dest" ]; do dest="$dir/$name-$n.zip"; n=$((n + 1)); done
if [ -d "$got" ]; then
  # Safari unzips downloads by itself; zip the folder back up.
  ditto -c -k --keepParent "$got" "$dest" || { echo "Couldn't copy it to the drive."; exit 1; }
else
  cp "$got" "$dest" || { echo "Couldn't copy it to the drive."; exit 1; }
fi
size="$(du -k "$dest" | awk '{printf "%.1f", $1/1024}')"
echo "Done: your brain is on the drive as $dest ($size MB). You can eject the drive and unplug it now."
