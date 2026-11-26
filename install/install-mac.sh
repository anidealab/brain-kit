#!/bin/bash
# Sets up your own second brain on this Mac, from the AnIdeaLab brain kit. It asks you to accept AnIdeaLab's
# terms of use (TERMS.md, at the kit repo's root) first, and stops if you don't. It opens Claude in the
# browser, to sign in or sign up for a paid plan (S skips it), and asks whether you'd like Obsidian. Then it
# installs Apple's command line tools (they have Git) and GitHub's command line (gh) if they're missing, and
# Obsidian if you said yes, signs you in to GitHub, makes your brain's private repo (inviting AnIdeaLab's
# testing account to it, as the terms say) and puts the brain in it, puts your copy in ~/AI-Brain-Link,
# sets up the Mac runner if you say yes to it, so AI agents can run jobs on this Mac, then sets Obsidian up on
# your brain, with its syncing on, if you chose Obsidian. It doesn't open Obsidian: you go back to your chat,
# and your agent says how to open it. Obsidian and the runner are extras: your brain works without either, and
# pasting the same command again adds one later. It needs no password: gh and Obsidian come from
# their own releases on GitHub, each checked against its checksum, not from Homebrew.
# Safe to run again: it skips what's already done. It ends with a list of which steps finished, and keeps it
# in ~/AI-Brain-Link/_logs/install.log, which the setup check reads.
# It's install-windows.ps1 for a Mac: the same steps in the same order, with the same questions. The brain is
# the kit repo's brain/ folder beside this script's install/ folder (or --brain <a brain folder>), with the
# Mac's parts added, since brain/ is made for a Windows PC: install/mac-brain/'s files where brain/ doesn't
# have them yet (the Mac runner's workflow, skill and note), and a few of brain/'s lines adapted (the list in
# mac_brain below). install.sh, at the kit repo's root, downloads the repo and runs this from it.
# macOS's own bash 3.2, and the Python 3 that comes with Apple's command line tools.
# BRAIN_KIT_CHECK=<a test folder>: nothing is installed, and GitHub and Obsidian aren't touched (tools/kit.py
# build runs it so, and fails if a line it adapts has changed). With BRAIN_KIT_CHECK_TOOLS=1 as well, it also
# installs gh, Obsidian and GitHub's runner in the test folder, without registering the runner (the kit's
# test on GitHub's Macs, .github/workflows/mac-installer.yml).

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
check="${BRAIN_KIT_CHECK:-}"
tools_check="${BRAIN_KIT_CHECK_TOOLS:-}"
if [ -n "$check" ]; then root="$check"; else root="$HOME/AI-Brain-Link"; fi
# AnIdeaLab's set-up (the brain set up for you): BRAIN_KIT_SETUP=1, in the command its set-up page gives. It
# lets AnIdeaLab's set-up account in to the brain even when the brain was made already (from the template),
# maps this Mac last (set-up/index-computer.sh --map, beside install/: folders and documents' names, nothing opened) and sends the
# map to the brain's repo as a private draft release, and ends with "we'll take it from here" instead of the chat
# steps. Anyone can set it; it's off unless they do.
setup="${BRAIN_KIT_SETUP:-}"
# The start page's step 4 (anidealab.com/second-brain, 25 Nov 2026): BRAIN_KIT_FROM_SITE=1, which connect.sh sets.
# There it runs before the brain's first chat, so it ends by sending them back to that page for their first
# message, not back to a chat. Otherwise the same.
from_site="${BRAIN_KIT_FROM_SITE:-}"
brain=""
while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="$2"; shift 2 ;;
    *) shift ;;
  esac
done
tools="$root/Tools"
export PATH="$tools/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
day=$(LC_ALL=C date -u '+%d %b %Y'); day="${day#0}"
iso=$(date -u '+%Y-%m-%d')
gh=""
obsidian_app=""
# The oldest versions the setup takes as it finds them. macOS: GitHub's runner needs 11, and gh's newest
# builds need 12. gh: an older one on the PATH (an old Homebrew one, or the kit's own from an earlier run) is
# replaced by the newest, in ~/AI-Brain-Link/Tools. Obsidian: the Obsidian Git plugin's minAppVersion (its
# manifest.json); an older Obsidian is replaced by the newest where it is, and its vaults and settings stay.
macos_min=12
gh_min=2.40.0
obsidian_min=1.13.0

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }
say() { printf '\n\033[36m%s\033[0m\n' "$1"; }
warn() { printf '\033[33m%s\033[0m\n' "$1"; }
# Each question in yellow on its own line, so it can't be missed among the installs' output.
ask() {
  if [ -n "$check" ]; then answer="$2"; return; fi
  local a=""
  printf '\n\033[33m%s\033[0m\n' "$1"
  read -r -p "Type your answer, or press Enter for $2: " a
  a=$(trim "$a")
  answer="${a:-$2}"
}
yes_to() { ask "$1" Y; case "$answer" in [Yy]*) return 0 ;; *) return 1 ;; esac; }

# The steps and how each went, kept in ~/AI-Brain-Link/_logs/install.log as it goes and listed at the end,
# so if the setup stops, or its window is closed, the brain's agent and the setup check can see how far it got.
log_file="$root/_logs/install.log"
log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$log_file" 2>/dev/null; }
step_names=()
step_states=()
step() {
  local i=0
  while [ "$i" -lt "${#step_names[@]}" ]; do
    if [ "${step_names[$i]}" = "$1" ]; then step_states[$i]="$2"; log "$2  $1"; return; fi
    i=$((i + 1))
  done
  step_names+=("$1")
  step_states+=("$2")
  log "$2  $1"
}
show_steps() {
  local i=0 s shown colour
  printf '\n\033[36m%s\033[0m\n' 'The setup, step by step:'
  while [ "$i" -lt "${#step_names[@]}" ]; do
    s="${step_states[$i]}"
    case "$s" in done) colour=32 ;; skipped) colour=90 ;; *) colour=33 ;; esac
    shown="$s"
    if [ "$s" = started ]; then shown='stopped here'; fi
    printf '\033[%sm  %-12s %s\033[0m\n' "$colour" "$shown" "${step_names[$i]}"
    i=$((i + 1))
  done
  echo "  (also kept in $log_file)"
}
# A step that stops the setup: list the steps and where it stopped.
die() {
  log "stopped: $1"
  printf '\n\033[31m%s\033[0m\n' "$1"
  show_steps
  exit 1
}
trap 'log "stopped: interrupted"; show_steps; exit 130' INT
trap 'log "stopped: the window was closed"; exit 129' HUP

