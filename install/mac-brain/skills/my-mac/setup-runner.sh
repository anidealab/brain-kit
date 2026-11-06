#!/bin/bash
# Sets up the Mac runner for this brain, or sets it up again: GitHub's Actions runner, registered with
# this brain's repo under the label my-mac, running as a LaunchAgent under your own account, so AI agents
# can run jobs on this Mac while it's on and you're logged in.
#   bash skills/my-mac/setup-runner.sh [--repo owner/name] [--root ~/AI-Brain-Link]
# It needs no password, and GitHub's command line (gh) signed in, which the installer did. Safe to run
# again. How agents use the runner: skills/my-mac/SKILL.md. macOS's own bash 3.2.
# With BRAIN_KIT_CHECK set (the kit's own test on GitHub's Macs), it downloads GitHub's runner and checks
# it, then stops before registering it.

say() { printf '\n\033[36m%s\033[0m\n' "$1"; }
fail() { printf '\n\033[31m%s\033[0m\n' "Something went wrong: $1"; exit 1; }
yes_to() {
  local a
  printf '\n\033[33m%s\033[0m\n' "$1"
  read -r -p 'Type Y or N, or press Enter for Y: ' a
  case "$a" in [Nn]*) return 1 ;; *) return 0 ;; esac
}
sha256() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else openssl dgst -sha256 -r "$1" | cut -d' ' -f1; fi
}

