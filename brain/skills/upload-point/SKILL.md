---
name: upload-point
description: "The upload point: My brain in File Explorer's Send to menu on the owner's Windows PC, where they send files and folders for the brain, listed by path in a plain text file on the PC. How the owner uses it, how to set it up again, how to read and clear the list from a session on the PC or a cloud session, and how to sort what's waiting: files moved into the brain or onto the PC, code repos learned where they are, a big drop passed to file-intake. Use when the owner mentions the upload point, Send to, or files they sent or dropped, or the session start says something's waiting."
---

# The upload point
A way for the owner to hand the brain files or folders of any kind, straight from File Explorer. An agent then works with them, or sorts them into the repo, the PC's `C:\AI-Brain-Link\` folder or the skills, so nothing that was sent needs keeping twice. **Windows only: a Mac has no Send to.**

## What the owner does
1. **Sends things:** selects files or folders in File Explorer, right-clicks, and picks Send to, then My brain (on Windows 11, Send to is under "Show more options"). A small box says "Sent to your brain: 2. Tell Claude what to do with them."
2. **Tells you what to do with them,** in a session: "sort what I sent", "make a note from the quote", "learn this project".

That's all of it, on purpose: no window to keep open, and nothing to sign in to.

## How it works
- **Paths, not copies.** Send to keeps only where each thing is, so a code repo or a big video isn't duplicated or pulled out of place. The one exception: anything on a USB stick or other removable drive is copied to `C:\AI-Brain-Link\_upload\<date>\` first, since the stick may be gone when you look, and the copy is what's listed.
- **The list is a plain text file on the PC,** `C:\AI-Brain-Link\_upload\waiting.txt` (the `_upload` folder beside the brain's copy), outside the repo: one line per thing, the time it was sent, a tab, and its path, like `2026-10-31 14:02	C:\Users\Sam\Downloads\quote.pdf`. No file, or an empty one, means nothing's waiting. A path already on the list isn't added twice. It's on the PC and not in the repo so that sending needs no GitHub sign-in and can't clash with Obsidian Git; the price is that only something running on the PC can read it.
- **At session start,** `reminders.py` says how many things are waiting when the session runs on the owner's PC, in the brain's copy. A cloud session isn't told: the owner says when they've sent something, and you look.
- **The files here:** [upload-point.ps1](upload-point.ps1), what Send to runs (Windows PowerShell 5.1, nothing to install); [setup-upload-point.ps1](setup-upload-point.ps1), which makes the Send to entry; [look.ps1](look.ps1), which reads the list and takes lines off it.

## Reading and clearing the list
- **From a cloud session,** one job on the PC ([my-pc](../my-pc/SKILL.md)): `pc-run.yml` with `checkout` on and the command `& "$env:GITHUB_WORKSPACE\skills\upload-point\look.ps1"`. For each path it says when it was sent, whether it's there, its kind and size, and a peek inside: a folder's top two levels, a text file's first lines, and for a code repo its remote, latest commits, what isn't committed, and the start of its README and `CLAUDE.md`. A look changes nothing. To take what you've dealt with off the list, the same job with `-Done` and the paths exactly as listed: `& "$env:GITHUB_WORKSPACE\skills\upload-point\look.ps1" -Done 'C:\Users\Sam\Downloads\quote.pdf','D:\Old drive'` (an apostrophe in a path is written twice). It says what's still waiting.
- **From a session on the PC itself** (Claude Code in the brain's copy), read `C:\AI-Brain-Link\_upload\waiting.txt` directly, or run `powershell -ExecutionPolicy Bypass -File skills\upload-point\look.ps1` for the same look. Clear a line by deleting it from the file, or with `-Done` as above.
- **If the brain's copy isn't in `C:\AI-Brain-Link`** ([the PC's note](../../knowledge/systems/my-pc.md) says where it is), the list is in `_upload` beside it, and a job names it: `look.ps1 -List '<that folder>\_upload\waiting.txt'`.
- **To add a path yourself,** when the owner tells you where something is and you'd like it kept on the list: a job running `powershell -ExecutionPolicy Bypass -File "C:\AI-Brain-Link\<repo name>\skills\upload-point\upload-point.ps1" -Quiet "<path>"`. `-Quiet` prints the message where Send to would show its box.

## Setting it up
The installer runs the setup when it makes the brain. For a brain set up before the upload point, when Send to has lost its entry, or after a brain update that changed the upload point, give the owner this to paste into PowerShell (no admin rights needed, safe to run again):
```
powershell -ExecutionPolicy Bypass -File "C:\AI-Brain-Link\<repo name>\skills\upload-point\setup-upload-point.ps1"
```
It makes "My brain" in Send to, running `upload-point.ps1` from this folder in the brain's copy, so a change to the script reaches the PC with Obsidian Git's next sync. It also takes away the "Upload point" shortcut that earlier versions put on the desktop: the window it opened is gone, and that shortcut would now only say how to use Send to.

## Sorting what's waiting
1. **Read the list** ("Reading and clearing the list" above), and do what the owner asked. If they didn't say, sort everything into the brain as below, but first ask about anything unclear or personal: what a file is, whose it is, or where it should live.
   - **A big drop goes to [file-intake](../file-intake/SKILL.md).** When what's waiting is more than about 30 documents (`look.ps1` says how many files a folder holds), or a folder that mixes several projects or years, don't sort it here: one agent reading it all gets things wrong and can't say what it missed. That skill surveys the pile first (`intake.py survey --upload-list`, run on the PC, reads this list), picks a method by its size and kinds, and keeps a list of what every file became. The steps below are its "small" method, for a few files.
2. **Look at them on the PC,** with `look.ps1`: it changes nothing. If a path isn't there any more (a drive unplugged, a file moved), ask the owner.
3. **Files that belong in the brain,** up to about 25 MB each (documents, PDFs, spreadsheets, notes, the images a note is about), move into their place in the brain's copy on the PC, next to the note each becomes, and are pushed from there, so you can read them in your session. One job does them all; the brain's copy is `C:\AI-Brain-Link\<repo name>`, or the folder in [the PC's note](../../knowledge/systems/my-pc.md):
   ```
   # Upload point: the quote, into the brain
   $copy = 'C:\AI-Brain-Link\<repo name>'
   $moves = @'
   C:\Users\Sam\Downloads\quote.pdf | knowledge/areas/money/2026-10-31-quote.pdf
   '@ -split "`r?`n" | Where-Object { $_.Trim() }
   git -C $copy pull --rebase --autostash
   foreach ($line in $moves) {
     $from, $to = $line -split '\s*\|\s*', 2
     $dest = Join-Path $copy $to
     if (Test-Path -LiteralPath $dest) { "already there, not moved: $to"; continue }
     New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
     Move-Item -LiteralPath $from -Destination $dest
     if (Test-Path -LiteralPath $dest) { git -C $copy add -- $to; "moved: $to" } else { "NOT moved: $from" }
   }
   git -C $copy commit -m 'Upload point: the quote, into the brain'
   git -C $copy push
   ```
   The here-string keeps each path exactly as written, apostrophes and all, so copy them from the list; the `'@` stays at the start of its line. Then pull, read each file, and write its note beside it, saying the file next to it is the raw original. If the job's push failed, the commit is in the copy, and Obsidian Git pushes it at its next sync.
   - **Bigger files and media** (video, audio, big sets of images, zips, installers) stay on the PC, not in the repo: code lives in the repo, data lives on the PC ([my-pc](../my-pc/SKILL.md)). A job moves them to `C:\AI-Brain-Link\<Project>\...`, and a note in the brain says what's there and where.
   - **A folder that's a skill** (it has a `SKILL.md`) moves into `skills/<name>/`, with its line in a topic list ([the brain spec](../brain-spec/SKILL.md#a-skill)); one from somewhere else is recorded the way [find-skills](../find-skills/SKILL.md) says.
   - **A copy from a USB stick,** in `C:\AI-Brain-Link\_upload\<date>\`, is sorted like any other file; delete the date's folder once it's empty.
4. **Code repos are learned, never moved or copied:** their progress and decisions, a quick look at their files for a general picture, and in-depth knowledge here and there, all saved to the brain, so an agent is ready to work on the project when asked. So read it where it is: through jobs on the PC (its README, `CLAUDE.md`, docs, `git log`, its folders and the files that matter), or from GitHub if it has a remote your session can reach. Then save a note for the project on the ventures shelf (a folder once it has several notes): what it is and its goal, where it lives on the PC and its remote, where it stands and what's next, the decisions its history shows (dated, with where each came from), how to build, run and test it, a map of its code, and in-depth notes on the parts that matter.
5. **Move, don't copy,** so nothing's kept twice. But leave a thing where it is when moving it would break something: a file inside a code repo or an app's folder, or a folder something syncs. Its note says where it is.
6. **Take what's done off the list,** with `look.ps1 -Done` and its paths, or by deleting its lines from the file in a session on the PC. Leave what you haven't dealt with. Tell the owner in a few lines where things went.
