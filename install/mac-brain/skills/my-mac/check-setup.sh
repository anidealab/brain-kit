#!/bin/bash
# Checks a second brain's setup on this Mac against the AnIdeaLab brain kit: the tools, the GitHub sign-in,
# the brain's repo and its settings, the Mac runner, your copy of the brain and Obsidian, the installer's last
# run and the Mac's settings. It changes nothing, apart from saving its report. Each line says OK, FIX (with
# what to do, as a command where there is one), NOTE or INFO. The report is saved in ~/AI-Brain-Link and
# copied, so you can paste it into a Claude session on your brain with: Fix what this setup check found.
# With --send it also saves the report in the brain's repo, as knowledge/systems/setup-check.md, so an agent
# can read it there, even before the runner works.
#   bash check-setup.sh [--repo owner/name] [--vault folder] [--send]
# Agents can run it through the runner too (skills/my-mac/SKILL.md). macOS's own bash 3.2.

lines=""
fixes=0
report() {
  local kind="$1" text="$2" todo="$3" colour line
  case "$kind" in OK) colour=32 ;; FIX) colour=31; fixes=$((fixes + 1)) ;; NOTE) colour=33 ;; *) colour=90 ;; esac
  line=$(printf '[%-4s] %s' "$kind" "$text")
  if [ -n "$todo" ]; then line="$line"$'\n'"         -> $todo"; fi
  lines="$lines$line"$'\n'
  printf '\033[%sm%s\033[0m\n' "$colour" "$line"
}
ok() { report OK "$1"; }
fix() { report FIX "$1" "$2"; }
note() { report NOTE "$1" "$2"; }
info() { report INFO "$1"; }
section() { lines="$lines"$'\n'"== $1"$'\n'; printf '\n\033[36m== %s\033[0m\n' "$1"; }
# gh's output, or nothing if gh isn't there, isn't signed in or the call failed.
ghq() { if [ -n "$gh" ]; then "$gh" "$@" 2>/dev/null; fi; }
repo_of() { # the owner/name a GitHub address points at
  if [[ "$1" =~ github\.com[/:]([^/]+/[^/[:space:]]+)$ ]]; then printf '%s' "${BASH_REMATCH[1]%.git}"; fi
}

repo=""; vault=""; send=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --vault) vault="$2"; shift 2 ;;
    --send) send=yes; shift ;;
    *) shift ;;
  esac
done
root="$HOME/AI-Brain-Link"
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export PATH="$root/Tools/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
me=$(whoami)
computer=$(scutil --get ComputerName 2>/dev/null || hostname -s)

section 'This Mac'
info "$computer: $(sysctl -n hw.model 2>/dev/null), $(uname -m), macOS $(sw_vers -productVersion 2>/dev/null), checked as $me on $(date '+%d %b %Y %H:%M')"

# The tools ----------------------------------------------------------------------------------------
section 'Tools'
git=""
if xcode-select -p >/dev/null 2>&1; then
  ok "Apple's developer tools: $(xcode-select -p)"
  if git --version >/dev/null 2>&1; then git=$(command -v git); ok "Git: $(git --version)"
  else fix "Git doesn't run: $(git --version 2>&1 | head -n 1)" 'Ask an agent, with this line'; fi
else
  fix "Apple's command line tools aren't installed, so there's no Git" 'xcode-select --install   (then click Install in the window that opens)'
fi
gh=$(command -v gh)
login=""
if [ -n "$gh" ]; then
  ok "GitHub's command line: $("$gh" --version | head -n 1)"
  if "$gh" auth status --hostname github.com >/dev/null 2>&1; then
    login=$(ghq api user --jq .login)
    ok "gh is signed in to GitHub as $login"
    if ! "$gh" auth status --hostname github.com 2>&1 | grep -q workflow; then note "gh's sign-in can't change workflow files" 'gh auth refresh --hostname github.com --scopes workflow'; fi
  else
    fix "gh isn't signed in to GitHub, so the repo can't be checked from here" 'gh auth login --hostname github.com --git-protocol https --web --scopes workflow'
    gh=""
  fi
else
  fix "GitHub's command line (gh) isn't installed, so the repo can't be checked from here" "Paste the install line from the kit's README again: it installs what's missing"
fi
obsidian=""
for o in /Applications/Obsidian.app "$HOME/Applications/Obsidian.app"; do if [ -d "$o" ]; then obsidian="$o"; break; fi; done
if [ -n "$obsidian" ]; then ok "Obsidian is installed ($obsidian)"; else fix 'Obsidian is not installed' "Paste the install line from the kit's README again: it installs what's missing"; fi