sha256() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else openssl dgst -sha256 -r "$1" | cut -d' ' -f1; fi
}
# A release's newest tag, from where GitHub's "latest" page sends the browser, so no sign-in is needed.
latest_tag() {
  local u
  u=$(curl -fsSLI --retry 3 -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest") || return 1
  u="${u##*/}"
  case "$u" in v[0-9]*) printf '%s\n' "$u" ;; *) return 1 ;; esac
}
# A release file's SHA-256, as GitHub's API lists it, or nothing.
asset_digest() {
  local json=""
  if [ -n "$gh" ]; then json=$("$gh" api "repos/$1/releases/tags/$2" 2>/dev/null); fi
  if [ -z "$json" ]; then json=$(curl -fsSL "https://api.github.com/repos/$1/releases/tags/$2" 2>/dev/null); fi
  printf '%s' "$json" | python3 -c '
import json, sys
try:
    for a in json.load(sys.stdin).get("assets", []):
        d = str(a.get("digest") or "")
        if a.get("name") == sys.argv[1] and d.startswith("sha256:"):
            print(d[7:])
except ValueError:
    pass' "$3" 2>/dev/null
}

# Version $1 is older than version $2: the first three numbers, each part's leading digits (bash 3.2 has no sort -V).
older_than() {
  local IFS=. i x y a b
  read -r -a a <<< "$1"; read -r -a b <<< "$2"
  for i in 0 1 2; do
    x="${a[$i]%%[!0-9]*}"; y="${b[$i]%%[!0-9]*}"; x=$((10#${x:-0})); y=$((10#${y:-0}))
    if [ "$x" -lt "$y" ]; then return 0; fi
    if [ "$x" -gt "$y" ]; then return 1; fi
  done
  return 1
}
gh_version() { "$1" --version 2>/dev/null | awk 'NR == 1 {print $3}'; }
app_version() { defaults read "$1/Contents/Info" CFBundleShortVersionString 2>/dev/null; }
quit_obsidian() {
  local i=0
  if [ -n "$check" ] || ! pgrep -x Obsidian >/dev/null 2>&1; then return; fi
  osascript -e 'quit app "Obsidian"' >/dev/null 2>&1
  while pgrep -x Obsidian >/dev/null 2>&1 && [ "$i" -lt 10 ]; do sleep 1; i=$((i + 1)); done
}

find_gh() {
  if [ -x "$tools/bin/gh" ]; then printf '%s\n' "$tools/bin/gh"; return; fi
  if [ -n "$check" ]; then return; fi # the test installs its own
  command -v gh 2>/dev/null
}
find_obsidian() {
  local o
  if [ -n "$check" ]; then o="$root/Applications/Obsidian.app"; if [ -d "$o" ]; then printf '%s\n' "$o"; fi; return; fi
  for o in /Applications/Obsidian.app "$HOME/Applications/Obsidian.app"; do
    if [ -d "$o" ]; then printf '%s\n' "$o"; return; fi
  done
  mdfind 'kMDItemCFBundleIdentifier == "md.obsidian"' 2>/dev/null | head -n 1
}

# Git comes with Apple's command line tools. macOS installs them from a window of its own, with no password
# for an admin account, while this waits.
ensure_git() {
  if xcode-select -p >/dev/null 2>&1 && git --version >/dev/null 2>&1; then return; fi
  say "Installing Apple's command line tools, which have Git. A window opens: click Install, then Agree. It takes 5 to 20 minutes, and this carries on by itself once they're in."
  xcode-select --install >/dev/null 2>&1
  local waited=0
  until xcode-select -p >/dev/null 2>&1; do
    sleep 10
    waited=$((waited + 10))
    if [ $((waited % 120)) -eq 0 ]; then echo "  Still waiting for Apple's command line tools ($((waited / 60)) minutes)..."; fi
    if [ "$waited" -ge 3600 ]; then die "Apple's command line tools aren't in yet. If their window was closed, paste the same command again to bring it back; otherwise wait until they're installed, then paste it."; fi
  done
  git --version >/dev/null 2>&1 || die "Apple's command line tools are in, but Git doesn't run yet ($(git --version 2>&1 | head -n 1)). Close Terminal, open it again and paste the same command."
  say "Apple's tools are in. If their window is still finishing, leave it, it doesn't matter."
  log "installed Apple's command line tools"
}

# GitHub's command line, from its own release, checked against the release's checksums, into
# ~/AI-Brain-Link/Tools, so it needs no password; new Terminal windows get it on their PATH.
install_gh() {
  local arch tag v zip tmp want got bin
  say "Installing GitHub's command line (gh), from its own release on GitHub..."
  if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ]; then arch=arm64; else arch=amd64; fi
  tag=$(latest_tag cli/cli) || die "Couldn't find the newest version of GitHub's command line. Check the Mac is online, then paste the same command again."
  v="${tag#v}"
  zip="gh_${v}_macOS_${arch}.zip"
  tmp=$(mktemp -d)
  if ! curl -fsSL --retry 3 -o "$tmp/$zip" "https://github.com/cli/cli/releases/download/$tag/$zip" ||
     ! curl -fsSL --retry 3 -o "$tmp/sums.txt" "https://github.com/cli/cli/releases/download/$tag/gh_${v}_checksums.txt"; then
    rm -rf "$tmp"; die "Couldn't download GitHub's command line ($zip). Check the Mac is online, then paste the same command again."
  fi
  want=$(awk -v f="$zip" '$2 == f {print $1}' "$tmp/sums.txt")
  got=$(sha256 "$tmp/$zip")
  if [ -z "$want" ] || [ "$want" != "$got" ]; then rm -rf "$tmp"; die "GitHub's command line didn't match its checksum, so it wasn't installed. Paste the same command again."; fi
  mkdir -p "$tmp/x" && unzip -q "$tmp/$zip" -d "$tmp/x" || { rm -rf "$tmp"; die "Couldn't unpack GitHub's command line."; }
  bin=$(find "$tmp/x" -type f -path '*/bin/gh' | head -n 1)
  [ -n "$bin" ] || { rm -rf "$tmp"; die "GitHub's command line wasn't where it should be in its download, so it wasn't installed."; }
  rm -rf "$tools/gh"
  mkdir -p "$tools/bin"
  mv "$(dirname "$(dirname "$bin")")" "$tools/gh" && ln -sf ../gh/bin/gh "$tools/bin/gh"
  rm -rf "$tmp"
  "$tools/bin/gh" --version >/dev/null 2>&1 || die "GitHub's command line is in $tools/gh, but it doesn't run on this Mac."
  log "installed gh $v in $tools"
  if [ -z "$check" ]; then
    local profile line
    # shellcheck disable=SC2016 # the line is written as it is, for Terminal to read
    line='export PATH="$HOME/AI-Brain-Link/Tools/bin:$PATH"'
    case "$(basename "${SHELL:-/bin/zsh}")" in bash) profile="$HOME/.bash_profile" ;; *) profile="$HOME/.zprofile" ;; esac
    if ! grep -qsF "$line" "$profile"; then
      printf '\n# GitHub'"'"'s command line (gh), from the AnIdeaLab brain kit'"'"'s installer\n%s\n' "$line" >> "$profile"
    fi
  fi
}

