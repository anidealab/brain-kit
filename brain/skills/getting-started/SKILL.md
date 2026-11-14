---
name: getting-started
description: "The first session in a new brain, made from the template with nothing installed or by the installer: welcome the owner, learn who they are and what they want the brain for, write their first notes, offer or test the PC runner and Obsidian, show them skills and where keys go, offer the weekly tidy-up and monthly deep audit, ask about files to bring in, then mark the brain set up. Use when the core says the brain is new, or when the owner asks to redo their setup."
---

# Getting started
This brain was started from the AnIdeaLab brain kit, one of two ways. Find out which first, because it decides what's on the owner's computer:
- **From the template, with nothing installed:** `.github/workflows/first-run.yml` is in the repo. The brain is this GitHub repo and nothing else: the owner pressed a button on GitHub and opened Claude. There's no copy on their computer, no Obsidian and no runner, and they don't need any of them to start. Do step 0 first.
- **By the installer:** that file isn't there. On the owner's Windows PC, the installer has already made this private GitHub repo and put the brain in it; put a copy in `C:\AI-Brain-Link\<repo name>` and opened it in Obsidian, with the Obsidian Git plugin syncing it; and set up the PC runner (a GitHub Actions self-hosted runner with the label `my-pc`, running as a Windows service under the owner's account), unless they skipped it. Skip step 0.

This skill is the first session: about 15 minutes of the owner's time. Guide mode applies, so keep each message short, and ask everything you need in as few messages as you can.

## 0. A brain from the template
- **Its start date.** If `.github/first_run.py` is still there, the brain's "Start this brain" workflow didn't run, and the brain's start date is still a placeholder in curly brackets. Run `python3 .github/first_run.py` from the top of the brain, then commit ("Started this brain from the AnIdeaLab brain kit") and push to `main`, before anything else.
- **Private.** Check the repo is private, with the GitHub tool, or by asking the owner whether GitHub shows "Private" beside its name. If it's public, stop there and ask them to change it (on GitHub: Settings, the bottom of the page, Change visibility) before anything of theirs goes in. A brain holds their own notes, and a runner on a public repo would let strangers run commands on their computer.
- **The terms.** Say in one line that the kit is free under AnIdeaLab's [terms of use](https://github.com/AnIdeaLab/brain-kit/blob/main/TERMS.md).
- **Its workflow's job is done.** Delete `.github/workflows/first-run.yml` in step 8's commit. If the push is refused because the session can't change workflow files, put it back and leave it: it has turned itself off.

## 1. Say hello, and what this is
In a few lines, in plain words:
- This repo is their second brain: plain notes that any AI agent can read. The core (`CLAUDE.md`) is the page every agent reads first. The skills library is how to do things (65 to start, and more whenever a job needs one). The knowledge library is what the brain knows about them and their projects, and it fills up as they use it.
- Obsidian on their PC shows the brain as a map, and the brain graph replays how it grew. Their edits there sync here, and agents' work syncs there.
- The PC runner lets agents run jobs on their PC whenever it's on.
- For a brain from the template, say those two are extras they can add to their computer in a few minutes, and that you'll ask about them shortly. The brain works without either.
- Guide mode: agents check a plan with them before bigger jobs, because their plan's usage runs out. Once they've found their feet they can tune it down: agents still size each job and hand off between stages, without the explaining ([guide-mode](../guide-mode/SKILL.md#tuned-down)).

## 2. Ask, in one message
- Their first name, and where they live (a town and country is enough), so reminders fall due in their own time.
- What they'd like the brain to help with: projects, a business, study, life admin, learning to build things. A few words is fine.
- Any business or project names.
- Whether they have files they'd like the brain to know: documents for a project, a folder from an old computer, years of paperwork. A rough idea of how much is enough ("a dozen PDFs", "my whole Documents folder").
- Their Claude plan (Pro, Max or another), and whether agents should check a plan with them before every job or only bigger ones (guide mode's default is bigger ones).

## 3. Write it down
- `knowledge/people/<first-name>.md`: the owner's note, with a card ([brain spec](../brain-spec/SKILL.md#cards)), what they said in their words, their plan, and the date.
- In the core, change "A second brain" at the top to "<Name>'s second brain".
- In [routines](../../knowledge/systems/routines.md), put their time zone's name on the Time zone line under "The owner's own", in place of "not set yet": the name from the time zone database, like Pacific/Auckland, Europe/London or America/New_York.
- One short note per project or business they named, `knowledge/ventures/<name>.md`: what it is and their goal, in their words. They grow into folders when work starts.
- Anything they said about how agents should work goes in a decision note, `knowledge/decisions/the-brain/<date>-<what>.md`.
- Run `python3 skills/brain-spec/library.py build`, then the checks in the brain spec's "Before you push", and commit and push.

## 4. The owner's computer
**A brain from the template** has nothing on their computer yet. Ask, in one message, whether they'd like either extra, and take no for an answer:
- **The PC runner:** agents can then run jobs on their computer from any chat, on their phone too, whenever it's on. It suits a Windows PC or Mac that's usually on.
- **Obsidian:** a free app that shows the brain as a map on their computer, where they can read and edit their notes.

If they want neither, say they can ask for them any time, and go to step 5. If they want one or both, give them the one command for their computer, and what to answer:
- **Windows:** open PowerShell (press the Windows key, type powershell, press Enter), paste this and press Enter: `irm https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/install.ps1 | iex`
- **Mac:** open Terminal (press Command and Space, type terminal, press Enter), paste this and press Enter: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/install.sh)"`
- **At the name question, they type this repo's name exactly** (give it to them), so the command uses this brain. Enter alone would make a second one.
- **At the runner question,** Y if they want the runner, N if they only want Obsidian. For now the command installs Obsidian either way; they needn't open it.
- **At "Keep this PC awake",** Y. Most people say no, and then the brain can't reach the PC whenever it has gone to sleep. The screen still turns off as usual.
- If their antivirus blocks the command, or it stops, ask them to paste what it showed, and work from that: the [my-pc skill](../my-pc/SKILL.md) has the setup check.

When they say it's finished, and they chose the runner, test it as below. Then carry on: nothing else in this skill waits on it, so if they'd rather do it another day, save it as a task they hold and go on.

**A brain from the installer,** or one whose owner has just added the runner: test it. Find the repo's owner and name from `git remote get-url origin` (the part after `github.com/` or `/git/`). Start the workflow `pc-run.yml` ("Run on my PC") on `main` with the GitHub tool's run-workflow method, with `workdir` left as it is and this `command`:
```
# Hello from the brain: what this PC has
$os = Get-CimInstance Win32_OperatingSystem
"PC: $env:COMPUTERNAME, $($os.Caption) $($os.Version), running as $(whoami)"
"CPU: $((Get-CimInstance Win32_Processor | Select-Object -First 1).Name)"
"RAM: {0:N0} GB" -f ($os.TotalVisibleMemorySize / 1MB)
Get-CimInstance Win32_VideoController | ForEach-Object { "GPU: $($_.Name)" }
Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { "Disk {0} {1:N0} GB free of {2:N0} GB" -f $_.DeviceID, ($_.FreeSpace / 1GB), ($_.Size / 1GB) }
foreach ($t in 'git','gh','python','py','node','winget','ffmpeg','nvidia-smi') { $c = Get-Command $t -ErrorAction SilentlyContinue; "{0}: {1}" -f $t, $(if ($c) { $c.Source } else { 'not found' }) }
```
Wait until the run shows as completed, then read its job log. Put what it found in [the PC's note](../../knowledge/systems/my-pc.md) under "What's on the PC", dated, and tell the owner in two lines, with a note that the live jobs window on their desktop showed it running.

- **It sat in "queued" for more than a few minutes:** the runner isn't up. Go through "If the runner stops picking up jobs" in the [my-pc skill](../my-pc/SKILL.md).
- **They skipped the runner** when installing: say they can set it up any time with one command, and give them the one in the my-pc skill's "Setting it up again".
- **No GitHub tool in this session** to start a workflow: say so, and that the owner can connect GitHub to Claude (claude.ai/code shows how) and start a new session; carry on with the rest.

## 5. Show them around, briefly
- **Obsidian,** if they have it: Ctrl+G opens the map; the bookmarks panel has "Start here"; the brain icon on the left opens the brain graph (the first time, Ctrl+P, then "Reload app without saving"). [Obsidian setup](../../knowledge/systems/obsidian-setup.md) has the rest.
- **What waits on them:** the [tasks index](../../knowledge/tasks/README.md), "Waiting on the owner" at the top.
- **More skills:** they can ask "find me a skill for X" ([find-skills](../find-skills/SKILL.md)).
- **Long chats:** every reply rereads the whole chat, so a long one uses more of their plan. When a chat gets long, the agent saves where things stand in the job's task note and gives them a line to paste into a new chat, ending in "continue" ([handoff](../handoff/SKILL.md)).
- **The upload point,** on a PC the installer has set up: to give the brain files, they right-click files or folders in File Explorer and pick Send to, then My brain (on Windows 11, under "Show more options"), then tell you what to do with them ([upload-point](../upload-point/SKILL.md)). If My brain isn't in Send to, give them the setup command in that skill.
- **Keys** (API keys for services, later): never pasted into a chat. When a job needs one, the agent gives them one command to paste into PowerShell, which opens the page that makes the key, reads it in hidden and saves it in the brain's GitHub secrets ([add-a-key](../add-a-key/SKILL.md)). Adding one by hand on GitHub is in [keys and accounts](../../knowledge/systems/keys-and-accounts.md).
- **When a site is blocked** in a Claude session, the agent will say which; the owner can allow it in the session's environment settings (the environment menu in the session's title bar, then Edit, then Network access).

## 6. Offer the weekly tidy-up and the monthly deep audit
The [brain-audit skill](../brain-audit/SKILL.md) tidies the brain once a week. It's a reminder, not a scheduled job: nothing runs, and none of their plan is used, until they say yes to it in a session. Ask if they'd like it. If yes, add its row to the owner's own table in [routines](../../knowledge/systems/routines.md), as the comment there shows, starting from the next Saturday, and commit.

Then offer [the monthly deep audit](../brain-audit/deep-audit.md), in a line: once a month it reads every decision in full for rules that clash, hunts down removed rules that survive elsewhere, and checks a sample of cards. It uses more of their plan than the tidy-up, and also runs only when they say yes. If they'd like it, add its row the same way, from the first Saturday of next month.

## 7. Their files, if they have some
If they said they have files to bring in, it's a job of its own, after this one: don't start reading files in the first session, which is for setting up.
- **A few files** (up to a few dozen): ask them to send them with Send to, My brain and say "sort what I sent" ([upload-point](../upload-point/SKILL.md)).
- **A lot** (a whole folder, an old drive, years of documents): ask them to send the folder with Send to, My brain, or tell you where it is on their PC, and say it will be brought in with the [file-intake skill](../file-intake/SKILL.md): a look at what's there first, which costs almost none of their plan, then a plan for them to say go to. Suggest a fresh chat for it.
- **No Send to** (a brain from the template with nothing on their computer, or a Mac): a few files can be attached to a chat; for a lot, the PC side from step 4 comes first.
- Either way, save it as a task they hold on the tasks shelf ("Send the files for <what> with Send to, My brain"), so it isn't lost if they do it another day.

## 8. Finish
- Take the "A new brain" paragraph out of the core, so this skill doesn't run again. In a brain from the template, delete `.github/workflows/first-run.yml` too (step 0).
- Run the checks, commit ("Set up <Name>'s brain") and push.
- Tell the owner in three lines what's set up, and suggest one small first job that fits what they said they want, sized the guide-mode way: bringing their files in, if they have some.