# The runner on this Mac ---------------------------------------------------------------------------
section 'The Mac runner'
runner="$root/_runner"; runner_repo=""; runner_name=""
if [ -f "$runner/.runner" ]; then
  runner_name=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8-sig")).get("agentName", ""))' "$runner/.runner" 2>/dev/null)
  runner_url=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8-sig")).get("gitHubUrl", ""))' "$runner/.runner" 2>/dev/null)
  runner_repo=$(repo_of "$runner_url")
  info "Runner '$runner_name' in $runner, registered to $runner_url"
  svc=$(sed -n 's/^SVC_NAME="\(.*\)"$/\1/p' "$runner/svc.sh" 2>/dev/null | head -n 1)
  if [ -n "$svc" ] && [ -f "$HOME/Library/LaunchAgents/$svc.plist" ]; then
    ok "It's a LaunchAgent ($svc), so it starts when you log in"
    if launchctl list 2>/dev/null | grep -qF "$svc"; then ok 'It is running'
    else fix "It isn't running, so jobs wait in the queue" 'cd ~/AI-Brain-Link/_runner && ./svc.sh start'; fi
  else
    fix "It isn't set up as a LaunchAgent, so it only runs while its window is open" "bash \"$here/setup-runner.sh\""
  fi
  ver=$("$runner/bin/Runner.Listener" --version 2>/dev/null)
  if [ -n "$ver" ]; then info "Runner version $ver (it updates itself)"; fi
else
  fix "No GitHub Actions runner is set up on this Mac, so agents can't run jobs here" "bash \"$here/setup-runner.sh\""
fi

# Which repo is the brain: what you gave, then the brain this script is in, then the runner's repo.
own=$(cd "$here/../.." 2>/dev/null && pwd)
if [ -z "$vault" ] && [ -f "$own/CLAUDE.md" ] && [ -e "$own/.git" ]; then vault="$own"; fi
if [ -z "$repo" ] && [ -n "$vault" ] && [ -n "$git" ]; then repo=$(repo_of "$(git -C "$vault" remote get-url origin 2>/dev/null)"); fi
if [ -z "$repo" ]; then repo="$runner_repo"; fi

# The repo on GitHub -------------------------------------------------------------------------------
section 'The brain on GitHub'
branch="main"; mine=""
if [ -z "$repo" ]; then note "Couldn't tell which repo is the brain" 'Run this again with: --repo owner/name'
elif [ -z "$gh" ]; then note "Can't check $repo on GitHub without gh signed in"
else
  r=$(ghq api "repos/$repo" --jq '[.private, .permissions.admin, .default_branch] | map(tostring) | join(" ")')
  if [ -z "$r" ]; then fix "GitHub doesn't show $repo to $login" 'Check the name, and that this GitHub account owns it'
  else
    read -r is_private is_admin branch <<EOF
$r
EOF
    info "Repo https://github.com/$repo"
    if [ "$is_private" = true ]; then ok 'It is private'; else fix "It is public: anyone can read the brain, and a runner on a public repo isn't safe" "gh repo edit $repo --visibility private --accept-visibility-change-consequences"; fi
    if [ "$is_admin" = true ]; then ok 'You are its admin'; else note "You aren't its admin, so some settings can't be checked"; fi
    if [ "$branch" != main ]; then note "Its main branch is called $branch; the kit uses main"; fi
    if [ -n "$runner_repo" ] && [ "$runner_repo" != "$repo" ]; then fix "The runner on this Mac is registered to $runner_repo, not $repo" "Set it up again from the brain's copy: bash \"$here/setup-runner.sh\""; fi
    enabled=$(ghq api "repos/$repo/actions/permissions" --jq .enabled)
    if [ "$enabled" = false ]; then fix "GitHub Actions is off for the repo, so nothing can run on the Mac" "gh api -X PUT repos/$repo/actions/permissions -F enabled=true"
    elif [ "$enabled" = true ]; then ok 'GitHub Actions is on'; fi
    runners=$(ghq api "repos/$repo/actions/runners" --jq '.runners[] | .name + "|" + .status + "|" + ([.labels[].name] | join(", "))')
    if [ -z "$runners" ]; then fix 'No runner is registered to the repo' "bash \"$here/setup-runner.sh\""; fi
    labelled=""
    while IFS='|' read -r n s l; do
      [ -n "$n" ] || continue
      if [ "$s" = online ]; then ok "Runner '$n' is online (labels: $l)"; else fix "Runner '$n' is $s (labels: $l)" 'Is that computer on, awake and logged in, with its runner running?'; fi
      case ", $l," in *", my-mac,"*) labelled=yes ;; esac
      if [ "$n" = "$runner_name" ]; then mine=yes; fi
    done <<EOF
