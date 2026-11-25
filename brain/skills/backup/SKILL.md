---
name: backup
description: "The backup to the owner's cold storage drive, an external drive they plug in for it and unplug after, through the runner on their connected computer: the brain with all its history and any other repos they name, plus only the folders or files they ask for. Only for a brain with a connected computer. Setting up what it saves, the Mac's optional iCloud step, running it, the tripwire, logging it and restoring. Use at the weekly tidy-up's optional last step when the owner says yes, or whenever they ask for a backup or a restore."
---

# The backup to a cold storage drive

GitHub keeps the brain, but one place isn't a backup: an account locked or lost, or a computer hit by ransomware, takes everything at once. So the owner keeps a copy on an external drive that's plugged in only for the backup, where nothing that gets into the computer can reach it. The weekly tidy-up offers it as its last step ([brain-audit](../brain-audit/SKILL.md), Part 4), and the owner can ask for one any time. Each one gets a line in the backup log (`knowledge/systems/backup-log.md`).

## Only with a connected computer
The backup runs through the runner on the owner's computer (the devices note, `knowledge/systems/devices.md`, lists one; `python3 skills/brain-spec/devices.py status` says whether it's on). **A brain with no computer connected doesn't get it:** the tidy-up doesn't offer it and you don't suggest it, since GitHub already keeps the brain. If the computer is connected but off, say so and offer it next week. If the owner asks for a backup without a connected computer, the computer guide comes first (the my-pc or my-mac skill).

Before it runs: **"Please plug in your cold storage external hard drive."** If they don't have one, any external drive works, kept for this alone: "You can buy one from [AnIdeaLab](https://anidealab.com/backup-drive) if you don't have one."