# Obsidian, from its own disk image on GitHub, checked against the checksum GitHub lists for it (or, if
# there's none, Apple's signature on it), into Applications. Downloaded by curl, it carries none of the
# quarantine flag a browser's download would, so it opens without asking; the flag is cleared anyway.
# With a folder, an older Obsidian there is replaced (or, if it can't be, the new one goes in ~/Applications).
# Obsidian is an extra, so if it doesn't come in, the setup carries on without it, as on Windows: it's tried
# again through gh once gh is signed in (GitHub's plain release links can answer 504 for hours while gh's route
# works, 8 Nov 2026), and the end says what to do.
obsidian_failed() { log "carried on without Obsidian: $1"; warn "$1 Your brain is fine without it: the setup carries on, and tries Obsidian again later."; }
install_obsidian() {
  local tag v dmg tmp want got dest ok
  say 'Installing Obsidian, from its own release on GitHub...'
  tag=$(latest_tag obsidianmd/obsidian-releases)
  if [ -z "$tag" ] && [ -n "$gh" ]; then tag=$("$gh" api repos/obsidianmd/obsidian-releases/releases/latest --jq .tag_name 2>/dev/null); fi
  [ -n "$tag" ] || { obsidian_failed "Couldn't find the newest version of Obsidian."; return 1; }
  v="${tag#v}"
  dmg="Obsidian-$v.dmg"
  tmp=$(mktemp -d)
  if ! { [ -n "$gh" ] && "$gh" auth status --hostname github.com >/dev/null 2>&1 &&
         "$gh" release download "$tag" --repo obsidianmd/obsidian-releases --pattern "$dmg" --clobber --dir "$tmp" 2>/dev/null; } &&
     ! curl -fsSL --retry 3 -o "$tmp/$dmg" "https://github.com/obsidianmd/obsidian-releases/releases/download/$tag/$dmg"; then
    rm -rf "$tmp"; obsidian_failed "Obsidian's download ($dmg) didn't come through. That's usually GitHub, and it usually passes."; return 1
  fi
  want=$(asset_digest obsidianmd/obsidian-releases "$tag" "$dmg")
  got=$(sha256 "$tmp/$dmg")
  if [ -n "$want" ] && [ "$want" != "$got" ]; then rm -rf "$tmp"; obsidian_failed "Obsidian didn't match its checksum, so it wasn't installed."; return 1; fi
  mkdir -p "$tmp/disk"
  hdiutil attach -nobrowse -noautoopen -readonly -quiet -mountpoint "$tmp/disk" "$tmp/$dmg" </dev/null || { rm -rf "$tmp"; obsidian_failed "Couldn't open Obsidian's disk image."; return 1; }
  if [ ! -d "$tmp/disk/Obsidian.app" ] || { [ -z "$want" ] && ! codesign --verify "$tmp/disk/Obsidian.app" 2>/dev/null; }; then
    hdiutil detach "$tmp/disk" -quiet; rm -rf "$tmp"
    obsidian_failed "Obsidian's disk image isn't as it should be, so it wasn't installed."; return 1
  fi
  if [ -n "$check" ]; then dest="$root/Applications"; elif [ -n "${1:-}" ]; then dest="$1"; elif [ -w /Applications ]; then dest=/Applications; else dest="$HOME/Applications"; fi
  if [ -d "$dest/Obsidian.app" ]; then
    quit_obsidian
    rm -rf "$dest/Obsidian.app" 2>/dev/null || { warn "Couldn't replace the old Obsidian in $dest, so the new one goes in $HOME/Applications."; dest="$HOME/Applications"; }
  fi
  mkdir -p "$dest"
  ditto "$tmp/disk/Obsidian.app" "$dest/Obsidian.app"; ok=$?
  hdiutil detach "$tmp/disk" -quiet || hdiutil detach "$tmp/disk" -force -quiet
  rm -rf "$tmp"
  [ "$ok" -eq 0 ] || { obsidian_failed "Couldn't copy Obsidian into $dest."; return 1; }
  xattr -dr com.apple.quarantine "$dest/Obsidian.app" 2>/dev/null
  if [ -z "$check" ] && [ -x "$LSREGISTER" ]; then "$LSREGISTER" -f "$dest/Obsidian.app" >/dev/null 2>&1; fi # so obsidian:// links open it
  obsidian_app="$dest/Obsidian.app"
  if [ -n "$want" ]; then log "installed Obsidian $v in $dest, checked against its checksum"; else log "installed Obsidian $v in $dest, checked by its signature (GitHub listed no checksum)"; fi
}

# Makes a brain for this Mac (new <folder>), or adds the Mac's parts to a brain made elsewhere (add <folder>).
# A new brain is made from the brain folder as tools/kit.py makes its zip's bundle and install-windows.ps1
# makes it: a copy, with today's date (UTC) in for the kit's {KIT_DATE} and {KIT_ISO} in file names and in its
# text files (UTF-8, as they came), and the newest update in its brain-updates note. Then the Mac's parts:
# install/mac-brain/'s files where the brain doesn't have them, and, in a new brain, its lines that say PC or
# PowerShell where a Mac has its own, each found by how it starts. In the kit's check, a line that isn't
# there any more stops it, so the build says which to change here. A brain made elsewhere keeps its own words:
# it gets the files and the skill lists' lines. Last, library.py builds the indexes.
mac_brain() {
  python3 - "$1" "$2" "$brain" "$here/mac-brain" "$day" "$iso" "${check:+strict}" <<'PY' >&2
import os, re, shutil, subprocess, sys
mode, work, brain, overlay, day, iso, strict = (sys.argv[1:] + [""] * 7)[:7]
TEXT = {".md", ".py", ".ps1", ".yml", ".json", ".txt", ".css", ".js", ".mjs", ".sh"}  # tools/kit.py's TEXT
MARK = re.compile(r"\{KIT_(DATE|ISO)\}")


def fill(s):
    return s.replace("{KIT_DATE}", day).replace("{KIT_ISO}", iso)


def fill_file(path):
    name = os.path.basename(path)
    if os.path.splitext(name)[1] not in TEXT and name != ".gitignore":
        return
    with open(path, encoding="utf-8", newline="") as f:
        text = f.read()
    if fill(text) != text:
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(fill(text))


if mode == "new":
    shutil.copytree(brain, work, symlinks=True, ignore=shutil.ignore_patterns("__pycache__", ".DS_Store"))
    for top, _, files in os.walk(work):
        for f in files:
            fill_file(os.path.join(top, f))
    # Deepest first, so a folder is renamed after what's in it.
    named = [os.path.join(top, n) for top, dirs, files in os.walk(work) for n in dirs + files if MARK.search(n)]
    for path in sorted(named, key=len, reverse=True):
        os.rename(path, os.path.join(os.path.dirname(path), fill(os.path.basename(path))))
    # The brain has every brain update in the kit's updates/ folder beside brain/, so its note says the newest,
    # in the form brain_update.py reads and writes; otherwise it would go by the start date, and on the day an
    # update goes out, offer the brain an update it already has.
    updates = os.path.join(os.path.dirname(brain), "updates")
    found = [re.match(r"^(\d{4})-[a-z0-9-]+\.md$", u) for u in (os.listdir(updates) if os.path.isdir(updates) else [])]
    newest = max([int(m.group(1)) for m in found if m] or [0])
    note = os.path.join(work, "knowledge", "systems", "brain-updates", "README.md")
    if newest and os.path.isfile(note):
        line = f"**On kit update:** {newest} (in the kit this brain started from, made on {day})"
        with open(note, encoding="utf-8", newline="") as f:
            text = f.read()
        text, n = re.subn(r"(?m)^\*\*On kit update:\*\* [^\r\n]*", lambda m: line, text, count=1)
        if not n:
            text = text.rstrip() + f"\n\n{line}\n"
        with open(note, "w", encoding="utf-8", newline="") as f:
            f.write(text)

# The Mac's files, where the brain doesn't have them: once a brain update brings them into brain/, its copies win.
for top, dirs, files in os.walk(overlay):
    dirs[:] = [d for d in dirs if d != "__pycache__"]
    for f in files:
        rel = os.path.relpath(os.path.join(top, f), overlay)
        dest = os.path.join(work, fill(rel))
        if f == ".DS_Store" or os.path.exists(dest):
            continue
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(os.path.join(top, f), dest)
        fill_file(dest)

problems = []


def edit(rel, start, new, how="line", old=None, done=None):
    """The first line that starts with start: replaced by new, or with new after it ("after"), or with old in it
    swapped for new ("swap"). Nothing changes if a line already starts with done."""
    path = os.path.join(work, fill(rel))
    try:
        with open(path, encoding="utf-8", newline="") as f:
            lines = f.read().split("\n")
    except OSError:
        problems.append(f"{fill(rel)} isn't there")
        return
    if done and any(line.startswith(done) for line in lines):
        return
    for i, line in enumerate(lines):
        if line.startswith(start):
            if how == "after":
                lines[i + 1:i + 1] = new.split("\n")
            elif how == "swap":
                if old not in line:
                    problems.append(f'{fill(rel)}: its line starting "{start}" has no "{old}"')
                    return
                lines[i] = line.replace(old, new, 1)
            else:
                lines[i] = new
            break
    else:
        problems.append(f'{fill(rel)}: no line starts "{start}"')
        return
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(lines))


