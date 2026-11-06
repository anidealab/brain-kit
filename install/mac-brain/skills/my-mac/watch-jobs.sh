#!/bin/bash
# Live view of what agents run on this Mac through the runner (mac-run.yml).
# Each job writes ~/AI-Brain-Link/_logs/mac-run-<run id>.log: the command, then its output.
# This window follows the newest log as it grows, and moves to a new job's log when one starts.
# Closing it stops only the watching. Installed as ~/AI-Brain-Link/Tools/watch-jobs.sh, opened by
# "AI Brain Link - live jobs" in ~/AI-Brain-Link. macOS's own bash 3.2.
logs="${1:-$HOME/AI-Brain-Link/_logs}"
printf '\033]0;AI Brain Link - live jobs\007'
printf '\033[36m%s\033[0m\n' "Watching $logs. Jobs from GitHub show up here as they run."
printf '\033[36m%s\033[0m\n' "Full history: your brain's repo on GitHub, the Actions tab, 'Run on my Mac'."
current=""
follower=""
trap '[ -n "$follower" ] && kill "$follower" 2>/dev/null; exit 0' INT TERM HUP EXIT
while :; do
  newest=$(ls -t "$logs"/mac-run-*.log 2>/dev/null | head -n 1)
  if [ -n "$newest" ] && [ "$newest" != "$current" ]; then
    if [ -n "$follower" ]; then kill "$follower" 2>/dev/null; wait "$follower" 2>/dev/null; fi
    current="$newest"
    printf '\n\033[33m===== %s =====\033[0m\n' "$(basename "$current")"
    tail -n +1 -f "$current" &
    follower=$!
  fi
  sleep 2
done