# All in a function, so bash has read the whole script before it runs any of it.
main() {
  local repo="" root="$HOME/AI-Brain-Link" check="${BRAIN_KIT_CHECK:-}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --repo) repo="$2"; shift 2 ;;
      --root) root="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  local here brain url
  here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  # The jobs get the PATH this runs with (the runner saves it in _runner/.path), so the kit's tools and
  # Homebrew's, if there is one, go on it first.
  export PATH="$root/Tools/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
  local gh
  gh=$(command -v gh) || fail "GitHub's command line (gh) isn't installed. Run the brain's installer first (the one line in the AnIdeaLab brain kit's README)."

  # The brain's repo: the one this copy of the brain syncs with (this script is two folders down in it).
  if [ -z "$repo" ]; then
    brain=$(cd "$here/../.." && pwd)
    url=$(git -C "$brain" remote get-url origin 2>/dev/null)
    if [[ "$url" =~ github\.com[/:]([^/]+/[^/]+)$ ]]; then repo="${BASH_REMATCH[1]%.git}"; fi
  fi
  if [ -z "$repo" ] && [ -z "$check" ]; then read -r -p "Your brain's repo on GitHub, as owner/name: " repo; fi
  [ -n "$repo" ] || [ -n "$check" ] || fail "There's no repo to register the runner with."

  local runner="$root/_runner"
  mkdir -p "$runner" "$root/_logs" "$root/Tools" || fail "Couldn't make $runner."

  # 1. GitHub's runner, from its own release, checked against the checksum GitHub lists for it.
  if [ ! -x "$runner/config.sh" ]; then
    local plat tag v file tmp want got
    if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ]; then plat=osx-arm64; else plat=osx-x64; fi
    tag=$("$gh" api repos/actions/runner/releases/latest --jq .tag_name 2>/dev/null)
    [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Couldn't find the latest version of GitHub's runner ('$tag'). Check the internet connection and that gh is signed in (gh auth status), then run this again."
    v="${tag#v}"
    file="actions-runner-$plat-$v.tar.gz"
    say "Downloading GitHub's runner $v..."
    tmp=$(mktemp -d)
    curl -fsSL --retry 3 -o "$tmp/$file" "https://github.com/actions/runner/releases/download/$tag/$file" || fail "Couldn't download GitHub's runner. Check the internet connection and run this again."
    want=$("$gh" api "repos/actions/runner/releases/tags/$tag" --jq ".assets[] | select(.name == \"$file\") | .digest" 2>/dev/null)
    want="${want#sha256:}"
    if [ -z "$want" ]; then # the release's notes list each file's checksum too
      want=$("$gh" api "repos/actions/runner/releases/tags/$tag" --jq .body 2>/dev/null | grep -F "$file" | grep -Eo '[0-9a-f]{64}' | head -n 1)
    fi
    got=$(sha256 "$tmp/$file")
    if [ -z "$want" ] || [ "$want" != "$got" ]; then rm -rf "$tmp"; fail "GitHub's runner didn't match its checksum, so it wasn't installed. Run this again."; fi
    tar -xzf "$tmp/$file" -C "$runner" || fail "Couldn't unpack GitHub's runner into $runner."
    rm -rf "$tmp"
  fi
  if [ -n "$check" ]; then
    local ver
    ver=$("$runner/bin/Runner.Listener" --version 2>/dev/null)
    [ -n "$ver" ] || fail "GitHub's runner is in $runner, but it doesn't start on this Mac."
    echo "Check mode: GitHub's runner $ver is downloaded, checked and starts here. It wasn't registered."
    return 0
  fi
  cd "$runner" || fail "Couldn't open $runner."

  # 2. Registered with the brain's repo, under the label my-mac, with a token gh gets and never shows.
  local name token rt state i
  name=$(scutil --get LocalHostName 2>/dev/null || hostname -s)
  if [ -f .runner ]; then
    say 'Removing the old registration first...'
    if [ -f .service ]; then ./svc.sh uninstall >/dev/null 2>&1; fi
    rt=$("$gh" api -X POST "repos/$repo/actions/runners/remove-token" --jq .token 2>/dev/null)
    if [ -n "$rt" ]; then ./config.sh remove --token "$rt" >/dev/null 2>&1; fi
    rt=""
    # GitHub had already forgotten it, or the removal failed: clear it here.
    rm -f .runner .credentials .credentials_rsaparams .service
  fi
  token=$("$gh" api -X POST "repos/$repo/actions/runners/registration-token" --jq .token 2>/dev/null)
  [ -n "$token" ] || fail "GitHub didn't hand over a runner token for $repo. Check the repo is yours and that gh is signed in (gh auth status)."
  say "The runner runs as you ($(whoami)), so it can reach your files and apps."
  ./config.sh --unattended --url "https://github.com/$repo" --token "$token" --name "$name" --labels my-mac --work _work --replace
  local ok=$?
  token=""
  if [ "$ok" -ne 0 ] || [ ! -f .runner ]; then fail "The runner couldn't be registered. Ask an agent, and say what this window showed."; fi

  # 3. A LaunchAgent, so it starts whenever you log in. One left from an earlier setup goes first, since
  # the runner's svc.sh won't make one where its file already is.
  local svc
  svc=$(sed -n 's/^SVC_NAME="\(.*\)"$/\1/p' svc.sh 2>/dev/null | head -n 1)
  if [ -n "$svc" ] && [ -f "$HOME/Library/LaunchAgents/$svc.plist" ]; then
    launchctl unload "$HOME/Library/LaunchAgents/$svc.plist" >/dev/null 2>&1
    rm -f "$HOME/Library/LaunchAgents/$svc.plist"
  fi
  ./svc.sh install || fail "The runner is registered, but its LaunchAgent couldn't be made. Ask an agent, and say what this window showed."
  ./svc.sh start || fail "The runner's LaunchAgent didn't start. Ask an agent, and say what this window showed."

  # 4. The live jobs window, as a file to double-click in ~/AI-Brain-Link. Not on the desktop: writing
  # there makes macOS ask whether Terminal may use the Desktop folder.
  say "Adding \"AI Brain Link - live jobs\" to $root, to watch jobs as they run..."
  cp "$here/watch-jobs.sh" "$root/Tools/watch-jobs.sh" && chmod +x "$root/Tools/watch-jobs.sh"
  local live="$root/AI Brain Link - live jobs.command"
  printf '#!/bin/bash\n# Opens the live jobs window: what agents run on this Mac, as it runs.\nexec /bin/bash "%s"\n' "$root/Tools/watch-jobs.sh" > "$live" && chmod +x "$live"

  # 5. No sleep on the charger, through a LaunchAgent that holds caffeinate -s, which needs no password.
  if yes_to "Keep this Mac awake while it's on the charger, so jobs can run? The screen still turns off as usual, and closing the lid still puts it to sleep."; then
    local plist="$HOME/Library/LaunchAgents/com.anidealab.brain-keep-awake.plist"
    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.anidealab.brain-keep-awake</string>
  <key>ProgramArguments</key><array><string>/usr/bin/caffeinate</string><string>-s</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict>
</plist>
PLIST
    launchctl unload "$plist" >/dev/null 2>&1
    if launchctl load -w "$plist"; then echo "Done: it doesn't sleep while it's on the charger and you're logged in."; fi
  fi

  # 6. Done only once GitHub sees the runner online, so nobody is told it worked when it didn't.
  state=""
  i=0
  while [ "$i" -lt 12 ] && [ "$state" != online ]; do
    sleep 5
    state=$("$gh" api "repos/$repo/actions/runners" --jq ".runners[] | select(.name == \"$name\") | .status" 2>/dev/null | head -n 1)
    i=$((i + 1))
  done
  if [ "$state" != online ]; then
    if [ -n "$state" ]; then state="it says $state"; else state="it isn't listed"; fi
    fail "The runner is installed, but GitHub doesn't see it online yet ($state). Run this again, or ask an agent, and say what this window showed."
  fi
  printf '\n\033[32m%s\033[0m\n' "The Mac runner '$name' is set up, and GitHub sees it online."
  echo "It starts when you log in, so agents can run jobs while this Mac is on and you're logged in."
}

main "$@"
