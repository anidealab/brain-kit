#!/bin/bash
# Upload point on a Mac: what "My brain" in Finder's right-click menu runs (Quick Actions, then My brain). The
# owner selects files or folders, right-clicks and picks it; this adds each one's path to a plain text list on
# the Mac and says so in a small box. An agent reads the list and sorts them into the brain when the owner says
# what to do (SKILL.md in this folder; the Windows version, Send to, My brain, is upload-point.ps1 here).
# The list is _upload/waiting.txt in the folder that holds the brain's copy (~/AI-Brain-Link/_upload/
# waiting.txt): one line per thing, the time it was sent, a tab, and its path. UTF-8.
# Paths only, no copies, except anything on a USB stick, memory card or disc, which is copied to
# _upload/<date>/ first, since it may be gone by the time the agent looks; the copy is what's listed.
# A first argument of --quiet prints the message instead of showing the box (for an agent or a test).
# setup-upload-point.sh makes the Quick Action. macOS's own bash 3.2.

quiet=''
if [ "${1:-}" = --quiet ]; then quiet=yes; shift; fi
if [ -n "${BRAIN_KIT_CHECK:-}" ]; then quiet=yes; fi  # the kit's test on GitHub's Macs: no box to wait on
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
copy=$(cd "$here/../.." && pwd)       # the brain's copy: <copy>/skills/upload-point
upload="$(dirname "$copy")/_upload"
list="$upload/waiting.txt"

tell() {
  local text="" line
  for line in "$@"; do if [ -n "$line" ]; then text="${text:+$text

}$line"; fi; done
  if [ -n "$quiet" ]; then printf '%s\n' "$text"; return; fi
  osascript -e 'on run argv' -e 'display dialog (item 1 of argv) with title "My brain" buttons {"OK"} default button 1 giving up after 120' -e 'end run' "$text" >/dev/null 2>&1 ||
    printf '%s\n' "$text"
}
# A USB stick, memory card or disc: under /Volumes, and diskutil calls its media removable, or optical.
# Drives that stay put (an external disk, the Mac's own) and network shares are listed where they are.
on_removable() {
  local rest mnt info
  case "$1" in /Volumes/*) ;; *) return 1 ;; esac
  rest="${1#/Volumes/}"
  mnt="/Volumes/${rest%%/*}"
  [ -L "$mnt" ] && return 1  # the Mac's own disk shows in /Volumes as a link to /
  info=$(diskutil info "$mnt" 2>/dev/null) || return 1
  printf '%s\n' "$info" | grep -Eq 'Removable Media: +(Removable|Yes)|Optical Drive Type|Optical Media Type'
}
# A copy in _upload/<date>/, under a name nothing there has yet. Prints where it went.
copy_in() {
  local dir name base ext dest n=2
  dir="$upload/$(date '+%Y-%m-%d')"
  mkdir -p "$dir" || return 1
  name=$(basename "$1")
  if [ -z "$name" ] || [ "$name" = / ]; then name="drive"; fi
  dest="$dir/$name"
  while [ -e "$dest" ]; do
    if [ -d "$1" ]; then dest="$dir/$name ($n)"
    else
      base="${name%.*}"; ext=''
      if [ "$base" != "$name" ] && [ -n "$base" ]; then ext=".${name##*.}"; else base="$name"; fi
      dest="$dir/$base ($n)$ext"
    fi
    n=$((n + 1))
  done
  cp -R "$1" "$dest" || return 1
  printf '%s\n' "$dest"
}

if [ $# -eq 0 ]; then
  tell 'Nothing was sent. To give your brain files or folders, select them in Finder, right-click, and pick Quick Actions, then My brain.'
  exit 0
fi

# What's on the list already, so the same path isn't listed twice (as on Windows, whatever its capitals).
have=''
if [ -f "$list" ]; then have=$(awk -F'\t' 'NF > 1 {print tolower($2)}' "$list" | tr -d '\r'); fi

new=''
trouble=()
sent=0
for p in "$@"; do
  case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
  if [ "$p" != / ]; then p="${p%/}"; fi
  if [ ! -e "$p" ]; then trouble+=("Couldn't find $p"); continue; fi
  if on_removable "$p"; then
    if c=$(copy_in "$p"); then p="$c"; else trouble+=("Couldn't copy $(basename "$p") off the drive, so it's listed where it is."); fi
  fi
  sent=$((sent + 1))
  low=$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]')
  if ! printf '%s\n' "$have" | grep -Fxq -- "$low"; then
    new="$new$(date '+%Y-%m-%d %H:%M')	$p
"
    have="$have
$low"
  fi
done

if [ -n "$new" ]; then
  if ! mkdir -p "$upload" || ! printf '%s' "$new" >> "$list"; then
    tell "Not sent: couldn't write the list, $list." "${trouble[@]}"
    exit 1
  fi
fi
msg=''
if [ "$sent" -gt 0 ]; then msg="Sent to your brain: $sent. Tell Claude what to do with them."; fi
tell "$msg" "${trouble[@]}"
exit 0
