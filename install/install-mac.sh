#!/bin/bash
# Sets up your own second brain on this Mac, from the AnIdeaLab brain kit. It asks you to accept AnIdeaLab's
# terms of use (TERMS.md, at the kit repo's root) first, and stops if you don't. It opens Claude in the
# browser, to sign in or sign up for a paid plan (S skips it). Then it installs Apple's
# command line tools (they have Git), GitHub's command line (gh) and Obsidian if they're missing, signs you in
# to GitHub, makes your brain's private repo (inviting AnIdeaLab's testing account to it, as the terms say)
# and puts the brain in it, puts your copy in ~/AI-Brain-Link with Obsidian's syncing on, sets up the Mac
# runner, so AI agents can run jobs on this Mac, and opens Obsidian last. It needs no password: gh and
# Obsidian come from their own releases on GitHub, each checked against its checksum, not from Homebrew.
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
install_obsidian() {
  local tag v dmg tmp want got dest ok
  say 'Installing Obsidian, from its own release on GitHub...'
  tag=$(latest_tag obsidianmd/obsidian-releases) || die "Couldn't find the newest version of Obsidian. Check the Mac is online, then paste the same command again."
  v="${tag#v}"
  dmg="Obsidian-$v.dmg"
  tmp=$(mktemp -d)
  curl -fsSL --retry 3 -o "$tmp/$dmg" "https://github.com/obsidianmd/obsidian-releases/releases/download/$tag/$dmg" || { rm -rf "$tmp"; die "Couldn't download Obsidian ($dmg). Check the Mac is online, then paste the same command again."; }
  want=$(asset_digest obsidianmd/obsidian-releases "$tag" "$dmg")
  got=$(sha256 "$tmp/$dmg")
  if [ -n "$want" ] && [ "$want" != "$got" ]; then rm -rf "$tmp"; die "Obsidian didn't match its checksum, so it wasn't installed. Paste the same command again."; fi
  mkdir -p "$tmp/disk"
  hdiutil attach -nobrowse -noautoopen -readonly -quiet -mountpoint "$tmp/disk" "$tmp/$dmg" </dev/null || { rm -rf "$tmp"; die "Couldn't open Obsidian's disk image."; }
  if [ ! -d "$tmp/disk/Obsidian.app" ] || { [ -z "$want" ] && ! codesign --verify "$tmp/disk/Obsidian.app" 2>/dev/null; }; then
    hdiutil detach "$tmp/disk" -quiet; rm -rf "$tmp"
    die "Obsidian's disk image isn't as it should be, so it wasn't installed. Paste the same command again."
  fi
  if [ -n "$check" ]; then dest="$root/Applications"; elif [ -w /Applications ]; then dest=/Applications; else dest="$HOME/Applications"; fi
  mkdir -p "$dest"
  ditto "$tmp/disk/Obsidian.app" "$dest/Obsidian.app"; ok=$?
  hdiutil detach "$tmp/disk" -quiet || hdiutil detach "$tmp/disk" -force -quiet
  rm -rf "$tmp"
  [ "$ok" -eq 0 ] || die "Couldn't copy Obsidian into $dest."
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
         "- **Mac work goes to the owner's Mac,** through the `my-mac` runner, so needing it never rules a route out (how: the [my-mac skill](skills/my-mac/SKILL.md)).")
    edit("CLAUDE.md", "- **Give the owner a command:**",
         "- **Give the owner a command:** when something has to happen on their Mac, run it through the runner if you can; if they have to do it, give one command to paste into Terminal, not click-by-click steps.")
    rules = "knowledge/decisions/the-brain/{KIT_ISO}-starting-rules.md"
    edit(rules, "- **PC work goes to the owner's PC,**",
         "- **Mac work goes to the owner's Mac,** through a GitHub Actions runner there, so a job that needs their Mac or their apps never rules a route out. How: the [my-mac skill](../../../skills/my-mac/SKILL.md).")
    edit(rules, "- **Give the owner a command:**",
         "- **Give the owner a command:** a task on the owner's computer runs through the runner if it can. If the owner has to do it, they get one command to paste into Terminal, not click-by-click steps, which are slower and easy to get wrong.")
    # The front door, in the owner's words.
    edit("README.md", "- **Obsidian:** this repo is a vault on my PC",
         "- **Obsidian:** this repo is a vault on my Mac, in `~/AI-Brain-Link`, and its graph draws every link between notes ([setup and how to read it](knowledge/systems/obsidian-setup.md)).")
    edit("README.md", "- **My PC:**",
         "- **My Mac:** agents run jobs on it through a GitHub Actions runner while it's on and I'm logged in ([the Mac](knowledge/systems/my-mac.md)). \"AI Brain Link - live jobs\", in my `~/AI-Brain-Link` folder, shows what's running.")
    edit("README.md", "- **Giving it files:**",
         "- **Giving it files:** I put files or folders in `~/AI-Brain-Link/_upload` and tell the agent what to do with them ([the Mac](knowledge/systems/my-mac.md)).")
    skills = len([d for d in os.listdir(os.path.join(work, "skills")) if os.path.isfile(os.path.join(work, "skills", d, "SKILL.md"))])
    with open(os.path.join(work, "README.md"), encoding="utf-8") as f:
        count = re.search(r" \d+ to start,", f.read())
    if count:
        edit("README.md", "- **[The skills](skills/README.md):**", f" {skills} to start,", how="swap", old=count.group(0))
    else:
        problems.append('README.md: no " <number> to start," saying how many skills there are')
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
add_mac_parts() {
  if [ -f "$1/skills/my-mac/SKILL.md" ]; then return; fi
  say 'Adding the Mac parts to your brain (the Mac runner workflow, its skill and a note for this Mac)...'
  mac_brain add "$1" || { warn "Couldn't add the Mac parts. Your brain works without them, but agents can't run jobs on this Mac until it has them: ask Claude to add them from the AnIdeaLab brain kit (install/mac-brain)."; return; }
  git -C "$1" add -A && git -C "$1" commit -q -m 'Added the Mac parts from the AnIdeaLab brain kit' >/dev/null
  if [ -z "$check" ]; then git -C "$1" push -q origin HEAD >/dev/null 2>&1 || warn "Couldn't send the Mac parts to GitHub yet; Obsidian Git sends them at its next sync."; fi
}

