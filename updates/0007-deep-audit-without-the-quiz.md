# Brain update 7 from AnIdeaLab: the monthly deep audit loses its quiz

Sent 14 Nov 2026. A small update: it takes the quiz out of the monthly deep audit. Nothing is added, nothing runs on the owner's PC, and a brain that never said yes to the deep audit only loses a part it never ran.

## Summary for the owner
- **The monthly deep audit no longer has a quiz.** Since update 5, the deep audit ended by asking a fresh agent a set of questions about your brain, to find notes that mislead. AnIdeaLab has stopped using the quiz in its own brain and doesn't think a brain needs one: it meant a file of questions to look after and extra agents to run every month. The rest of the deep audit stays: reading every decision in full for rules that clash, hunting down removed rules that survive elsewhere, and checking a sample of cards.
- **If you said yes to the deep audit,** it still comes up on the first Saturday of each month, and uses a little less of your plan than it would have.
- **If you said no, or were never asked,** nothing changes for you.

Nothing to paste, and nothing runs on your PC.

## What changed, and why
1. **The deep audit's quiz is gone.** `skills/brain-audit/deep-audit.md` loses its part 2, "The quiz", so "Cards that drifted" is now part 2 and "Log it and tell the owner" part 3; its opening no longer says it asks a fresh agent questions, and its log line no longer asks for a quiz score. `skills/brain-audit/quiz.json`, the question file, is deleted. Why: the quiz was the deep audit's only part that needed its own file kept up and a fresh agent run each month, and AnIdeaLab decided no brain needs it. The reading does the audit's work.
2. **The two places that described it.** `skills/brain-audit/SKILL.md` (its description, and "Two levels") and `skills/getting-started/SKILL.md` (part 6, the offer of the deep audit) now describe the deep audit without the quiz.

## The setup this brain should have afterwards
- `skills/brain-audit/deep-audit.md` as the kit has it, with three parts: the clash sweep, cards that drifted, and log it and tell the owner.
- No `skills/brain-audit/quiz.json`.
- `skills/brain-audit/SKILL.md` and `skills/getting-started/SKILL.md` as the kit has them, with any lessons the brain had already folded into those skills put back.
- The "Monthly deep audit" row in the owner's own table in `knowledge/systems/routines.md` exactly as it was, if the owner has one. No row is added or removed.
- `knowledge/areas/the-brain/deep-audit-log.md` as it was.

## What to do beyond the files
**Read the owner the summary above before anything else, and apply only on their go,** even if they asked for the update by name.

1. **Clashes.** Save `apply`'s output and read both sides of each clash. The likely ones are in `skills/brain-audit/SKILL.md` and `skills/getting-started/SKILL.md`, where the weekly tidy-up may have folded lessons in: take the kit's lines about the deep audit and put back any lesson of the brain's own. If `skills/brain-audit/deep-audit.md` clashes, take the kit's page and put back any lesson folded into the parts that stay; a lesson that was only about the quiz goes with it.
2. **The question file.** `apply` deletes `skills/brain-audit/quiz.json`, also where the brain had added questions to it. That's meant: don't put it back, and don't move its questions anywhere. If the file is somehow still there afterwards, delete it.
3. **A deep audit this brain has already run.** Leave its entry in `knowledge/areas/the-brain/deep-audit-log.md` as written, quiz score and all: it's the record of that run. Later entries have no score.
4. **Don't ask the owner about the deep audit again.** Whether they have it is already settled, and this update changes neither answer. If they ask what it does now, the summary's first point says.
5. **Anything else in the brain that mentions the quiz** (a task to run it, a note of the brain's own that says the deep audit has one): close the task as dropped, and bring the note into step.
6. **Run `python3 skills/brain-spec/brain_update.py compare`,** and fix what it finds.
7. **Run `python3 skills/brain-spec/brain_update.py finish 7`,** and fill in the report's sections.
8. **Check the report went:** the "Send brain update reports" run for your push should say "Sent 0007-report.md" in its log. If it says anything else, run that workflow by hand.


The exemplar, the kit's brain at this update: https://github.com/AnIdeaLab/brain-kit/tree/84d8a975417d3baaac1a281d6819abd9776810f1/brain. `compare` prints it too.
