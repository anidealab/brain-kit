---
name: handoff
description: "How any agent in this brain hands work on. To a fresh chat: the job's task note, kept up to date as the work goes (it took the place of the session hand-off at brain update 6), brought up to date at the end of a stage or at the hand-off nudge, and its path given to the owner to paste only when a new chat is due (the nudge, a chat stopping, or they ask), not at every stage. To an agent: a brief, and a report back (at the end of its work, or at its own nudge), on the hand-offs shelf. Saving what's lasting first, what to do at the nudge, and how to start from a task note or an old hand-off. Use whenever you hand a job on, brief an agent, report back, get the nudge, or are given a task's or hand-off's path."
---

# Hand-offs
One way for every agent and sub-agent to hand work on, saved in the brain so the coordinator, or any later session, can pick it up, and that always says where everything is.

**Why it matters.** Everything said in a conversation is read again on every reply, so a long conversation uses more of the owner's plan with each turn, gets slower, and in the end gets summarised, which loses detail. A note saved in the brain doesn't. The next chat or agent starts clean, reads one note, and carries on.

**Why the task note.** A job used to get a new session hand-off at each stage and each nudge, each copying the last one's open list, so finding where a job really stood meant reading down a trail of them. Now each job has one note whose status is rewritten as the work moves, so it's always true and always in the same place. There are no new session hand-offs.

It's plain Markdown and git, so any agent can follow it. The nudge is a Claude Code hook (a setting that makes Claude Code run a small script at set moments, like after each tool call): a shortcut. How it works, its settings, how it reaches every cloud chat, and handing off by hand where no hook runs are in [the nudge's note](nudge-settings.md), for whoever changes the nudge or works without one.

## Three ways work is handed on
| What | From and to | Where it lives |
|---|---|---|
| The task note | This chat to a fresh one, or to whoever picks the job up | The [tasks shelf](../../knowledge/tasks/README.md), one note per job, updated as the work goes |
| A brief | A coordinator to an agent | The [hand-offs shelf](../../knowledge/handoffs/README.md), `kind: brief` |
| A report | An agent back to its coordinator | The hand-offs shelf, `kind: report` |

