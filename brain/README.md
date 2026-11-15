# My second brain

AI agents working on my projects, and everything they know, kept as plain Markdown notes that any agent can read and I can read anywhere. It was started on {KIT_DATE} from the AnIdeaLab brain kit, and it has three parts:

- **[The core](CLAUDE.md):** the one page every agent reads: what the brain is, guide mode, my defaults and the few gates (money, secrets, the sign-off, my voice).
- **[The skills](skills/README.md):** how to do things, one folder per skill: 68 to start, and more whenever a job needs one.
- **[The knowledge library](knowledge/README.md):** what the brain knows, on shelves: tasks, hand-offs, ventures, areas, decisions, people, systems, ideas and subjects. Every note starts with a one-line card saying what's in it and when to read it.

## What waits on me
The **[tasks index](knowledge/tasks/README.md)** is the "now" page: everything in flight, with what waits on me at the top.

## Seeing it
- **On GitHub:** every note is a page of this repo, in a browser or on my phone.
- **Obsidian,** if I've added it: this repo is a vault on my PC, in `C:\AI-Brain-Link`, and its graph draws every link between notes ([setup and how to read it](knowledge/systems/obsidian-setup.md)).
- **The brain graph:** the brain icon in Obsidian's left ribbon replays the brain growing from its git history ([how to read it](knowledge/systems/brain-graph.md)).

## Working with it
- **Start a session** at [claude.ai/code](https://claude.ai/code) with this repo selected, one session per job. Agents check a plan with me before bigger jobs (guide mode).
- **My PC,** if I've added its runner: agents run jobs on it through a GitHub Actions runner whenever it's on ([the PC](knowledge/systems/my-pc.md)). The "AI Brain Link - live jobs" window on my desktop shows what's running.
- **Giving it files:** in a chat, I attach them. With the brain on my PC, I right-click files or folders and pick Send to, then My brain, and tell the agent what to do with them ([the upload point](knowledge/systems/upload-point.md)).
- **Brain updates:** AnIdeaLab sends fixes and new parts. The weekly tidy-up tells me what each one does, and applies it only if I say go ([brain updates](knowledge/systems/brain-updates/README.md)).
- **Keys** for services go in this repo's Actions secrets, never in a chat: the agent gives me one command to paste, which opens the page that makes the key and saves it there ([keys and accounts](knowledge/systems/keys-and-accounts.md)).
- **Extras:** Obsidian and the PC runner are extras, and the brain works without them. To add one, I ask an agent, which gives me one command to paste ([the first session's step 4](skills/getting-started/SKILL.md#4-the-owners-computer)).