# Where the brain comes from (the notes at the top).
if [ -z "$brain" ]; then brain="$(dirname "$here")/brain"; fi
mkdir -p "$root/_logs" 2>/dev/null
[ -f "$brain/CLAUDE.md" ] || die "There's no brain to set up: $brain has no CLAUDE.md."
brain=$(cd "$brain" && pwd)
if [ -z "$check" ] && [ "$(uname -s)" != Darwin ]; then die "This installer is for a Mac. On a Windows PC, paste the PowerShell line from the kit's README instead."; fi
macos=$(sw_vers -productVersion 2>/dev/null)
log "== The installer started, from $brain (${macos:+macOS $macos}${macos:-$(uname -sr)}, bash $BASH_VERSION)"
say 'Setting up your second brain. It takes about 10 minutes, mostly installing. Questions show in yellow.'

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

# Claude, before the installs: making an account and choosing a plan can be done while they run.
if [ -z "$check" ]; then
  say "Your brain works with Claude, in Claude Code. That needs a Claude account on a paid plan (Pro or above): the free plan doesn't include Claude Code. Already signed in on a paid plan? Type S to skip. Otherwise press Enter to open Claude in your browser: sign in, or make an account and choose a plan there. The setup carries on here while you do."
  answer=''
  read -r -p 'Press Enter to open Claude, or type S to skip: ' answer || answer=S
  case "$(trim "$answer")" in
    [Ss]*) log 'Claude: skipped, already set up' ;;
    *) open 'https://claude.ai/code' >/dev/null 2>&1 || echo 'Open https://claude.ai/code in your browser.'; log 'Claude: opened claude.ai/code to sign in or sign up' ;;
  esac
fi

# 1. The tools
step "The tools (Git, GitHub's command line, Obsidian)" started
if [ -z "$check" ]; then ensure_git; fi
if [ -z "$check" ] || [ -n "$tools_check" ]; then
  gh=$(find_gh)
  if [ -z "$gh" ]; then install_gh; gh=$(find_gh); fi
  obsidian_app=$(find_obsidian)
  if [ -z "$obsidian_app" ]; then install_obsidian; fi
fi
command -v git >/dev/null 2>&1 || die "Git is installed, but this window can't see it yet. Close Terminal, open it again and paste the same command."
python3 -c 'import json' >/dev/null 2>&1 || die "Python 3, which comes with Apple's command line tools, doesn't run. Close Terminal, open it again and paste the same command."
if [ -z "$check" ] && [ -z "$gh" ]; then die "GitHub's command line is installed, but this window can't see it yet. Close Terminal, open it again and paste the same command."; fi
step "The tools (Git, GitHub's command line, Obsidian)" 'done'

