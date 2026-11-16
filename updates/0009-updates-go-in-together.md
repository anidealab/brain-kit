# Brain update 9 from AnIdeaLab: updates go in together, judgements age, and check the tasks before making one

Sent 16 Nov 2026. From now on, brain updates go in together: when a brain is a few behind, one go brings it to the kit as it is now, with one merge and one report, rather than one update at a time. This update also adds two defaults: old advice is re-thought before it's built on, and an agent checks the tasks shelf before making a task. This one is applied the old way, by the `brain_update.py` the brain already has; the next update is the first to go in together.

## Summary for the owner
- **Updates catch your brain up in one go.** Until now each update went in on its own, oldest first, each with its own summary, go and report, so a brain a few behind had several rounds to get through, and one you said no to was left out for good. Now, whenever updates are waiting, you hear one summary of them all, and one go brings your brain to the newest. Saying no just means not now: they come up again, with anything sent since, and nothing is left out. Any update you said no to before comes up again too.
- **Old advice gets a fresh look before it's built on.** Facts stand, and so do your decisions until you change them. But advice, plans and designs, whether from an old AI chat or one of your own agents, are the thinking of their day, so an agent now thinks one through again before building on it, and tells you where it would now differ. Your decisions aren't changed without you. When you bring in chats with an AI assistant, your own words are kept apart from the assistant's advice, and you get a task to revisit the decisions that rest on it.
- **Fewer duplicate tasks.** Before an agent makes a new task, it checks your tasks for one the job fits into, and tells you in a line which one it went into, or that it's new.

Nothing runs on your computer, and there's nothing to paste.

## What changed, and why
1. **Updates go in together.** `skills/brain-spec/brain_update.py`: `check` lists every waiting update, oldest first, with a line to give the owner one summary of them all. `apply`, with no number, merges the kit's `brain/` from the update this brain is on to the newest in one pass, records the newest, starts one report named for it (with a part for each update's steps) and prints each update's message, oldest first. `skip` records nothing now: a no is "not now". An update an earlier copy of the script marked as skipped is waiting again, the merge starts from the update before it, and the "Skipped" line goes. `finish` needs no number. The daily notice says how many are waiting. `skills/brain-spec/SKILL.md` ("Brain updates"), the core's line on updates, `skills/brain-audit/SKILL.md`'s step 1 and `knowledge/systems/brain-updates/README.md` say the same. Why: a brain a few updates behind had a round of summary, go, merge and report for each, which costs the owner's time and usage, and a skipped update's changes never arrived, so later updates landed on a brain nobody had tried them on. Every update's commit holds the kit's whole brain, so one merge from where the brain is to the newest has all it needs.
2. **Judgements age.** A new default in the core (`CLAUDE.md`) and the starting rules note (`knowledge/decisions/the-brain/<start date>-starting-rules.md`): facts stand, the owner's decisions stand until they change them, and judgements (advice, plans, designs, an old AI's or an agent's own call) are their date's thinking, re-thought before an agent builds on one. `skills/file-intake/SKILL.md`: chats with an AI assistant get a line in its table, a subject agent keeps the owner's words apart from the assistant's advice and treats what it made as a loose sign of taste, and an import of chats ends with a revisit task the owner holds. Why: from a brain's report, where an agent built on an old assistant's advice as if it were the owner's decision.
3. **Check the tasks before making one.** A new line in the core's "Asking the owner and saving your work", a default in the starting rules note, a new part "Before you make one" in `knowledge/tasks/README.md`, and a line in `skills/handoff/SKILL.md`: read the board first, fit the job into a task that covers it, and make a new note only when none fits. Why: agents left to themselves make a new note for work the shelf already holds, and the board fills with half-copies nobody keeps up to date.
4. **Two shorter lines in the core,** to keep it under 6 KB with the new ones: "no rules about personal information" loses "only the secrets gate holds anything back", and the sign-off loses "plain text keeps the bare words". Neither changes what an agent does.

## The setup this brain should have afterwards
- `skills/brain-spec/brain_update.py`, `skills/brain-spec/SKILL.md`, `skills/brain-audit/SKILL.md`, `skills/file-intake/SKILL.md` and `skills/handoff/SKILL.md` as the kit has them, with any lessons the brain had already folded into those skills put back.
- The core with the kit's "Judgements age" default, the line on updates, the tasks line, and the two shorter lines, and every line of the owner's own kept. The core under 8 KB.
- The starting rules note with its two new defaults, and every line of the owner's own kept.
- `knowledge/tasks/README.md` with "Before you make one", and any line of the owner's own above the index kept.
- `knowledge/systems/brain-updates/README.md` with this brain's own "On kit update" line, at 9.
- `python3 skills/brain-spec/brain_update.py check` says the brain is up to date.

## What to do beyond the files
**Read the owner the summary above before anything else, and apply only on their go,** even if they asked for the update by name.

1. **This one goes in the old way:** `python3 skills/brain-spec/brain_update.py apply 9`, after any update before it that this brain hasn't had (the script says which comes next). The new script comes in with it, so `finish` and every update after this go the new way.
2. **Clashes.** Save `apply`'s output and read both sides of each clash. Git takes the whole clashing stretch, so a line of the owner's right next to a changed line is dropped without any sign but the clash: put each one back. The likely ones:
   - The core (`CLAUDE.md`): owners add their own lines at its first line and under "The owner's defaults", and the new default goes in there, next to "No rules about personal information", which changes. Keep every line of the owner's own where it was. If the owner changed one of the two shortened lines themselves, keep theirs. If the core comes out over 8 KB, move the detail of the owner's longest rule into its decision note and leave a short line with a link; never cut a rule.
   - The starting rules note: the same, for the two new defaults.
   - `knowledge/tasks/README.md`: keep any line of the owner's own above the index; take the kit's "Before you make one".
   - `skills/file-intake/SKILL.md`, `skills/handoff/SKILL.md`, `skills/brain-audit/SKILL.md` and `skills/brain-spec/SKILL.md`: put back any lesson the tidy-up folded in.
   - `knowledge/systems/brain-updates/README.md`: keep this brain's "On kit update" line as the script wrote it, and its "Skipped" line if it has one: the next go takes it out.
   - The shelves' indexes: `apply` leaves them to `library.py build`.
3. **An update the owner skipped before** is waiting again after this one, and `check` lists it. Don't apply it now: tell the owner in a line that it comes up again with the next update, and they can hear its summary whenever they like.
4. **A brain made from AnIdeaLab's template** may already have most of this update: `apply` merges it with little or nothing to do.
5. **Run `python3 skills/brain-spec/brain_update.py compare`,** and fix what it finds.
6. **Run `python3 skills/brain-spec/brain_update.py finish 9`,** and fill in the report's sections.
7. **Check the report went:** the "Send brain update reports" run for your push should say "Sent 0009-report.md" in its log. If it says anything else, run that workflow by hand.