$runners
EOF
    if [ -n "$runner_name" ] && [ -z "$mine" ] && [ "$runner_repo" = "$repo" ]; then fix "This Mac's runner ('$runner_name') isn't registered on GitHub any more" "bash \"$here/setup-runner.sh\""; fi
    collaborators=$(ghq api "repos/$repo/collaborators" --jq '.[].login')
    others=""
    for c in $collaborators; do
      if [ "$c" = "$login" ]; then continue; fi
      # AnIdeaLab's testing account, which the installer invites to a new brain, as the kit's terms say.
      if [ "$c" = diagnostics-anidealab ]; then info "AnIdeaLab's testing account ($c) can see and change it, to test the kit; the installer invited it. To take it off: the repo's Settings, Collaborators"; continue; fi
      others="$others $c"
    done
    if [ -n "$others" ]; then note "Others can write to it ($others ), and anyone who can write can run commands on this Mac through the runner" "Remove them in the repo's Settings, Collaborators, unless you'd trust them with your Mac"
    elif [ -n "$collaborators" ]; then ok 'Nobody else has access to it'; fi
    workflows=$(ghq api "repos/$repo/contents/.github/workflows" --jq '.[].name')
    if printf '%s\n' "$workflows" | grep -qx 'mac-run.yml'; then
      ok 'mac-run.yml lets agents run a command on the Mac'
      if [ -n "$runners" ] && [ -z "$labelled" ]; then fix "mac-run.yml waits for a runner labelled my-mac, and no runner on the repo has that label, so its jobs would queue forever" "bash \"$here/setup-runner.sh\""; fi
    else
      fix 'No mac-run.yml, so agents have no way to run jobs on the Mac' "Paste the install line from the kit's README again: it adds the brain's Mac parts"
    fi
    if printf '%s\n' "$workflows" | grep -qx 'library.yml'; then ok 'library.yml rebuilds the knowledge indexes on each push'; else note 'No library.yml, so the knowledge indexes update only when an agent runs library.py build'; fi
    secrets=$(ghq api "repos/$repo/actions/secrets" --jq '[.secrets[].name] | join(", ")')
    if [ -n "$secrets" ]; then info "Actions secrets, names only: $secrets"; else info 'No Actions secrets yet; keys get added when a job needs one'; fi
  fi
fi

# Your copy of the brain, and Obsidian -------------------------------------------------------------
section 'Your copy of the brain, and Obsidian'
if [ -z "$vault" ] && [ -n "$repo" ] && [ -d "$root/${repo##*/}/.git" ]; then vault="$root/${repo##*/}"; fi
obs_cfg="$HOME/Library/Application Support/obsidian/obsidian.json"
if [ -z "$vault" ]; then
  if [ -n "$repo" ]; then fix "Couldn't find your copy of the brain on this Mac" "git clone https://github.com/$repo.git \"$root/${repo##*/}\"   then in Obsidian: Open folder as vault, and pick that folder"
  else note "Couldn't find a copy of the brain on this Mac" 'Run this again with: --vault <folder>'; fi