if mode == "new":
    # The core: its first session, and the two defaults about the owner's computer. It stays under the kit's 6 KB.
    edit("CLAUDE.md", "**A new brain.**", " and follow it, with [my-mac](skills/my-mac/SKILL.md) for its PC steps.", how="swap", old=" and follow it.")
    edit("CLAUDE.md", "- **PC work goes to the owner's PC,**",
         "- **Mac work goes to the owner's Mac,** through the `my-mac` runner, so needing it never rules a route out; not set up yet? offer it, never a local session (how: the [my-mac skill](skills/my-mac/SKILL.md)).")
    edit("CLAUDE.md", "- **Give the owner a command:**",
         "- **Give the owner a command:** Mac jobs go through the runner if they can; otherwise one command to paste into Terminal, not click-by-click steps.")
    rules = "knowledge/decisions/the-brain/{KIT_ISO}-starting-rules.md"
    edit(rules, "- **PC work goes to the owner's PC,**",
         "- **Mac work goes to the owner's Mac,** through a GitHub Actions runner there, so a job that needs their Mac or their apps never rules a route out. How: the [my-mac skill](../../../skills/my-mac/SKILL.md).")
    edit(rules, "- **Give the owner a command:**",
         "- **Give the owner a command:** a task on the owner's computer runs through the runner if it can. If the owner has to do it, they get one command to paste into Terminal, not click-by-click steps, which are slower and easy to get wrong.")
    # The front door, in the owner's words.
    edit("README.md", "- **Obsidian,** if I've added it: this repo is a vault on my PC",
         "- **Obsidian,** if I've added it: this repo is a vault on my Mac, in `~/AI-Brain-Link`, and its graph draws every link between notes ([setup and how to read it](knowledge/systems/obsidian-setup.md)).")
    edit("README.md", "- **My PC,**",
         "- **My Mac,** if I've added its runner: agents run jobs on it through a GitHub Actions runner while it's on and I'm logged in ([the Mac](knowledge/systems/my-mac.md)). \"AI Brain Link - live jobs\", in my `~/AI-Brain-Link` folder, shows what's running.")
    edit("README.md", "- **Giving it files:**",
         "- **Giving it files:** in a chat, I attach them, or tell the agent where they are on my Mac.")
    edit("README.md", "- **Extras:**",
         "- **Extras:** Obsidian and the Mac runner are extras, and the brain works without them. To add one, I ask an agent, which gives me one command to paste ([the first session's step 4](skills/getting-started/SKILL.md#4-the-owners-computer)).")
    skills = len([d for d in os.listdir(os.path.join(work, "skills")) if os.path.isfile(os.path.join(work, "skills", d, "SKILL.md"))])
    with open(os.path.join(work, "README.md"), encoding="utf-8") as f:
        count = re.search(r" \d+ to start,", f.read())
    if count:  # brain/ before update 12 gives a count; from update 12 it gives none, so there's nothing to change
        edit("README.md", "- **[The skills](skills/README.md):**", f" {skills} to start,", how="swap", old=count.group(0))
    # The PC's note: no PC yet.
    edit("knowledge/systems/my-pc.md", "about: ",
         "about: \"The owner's Windows PC, if they add one: this brain was set up on their Mac (the my-mac note). How agents reach a PC (the my-pc runner), its folders in C:/AI-Brain-Link, and what's on it.\"")
    edit("knowledge/systems/my-pc.md", "# ",
         "\n*This brain was set up on the owner's Mac, so it has no PC runner yet: the Mac is in [my-mac](my-mac.md). The rest of this note is for a Windows PC, if they add one with the kit's Windows installer or `skills/my-pc/setup-runner.ps1`.*",
         how="after")

# The skill lists, in any brain.
edit("skills/lists/the-brain.md", "- [my-pc](../my-pc/SKILL.md)",
     "- [my-mac](../my-mac/SKILL.md): run commands and jobs on the owner's Mac through the `my-mac` runner, check or fix its setup, give the brain files from the Mac, and the Mac's part of a new brain's first session.",
     how="after", done="- [my-mac](")
edit("skills/README.md", "- [my-pc](my-pc/SKILL.md)",
     "- [my-mac](my-mac/SKILL.md): run commands and jobs on the owner's Mac through the `my-mac` runner, and check or fix its setup.",
     how="after", done="- [my-mac](")

library = os.path.join(work, "skills", "brain-spec", "library.py")
if os.path.isfile(library):
    r = subprocess.run([sys.executable, library, "build"], cwd=work, capture_output=True, text=True)
    if r.returncode:
        problems.append("library.py build: " + (r.stdout + r.stderr).strip()[-300:])
for p in problems:
    print(f"Couldn't adapt the brain for a Mac: {p}")
if problems and strict:
    sys.exit(1)
PY
}

