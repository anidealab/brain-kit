# Brain update 6 from AnIdeaLab: bringing a big pile of files in, an agent per busy project in the weekly tidy-up, and the link check fixed on Windows

Sent: not yet. This is a draft on the kit's `next` branch. This update gives your brain a proper way to take in a lot of the owner's files at once, and the same idea for a busy week's tidy-up: split the work by subject, give each subject to an agent with a clear head, and have the coordinator join them up. It needs nothing run on the owner's computer.

## Summary for the owner
- **Bringing a lot of files in:** until now your brain sorted dropped files one agent at a time, which suits a few files but not a whole folder: the agent's memory fills up, detail gets lost, and nobody can say afterwards which files were read. Now there's a method for a big pile. Your agent first takes a look at what's there (how many files, what kinds, which are copies), which costs almost none of your plan, then shows you a plan. For a big pile it gives each subject (a business, the house, tax) to its own agent, two at a time, and keeps a list of every file and what it became, so nothing is quietly missed. Your files stay where they are.
- **A free tool for reading documents:** to turn PDFs, Word, Excel and PowerPoint files into text, your agent installs Microsoft's free MarkItDown on your computer, the first time you bring a pile in. Your agent tells you when it does.
- **A busy week's tidy-up:** when one of your projects has moved a lot in a week, the weekly tidy-up now gives that project its own agent, so the rest of your brain still gets a careful read. A quiet week's tidy-up is the same as before, with no extra agents. It tells you first, because agents use more of your plan.
- **A fix for brains used on a Windows PC:** the link check wrongly said nearly every note had nothing linking to it when it ran on Windows. Fixed.

Nothing runs on your PC, and there's nothing to paste.

## What changed, and why
1. **The file-intake skill.** New: `skills/file-intake/SKILL.md` and `skills/file-intake/intake.py`, with its line in `skills/lists/the-brain.md`. The skill has the steps, a table for picking the method by how many documents there are, how much text and what kinds, the brief for a subject agent and for the links agent, and the file list. The script surveys a pile (`survey`), turns its documents into text with MarkItDown where it's installed (`convert`), puts the files into subjects (`split`), and checks that every file has an outcome and every note names the file it came from (`check`). Why: one agent reading a whole pile gets things wrong and can't say what it missed. AnIdeaLab tried it on a made-up pile of 35 files in three subjects, with two subject agents and a links agent: every file was accounted for, and what those agents found unclear is in the skill.
2. **The first session asks about files.** `skills/getting-started/SKILL.md`: its questions now ask whether the owner has files to bring in, and a new part 7, "Their files, if they have some", says a few go through the upload point and a lot through file-intake, as a job of its own after setup. "Finish" is now part 8.
3. **The upload point passes a big drop on.** `skills/upload-point/SKILL.md`, "Sorting what's waiting", step 1, and its description: more than about 30 documents, or a folder mixing several projects, goes to file-intake.
4. **The weekly tidy-up gives a busy project its own agent.** `skills/brain-audit/SKILL.md`: a new section before "1. Clean up", "A busy project gets its own agent", and its description. A quiet week is unchanged. A project with more than about ten notes, tasks and hand-offs moved gets an agent that does the tidy-up's steps for that project alone and reports back; with two or more, a links agent reads the reports and says what crosses between projects, and the coordinator writes those. Why: a busy project's detail fills the one agent's memory, and the rest of the brain gets a tired read.
5. **The link check on Windows.** `skills/brain-spec/check_links.py`: a linked note's path is now compared with `/` on Windows too. Before, every note looked as if nothing linked to it.
6. **The skill count.** `README.md`, `knowledge/areas/the-brain/README.md`, `skills/find-skills/SKILL.md` and `skills/getting-started/SKILL.md` say 65 skills to start, not 64.

## The setup this brain should have afterwards
- `skills/file-intake/SKILL.md` and `skills/file-intake/intake.py` as the kit has them, and a file-intake line under "The brain's own" in `skills/lists/the-brain.md`.
- `skills/getting-started/SKILL.md`, `skills/upload-point/SKILL.md`, `skills/brain-audit/SKILL.md` and `skills/brain-spec/check_links.py` as the kit has them, with any lessons the brain had already folded into those skills put back.
- `python3 skills/file-intake/intake.py survey --help` prints its options.
- Nothing new on the owner's computer, and no new row in routines.

## What to do beyond the files
1. **Clashes.** Save `apply`'s output and read both sides of each clash. The likely ones: `knowledge/areas/the-brain/README.md`, which holds this brain's own history (keep the brain's own lines, and don't change its count of skills if the brain has added its own); `README.md`, the front door, where the owner may have their own lines (keep them); and `skills/lists/the-brain.md`, if the brain added lines of its own (keep them, and add the file-intake line). In `skills/brain-audit/SKILL.md`, `skills/upload-point/SKILL.md` and `skills/getting-started/SKILL.md`, put back any lesson the tidy-up folded in.
2. **Ask the owner once, in a line, whether they have files they'd like the brain to know.** If yes, follow `skills/getting-started/SKILL.md` part 7: it's a job of its own, not part of this update. If no, nothing more.
3. **Don't install MarkItDown now.** The file-intake skill installs it the first time a pile is brought in, and tells the owner then.
4. **Don't start any agents now.** The next weekly tidy-up decides, from what moved that week, whether a project gets one.
5. **Run `python3 skills/brain-spec/brain_update.py compare`,** and fix what it finds.
6. **Run `python3 skills/brain-spec/brain_update.py finish 6`,** and fill in the report's sections.
7. **Check the report went:** the "Send brain update reports" run for your push should say "Sent 0006-report.md" in its log. If it says anything else, run that workflow by hand.
