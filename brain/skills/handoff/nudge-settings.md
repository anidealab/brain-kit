# The nudge's note
For whoever changes the hand-off nudge, or works where it doesn't run. Agents doing ordinary work don't need this: the nudge's own message says what to do, and the [handoff skill](SKILL.md#at-the-nudge) has the steps. The nudge is the only word on a conversation's size, so its marks live here, not in what agents read every day: an agent told the marks keeps telling the owner how much room is left, which only pulls attention onto it (since brain update 12).

## The marks
**A chat's:** 300,000 tokens, and again at 325,000 and each extra 25,000. A token is a word or part of a word: about how much the agent reads. From 400,000 the nudge is urgent, and after 500,000 every message the owner sends comes with a reminder to start a fresh chat.

**A sub-agent's:** at 300,000 tokens, again at each extra 25,000, and urgent from 400,000. A long agent's work loses detail the same way, and its report has to fit back into the chat. Sizing the job first ([guide mode](../guide-mode/SKILL.md)) stays the main way work is split; this is the safety net for when a job turns out bigger than you thought.

## In every cloud chat, whatever its repos
Claude Code loads the brain's hooks from `.claude/settings.json` only in a chat that starts in the brain's folder. A claude.ai/code chat that starts with two or more repos starts in the folder above them (`/home/user`), and one that attaches a project's repo partway through moves there; either way the brain's hooks stop, and with them the nudge. So the cloud environment's setup script, [cloud-setup.sh](cloud-setup.sh), writes the nudge's hooks into the home folder's settings (`~/.claude/settings.json`), which Claude Code reads wherever the chat is, and with two or more repos the start-up reminders too. A chat that loads both copies is still nudged once: the script remembers its marks by session. Keep the brain's own hooks in `.claude/settings.json` as they are: they're the catch for a chat whose environment never got the setup script, and they work whenever it starts in the brain's folder and attaches nothing. It needs nothing from the network, so the environment's usual settings are enough. It runs each time a fresh cloud machine is built for a chat, so it works from the next new chat.

**Setting it up** is one approval, in the first chat ([getting-started](../getting-started/SKILL.md)) or with brain update 12: in a claude.ai/code chat, call the environment tool's `get_environment`, then `update_environment` with this file's text as `setup_script` (`script_change` "adds a setup script", or "replaces the existing setup script" with the script already there kept above this one), and the `environment_name` and `applies_to` it gave. Tell the owner in one line first: "One tap to approve: it keeps the brain's settings working in every chat, whatever you attach." The owner approves it in the app; nothing changes if they don't. Where there's no such tool (Claude Code on their own computer, which opens in the brain's folder and loads its hooks anyway, or another AI tool), skip it. If they say no, don't ask again.

## By hand, where no hook runs
Anywhere the hook can't run (another AI tool, an agent with no hooks), notice it yourself and hand off the same way (the core's "not tied to one AI provider"). Signs a conversation is long: the tool shows how full its memory is, warns, or starts summarising earlier turns; many long tool outputs, logs or file reads; hours of back-and-forth. In Claude Code you can measure it: `python3 skills/handoff/nudge.py --size <the session's .jsonl log>` (the logs are in `~/.claude/projects/`) prints the size in tokens, and a sub-agent's log, in the session's `subagents/` folder, works the same way. At about 300,000 (the same if you're an agent the chat handed work to), or the first time the tool warns or summarises, hand off: bring the job's task note up to date, or write your report. Say nothing about the size before then.

## The nudge's settings
Hooks in `.claude/settings.json` run [nudge.py](nudge.py) after each tool call (`PostToolUse`), when the agent finishes an answer (`Stop`) and when the owner sends a message (`UserPromptSubmit`). It reads the hook's input, takes the conversation's size from the newest main-thread assistant message in the session's log (its input, cache-write and cache-read tokens added up), and when that passes a mark it hasn't nudged for, hands the agent the message: as added context after a tool call or with the owner's message, or by keeping a finished answer going. It remembers which marks a session has had in a small file in the temp folder, named by the session's id. Inside a sub-agent, whose hook input carries `agent_id`, it measures that agent's own conversation instead, after each of its tool calls: from `agent_transcript_path` if the input gives it, or else from the log Claude Code keeps beside the session's, `<the session's log without .jsonl>/subagents/agent-<agent_id>.jsonl`, where every line is marked `isSidechain`. It remembers a sub-agent's marks in a file of its own, named by the session's and the agent's ids. It stays silent on a `Stop` already continuing because of a stop hook (`stop_hook_active`), and on any error it prints nothing and exits 0, so it can't break a chat. The hooks run through bash (on Windows, Git Bash, which comes with Git), trying `python3`, then `python`, as the session-start hook does, and doing nothing if neither is there: a claude.ai/code chat has Python, and a Claude Code chat on the owner's PC needs it installed.

The policy is in [nudge.json](nudge.json), not the code, so it can change without touching the script:

| Setting | What it does | This brain's |
|---|---|---|
| `first_at` | Tokens at the first nudge; 0 turns the nudge off | 300000 |
| `repeat_every` | Tokens between later nudges; 0 means one only | 25000 |
| `urgent_at` | From this size on, nudges use `urgent_message`; 0 means never | 400000 |
| `every_prompt_after` | From this size on, every message the owner sends gets `prompt_message` (the `UserPromptSubmit` hook); 0 means never | 500000 |
| `agent_at` | Tokens in a sub-agent's own conversation at its first nudge, `agent_message`; 0 means never | 300000 |
| `agent_repeat_every` | Tokens between a sub-agent's later nudges; 0 means one only | 25000 |
| `agent_urgent_at` | From this size on, a sub-agent's nudges use `agent_urgent_message`; 0 means never | 400000 |
| `tell_person` | `true` also shows the message to the owner in Claude Code; off, since it's written for the agent, who tells the owner in plain words | false |
| `state_dir` | Where it remembers the marks; empty means the temp folder | empty |
| `message`, `urgent_message`, `prompt_message`, `agent_message`, `agent_urgent_message` | What it says; `{size}` and `{mark}` are filled in | |

The owner can change any of these: save it as a decision ([brain spec](../brain-spec/SKILL.md#saving-knowledge)), then change `nudge.json`. To check a change, pipe made-up hook input in, with a made-up session id so no real chat's nudge is used up:
```
echo '{"session_id":"test-1","transcript_path":"<a .jsonl log>","hook_event_name":"PostToolUse"}' | python3 skills/handoff/nudge.py
```
For a sub-agent's nudge, add `"agent_id":"test-agent"` and `"agent_transcript_path":"<its .jsonl log>"`. `--settings <file>` tries other settings.
