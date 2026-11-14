# The monthly deep audit

The brain has two levels of audit. The [weekly tidy-up](SKILL.md) is cheap: scripts and cards, not notes. This monthly one reads notes in full, to catch what only reading does: rules that clash without linking, a removed rule surviving in other words, and cards that no longer say what's in their note. It uses more of the owner's plan, so it comes once a month.

**When:** the first Saturday of each month, as a reminder, like the tidy-up: nothing runs until the owner says yes in a session ([routines](../../knowledge/systems/routines.md)). Do the weekly tidy-up first if it's due the same morning.

**Budget:** more of the owner's plan than the tidy-up, on purpose, but keep it in proportion. A young brain's decisions read in a few minutes; once they pass about 100 KB, read a shelf at a time and save as you go, so a usage limit doesn't lose the work. One or two agents at once, as the core says.

## 1. The clash sweep
1. **Read the core and every current decision in full,** a shelf at a time (`python3 skills/brain-spec/library.py find --shelf knowledge/decisions`). For each, ask:
   - Does a later decision change, narrow or remove it, without this one saying so?
   - Does another current note say the opposite?
   - Does the core still say what the decisions say?
2. **Hunt down removed rules.** For each rule removed or replaced since the last deep audit, search the knowledge library and the brain's own skills for its wording, and for its idea in other words ("signs off", "approves every", "must", "never"). Fix what survived.
3. **Fix the clear cases:** mark a replaced decision `status: superseded`, with a line at its top linking the newer one; add a dated pointer line to an older note a newer one changes; reword a skill line that states a removed rule. When it isn't clear which of two notes stands, ask the owner, quoting both, and leave them until they answer. Never guess for them.
4. **Leave copied skills as they came,** apart from folding in their lessons, as the tidy-up does.

## 2. Cards that drifted
The tidy-up rechecks the cards of notes that changed. Here, open 10 current notes that haven't changed in a while (the 5 most linked-to and 5 at random), and fix any card that doesn't say what its note holds.

## 3. Log it and tell the owner
- Add a heading to the top of [the deep audit log](../../knowledge/areas/the-brain/deep-audit-log.md), with today's UTC date, like `## 7 Nov 2026: deep audit`, and two or three lines under it: what was fixed, and what waits on the owner. That heading turns the reminder off until next month.
- Commit in small commits with plain messages, and push.
- Tell the owner the short version in the thread.