# A new brain's git repo, made from the brain folder with mac_brain new, in one commit. Prints its folder,
# for the brain to be cloned from.
new_brain_repo() {
  local work
  if [ -n "$check" ]; then work="$root/new-brain"; else work="${TMPDIR:-/tmp}"; work="${work%/}/brain-kit-new"; fi
  rm -rf "$work"
  mac_brain new "$work" || return 1
  { git -c init.defaultBranch=main init -q "$work" &&
    git -C "$work" symbolic-ref HEAD refs/heads/main &&
    git -C "$work" config core.autocrlf false && # the kit's bytes as they are, line endings too
    git -C "$work" add -A; } >&2 || return 1
  GIT_AUTHOR_NAME='AnIdeaLab brain kit' GIT_AUTHOR_EMAIL='brain-kit@anidealab.com' \
    GIT_COMMITTER_NAME='AnIdeaLab brain kit' GIT_COMMITTER_EMAIL='brain-kit@anidealab.com' \
    git -C "$work" commit -q -m "Started this brain from the AnIdeaLab brain kit, $day" >&2 || return 1
  printf '%s\n' "$work"
}

# A brain made on another computer gets the Mac's parts here, in a commit of their own, so the Mac runner has
# its workflow and agents its skill.
# Run again on a brain that has them, it adds only the Mac parts the kit has gained since, and commits only then.
add_mac_parts() {
  if [ -f "$1/skills/my-mac/SKILL.md" ]; then say 'Bringing the Mac parts in your brain up to the kit...'
  else say 'Adding the Mac parts to your brain (the Mac runner workflow, its skill and a note for this Mac)...'; fi
  mac_brain add "$1" || { warn "Couldn't add the Mac parts. Your brain works without them, but agents can't run jobs on this Mac until it has them: ask Claude to add them from the AnIdeaLab brain kit (install/mac-brain)."; return; }
  git -C "$1" add -A
  if git -C "$1" diff --cached --quiet; then return; fi
  git -C "$1" commit -q -m 'Added the Mac parts from the AnIdeaLab brain kit' >/dev/null
  if [ -z "$check" ]; then git -C "$1" push -q origin HEAD >/dev/null 2>&1 || warn "Couldn't send the Mac parts to GitHub yet. Pasting the same command again sends them, and so does Obsidian Git's next sync, if you have Obsidian."; fi
}

# Once the runner is online, the brain records this Mac itself: its row in knowledge/systems/devices.md and
# what it has in the Mac's note, in a commit of their own. Without it, a brain whose owner ran this after their
# session ended said no computer had a runner, though this one worked, until an agent happened to test it.
record_mac() {
  local name host facts
  name=$(scutil --get ComputerName 2>/dev/null || hostname -s)
  host=$(hostname -s)
  facts="macOS $(sw_vers -productVersion), $(sysctl -n hw.model) ($(uname -m)), $(sysctl -n machdep.cpu.brand_string), $(( $(sysctl -n hw.memsize) / 1073741824 )) GB RAM, $(df -H / | awk 'NR == 2 {print $4 " free of " $2}') on its disk"
  python3 - "$1" "$name" "$host" "$facts" "$day" <<'PY' || { warn "Couldn't add this Mac to the brain's list of computers. It works: the first chat adds it."; return; }
import os, re, sys
vault, name, host, facts, day = sys.argv[1:6]
devices = os.path.join(vault, "knowledge", "systems", "devices.md")
if os.path.isfile(devices):
    lines = open(devices, encoding="utf-8").read().split("\n")
    rows = [i for i, l in enumerate(lines) if l.lstrip().startswith("|")]
    if rows and not any("`my-mac`" in lines[i] for i in rows):
        last = rows[0]
        while last + 1 < len(lines) and lines[last + 1].lstrip().startswith("|"):
            last += 1
        cell = lambda t: t.replace("|", "/")
        lines.insert(last + 1, f"| [{cell(name)}](my-mac.md) | The `my-mac` runner (`mac-run.yml`), added by the installer on {day} | "
                               f"While the owner is logged in and it's awake | {cell(facts)} | `my-mac` | `{host}` |")
        open(devices, "w", encoding="utf-8", newline="").write("\n".join(lines))
note = os.path.join(vault, "knowledge", "systems", "my-mac.md")
if os.path.isfile(note):
    text = open(note, encoding="utf-8").read()
    new = re.sub(r"(?m)^\*Not checked yet:.*\*$", f"Recorded by the installer on {day}, when the runner first came online: {name} (`{host}`), {facts}. "
                 "A first job adds what's installed (the my-mac skill's \"The first session\").", text, count=1)
    if new != text:
        open(note, "w", encoding="utf-8", newline="").write(new)
PY
  git -C "$1" add -A knowledge/systems
  if git -C "$1" diff --cached --quiet; then return; fi
  git -C "$1" commit -q -m "This Mac's runner is set up: added it to the brain's devices" >/dev/null
  git -C "$1" push -q origin HEAD >/dev/null 2>&1 || warn "Couldn't send this Mac's row to GitHub yet. Obsidian Git's next sync sends it, or pasting the same command again."
}

# Where the brain comes from (the notes at the top).
if [ -z "$brain" ]; then brain="$(dirname "$here")/brain"; fi
mkdir -p "$root/_logs" 2>/dev/null
[ -f "$brain/CLAUDE.md" ] || die "There's no brain to set up: $brain has no CLAUDE.md."
brain=$(cd "$brain" && pwd)
if [ -z "$check" ] && [ "$(uname -s)" != Darwin ]; then die "This installer is for a Mac. On a Windows PC, paste the PowerShell line from the kit's README instead."; fi
macos=$(sw_vers -productVersion 2>/dev/null)
log "== The installer started, from $brain (${macos:+macOS $macos}${macos:-$(uname -sr)}, bash $BASH_VERSION)"
if [ -z "$check" ] && [ -n "$macos" ] && older_than "$macos" "$macos_min"; then
  die "This Mac has macOS $macos, and the setup needs macOS $macos_min (Monterey) or newer: GitHub's command line doesn't run on older ones. Update macOS (Apple menu, System Preferences, Software Update), then paste the same command again. Your brain still works in the browser without this Mac."
fi
say "Connecting this Mac to your brain: the runner and Obsidian, if you'd like them. Questions show in yellow."

# AnIdeaLab's terms of use, before anything is installed or made. No default: Enter alone asks again, V opens
# the terms in the browser, and anything else but Y stops here.
terms='https://github.com/AnIdeaLab/brain-kit/blob/main/TERMS.md'
if [ -z "$check" ]; then
  printf '\n\033[33m%s\033[0m\n' "AnIdeaLab's terms of use for the brain kit: $terms"
  printf '\033[33m%s\033[0m\n' "Do you accept AnIdeaLab's terms of use? (Y/N)"
  answer=''
  while [ -z "$answer" ]; do
    read -r -p 'Type Y or N, or V to read them in your browser: ' answer || answer=N
    answer=$(trim "$answer")
    case "$answer" in [Vv]*) open "$terms" >/dev/null 2>&1; answer='' ;; esac
  done
  case "$answer" in
    [Yy]*) log 'the terms of use were accepted' ;;
    *)
      log 'the terms of use were not accepted, so nothing was set up'
      printf '\n\033[33m%s\033[0m\n' "You didn't accept the terms, so nothing was set up. To set up later, paste the same line again."
      exit 0 ;;
  esac
fi

# Claude isn't asked about here: nearly everyone runs this from their brain's first chat, so they're in Claude
# already, and a brain made here gets the plan's line in the last step below (22 Nov 2026).

