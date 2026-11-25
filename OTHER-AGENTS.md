# A brain with an agent other than Claude

For agents setting up an AnIdeaLab brain for an owner who uses Codex, Gemini, Cursor, GitHub Copilot, ChatGPT or another agent instead of Claude. These are guidelines, not exact steps for each tool: work out the details for yours, and ask the owner where you need to.

A brain is plain Markdown in a private GitHub repo, so any agent that can read and write a GitHub repo can work in it. The kit is free under AnIdeaLab's [terms of use](TERMS.md); tell the owner in a line.

## 1. Make the brain
The owner needs a free GitHub account. Then either:
- **The no-install way:** the owner opens [this link](https://github.com/new?template_owner=AnIdeaLab&template_name=second-brain&name=my-brain-ail&visibility=private), signs in, and presses "Create repository", left on Private. That makes `my-brain-ail` from the template, AnIdeaLab/second-brain.
- **On their computer:** the kit's one command makes the brain and puts a copy on their PC or Mac, with Git, GitHub's command line, and the runner and Obsidian if they want them ([README.md](README.md#on-your-computer-if-you-like) has the commands). Its Claude sign-in step can be skipped.

## 2. Give your agent the brain
Your agent needs to read and write the repo:
- **An agent in the terminal or an editor** (Codex CLI, Gemini CLI, Cursor, Copilot, Aider and the like): clone the repo, or use the copy the command made (`C:\AI-Brain-Link\my-brain-ail` on a PC, `~/AI-Brain-Link/my-brain-ail` on a Mac), and work in that folder. It pushes to GitHub with the owner's sign-in.
- **A cloud agent** (Codex in the cloud, Jules, Copilot's coding agent and the like): connect it to GitHub and give it access to `my-brain-ail`.
- **A chat app** (ChatGPT, Gemini and the like): it needs a GitHub connection that can write as well as read. Without one it can only read, and the brain works much better with an agent that can write.

## 3. Point your agent at the core
`CLAUDE.md` is the brain's core, the one note every agent reads first, whatever the agent. Claude reads it by itself; other agents read their own file. Add the one yours reads, in the brain's top folder, saying only to read `CLAUDE.md` first and follow it as the core:
- `AGENTS.md`: Codex, Cursor, Copilot, Jules, Aider and most others.
- `GEMINI.md`: Gemini CLI.
- `.github/copilot-instructions.md`: GitHub Copilot in an editor.

For a chat app, put the same line in its custom instructions or the project's instructions. Commit and push the file.

## 4. Do by hand what Claude Code does by itself
The brain is written so any agent can do everything; a few things Claude Code does for itself:
- **At the start of a session the owner began,** run `python3 skills/brain-spec/reminders.py` and tell them what's due (`.claude/settings.json` runs it for Claude Code).
- **In a long conversation,** hand on to a fresh one as the [handoff skill](brain/skills/handoff/SKILL.md) says, without waiting for a nudge (`skills/handoff/nudge.py` gives Claude Code that nudge).
- **Skills** are plain folders under `skills/`, each a `SKILL.md`. Open `skills/README.md` and read the one a job needs; nothing has to be installed.
- **Jobs on GitHub's machines or the owner's computer** run as GitHub Actions workflows, started with a GitHub tool or GitHub's command line (`gh workflow run`). Any agent with that access can use them.
- Where a note says "Claude", read it as you, the owner's agent, and a "Claude Pro plan" as whatever plan the owner's agent needs.

## 5. Get the owner started
Start a session in the brain and send:

```
This is my new second brain. Read CLAUDE.md and get me set up.
```

The core sends the agent to the getting-started skill, which asks the owner a few questions and sets everything up from there.
