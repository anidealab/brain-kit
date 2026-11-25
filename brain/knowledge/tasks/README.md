---
about: "What's in flight: open tasks, who holds them, and what waits on the owner; and a task note's shape and how to check for one first. Read to see what needs doing now, or before you make a task."
updated: {KIT_DATE}
---
# Tasks

The "now" page: one note per piece of work that outlives a session, waits on someone, or is handed on. The board comes first; how a task note is kept is under it.

- **Whoever hands a task out makes its note** and closes it when the work comes back. An agent working alone is its own parent.
- **Holders:** `owner`, `open`, or the session link of the agent holding it.
- **Finished tasks stay here for two weeks,** counted rather than listed, then the weekly tidy-up moves them to `history/`. It also closes tasks that have gone stale. Anything learned in them goes to the library when they close.
- **The board stays short:** an owner's task nobody has touched for a month is listed by name only, until the tidy-up asks them to keep or drop it.

Everything the owner holds: `python3 skills/brain-spec/library.py find --shelf tasks --holder owner`.

<!-- index:start -->
*No open tasks.*
<!-- index:end -->

## A task note is the job's live status
A task note is kept up to date as the work goes, so it always says where the job stands, and a fresh chat can carry on from it alone. It takes the place of the session hand-off: one note that stays true, not a new write-up at each stage that copies the last one's open list. Briefs to agents and their reports stay on the [hand-offs shelf](../handoffs/README.md). To carry a job on in a new chat, the owner pastes its path with "continue": `knowledge/tasks/<task>.md continue`. When to update it, and how two chats share one without writing over each other: the [handoff skill](../../skills/handoff/SKILL.md#when-to-update-a-task-note).

### Its shape
```
---
about: "<the job and where it stands now, in a line>"
tags: [<project or area>]
status: doing
holder: <owner, open, or your session link>
due: <a date, if it has one>
updated: {KIT_DATE}
---
# <The job>

## The ask
## Where it stands
## Next
## Waiting on
## Where everything is
## Decisions
## Watch-outs
## The last messages
## Progress
```
| Part | What it holds | How it changes |
|---|---|---|
| **The ask** | What was asked, in the owner's own words, with the date | Only grows: a later change goes under it, dated, in their words |
| **Where it stands** | First a line saying when and by whom. Then a few lines: what's now true, what's half done and in what state, what isn't done or hasn't been checked | Rewritten in place each time |
| **Next** | The steps left, in order, the one in hand marked, clear enough to start cold | Rewritten in place |
| **Waiting on** | What only the owner can answer or do, one line each with your suggested answer; anything waiting on an agent, someone else or a timer | Rewritten in place; an answered line moves to Decisions |
| **Where everything is** | The repo and branch and whether it's pushed, the files and notes, commits and pull requests, and anything outside the repo: a folder on the owner's PC, a preview's address, a job on the PC runner, an agent still running, its brief | Rewritten in place |
| **Decisions** | Links to the owner's answers on the decisions shelf (their line in the project's `answers.md`, or a decision note), saved there first; the agent's own calls, marked as that | Only grows |
| **Watch-outs** | About this job: what was tried and didn't work, what's easy to get wrong, what not to redo. One about how to do a kind of job goes in that skill's `LESSONS.md` | Only grows |
| **The last messages** | Only when a chat stops mid-conversation: the last exchanges with the owner, word for word, so "yes, send it" still makes sense | Replaced each time; deleted once they're acted on |
| **Progress** | One dated line per stage or chat, signed with the session's link, newest last | Grows; past 10 lines, all but the last 5 move to `history/` (below) |

Skip a part with nothing in it. The top four parts are the status, and they stay short: about a screen. They're rewritten, never stacked, so nobody has to read down a pile of old "next steps" to find the true one. The card's `about` is the same: the job and where it stands now, rewritten as it moves, since it's what the board shows. The whole note stays under about 14 KB; the weekly tidy-up lists one past that.

What's lasting goes on its own shelf first, as it's found, and the task links to it: research and findings to a note on the project's shelf, the owner's answers to the decisions shelf, lessons to the skill. A task holds where the job stands, not what was learned doing it, so nothing is lost when it closes and moves to `history/` ([what goes wrong otherwise](../../skills/brain-spec/SKILL.md#saving-knowledge)). While the job runs, the task is where its status lives; the project's note gives a few lines and links it.

**When Progress passes 10 lines,** keep the last 5. Old lines are where something easily gets lost: "tried X, it failed" written once in Progress and never anywhere else, so the next chat tries X again. So first read the lines you're moving, and put whatever in them is still true into the status, Watch-outs or Decisions. Then move them word for word to the project's `history/` (`<task>-progress.md`), and start Progress with a line saying where they went, so no one takes the five for the whole story. Ask changes the work has already carried out can go with them, with a line under The ask saying where. Moving at 10 down to 5 keeps it to a move every few stages, not every chat.

### Before you make one
Agents tend to make a new note for a job the shelf already holds, or one close to it, and the board fills with half-copies nobody keeps up to date. When they check first they mostly put the job in the right place. So before you make a task note, yours or one for a job you hand out:
1. **Read the board, not the notes:** the index below has each task's summary line. `python3 skills/brain-spec/library.py find --shelf tasks --all --text <word>` finds finished ones too. Open only the few that look close.
2. **If one covers your job, or something like it, fit the job into it:**
   - **Open, or its holder gone quiet:** take it (set `holder`, push), and put the new ask under The ask, dated.
   - **Another chat holds it:** add a Progress line, or take your part as a piece with a note of its own that the holder lists under Next (two chats, one note, below).
   - **The owner holds it:** add what's new to it.
   - **Finished in the last two weeks, and your job carries it on:** reopen it (`status: doing`, a Progress line) rather than start again.
3. **If none fits,** make the new note, and link the close ones under Where everything is, with why it's separate.

Tell the owner in a line which task the job went into, or that it's new.