# Obsidian is an extra, so it's asked about, here, before anything is installed: the answer covers the app, its
# Git plugin and the brain in its list of vaults, and a no leaves an Obsidian that's
# already on the Mac alone. Enter is yes. The kit's check answers yes, so it still tries Obsidian's steps.
want_obsidian=''
if yes_to "Would you like Obsidian too? It's a free app that shows your brain as a map on this Mac, where you can read and edit your notes. Your brain works without it, and you can add it later by pasting the same command again."; then want_obsidian=yes; fi
if [ -n "$want_obsidian" ]; then log 'Obsidian: wanted'; else log 'Obsidian: not wanted, so its steps are skipped'; fi

# 1. The tools
if [ -n "$want_obsidian" ]; then tools_step="The tools (Git, GitHub's command line, Obsidian)"; else tools_step="The tools (Git, GitHub's command line)"; fi
step "$tools_step" started
if [ -z "$check" ]; then ensure_git; fi
if [ -z "$check" ] || [ -n "$tools_check" ]; then
  gh=$(find_gh)
  if [ -n "$gh" ]; then
    v=$(gh_version "$gh")
    if [ -z "$v" ] || older_than "$v" "$gh_min"; then
      log "gh ${v:-of no known version} at $gh is older than $gh_min, so the newest goes in $tools"
      say "GitHub's command line on this Mac is old (${v:-its version is unknown}), so the newest goes in beside it, for your brain."
      install_gh; gh=$(find_gh)
    fi
  fi
  if [ -z "$gh" ]; then install_gh; gh=$(find_gh); fi
  if [ -n "$want_obsidian" ]; then
    obsidian_app=$(find_obsidian)
    if [ -z "$obsidian_app" ]; then install_obsidian || true
    else
      v=$(app_version "$obsidian_app")
      if [ -n "$v" ] && older_than "$v" "$obsidian_min"; then
        log "Obsidian $v at $obsidian_app is older than $obsidian_min, so it's replaced by the newest"
        say "Obsidian on this Mac is old ($v), so it's updated to the newest. Your vaults and settings stay."
        install_obsidian "$(dirname "$obsidian_app")" || obsidian_app=$(find_obsidian)
      fi
    fi
  fi
fi
command -v git >/dev/null 2>&1 || die "Git is installed, but this window can't see it yet. Close Terminal, open it again and paste the same command."
python3 -c 'import json' >/dev/null 2>&1 || die "Python 3, which comes with Apple's command line tools, doesn't run. Close Terminal, open it again and paste the same command."
if [ -z "$check" ] && [ -z "$gh" ]; then die "GitHub's command line is installed, but this window can't see it yet. Close Terminal, open it again and paste the same command."; fi
# What the setup goes on with, on screen and in the log, so the brain's agent sees an old version even when
# nothing breaks.
found="macOS ${macos:-unknown}, git $(git --version 2>/dev/null | awk '{print $3}'), python3 $(python3 --version 2>&1 | awk '{print $2}')"
if [ -n "$gh" ]; then found="$found, gh $(gh_version "$gh") at $gh"; fi
if [ -n "$obsidian_app" ]; then found="$found, Obsidian $(app_version "$obsidian_app") at $obsidian_app"; fi
log "this Mac has: $found"
echo "  This Mac has: $found"
step "$tools_step" 'done'

# 2. GitHub
# GitHub's sign-in page opens in the browser used last, not only the Mac's default (Safari on a new Mac), since
# that's the one they're signed in to GitHub with, having just made their brain there (found 26 Nov 2026 on a
# wiped Mac). lsappinfo lists the open apps front to back; the first browser in it wins. Anything odd, and gh
# opens the default as before.
last_browser() {
  lsappinfo visibleProcessList 2>/dev/null | grep -o -E '"(Google Chrome|Safari|Firefox|Arc|Microsoft Edge|Brave Browser|Opera|Vivaldi|Chromium)"' | head -1 | tr -d '"'
}
if [ -z "${BROWSER:-}" ]; then
  b=$(last_browser || true)
  if [ -n "$b" ] && open -Ra "$b" >/dev/null 2>&1; then export BROWSER="open -a \"$b\""; log "GitHub's sign-in opens in $b, the browser used last"; fi
fi
step 'Signed in to GitHub' started
if [ -n "$check" ]; then owner=example; else
  if ! "$gh" auth status --hostname github.com >/dev/null 2>&1; then
    say "Signing in to GitHub. Your one-time code is copied for you: press Enter, and in the page that opens in your browser, press Command+V to paste it. No GitHub account yet? Make one on that page first (it's free)."
    "$gh" auth login --hostname github.com --git-protocol https --web --scopes workflow --clipboard || die "GitHub sign-in didn't finish. Paste the same command again to retry."
  elif ! "$gh" auth status --hostname github.com 2>&1 | grep -q workflow; then
    say 'GitHub needs one more permission (to add the Mac workflow). Your code is copied for you: press Enter, and press Command+V in the page that opens.'
    "$gh" auth refresh --hostname github.com --scopes workflow --clipboard
  fi
  "$gh" auth setup-git --hostname github.com >/dev/null 2>&1
  owner=$("$gh" api user --jq .login 2>/dev/null)
  [ -n "$owner" ] || die "Couldn't read your GitHub user name. Paste the same command again."
  # Git signs each commit with a name and email. GitHub's private address keeps your real email out of the history.
  if [ -z "$(git config --global user.name)" ]; then git config --global user.name "$("$gh" api user --jq '.name // .login')"; fi
  if [ -z "$(git config --global user.email)" ]; then git config --global user.email "$("$gh" api user --jq .id)+$owner@users.noreply.github.com"; fi
fi
step 'Signed in to GitHub' 'done'
log "signed in as $owner"

# 3. Your brain's repo on GitHub
step "Your brain's private repo on GitHub" started
# Every brain has the same name, so there's no question: a new brain from AnIdeaLab's template link gets it
# too, and this finds that one. A brain made before the name was set (or renamed) passes its own name in
# BRAIN_KIT_NAME, in the command its first chat gives: BRAIN_KIT_NAME=<name> /bin/bash -c "$(curl ...)"
name="${BRAIN_KIT_NAME:-my-brain-ail}"
name="${name//[[:space:]]/}"
[[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || die "BRAIN_KIT_NAME has to be your brain's name on GitHub: letters, numbers, dashes, dots and underscores only."
repo="$owner/$name"
vault="$root/$name"
fresh=yes
if [ -z "$check" ]; then
  info=$("$gh" repo view "$repo" --json isEmpty,visibility --jq '.visibility + " " + (.isEmpty | tostring)' 2>/dev/null)
  if [ -z "$info" ]; then
    say "Making your brain, the private repo $repo on GitHub..."
    echo "(Already have a brain with another name? Close this window and ask that brain's chat for its command.)"
    "$gh" repo create "$repo" --private --description "My second brain, started from the AnIdeaLab brain kit" || die "Couldn't make $repo on GitHub."
  else
    case "$info" in PRIVATE*) ;; *) die "$repo is public. A brain has to be private, because the Mac runner lets the repo run commands on this Mac. Make it private on GitHub (its Settings, at the bottom), then paste the command again." ;; esac
    case "$info" in *true) fresh=yes ;; *) fresh='' ;; esac
  fi