else
  info "Your copy: $vault"
  case "$vault" in *"Mobile Documents"*|*Dropbox*|*CloudStorage*|*OneDrive*) fix "It's inside a synced folder (iCloud, Dropbox or OneDrive), and two sync systems on one git folder can corrupt it" "Clone it again into $root and open that copy in Obsidian instead" ;; esac
  if [ -n "$git" ]; then
    st=$(git -C "$vault" status --porcelain -b 2>&1); code=$?
    if printf '%s' "$st" | grep -q 'dubious ownership'; then fix "Git refuses this folder ('dubious ownership'), so Obsidian can't sync it" "sudo chown -R $me \"$vault\"   (it asks for your Mac password)"
    elif [ "$code" -ne 0 ]; then fix "Git can't read it: $(printf '%s' "$st" | head -n 1)" 'Ask an agent, with this line'
    else
      u=$(git -C "$vault" remote get-url origin 2>/dev/null)
      if [ -n "$repo" ] && [ "$(repo_of "$u")" != "$repo" ]; then fix "It syncs with $u, not $repo" "git -C \"$vault\" remote set-url origin https://github.com/$repo.git"
      elif [ -n "$u" ]; then ok "It syncs with $u"; fi
      changed=$(printf '%s\n' "$st" | grep -vc '^##')
      if [ "$changed" -gt 0 ]; then note "$changed file(s) changed here and not yet synced" 'Obsidian Git syncs them every 10 minutes while Obsidian is open'; fi
      if [ -n "$gh" ] && [ -n "$repo" ]; then
        remote=$(ghq api "repos/$repo/commits/$branch" --jq .sha)
        local_head=$(git -C "$vault" rev-parse HEAD 2>/dev/null)
        if [ -n "$remote" ] && [ "$remote" = "$local_head" ]; then ok 'It matches GitHub'
        elif [ -n "$remote" ]; then note "It isn't at the same commit as GitHub" "Obsidian Git catches up while Obsidian is open; or: git -C \"$vault\" pull"; fi
      fi
    fi
    if [ -z "$(git config --global user.name)" ] || [ -z "$(git config --global user.email)" ]; then fix "Git doesn't know your name and email, so commits from Obsidian fail" 'git config --global user.name "Your Name"; git config --global user.email "you@users.noreply.github.com"'; fi
    helper=$(git config --get-all credential.https://github.com.helper 2>/dev/null | tr '\n' ' ')
    if [ -n "$(printf '%s' "$helper" | tr -d ' ')" ]; then info "Git signs in to GitHub with: $helper"; else note "Git has no GitHub sign-in of its own, so Obsidian's pushes may ask for one" 'gh auth setup-git --hostname github.com'; fi
  fi
  plugins="$vault/.obsidian/plugins"
  enabled=$(cat "$vault/.obsidian/community-plugins.json" 2>/dev/null)
  if [ ! -f "$plugins/obsidian-git/main.js" ]; then
    fix "The Obsidian Git plugin isn't installed in this vault, so edits don't sync" "gh release download --repo Vinzent03/obsidian-git --pattern main.js --pattern manifest.json --pattern styles.css --clobber --dir \"$plugins/obsidian-git\""
  elif ! printf '%s' "$enabled" | grep -q '"obsidian-git"'; then fix "The Obsidian Git plugin is switched off, so the vault doesn't sync" 'In Obsidian: Settings, Community plugins, and switch on Git'
  else ok 'The Obsidian Git plugin is installed and on, so edits sync'; fi
  if [ -f "$plugins/brain-graph/main.js" ]; then
    if printf '%s' "$enabled" | grep -q '"brain-graph"'; then ok 'The brain graph is installed and on'; else note 'The brain graph is installed but switched off' 'In Obsidian: Settings, Community plugins, and switch on Brain graph'; fi
  fi
  if python3 -c 'import json,sys; v=json.load(open(sys.argv[1])).get("vaults", {}); sys.exit(0 if any(x.get("path") == sys.argv[2] for x in v.values()) else 1)' "$obs_cfg" "$vault" 2>/dev/null; then ok 'Obsidian has it as a vault'
  else fix "Obsidian hasn't opened this folder as a vault" "In Obsidian: Open folder as vault (from the vault list), and pick $vault"; fi
fi

# The installer's last run: it keeps a log of each step, so a setup that stopped partway shows here.
install_log="$root/_logs/install.log"
if [ -s "$install_log" ]; then
  section "The installer's last run"
  from=$(grep -n '^[^ ]* [^ ]*  == ' "$install_log" | tail -n 1 | cut -d: -f1)
  last=$(tail -n +"${from:-1}" "$install_log")
  info "It last ran $(printf '%s\n' "$last" | head -n 1 | cut -c1-16)"
  why=$(printf '%s\n' "$last" | sed -n 's/^[^ ]* [^ ]*  stopped: //p' | tail -n 1)
  # Each step's last state, in the order the steps started.
  states=$(printf '%s\n' "$last" | sed -En 's/^[^ ]+ [^ ]+  (started|done|skipped|not done)  (.*)$/\1|\2/p')
  names=$(printf '%s\n' "$states" | cut -d'|' -f2 | awk 'NF && !seen[$0]++')
  left=0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    state=$(printf '%s\n' "$states" | awk -F'|' -v n="$name" '$2 == n {s = $1} END {print s}')
    if [ "$state" = started ] || [ "$state" = 'not done' ]; then
      left=$((left + 1))
      if [ "$state" = started ]; then
        if [ -n "$why" ]; then what="It stopped at this step: $name ($why)"; else what="It stopped at this step: $name, with no error, so its window was probably closed while it waited"; fi
      else what="This step didn't finish: $name"; fi
      case "$name" in *runner*) todo="bash \"$here/setup-runner.sh\"" ;; *) todo="Paste the install line from the kit's README again: it skips what is already done" ;; esac
      note "$what" "$todo"
    fi
  done <<EOF