## The task note
Its shape is on the tasks shelf's page ([a task note is the job's live status](../../knowledge/tasks/README.md#a-task-note-is-the-jobs-live-status)); when to update it and how two chats share one are [below](#when-to-update-a-task-note). In short:
- **Check the board before making one:** if a task already covers the job or something like it, fit the job into that one ([how](../../knowledge/tasks/README.md#before-you-make-one)).
- **The status is rewritten, never stacked:** Where it stands, Next, Waiting on and Where everything is always say what's true now.
- **The record only grows:** the ask in the owner's words, decisions, watch-outs, and a dated Progress line per stage or chat.
- **Update it** when the job starts, when a stage or a working piece is finished, when the owner decides something, when something starts waiting, and before you stop for any reason.
- **One holder writes the status;** any other chat only adds a Progress line, or takes a piece with a note of its own.

No task note is needed for a job finished in one go with nothing left for anyone (git has the change), or for a quick search or read whose answer goes straight into your work.

There's no length limit and no checker: some jobs need more written down than others, and the agent is trusted to judge. Decide what each job needs, and skip a part that has nothing in it.

## When to update a task note
- **When the job starts,** if it will outlive the chat, wait on someone or be handed on: check the board first ([how](../../knowledge/tasks/README.md#before-you-make-one)), then make the note, with the ask and the plan as Next. Set `holder` to your session link and push that first, so the board shows the job is taken.
- **When a stage or a piece that works is finished:** rewrite Where it stands and Next, and add one Progress line, in the same push as the work.
- **When the owner decides something or changes the ask:** their words go in then, not at the end.
- **When something starts waiting,** on the owner, an agent or a timer, or stops waiting.
- **Before you stop, whatever the reason:** the end of the chat, the size nudge, the owner's plan running out, the owner leaving. Add The last messages if the talk is mid-way.
- **When it's done or dropped:** the status, a last Progress line, and what was learned saved to the library.
- **Not** after every reply or tool call. A job finished in one go needs no task note at all.

Each update also changes the card: `status`, `holder`, `updated`, and `about` when where it stands has moved. When Progress passes 10 lines, save what's still true in the old ones, then move all but the last 5 ([how](../../knowledge/tasks/README.md#its-shape)).

### Two chats, one note
There's no lock and nothing in the middle keeping order: git is the only thing every chat shares, so these rules are what keep two chats from writing over each other.
- **One holder writes the status.** Only the chat named in `holder` rewrites the top four parts and Where everything is. To take a job, set `holder` to yourself and push that alone before you start. If the push is refused because another chat just took it, it's theirs.
- **Everyone else only adds.** A chat that isn't the holder adds one line at the end of Progress (or under The ask, if the owner said it to them), and touches nothing else.
- **A second chat on the same job gets a piece, with a note of its own.** The holder lists the piece under Next with a link; the other chat holds that note, and the holder folds it in when the piece is done. Two chats never share one status. Once a job runs in several chats at once, make it a project page early, in its project's folder: the phases, a task each, where everything is, and what the owner has settled. Each chat's progress goes on its phase's task, and the owner's own task stays one current list that answered items leave; otherwise hand-offs pile up, the owner's task swells, and an agreed piece gets lost between chats.
- **Pull, edit, push, in one go.** `git pull --rebase origin main` right before you edit the note, commit only that file (`git commit -- <path>`), and push at once. Never leave it edited and unpushed while you work.
- **If the rebase clashes:** keep both sides' Progress lines, in time order. In the status the holder's text stands, and the other side's facts become a Progress line. Nothing either side wrote is dropped.
- **A holder that's gone quiet:** if the holder is a chat and the note hasn't changed for two days (`git log -1 --format=%cs -- <path>`), take it over and say so in Progress.

## Save what's lasting first
Before you bring the task note up to date, or write a brief or a report, put what should outlive the job where it belongs, as the [brain spec](../brain-spec/SKILL.md#saving-knowledge) says: the owner's answers on the decisions shelf (a line in the project's `answers.md`, or a note of its own for a big choice), research and facts in their notes, lessons about a kind of job in its skill's `LESSONS.md`, friction in the friction log, and jobs still to do as tasks of their own (the owner's with `holder: owner`). The task note links to them rather than copying them. So it stays short, the brain stays the memory, and a later chat finds a fact on its shelf, not buried in a finished task.

## At the end of a stage, or when a chat has to stop
A big job runs in stages ([guide mode](../guide-mode/SKILL.md)). At the end of each, and whenever a chat has to stop before the work is done (the owner leaving, their plan's limit coming):
1. **Save what's lasting** (above).
2. **Bring the task note up to date:** rewrite its status, add a Progress line, and add The last messages, word for word, if the talk with the owner is mid-way. Cut long tool output, never the owner's words.
3. **Commit and push** it: `git pull --rebase origin main`, run `python3 skills/brain-spec/library.py build`, commit only your paths (`git commit -- <paths>`), and push to `main`. A note only on your disk hands nothing on.
4. **Tell the owner** in a few plain lines where things stand. No carry-on line here: the stage's end updates the note quietly, and the line comes only when a new chat is due (below).

## At the nudge
In Claude Code, a hook tells you when the conversation has grown long enough to hand off, and again if it carries on; later ones are urgent. Until it comes, there's nothing to watch or tell the owner about the conversation's size: the nudge is the only word on it, and saying how much room is left only pulls attention onto it. Then:
1. **Finish what you're doing.** It's a nudge, not a hard stop. Bring the step you're on to a safe point (a change that works, a message sent, an answer the owner is waiting for), but don't start a new piece. When it's urgent, stop at the first safe point.
2. **Save what's lasting,** and **bring the task note up to date,** with the last messages word for word. If the job has no task note yet, make one now. If the conversation covers more than one job, update each one's note.
3. **Commit and push** it.
4. **Tell the owner,** in a few plain lines: where things stand, why a fresh chat helps (it goes further on their plan and keeps the detail), and the task note's path to paste into a new chat with "continue" or whatever they want to say. Give it ready to paste, the way "Telling the owner" below says:
   ```
   knowledge/tasks/shop-website.md continue
   ```
5. **Then it's their call:** start the new chat, or carry on here. If you carry on, keep the task note up to date as usual, and push it at the next nudge and before the chat ends.

### Telling the owner
**When to give it:** only when a new chat is actually due: at the nudge, when a chat has to stop with work left (the owner leaving, a usage limit coming), when a job ends with something left for a later chat, when it's a brief they'll run themselves, or when they ask. Not at every check-in or the end of every stage: the task note is still brought up to date there, quietly, and the line waits until it's needed, so the owner isn't asked to start a new chat over and over.

Whenever you do tell the owner a fresh chat can carry on from a file, give the line as a code block on its own, like the one above: the file's path from the brain's top folder as plain text, then "continue". The chat app puts a copy button on a code block, so it pastes straight into a new chat. Never a link, a clickable file reference or a path inside a sentence: a link only opens the file, which doesn't start anything.

The agent never moves the owner to a new chat by itself, and nothing starts up on its own: the owner pastes the path. The pasted path says exactly which job, even with several chats going.

## Starting from a task note
When someone gives you a task's path, the owner pasting it or a coordinator in a brief:
1. **Pull** (`git pull --rebase origin main`), so you have it.
2. **Read the core, the task note, and what its Where everything is names for the next step.** Nothing else up front; open more only when the work needs it.
3. **Take it:** set `holder` to your session link and `status: doing`, add a Progress line, `**Picked up** {KIT_DATE}, by <your session link>`, and commit and push that alone, so the board shows it's taken and no second chat starts on it too. If the holder is another chat, check it's really idle first (in a cloud session, your app's session tool, like `get_session` with its id; or the time of its last push on the job's branches): a note saying what's lost "if the chat ends" doesn't mean it has. If it's still at work, don't take it, or two chats do the same work: ask the owner which carries on, add a Progress line, or ask for a piece with a note of its own.
4. **Check what moved since it was last updated** (`git log --since=<its date> --oneline`), then carry on from its Next. If the owner said more than "continue", their words come first, and go under The ask.
5. **Delete The last messages** once you've acted on them.

**Given an old session hand-off's path** (a note with `kind: session` on the hand-offs shelf, from before brain update 6): read it the same way, mark it `picked-up`, move where it stands into the job's task note (making one if there's none), and mark the hand-off `done`. From then on the task note is the status. Old ones stay on the shelf as the record until the weekly tidy-up moves them to `history/`.

## Briefs and reports
The chat the owner talks to is the coordinator, and the agents it hands work to are its helpers, each in a clean thread of its own, and each hands its work back to the coordinator in a hand-off of its own. When to hand work to an agent at all, and how many at once, is in the brain spec ([handing work to an agent](../brain-spec/SKILL.md#handing-work-to-an-agent)).
- **A brief** is a hand-off with `kind: brief`, saved on the shelf and pushed; give the agent its path, with a line on the job in the prompt. Cut it to what the agent needs, add the gates that bear on the job, and say what to send back: a report on the shelf, and its path. The agent can't ask the owner, so put in what it would ask. Agents given too much spend their whole budget reading and build nothing, so:
  - **One job a brief** (two at most in big code files), with the facts it needs written in rather than a list of files to read, line ranges rather than whole files, sized well inside its nudge, and pushing each piece as it's made. For a big area (about 20 notes or more), the survey and the rewrites go to separate agents, or the one agent stops at the survey and reports, and the rewriters are told not to survey again.
  - **One light check, then the report,** and say that's the end of it: the build or tests and a look at the main states, for the agent itself. No round of screenshots for the owner, who looks at the work themselves; long check rounds hit the usage limit before the report.
  - **A research brief asks for a short answer:** a brief comparison and one pick from what's quick to find; deeper tests only when the owner asks.
  - **Fresh eyes get the owner's words and the material,** never your own picks, and the brief keeps the agent off notes and commits that hold them, or it finds your ideas again.
  - **Agents side by side echo each other** (the same example business, the same names): tell each what the others are using, and read across their work before it ships.
  - **An agent in a worktree of its own** has a guard that refuses what it can't prove stays inside it: here-documents, `git -C <path>`, `cd <path> && git`, `git -c`, and clones outside the worktree or the scratchpad. So the brief names a scratchpad path for side clones, says to write files with the write tool and run plain git from inside each checkout, and has it test on `main` or a branch it can delete.
- **A report** is a hand-off with `kind: report` and `before` naming the brief. The agent saves it on the shelf, commits only its own paths, pushes, and sends back its path and a few lines as its last message. An agent that can't write files sends the report itself, and the coordinator saves it.
- **The coordinator** reads the report, checks the work once the normal way, saves what's lasting, and marks the brief and the report `done`.
- **The board** is the shelf's own index: the open and picked-up hand-offs, newest first, rebuilt by `library.py build`. A coordinator reads it to see what's in flight, not every hand-off.
- **The coordinator's own task note,** brought up to date at the nudge like any chat's, also says what's in flight (agents running, briefs out) under Where everything is and Waiting on.

**What goes in a brief or a report,** each part only if it has something in it: the ask (the coordinator's, with the owner's words where they set it); where it stands, and the next step; where everything is: the repo and branch and whether it's pushed, files, commits, and anything outside the repo, like a folder on the owner's PC (`C:\AI-Brain-Link\...`), a preview's address or a job on the PC runner; decisions made and who made them; open questions; what to read first, in order; and watch-outs. A brief links the job's task note; the agent adds a Progress line to it only if the brief says so, since the coordinator holds it.

**Its card and where it goes:** one note each on the hand-offs shelf, `knowledge/handoffs/`, named with the date and what it's about, `{KIT_ISO}-shop-website-brief.md`:
```
---
about: "Brief: <the work>, for <who>. Read to do it."
tags: [<project or area>]
kind: brief
status: open
before: <file name of the brief a report answers, or the report a new brief carries on from, if any>
updated: {KIT_DATE}
---
```
`kind` is `brief` or `report` (`session` only on notes from before brain update 6). Statuses: `open` when written, `picked-up` once someone starts from it, `done` once its work is finished; whoever does each step changes it. Save it where anyone can get it: pull, run `python3 skills/brain-spec/library.py build`, commit only your paths, and push to `main`.

## The sub-agent nudge
An agent you hand work to (a sub-agent) gets nudges of its own, by its own conversation's size. A long agent's work loses detail the same way, and its report has to fit back into the chat. Sizing the job first ([guide mode](../guide-mode/SKILL.md)) stays the main way work is split; this is the safety net for when a job turns out bigger than you thought.
- **The agent, at its nudge:** finish the step you're on, write your report back as above (what's done, what's left, and where everything is), and stop. The owner has nothing to paste. An agent that carries on gets more nudges, then an urgent one: stop now, push what you have, and report.
- **The chat that started it** picks up from the report: it checks what's done, and carries on what's left itself or hands it to a fresh agent with the report as its brief.
- **It's separate from the chat's own nudge:** an agent's nudge doesn't use up the chat's, and the chat's never reaches an agent.