# 2. GitHub
step 'Signed in to GitHub' started
if [ -n "$check" ]; then owner=example; else
  if ! "$gh" auth status --hostname github.com >/dev/null 2>&1; then
    say "Signing in to GitHub. Copy the code shown below, press Enter, and paste it into the page that opens in your browser. No GitHub account yet? Make one on that page first (it's free)."
    "$gh" auth login --hostname github.com --git-protocol https --web --scopes workflow || die "GitHub sign-in didn't finish. Paste the same command again to retry."
  elif ! "$gh" auth status --hostname github.com 2>&1 | grep -q workflow; then
    say 'GitHub needs one more permission (to add the Mac workflow). Copy the code, press Enter, and paste it in your browser.'
    "$gh" auth refresh --hostname github.com --scopes workflow
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
ask 'A name for your brain on GitHub?' my-brain
name="$answer"
until [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]]; do ask 'Letters, numbers, dashes, dots and underscores only, please' my-brain; name="$answer"; done
repo="$owner/$name"
vault="$root/$name"
fresh=yes
if [ -z "$check" ]; then
  info=$("$gh" repo view "$repo" --json isEmpty,visibility --jq '.visibility + " " + (.isEmpty | tostring)' 2>/dev/null)
  if [ -z "$info" ]; then
    say "Making the private repo $repo on GitHub..."
    "$gh" repo create "$repo" --private --description "My second brain, started from the AnIdeaLab brain kit" || die "Couldn't make $repo on GitHub."
  else
    case "$info" in PRIVATE*) ;; *) die "$repo is public. A brain has to be private, because the Mac runner lets the repo run commands on this Mac. Paste the command again and pick another name." ;; esac
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
if [ -n "$fresh" ] && [ -z "$ours" ] && [ "$owner" != "$tester" ] && [ -z "$check" ]; then
  "$gh" api -X PUT "repos/$repo/collaborators/$tester" --silent >/dev/null 2>&1 ||
    warn "Couldn't invite AnIdeaLab's testing account just now. Your brain doesn't need it; to do it later, paste: gh api -X PUT repos/$repo/collaborators/$tester"
fi

# 4. The brain on this Mac, and on GitHub
step "Your brain on GitHub, and your copy in $vault" started
mkdir -p "$root"
if [ -d "$vault/.git" ]; then
  say "Your brain is already on this Mac, in $vault."
  if [ -z "$check" ]; then git -C "$vault" push -u origin main >/dev/null 2>&1; fi
  add_mac_parts "$vault"
elif [ -n "$fresh" ]; then
  say "Putting the brain in $vault, and on GitHub..."
  made=$(new_brain_repo) || die "Making the brain from $brain failed."
  git clone -q -b main "$made" "$vault" || die 'Unpacking the brain failed.'
  rm -rf "$made"
  git -C "$vault" remote set-url origin "https://github.com/$repo.git"
  if [ -z "$check" ]; then
    git -C "$vault" push -u origin main || die 'Sending the brain to GitHub failed. Paste the same command again to retry.'
    # A setup report, so AnIdeaLab can count new brains: the brain's "Send brain update reports" workflow sends
    # it to the kit's inbox, as it does an update's report. It holds the day it was set up, nothing else.
    say 'Sending AnIdeaLab a setup report (just the date), so it can count new brains...'
    report="$vault/knowledge/systems/brain-updates/0000-report.md"
    printf -- '---\nabout: "This brain'"'"'s setup report: the day it was set up from the AnIdeaLab brain kit. Sent to AnIdeaLab'"'"'s inbox."\ntags: [the-brain]\nupdated: %s\n---\n# Setup report\n\nThis brain was set up from the AnIdeaLab brain kit on %s (UTC).\n' "$day" "$day" > "$report"
    git -C "$vault" add -- "$report"
    git -C "$vault" commit -q -m 'Setup report for AnIdeaLab' >/dev/null
    git -C "$vault" push -q origin main >/dev/null 2>&1
  fi
else
  say "$repo already has a brain in it, so this Mac gets a copy of it..."
  git clone -q "https://github.com/$repo.git" "$vault" || die "Copying $repo to this Mac failed."
  add_mac_parts "$vault"
fi
step "Your brain on GitHub, and your copy in $vault" 'done'

