# The monthly deep audit

The brain has two levels of audit. The [weekly tidy-up](SKILL.md) is cheap: scripts and cards, not notes. This monthly one reads notes in full, to catch what only reading does: rules that clash without linking, and a removed rule surviving in other words. It uses more of the owner's plan, so it comes once a month. With a connected computer it also lists the AI-Brain-Link folder by size, so the owner can clear what's finished with before it fills the drive (step 3).

**When:** the first Saturday of each month, as a reminder, like the tidy-up: nothing runs until the owner says yes in a session ([routines](../../knowledge/systems/routines.md)). **If no tidy-up has run in the last week** (the [audit log](../../knowledge/areas/the-brain/audit-log.md)'s newest heading), do one first: the reading here counts on the cheap fixes being done, and the tidy-up's lists already mark the replaced decisions that link what replaced them.

**Budget:** more of the owner's plan than the tidy-up, on purpose, but in proportion. Most decisions stay true, so the current ones only pile up; reading all of them each month would cost more every month whatever else is done. So each month reads in full only that month's new decisions, and the cost follows how much was decided, not how much ever was. Past about 100 KB, read a shelf at a time and save as you go, so a usage limit doesn't lose the work. One or two agents at once, as the core says.

## 1. The clash sweep
1. **Read the core, and every current decision new or changed since the last deep audit, in full** (the deep audit log's newest heading gives its date; `git log --since=<that date> --name-only --format= -- knowledge/decisions` lists them). Read each against the decisions shelf's index, which has every current decision's card, and open an older one in full only where its card looks close. The older ones were read against each other at earlier deep audits, and a new clash needs a new or changed note. The brain's first deep audit (an empty log) reads every current decision. For each one you read, ask:
   - Does a later decision change, narrow or remove it, without this one saying so?
   - Does another current note say the opposite?
   - Does the core still say what the decisions say?
2. **Hunt down removed rules.** For each rule removed or replaced since the last deep audit, search the knowledge library and the brain's own skills for its wording, and for its idea in other words ("signs off", "approves every", "must", "never"). Fix what survived.
3. **Fix the clear cases:** mark a replaced decision `status: superseded`, with a line at its top linking the newer one; add a dated pointer line to an older note a newer one changes; reword a skill line that states a removed rule. When it isn't clear which of two notes stands, ask the owner, quoting both, and leave them until they answer. Never guess for them.
4. **Leave copied skills as they came,** apart from folding in their lessons, as the tidy-up does.

## 2. Rules not checked with the owner
Agents write rules as they go, and a guess written as a rule fences in every agent after it. So each rule that limits what agents can do is kept only once the owner confirms it, in [the rules table](../../knowledge/decisions/rules.md).
1. **Find them.** In the knowledge library and the brain's own skills (not copied ones), look for rules that limit what agents can do: "never", "only", "doesn't", "can't", "asks first", "must", and the same idea in other words. Leave out the core's gates and defaults. Also take every row of the rules table still marked "not checked yet".
2. **Sort them.** A rule in the table as confirmed is done. One from the owner's own decision (their words in a decision note) goes in the table as confirmed, with the link, without asking again. Every other one is for the owner.
3. **Ask the owner in one list:** each rule, where it lives, who wrote it and when, a short line on what keeping it costs (what it stops agents doing, where it could get in the way), a few words on what it protects if that isn't obvious, and your recommendation (keep or cut). Keep each one short: they already know why a rule was made. Leave every rule as it is until they answer.
4. **Do what they say.** Kept: its row says "Confirmed <date>" with their words (a new row if it wasn't listed), and "(confirmed: the rules table)" goes beside the rule where it lives. Cut: delete the rule from where it lives, and its row if it had one.

## 3. The AI-Brain-Link folder
**Only for a brain with a connected computer** (a runner set up: [devices](../../knowledge/systems/devices.md)); without one, skip this step. The brain's folder on the computer (`C:\AI-Brain-Link` on a PC, `~/AI-Brain-Link` on a Mac) fills up by itself: job data, renders, tools and installers, Python environments, logs. This step lists it by size and brings the owner a few folders at a time to choose for, so it doesn't fill the drive. It's light: names and sizes only, nothing opened. **It runs on its own too,** whenever the owner asks: do only this step, and log it the same way.

[link_check.py](link_check.py) does the listing, the same way each month; `link-sizes.json` beside it (made at the first save) keeps last month's sizes and the owner's choices. It never flags or bins the runner (`_runner`), the bin (`_trash`) or a copy of a repo (a folder with `.git` in it), and the brain's own copy is one of those.
1. **List it,** on each connected computer that's on (`python3 skills/brain-spec/devices.py status`); if none is, say so and do it next month. A job with `checkout` true (it reads every file's size; a few seconds for hundreds of GB):
   - PC, `pc-run.yml`, shell `powershell` (Python found or installed the way the [backup skill](../backup/SKILL.md) does):
     ```
     $py = Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1 -ExpandProperty FullName
     if (-not $py) { winget install --id Python.Python.3.12 -e --scope user --silent --accept-source-agreements --accept-package-agreements | Out-Host; $py = Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe" | Select-Object -Last 1 -ExpandProperty FullName }
     Set-Location $env:GITHUB_WORKSPACE; & $py skills\brain-audit\link_check.py scan
     ```
   - Mac, `mac-run.yml`, shell `bash`: `cd "$GITHUB_WORKSPACE" && python3 skills/brain-audit/link_check.py scan`
2. **Keep the numbers:** save the job's log to a file and run `python3 skills/brain-audit/link_check.py save <log file>`. Commit it.
3. **Read the table.** Each top folder by size; inside any folder over 10 GB, the folders in it, further down while they're still over 10 GB (to four levels); inside `_trash`, each dated bin. Small folders share a line. It says what changed since last month, whether the backup takes each folder, and any choice already made. Its "Worth asking about" list is what to bring: folders new or grown by 1 GB or more, folders of 5 GB or more never asked about, and bins over a month old. A folder the owner has chosen for, or one inside it, comes back only if it grows.
4. **Look each one up before suggesting:** search the brain for the folder's name (its task notes, the computer's note). It tells you what a folder is and whether it's finished with: a render a later, signed-off take replaced; a test; a tool for something shelved.
5. **Ask the owner, a few at a time** (three to five, biggest first), each with its size, what it is in plain words, a suggestion and why in a few words:
   - **Back it up**: their own work, or slow or impossible to make again (raw footage, finished edits).
   - **Keep it, but don't back it up**: still used, but can be got back (tools, installers, Python environments, files made from other files).
   - **Bin it**: finished with. It's moved to `AI-Brain-Link/_trash/<date>/` on the same drive, so it can still come back until the bin is emptied.
   - **Delete it**, if they say so: gone for good, not to the bin.
   Never answer for them; a folder they don't answer for stays as it is. When an answer is unclear (a voice message that says both), ask again rather than pick. When they give a rule rather than folders ("only the newest edits, full size"), list the files first (names, sizes, and a video's width and height from ffprobe), and get their yes on the exact list before deleting anything.