fi
step "Your brain's private repo on GitHub" 'done'
log "the repo is $repo"

# 3b. AnIdeaLab's testing account, as the terms of use say. Only for a brain made now, so a run again
# doesn't add it back after you've taken it off. A personal repo has no read-only option.
# Never on the accounts of AnIdeaLab's own people, the members of its GitHub organisation: the testing
# account mustn't reach their repos, or their computers through a runner.
tester='diagnostics-anidealab'
ours=''
if [ -z "$check" ] && [ "$("$gh" api user/memberships/orgs/AnIdeaLab --jq .state 2>/dev/null)" = active ]; then ours=yes; fi
invite_tester() {
  if [ -n "$check" ] || [ -n "$ours" ] || [ "$owner" = "$tester" ]; then return 0; fi
  if "$gh" api -X PUT "repos/$repo/collaborators/$tester" --silent >/dev/null 2>&1; then log 'the testing account was invited'
  else warn "Couldn't invite AnIdeaLab's testing account just now. Your brain doesn't need it; to do it later, paste: gh api -X PUT repos/$repo/collaborators/$tester"; fi
}
if [ -n "$fresh" ] || [ -n "$setup" ]; then invite_tester; fi

# 4. The brain on this Mac, and on GitHub
step "Your brain on GitHub, and your copy in $vault" started
mkdir -p "$root"
if [ -d "$vault/.git" ]; then
  say "Your brain is already on this Mac, in $vault."
  # Brought up to date first, where that changes nothing of yours (a fast-forward only): the runner's setup
  # runs from this copy, and without Obsidian nothing else on the Mac syncs it.
  if [ -z "$check" ]; then
    git -C "$vault" pull --ff-only -q origin main >/dev/null 2>&1
    git -C "$vault" push -u origin main >/dev/null 2>&1
  fi
  add_mac_parts "$vault"
elif [ -n "$fresh" ]; then
  say "Putting the brain in $vault, and on GitHub..."
  made=$(new_brain_repo) || die "Making the brain from $brain failed."
  git clone -q -b main "$made" "$vault" || die 'Unpacking the brain failed.'
  rm -rf "$made"
  git -C "$vault" remote set-url origin "https://github.com/$repo.git"
  if [ -z "$check" ]; then
    git -C "$vault" push -u origin main || die 'Sending the brain to GitHub failed. Paste the same command again to retry.'
    # The setup report, sent quietly: the brain's "Send brain update reports" workflow sends it to the kit's
    # inbox, as it does an update's report. It holds the day it was set up, nothing else (the terms say so).
    report="$vault/knowledge/systems/brain-updates/0000-report.md"
    printf -- '---\nabout: "This brain'"'"'s setup report: the day it was set up from the AnIdeaLab brain kit. Sent to AnIdeaLab'"'"'s inbox."\ntags: [the-brain]\nupdated: %s\n---\n# Setup report\n\nThis brain was set up from the AnIdeaLab brain kit on %s (UTC).\n' "$day" "$day" > "$report"
    git -C "$vault" add -- "$report"
    git -C "$vault" commit -q -m 'Setup report for AnIdeaLab' >/dev/null
    git -C "$vault" push -q origin main >/dev/null 2>&1
  fi
else
  say "$repo already has a brain in it, so this Mac gets a copy of it..."
  git clone -q "https://github.com/$repo.git" "$vault" || die "Copying $repo to this Mac failed."
  # A brain made from the kit's template, with nothing installed, hasn't invited the testing account: no
  # command ran when it was made. Its first setup on a Mac invites it, as the terms say, and only once: the
  # log says when it has, so a run again doesn't add the account back after you've taken it off.
  if grep -q "brain kit's template" "$vault/knowledge/systems/brain-updates/0000-report.md" 2>/dev/null &&
     ! grep -q 'the testing account was invited' "$log_file" 2>/dev/null; then invite_tester; fi
  add_mac_parts "$vault"
fi
step "Your brain on GitHub, and your copy in $vault" 'done'

# 5. The Mac runner
runner_setup="$vault/skills/my-mac/setup-runner.sh"
runner_ok=yes
step 'The Mac runner' started
if [ -z "$check" ]; then
  if yes_to "Set up the Mac runner now, so you can ask Claude to do things on this Mac from any chat, even your phone? It only does what you ask. It runs while you're logged in and needs no password. macOS then says background items were added: that's the runner."; then
    /bin/bash "$runner_setup" --repo "$repo" --root "$root" || runner_ok=''
    # "All done" only once GitHub sees the runner online.
    online=$("$gh" api "repos/$repo/actions/runners" --jq '[.runners[] | select(.status == "online")] | length' 2>/dev/null)
    if ! [ "${online:-0}" -gt 0 ] 2>/dev/null; then runner_ok=''; fi
    if [ -n "$runner_ok" ]; then record_mac "$vault"; step 'The Mac runner' 'done'; else step 'The Mac runner' 'not done'; fi
  else
    step 'The Mac runner' skipped
    echo "Skipped. To set it up later, paste: bash \"$runner_setup\""
  fi
else
  if [ -n "$tools_check" ]; then
    BRAIN_KIT_CHECK="$check" /bin/bash "$runner_setup" --repo "$repo" --root "$root" || die "setup-runner.sh's check of GitHub's runner failed."
  fi
  step 'The Mac runner' skipped
fi

# 6. Obsidian, if it's wanted, with the Git plugin that syncs your edits (its code isn't kept in the repo), after
# the runner, so nothing of Obsidian's comes up in front of the runner's questions. It isn't opened here: the owner
# goes back to their chat, and the agent says how to open it, to choose "Trust author and enable plugins" (what
# Obsidian asks the first time a vault has plugins) and where the brain graph is (the getting-started skill).
# Without Obsidian, the Mac runner brings this copy up to date at the start of each job (mac-run.yml, in the Mac
# parts).
has_obsidian=''
if [ -z "$want_obsidian" ]; then step 'Obsidian, with syncing on' skipped; else
  step 'Obsidian, with syncing on' started
  # The second try, through gh, if Obsidian didn't come in at the tools step.
  if { [ -z "$check" ] || [ -n "$tools_check" ]; } && [ -z "$obsidian_app" ]; then
    obsidian_app=$(find_obsidian)
    if [ -z "$obsidian_app" ]; then install_obsidian || true; fi
  fi
  plugin="$vault/.obsidian/plugins/obsidian-git"
  if { [ -z "$check" ] || [ -n "$tools_check" ]; } && [ ! -f "$plugin/main.js" ]; then
    say 'Adding the Obsidian Git plugin, which syncs your edits with GitHub...'
    mkdir -p "$plugin"
    # Through gh first: GitHub's plain release-download links can answer 504 for hours while gh's route, through
    # its API, works (8 Nov 2026). The plain link stays for when gh isn't there or isn't signed in. main.js is
    # moved in last, because it's what says the plugin is done.
    got_plugin=""
    plugin_tmp=$(mktemp -d)
    if [ -n "$gh" ] && "$gh" release download --repo Vinzent03/obsidian-git --pattern main.js --pattern manifest.json --pattern styles.css --clobber --dir "$plugin_tmp" 2>/dev/null; then got_plugin=yes; fi
    for f in manifest.json styles.css main.js; do
      if [ -z "$got_plugin" ]; then
        curl -fsSL --retry 3 -o "$plugin_tmp/$f" "https://github.com/Vinzent03/obsidian-git/releases/latest/download/$f" ||
          { rm -rf "$plugin_tmp"; die "Couldn't download the Obsidian Git plugin. Check the Mac is online, then paste the same command again."; }
      fi
      mv "$plugin_tmp/$f" "$plugin/$f" || die "Couldn't put the Obsidian Git plugin in $plugin."
    done
    rm -rf "$plugin_tmp"
  fi
  # Add the brain to Obsidian's list of vaults, so it opens straight into it. Obsidian writes the list when it
  # quits, so it's closed first.
  if [ -z "$check" ] && pgrep -x Obsidian >/dev/null 2>&1; then
    quit_obsidian
  fi
  if [ -n "$check" ]; then cfg_dir="$root/obsidian"; else cfg_dir="$HOME/Library/Application Support/obsidian"; fi
  mkdir -p "$cfg_dir"
  python3 - "$cfg_dir/obsidian.json" "$vault" <<'PY' || die "Couldn't add your brain to Obsidian's list of vaults ($cfg_dir/obsidian.json)."