## The drive's format
The drive has to be **exFAT**, the one format Windows and Macs can both read and write with no limit on file size, so one drive serves all the owner's computers. The drives AnIdeaLab sells come that way. Plenty of drives don't: NTFS (Windows only; a Mac can't write to it), FAT32 (no file over 4 GB), APFS or Mac OS Extended (Mac only).

**The script never formats a drive.** It checks the format first, and if it isn't exFAT it stops with code 4, having copied and changed nothing. `backup.py drives` shows each drive's format too. Then you, not the script, talk it through with the owner:
1. **Tell them plainly** what the drive is and why it won't do: "Your drive is formatted for Windows only (NTFS), so your Mac couldn't write to it. The backup needs exFAT, which works on both."
2. **Say what fixing it costs:** turning it into exFAT erases everything on it. Ask whether anything on it matters to them. If it does, they copy it somewhere else first, or use a different drive for the backup.
3. **Offer to do it**, naming the drive by its name and size, and only on a clear yes for that drive: a job through the runner, labelled with the drive's own name, that checks once more that the drive is external and not the computer's own disk before it formats:
   - Windows (`pc-run.yml`, shell `powershell`): `Format-Volume -DriveLetter <letter> -FileSystem exFAT -NewFileSystemLabel "<name>" -AllocationUnitSize 131072 -Force -Confirm:$false`. If it's refused for lack of admin rights, give them one command to paste into PowerShell run as administrator.
   - Mac (`mac-run.yml`, shell `bash`): `diskutil eraseVolume ExFAT "<name>" "/Volumes/<name>"`. If it asks for a password, give them the command to paste in Terminal.
   - Or they do it themselves: on Windows, right-click the drive in File Explorer > Format > exFAT; on a Mac, Disk Utility > Erase > ExFAT.
4. Then run the backup. If they'd rather keep the format and only ever back up one computer (say an NTFS drive on a Windows PC alone), that works: run it with `--any-format`, and note it in the backup log, since a second computer couldn't use the drive.

## Running it
[backup.py](backup.py) does it: Python 3 and git, which the computer has (on Windows the job below installs Python for the owner's account the first time, without admin rights).

**The first time, set up what it saves, with the owner.** It isn't a backup of everything they own: it's the brain, their working projects and the documents they've been working on, the essentials, and only what they ask for, so it never feels like the agent is going through all their files (AnIdeaLab, 25 Nov 2026: "This isn't a backup of everything the person owns ... Just essential things. It's not a everything folder"; "It's like ones that they've asked for"). So:
1. **The brain is always in.** Say so; there's nothing to choose.
2. **Other repos:** ask whether there are other repos they'd like a copy of too, like a project's or a website's code on GitHub. Each goes in `repos` by `owner/name` (a bare name means the brain's own owner), as a full copy with all its history. If you can see their repos, you can list them to choose from.
3. **Then only what they ask for:** ask whether there are folders or files on this computer they'd like kept as well, things they're working on. Add only what they name. Don't go looking through their folders to suggest things, by size, type or anything else. If they're not sure where something is, look for that one thing by its name.
4. **Left out, unless they ask by name:** Downloads (mostly things from the internet: if something of theirs is in there, add that file, or suggest moving it where it belongs); personal photos and videos (big, and a Mac's Photos library is usually closed to the runner anyway); music and films. Programs, games and installers can be got back, so they're never worth the room. If they ask for one of these, it's their call: say it may be big, then add it.
5. **On a Mac, an optional step: iCloud Drive's Desktop and Documents.** If the Mac keeps Desktop and Documents in iCloud (a job's `ls ~/Library/Mobile\ Documents/com~apple~CloudDocs` lists a `Desktop` and a `Documents`), offer them as an optional extra: they go in marked `"sometimes": true`, so they're left out of the weekly backup, and copied only in a week when you ask and the owner says yes. Tell them why: copying them makes the Mac download every file it keeps only in iCloud (they show as small or empty files until then), which takes much longer. If Desktop and Documents are only on the Mac, they're ordinary folders: in or out like anything else.
Then write `skills/backup/my-folders.json`:
```json
{
  "about": "What the backup copies to the owner's cold storage drive, read by backup.py. 'repos': other repos to keep a full copy of, by owner/name, beside the brain. For each computer, 'folders': what the owner asked for. 'to' is the folder on the drive. 'once': copy it the first time, then leave it. 'skip': folders inside it to leave out. 'skipNamed': folder names to leave out at any depth. 'sometimes': only when the owner says yes that week (--sometimes). Paths can use ~ (and %USERPROFILE% on Windows).",
  "repos": [
    { "repo": "their-github-name/their-website" }
  ],
  "computers": {
    "<the computer's name, as the job prints it>": {
      "folders": [
        { "from": "~/Work/Shop accounts", "to": "Shop accounts" },
        { "from": "D:\\Projects", "to": "Projects", "skipNamed": ["node_modules"] },
        { "from": "~/Desktop", "to": "Desktop", "sometimes": true },
        { "from": "~/Documents", "to": "Documents", "sometimes": true }
      ]
    }
  }
}
```
Commit it, and push it before the job starts: the job runs the owner's copy of the brain, which catches up first. The computer's name is the one the job prints (`== Backup to ... from <name>`), which is the computer's own name; it's also the computer's folder on the drive. A second computer gets its own entry under `computers`, set up the same way the first time it backs up, and its own folder on the drive, so two computers' "Documents" never mix; `repos` serves them all. When they want something added or dropped later, change the file.

**A private repo** needs a way in. The job first tries the computer's own sign-in to GitHub. If that fails (the summary says the repo couldn't be reached), the owner makes a read-only token for it, and it goes in the brain's Actions secrets as `BACKUP_GITHUB_TOKEN`, which the runner's workflow hands the job (the add-a-key skill; never in chat or a file). The token: on GitHub, Settings > Developer settings > Personal access tokens > Fine-grained tokens > Generate new token; repository access, the repos in the list (or all); permissions, Contents read-only; the longest expiry. With the token, the job can also take the brain itself from GitHub when it runs from a job's checkout.

**On a Mac, the owner sits beside the first one.** macOS asks before the runner reads Desktop, Documents, Downloads, Pictures, Movies or Music, and before it writes to an external drive, and a job nobody answers is simply refused ("no access" in the summary). The Mac's setup asks for the folders while the owner is there (the my-mac skill); the drive's question comes with the first backup, so tell them: "Your Mac may ask whether it can use the drive and your folders: click Allow."