$names
EOF
  if [ "$left" -eq 0 ]; then ok 'It finished every step (skipped ones aside)'; fi
fi

# Mac settings ---------------------------------------------------------------------------------------
section 'Mac settings'
if launchctl list 2>/dev/null | grep -q 'com.anidealab.brain-keep-awake'; then ok "It doesn't sleep while it's on the charger and you're logged in (the keep-awake helper is on)"
elif pmset -g custom 2>/dev/null | awk '/^AC Power/ {ac = 1} /^Battery Power/ {ac = 0} ac && $1 == "sleep" {print $2}' | grep -qx 0; then ok "It doesn't sleep while it's on the charger"
else note "It sleeps while on the charger, and jobs wait while it's asleep" "bash \"$here/setup-runner.sh\"   (it asks to keep the Mac awake on the charger)"; fi
if [ -f "$root/AI Brain Link - live jobs.command" ]; then ok "\"AI Brain Link - live jobs\" is in $root"; else note "No \"AI Brain Link - live jobs\" in $root" 'setup-runner.sh adds it; it shows what agents run, live'; fi
if [ -d "$root/_logs" ]; then ok "The jobs' log folder is there ($root/_logs)"; else fix "There's no $root/_logs, where the Mac workflow writes its logs" "mkdir -p \"$root/_logs\""; fi
if [ -d "$root/_upload" ]; then ok "The folder for giving the brain files is there ($root/_upload)"; else note "No $root/_upload, the folder for giving the brain files" "mkdir -p \"$root/_upload\""; fi
info "Disk: $(df -H / | awk 'NR == 2 {print $4 " free of " $2}')"

# The report ---------------------------------------------------------------------------------------
section 'Summary'
if [ "$fixes" -gt 0 ]; then info "$fixes thing(s) to fix, marked FIX above."; else info 'Nothing to fix.'; fi
out="$root/setup-check.txt"
[ -d "$root" ] || out="${TMPDIR:-/tmp}/brain-setup-check.txt"
printf '%s' "$lines" > "$out" && echo "Saved to $out"
copied=""
if printf '%s' "$lines" | pbcopy 2>/dev/null; then copied=yes; fi
if [ -n "$send" ]; then
  # Into the repo through GitHub's API, so it needs gh signed in but not the runner or this Mac's copy.
  sent=""
  if [ -n "$gh" ] && [ -n "$repo" ]; then
    path='knowledge/systems/setup-check.md'
    old=$(ghq api "repos/$repo/contents/$path" --jq .sha)
    req="${TMPDIR:-/tmp}/brain-setup-check.json"
    python3 - "$out" "$computer" "$old" > "$req" <<'PY'
import base64, json, sys
from datetime import datetime, timezone
text, computer, old = open(sys.argv[1], encoding="utf-8").read(), sys.argv[2], sys.argv[3]
now = datetime.now(timezone.utc)
day = f"{now.day} {now:%b %Y}"
md = (f'---\nabout: "The latest setup check of {computer}, sent by check-setup.sh --send. Read when fixing the Mac, the runner or Obsidian."\n'
      f"tags: [the-brain]\nupdated: {day}\n---\n# Setup check of {computer}\n\n```\n{text.rstrip()}\n```\n")
body = {"message": f"Setup check of {computer}", "content": base64.b64encode(md.encode()).decode()}
if old:
    body["sha"] = old
print(json.dumps(body))
PY
    sent=$(ghq api -X PUT "repos/$repo/contents/$path" --input "$req" --jq .commit.sha)
    rm -f "$req"
  fi
  if [ -n "$sent" ]; then printf '\033[32m%s\033[0m\n' "Sent to the brain: $path in $repo"
  else printf '\033[33m%s\033[0m\n' "Couldn't send it to the brain's repo (gh signed in? which repo?), so paste it instead."; fi
fi
echo ''
if [ -n "$copied" ]; then printf '\033[36m%s\033[0m\n' 'The report is copied. To get help fixing it, start a Claude session on your brain at claude.ai/code, press Cmd+V and add: Fix what this setup check found.'; fi
exit 0