6. **Do what they say:** `python3 skills/brain-audit/link_check.py choose <computer> "<folder as the table shows it>" <backup|keep|bin> --why "<their reason, a few words>"`. It records the choice and changes the backup's list (`skills/backup/my-folders.json`, once the backup is set up): back it up adds that folder, keep and bin take it out. For bin it prints the job that moves the folder to the bin: run it. For delete, record it as `bin` with the why "deleted at the owner's word", and run a job that deletes it: `Remove-Item -LiteralPath '<path>' -Recurse -Force` on a PC, `rm -rf '<path>'` on a Mac. Commit and push.
7. **The bin:** bins over a month old, and any the owner asks about sooner, get their size and an offer to empty them; only on their yes, a job deletes that dated folder the same way. A job can't reach the Recycle Bin or the Trash, so emptying it is for good.
8. **Scan and save again** once the moves and deletes are done, so next month compares with what's left. Tell the owner how much the folder and the drive's free space changed.

## 4. Log it and tell the owner
- Add a heading to the top of [the deep audit log](../../knowledge/areas/the-brain/deep-audit-log.md), with today's UTC date, like `## 7 Nov 2026: deep audit`, and two or three lines under it: what was fixed, and what waits on the owner. That heading turns the reminder off until next month. Step 3 adds a line: the folder's size before and after, and what the owner chose. Run on its own, step 3 adds no heading (any heading turns the reminder off): `link-sizes.json`'s date is its record, and the owner hears in the thread.
- Commit in small commits with plain messages, and push.
- Tell the owner the short version in the thread. End it with one line: guide mode is at level <N> of 4 (the core's line), and they can move it down for more explaining or up for less ([the levels](../guide-mode/SKILL.md#the-owners-level)). Once a month, here only: a reminder in every reply would be noise, and the level is theirs to change when they want.