**Run it.** Start the runner's workflow with no checkout (the script runs from the owner's own copy of the brain, which has its full history; a job's checkout has only the last commit):
- **Windows,** `pc-run.yml` ([my-pc](../my-pc/SKILL.md)), shell `powershell`, timeout 240:
  ```
  # Backup to the cold storage drive
  $py = Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1 -ExpandProperty FullName
  if (-not $py) { winget install --id Python.Python.3.12 -e --scope user --silent --accept-source-agreements --accept-package-agreements | Out-Host; $py = Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe" | Select-Object -Last 1 -ExpandProperty FullName }
  & $py "C:\AI-Brain-Link\<repo name>\skills\backup\backup.py" run --drive auto
  ```
- **Mac,** `mac-run.yml` (the my-mac skill), shell `bash`, timeout 240:
  ```
  # Backup to the cold storage drive
  python3 ~/AI-Brain-Link/<repo name>/skills/backup/backup.py run --drive auto
  ```
**The sometimes folders:** if `my-folders.json` has any, ask in the same message as the drive: "Shall I include your iCloud Desktop and Documents this time? It takes longer." Only on a yes, add `--sometimes` to the command. A sometimes folder can trip the tripwire after weeks away, since more has changed; ask the owner as below, and `--force` it if they say the files are fine.

`--drive auto` takes the one external drive plugged in; with more than one, it lists them and stops, so run it again with `--drive E:\` or `--drive "/Volumes/<name>"`. `--dry-run` says what it would copy, and whether each repo can be reached, and changes nothing; `--brain-only` does the brain and the repos and skips the folders. `python3 backup.py drives` lists the drives it sees, with each one's format.

**Read the summary** at the end of the job log: a line for the brain, each repo and each folder (new, changed, the same, gone from the computer and kept), then the drive's free space. Exit codes: 0 done (maybe with warnings), 1 something failed, 2 the tripwire stopped a folder, 3 no drive, 4 the drive isn't exFAT ([above](#the-drives-format)). The first backup copies everything and can take an hour or more for big folders; later ones copy only what changed. Then tell the owner it's done and they can unplug the drive, with any warning in a line.

## What's on the drive
Everything goes in `Brain backup/` on the drive:
```
Brain backup/
  brain/<repo>/        the one full git copy of the brain, and of each repo in `repos`, named after its repo, updated
                       by fast-forward only; every computer brings them up to date, so there's one copy, not one per computer
  <computer>/          one folder per computer, by the computer's own name (DESKTOP-7Q2KF, Sallys-MacBook-Air)
    <to>/              each folder chosen on that computer, by the name in `to`
    _older-versions/<date>/   the old copy of any file that changed, from that backup
    _backup-log/<date>/       what each backup copied, file by file (the job's own log has counts and names only)
    _backup-state.json        what each folder held last time, for that computer's tripwire
  README.txt           how to restore, for someone with no agent to hand
```
## The rules it keeps
- **It only reads on the computer.** It never changes, moves or deletes anything there.
- **It never deletes or overwrites anything on the drive.** A changed file's old copy moves to `_older-versions/<date>/` first; a file deleted on the computer stays on the drive.
- **The tripwire.** If more than 10% of a folder's files (and at least 200) changed or vanished since the last backup, which is what ransomware looks like, that folder is left alone and the run ends with code 2.
- **It refuses a drive on the same disk** as the computer's own files, which wouldn't be a separate copy.
- **It never formats a drive,** and stops on one that isn't exFAT ([the drive's format](#the-drives-format)).

## If the tripwire goes off
Tell the owner which folder, and ask them to open a few of its files.
- **They open fine** (they reorganised or re-saved a lot): run it again with `--force "<the folder's to name>"`. Old copies are kept as usual.
- **They don't open, or have odd new names:** don't run the backup again. Tell them to unplug the drive and keep it unplugged, and that the computer should be treated as infected: a clean reinstall, then their files back from the drive.

## Log it
A heading in the backup log (`knowledge/systems/backup-log.md`), dated today (UTC), newest first: `## <date>: backup`, with the run's link and the summary's counts; or `## <date>: skipped`, when the owner says no at the tidy-up.

## Restoring
- **Files:** copy them back from the computer's folder on the drive. An older version of a changed file is in that computer's `_older-versions/<date>/`.
- **The brain, or a repo:** `git clone "<drive>/Brain backup/brain/<repo>" <repo>` gives a working copy with all history, which can be pushed to a new GitHub repo if the old one is gone.