import json, os, random, shutil, sys, time
cfg, vault = sys.argv[1], sys.argv[2]
data = {}
if os.path.isfile(cfg):
    shutil.copyfile(cfg, cfg + ".bak")
    with open(cfg, encoding="utf-8-sig") as f:
        data = json.load(f)
vaults = data.setdefault("vaults", {})
if not any(isinstance(v, dict) and v.get("path") == vault for v in vaults.values()):
    vaults["%016x" % random.getrandbits(64)] = {"path": vault, "ts": int(time.time() * 1000), "open": True}
with open(cfg, "w", encoding="utf-8") as f:
    json.dump(data, f, separators=(",", ":"))
PY
  # Without the app, it's set up for when it comes: a run again installs it.
  if [ -n "$check" ] || [ -n "$obsidian_app" ] || [ -n "$(find_obsidian)" ]; then has_obsidian=yes; fi
  if [ -n "$has_obsidian" ]; then step 'Obsidian, with syncing on' 'done'; else step 'Obsidian, with syncing on' 'not done'; fi
fi

# 7. AnIdeaLab's set-up only: the map, the index's first stage (decided 25 Nov 2026), made here as the owner: folders
# and the past year's documents' names, none opened. It goes to the brain's repo as a private draft release (never
# into the brain's files); the set-up's agent picks what to read from it and the owner's answers, and reads that
# later as a job on this computer's runner (index-computer -Plan). The originals stay where they are.
index_ok=''
if [ -n "$setup" ] && [ -z "$check" ]; then
  step 'Your computer, mapped for your set-up' started
  say "Last, a quick map of this Mac: its folders and the names of the documents you've worked on this past year, so we can pick what to put in your brain. Nothing is opened yet, photos and anything that looks like passwords or keys are left out, and nothing on this Mac is changed or moved. We read what we pick later, in the background."
  indexer="$here/../set-up/index-computer.sh"
  index_work="$root/_intake/computer"
  if [ -f "$indexer" ] && /bin/bash "$indexer" --root "$root" --map && [ -f "$index_work/index.md" ]; then
    pack="${TMPDIR:-/tmp}"; pack="${pack%/}/anidealab-set-up-index.zip"
    rm -f "$pack"
    if (cd "$index_work" && zip -qr "$pack" .); then
      "$gh" release delete anidealab-set-up-index --repo "$repo" --yes >/dev/null 2>&1
      if "$gh" release create anidealab-set-up-index "$pack" --repo "$repo" --draft --title "Your computer's map, for AnIdeaLab's set-up" \
        --notes "A map of your computer: its drives, its folders and the names of the documents you worked on this past year, none of them opened. AnIdeaLab uses it to get its bearings and, only if you asked for your documents to be read, to pick what to read. Only you and AnIdeaLab can see it, and AnIdeaLab deletes it once your brain is set up. Your files stay on your computer."; then index_ok=yes; fi
    fi
    rm -f "$pack"
  fi
  if [ -n "$index_ok" ]; then step 'Your computer, mapped for your set-up' done; else step 'Your computer, mapped for your set-up' 'not done'; fi
fi

show_steps
if [ -z "$want_obsidian" ]; then say 'No Obsidian, as you chose. To add it later, paste the same command again and answer Y to the Obsidian question.'
elif [ -n "$has_obsidian" ] && [ -n "$from_site" ]; then say 'Obsidian is installed and set up on your brain. Your agent tells you how to open it in your first chat.'
elif [ -n "$has_obsidian" ]; then say 'Obsidian is installed and set up on your brain. Your agent tells you how to open it when you go back to your chat.'
else
  echo ''
  warn "Obsidian didn't install, because its download didn't come through. That's usually GitHub, and it usually passes. Your brain is fine without it for now: wait a few minutes, then paste the same command again."
fi
if [ -n "$runner_ok" ]; then say 'All done on this Mac.'; else
  echo ''
  warn "Your brain is set up, but the Mac runner isn't working yet, so agents can't run jobs on this Mac."
  echo "To try it again, paste: bash \"$runner_setup\""
  echo 'Or carry on below, and ask Claude to help get the runner working.'
fi
echo "Your brain on GitHub: https://github.com/$repo"
echo "Your copy on this Mac: $vault"
echo ''
if [ -n "$setup" ]; then
  printf '\033[36m%s\033[0m\n' "That's everything on your side. We'll take it from here, and email you when your brain is ready."
  if [ -z "$index_ok" ]; then echo "(Your Mac didn't get mapped just now. Nothing to do: we'll sort it with you by email.)"; fi
elif [ -n "$from_site" ] && [ -z "$fresh" ]; then
  # From the start page's step 4, before the first chat: back to the page, whose last part is the first message.
  printf '\033[36m%s\033[0m\n' "Last step: go back to anidealab.com/second-brain and send your first message."
elif [ -z "$fresh" ]; then
  # The brain was on GitHub already: made from AnIdeaLab's template, with this run from its first chat (or any
  # chat since), or a run again. So the chat is open, and that's where they go back to.
  printf '\033[36m%s\033[0m\n' "Last step: go back to your chat with your brain and say it's finished."
else
  printf '\033[36m%s\033[0m\n' 'Last step, in Claude:'
  echo '  1. Go to https://claude.ai/code. It needs a paid plan (Pro or above). If it asks, connect GitHub and let Claude see your brain repo.'
  echo "  2. Start a new session with $repo selected."
  echo '  3. Send this message:'
  printf '\033[32m%s\033[0m\n' '       This is my new second brain. Read CLAUDE.md and get me set up.'
fi
exit 0
