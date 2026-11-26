# Brain hooks: run the brain's hand-off nudge (and, with 2+ repos, its start-up
# reminders) whatever folder the session starts in or moves to.
B=""; N=0
for d in */; do
  [ -d "$d.git" ] && N=$((N+1))
  [ -z "$B" ] && [ -f "${d}skills/handoff/nudge.py" ] && B="$PWD/${d%/}"
done
if [ -n "$B" ]; then
  mkdir -p "$HOME/.claude"
  python3 - "$B" "$N" "$HOME/.claude/settings.json" <<'EOF'
import json, sys
b, n, path = sys.argv[1], int(sys.argv[2]), sys.argv[3]
try:
    s = json.load(open(path))
except Exception:
    s = {}
h = s.setdefault("hooks", {})
def add(event, cmd, matcher=None):
    entry = {"hooks": [{"type": "command", "command": cmd, "timeout": 10}]}
    if matcher:
        entry["matcher"] = matcher
    have = [x.get("command") for e in h.get(event, []) for x in e.get("hooks", [])]
    if cmd not in have:
        h.setdefault(event, []).append(entry)
nudge = f'python3 "{b}/skills/handoff/nudge.py" 2>/dev/null || true'
add("PostToolUse", nudge, "*")
add("Stop", nudge)
add("UserPromptSubmit", nudge)
if n > 1:
    add("SessionStart", f'python3 "{b}/skills/brain-spec/reminders.py" 2>/dev/null || true', "startup")
json.dump(s, open(path, "w"), indent=2)
EOF
fi
