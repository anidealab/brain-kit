---
about: "What's in flight: open tasks, who holds them, and what waits on the owner; and a task note's shape, when to update it, and how two chats share one. Read to see what needs doing now, or before you make, update or carry on a task."
updated: {KIT_DATE}
---
# Tasks

The "now" page: one note per piece of work that outlives a session, waits on someone, or is handed on.

- **Whoever hands a task out makes its note** and closes it when the work comes back. An agent working alone is its own parent. Where the job stands is in the note itself (below).
- **Holders:** `owner`, `open`, or the session link of the agent holding it.
- **Finished tasks stay here for two weeks,** counted rather than listed, then the weekly tidy-up moves them to `history/`. It also closes tasks that have gone stale. Anything learned in them goes to the library when they close.

Everything the owner holds: `python3 skills/brain-spec/library.py find --shelf tasks --holder owner`.

## A task note is the job's live status
A task note is kept up to date as the work goes, so it always says where the job stands, and a fresh chat can carry on from it alone. It takes the place of the session hand-off: one note that stays true, not a new write-up at each stage that copies the last one's open list. Briefs to agents and their reports stay on the [hand-offs shelf](../handoffs/README.md). To carry a job on in a new chat, the owner pastes its path with "continue": `knowledge/tasks/<task>.md continue`.

### Its shape
```
---
about: "<what the job is and where it stands, in a line or two>. Read before <when>."
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
| **Decisions** | The owner's, in their words with a link to the decision note; the agent's own calls, marked as that | Only grows |
| **Watch-outs** | What was tried and didn't work, what's easy to get wrong, what not to redo | Only grows |
| **The last messages** | Only when a chat stops mid-conversation: the last exchanges with the owner, word for word, so "yes, send it" still makes sense | Replaced each time; deleted once they're acted on |
| **Progress** | One dated line per stage or chat, signed with the session's link, newest last | Only grows, a line at the end |

Skip a part with nothing in it. The top four parts are the status, and they stay short: about a screen. They're rewritten, never stacked, so nobody has to read down a pile of old "next steps" to find the true one. When Progress passes about 20 lines, move the older ones word for word to the project's `history/` and say where they went. What's lasting (a decision, a fact, a lesson) still goes on its own shelf first, and the task links to it.

### When to update it
- **When the job starts,** if it will outlive the chat, wait on someone or be handed on: make the note, with the ask and the plan as Next. Set `holder` to your session link and push that first, so the board shows the job is taken.
- **When a stage or a piece that works is finished:** rewrite Where it stands and Next, and add one Progress line, in the same push as the work.
- **When the owner decides something or changes the ask:** their words go in then, not at the end.
- **When something starts waiting,** on the owner, an agent or a timer, or stops waiting.
- **Before you stop, whatever the reason:** the end of the chat, the size nudge, the owner's plan running out, the owner leaving. Add The last messages if the talk is mid-way.
- **When it's done or dropped:** the status, a last Progress line, and what was learned saved to the library.
- **Not** after every reply or tool call. A job finished in one go needs no task note at all.

Each update also changes the card: `status`, `holder`, `updated`, and `about` when where it stands has moved.

### Two chats, one note
There's no lock and nothing in the middle keeping order: git is the only thing every chat shares, so these rules are what keep two chats from writing over each other.
- **One holder writes the status.** Only the chat named in `holder` rewrites the top four parts and Where everything is. To take a job, set `holder` to yourself and push that alone before you start. If the push is refused because another chat just took it, it's theirs.
- **Everyone else only adds.** A chat that isn't the holder adds one line at the end of Progress (or under The ask, if the owner said it to them), and touches nothing else.
- **A second chat on the same job gets a piece, with a note of its own.** The holder lists the piece under Next with a link; the other chat holds that note, and the holder folds it in when the piece is done. Two chats never share one status.
- **Pull, edit, push, in one go.** `git pull --rebase` right before you edit the note, commit only that file (`git commit -- <path>`), and push at once. Never leave it edited and unpushed while you work.
- **If the rebase clashes:** keep both sides' Progress lines, in time order. In the status the holder's text stands, and the other side's facts become a Progress line. Nothing either side wrote is dropped.
- **A holder that's gone quiet:** if the holder is a chat and the note hasn't changed for two days (`git log -1 --format=%cs -- <path>`), take it over and say so in Progress.

<!-- index:start -->
*No open tasks.*
<!-- index:end -->