# 5. Obsidian, with the Git plugin that syncs your edits (its code isn't kept in the repo). It opens at the
# end, so it can't come up in front of this window while a question waits behind it.
step 'Obsidian, with syncing on' started
plugin="$vault/.obsidian/plugins/obsidian-git"
if { [ -z "$check" ] || [ -n "$tools_check" ]; } && [ ! -f "$plugin/main.js" ]; then
  say 'Adding the Obsidian Git plugin, which syncs your edits with GitHub...'
  mkdir -p "$plugin"
  for f in manifest.json styles.css main.js; do
    curl -fsSL --retry 3 -o "$plugin/$f.part" "https://github.com/Vinzent03/obsidian-git/releases/latest/download/$f" && mv "$plugin/$f.part" "$plugin/$f" ||
      die "Couldn't download the Obsidian Git plugin. Check the Mac is online, then paste the same command again."
  done
fi
# Add the brain to Obsidian's list of vaults, so it opens straight into it. Obsidian writes the list when it
# quits, so it's closed first.
if [ -z "$check" ] && pgrep -x Obsidian >/dev/null 2>&1; then
  osascript -e 'quit app "Obsidian"' >/dev/null 2>&1
  i=0
  while pgrep -x Obsidian >/dev/null 2>&1 && [ "$i" -lt 10 ]; do sleep 1; i=$((i + 1)); done
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
step 'Obsidian, with syncing on' 'done'

# 5b. The upload point's window and Send to are on Windows only for now. On a Mac, files for the brain go in
# ~/AI-Brain-Link/_upload, and the owner tells an agent (the my-mac skill).
mkdir -p "$root/_upload"
step 'The upload point' skipped
echo "The upload point's window is on Windows only for now. On this Mac, put files for your brain in $root/_upload and tell Claude."

# 6. The Mac runner
runner_setup="$vault/skills/my-mac/setup-runner.sh"
runner_ok=yes
step 'The Mac runner' started
if [ -z "$check" ]; then
  if yes_to "Set up the Mac runner now, so AI agents can run jobs on this Mac? It runs while you're logged in and needs no password. macOS then says background items were added: that's the runner."; then
    /bin/bash "$runner_setup" --repo "$repo" --root "$root" || runner_ok=''
    # "All done" only once GitHub sees the runner online.
    online=$("$gh" api "repos/$repo/actions/runners" --jq '[.runners[] | select(.status == "online")] | length' 2>/dev/null)
    if ! [ "${online:-0}" -gt 0 ] 2>/dev/null; then runner_ok=''; fi
    if [ -n "$runner_ok" ]; then step 'The Mac runner' 'done'; else step 'The Mac runner' 'not done'; fi
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

# 7. Obsidian opens last, so it can't hide a question in this window.
step 'Obsidian opened on your brain' started
if [ -z "$check" ]; then
  link=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$vault")
  open "obsidian://open?path=$link" >/dev/null 2>&1 || open -a "${obsidian_app:-Obsidian}" >/dev/null 2>&1
  sleep 3
fi
step 'Obsidian opened on your brain' 'done'

show_steps
say 'Obsidian is opening your brain. If it asks, choose "Trust author and enable plugins". Then come back to this window for the last step, below.'
if [ -n "$runner_ok" ]; then say 'All done on this Mac.'; else
  echo ''
  warn "Your brain is set up, but the Mac runner isn't working yet, so agents can't run jobs on this Mac."
  echo "To try it again, paste: bash \"$runner_setup\""
  echo 'Or carry on below, and ask Claude to help get the runner working.'
fi
echo "Your brain on GitHub: https://github.com/$repo"
echo "Your copy on this Mac: $vault (open in Obsidian)"
echo "Files for your brain: put them in $root/_upload, and tell Claude."
echo ''
printf '\033[36m%s\033[0m\n' 'Last step, in Claude:'
echo '  1. Go to https://claude.ai/code. If it asks, connect GitHub and let Claude see your brain repo.'
echo "  2. Start a new session with $repo selected."
echo '  3. Send this message:'
printf '\033[32m%s\033[0m\n' '       This is my new second brain. Read CLAUDE.md and get me set up.'

# Last, AnIdeaLab's tutorials page opens in the browser: these steps, and the rest, with a video each.
# It's on anidealab.com once the site's moved there, and on the site's preview address until then.
tutorials='https://anidealab.com/second-brain/tutorials'
if [ -z "$check" ] && ! curl -fsSL --max-time 8 "$tutorials" 2>/dev/null | grep -q 'second-brain/tutorials'; then
  tutorials='https://anidealab-website.vercel.app/second-brain/tutorials'
fi
echo ''
printf '\033[36m%s\033[0m\n' "The tutorials are opening in your browser: these steps with a video, then Obsidian and connecting Google. $tutorials"
if [ -z "$check" ]; then open "$tutorials" >/dev/null 2>&1; fi
exit 0
