---
about: "Every computer this brain can use: how agents reach each, when it's on, what it's good for, and how to tell which one you're on and which are on now. Read before picking where a job runs, or when a session starts somewhere new."
tags: [the-brain]
updated: {KIT_DATE}
---
# Devices

One row per computer a session can run on or send work to, so any agent can tell where it is, what it can reach, and which computers are on. Each computer can have its own note for the detail, like [the PC's](my-pc.md); this is the list to pick from.

- **Which one you're on:** the session-start script prints it in one line (`python3 skills/brain-spec/devices.py here`). It matches this computer's name against the "Spot it" column, so keep that right.
- **Which are on now:** `python3 skills/brain-spec/devices.py status`, about a minute (a second or two when no computer is set up; `--ping` checks anyway). It sends a tiny job to each computer's runner, cancels any that isn't picked up in time, and prints a table: on (with what the computer has now: system, GPU and how busy, disks, uptime, and its clock's time zone, flagged when it isn't the owner's in routines.md), on and busy (with the job it's running), or off. No key is needed. With only a run-workflow tool, start "Which devices are on" (`devices.yml`) on `main` with the label left empty, and read its log.
- **Adding or changing one:** the [brain spec's "Devices"](../../skills/brain-spec/SKILL.md#devices). The kit's installer adds the owner's computer once its runner is online, and the first session checks the row once its runner answers ([getting-started](../../skills/getting-started/SKILL.md), step 4). A runner with no row here still shows in `status`, as not in this note: add its row then.

| Device | Ways in | On when | Good for | Runner | Spot it |
|---|---|---|---|---|---|
| Cloud sessions (claude.ai/code) | Where most sessions run, started from the owner's phone or computer | Always | Code, notes, research, GitHub, light builds. Linux, no GPU, none of the owner's files or apps; wiped when the session ends, so push your work | — | `cloud` |

## Other machines, without a row of their own
- **GitHub's own machines** (`ubuntu-latest`): the workflows that use this brain's keys run there. A free GitHub account has a limited number of minutes a month on them for a private repo, so nothing loops or runs often there.
