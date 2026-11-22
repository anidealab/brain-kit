# Brain update 11 from AnIdeaLab: reports that always arrive, a key check that saves, and update 10's last two files

Sent 22 Nov 2026. A small update: two fixes found the day update 10 went out, and, for a brain that took update 10 early that day, the two files it was sent later with.

## Summary for the owner
- **The brain's reports reach AnIdeaLab again.** For a few hours on 22 Nov 2026 a security setting on AnIdeaLab's website turned the brain's update reports away. It's fixed on the website's side, and now the brain also says who it is when it sends one, so a setting like that can't block it again.
- **The weekly key check saves its results even when something else saves at the same moment.** Before, if another job pushed first, the check's dates were thrown away.
- **If this brain took update 10 early on 22 Nov 2026,** it gets the last two files that update came with: no brain-name question when it gives you the setup command, and plainer words when it offers to use your computer.

Nothing runs on your computer, and there's nothing to paste.

## What changed, and why
1. **Reports say who's sending them.** `skills/brain-spec/brain_update.py send` posts each report with `User-Agent: anidealab-brain-kit`. AnIdeaLab's inbox sits behind Cloudflare, whose browser check turns away Python's own client name (a 403, "error code: 1010"), so reports failed with "The inbox didn't take ... (403)" in the "Send brain update reports" run, while the run still showed as a success.
2. **Check keys retries for real.** `.github/workflows/check-keys.yml`: when the push of the week's dates is refused because something else pushed first, the loop now undoes its commit (`git reset -q --soft HEAD~1`) before `git stash -q`. Before, the stash found nothing, `git reset --hard` threw the commit away, and the run ended with "The keys table changed meanwhile". An owner's brain found and fixed this; thank you.
3. **Update 10's last two files, for a brain that took it early.** Update 10 was sent a third time on 22 Nov 2026 with `skills/getting-started/SKILL.md` (the setup command asks no brain name now: every new brain is `my-brain-ail`, and for a brain with another name the agent puts `BRAIN_KIT_NAME` in front of the command; the computer offered as "you ask Claude to do things on your PC or Mac, and it only does what you ask") and `skills/my-pc/setup-runner.ps1` (the stay-awake question says it's so Claude can do what you ask when you're away). A brain that applied update 10 before that has the older copies, and `apply` keeps them as if they were the owner's own, so step 2 below brings them in.

## The setup this brain should have afterwards
- `skills/brain-spec/brain_update.py` and `.github/workflows/check-keys.yml` as the kit has them, with any change of the owner's own put back.
- `skills/getting-started/SKILL.md` mentions `BRAIN_KIT_NAME`, and `skills/my-pc/setup-runner.ps1` says "so Claude can do what you ask when you're away from it".
- `knowledge/systems/brain-updates/README.md` with this brain's own "On kit update" line, at 11.
- `python3 skills/brain-spec/brain_update.py check` says the brain is up to date.

## What to do beyond the files
**Read the owner the summary above before anything else, and apply only on their go,** even if they asked for the update by name. If more than one update is waiting, give them one summary of all of them.

1. **Apply:** `python3 skills/brain-spec/brain_update.py apply`, with no number. A brain still on update 9 takes 10 and 11 together, and then follow update 10's message's steps too (its keys and devices steps); its step 5, for a Mac, now has the command with the brain's name as below.
2. **Update 10's last two files.** If `skills/getting-started/SKILL.md` doesn't mention `BRAIN_KIT_NAME` after the apply, run `python3 skills/brain-spec/brain_update.py compare --take skills/getting-started/SKILL.md` and `python3 skills/brain-spec/brain_update.py compare --take skills/my-pc/setup-runner.ps1`, then put back any lines of the owner's own (`git diff` shows what changed; a brain set up on a Mac keeps its Mac lines in getting-started's step 4). If it does mention it, skip this step.
3. **Clashes.** Save `apply`'s output to a file and read it whole. The likely one: `.github/workflows/check-keys.yml`, where this brain may have made the same fix itself: keep one `git reset -q --soft HEAD~1` line before `git stash -q`, not two. And `brain_update.py`, where an owner changed it: take the kit's, and put their change back.
4. **Run `python3 skills/brain-spec/brain_update.py compare`,** and fix what it finds.
5. **Run `python3 skills/brain-spec/brain_update.py finish`,** and fill in the report's sections, saying whether step 2 was needed.
6. **Check the report went:** the "Send brain update reports" run for your push should say "Sent 0011-report.md" in its log. If it says "didn't take", run that workflow by hand once; it sends every report in the folder, the ones that were turned away included.


The exemplar, the kit's brain at this update: https://github.com/AnIdeaLab/brain-kit/tree/fe35c951966be0a3d5ef009cbe6d1b01a3f25b11/brain. `compare` prints it too.
