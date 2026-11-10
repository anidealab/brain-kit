---
name: file-intake
description: "Bringing a pile of the owner's unsorted files into the brain as proper notes, accurately: a look-first survey of the pile, a table for picking the method by how much there is and what kind, one agent per subject for a big pile, a links agent, and a list of every file and what it became. Use when the owner has more than a few dozen files to bring in (a first session's documents, a big drop on the upload point, an old drive or folder), or asks to index, import or sort a lot of files."
---

# Bringing a pile of files in
An owner's files arrive unsorted: years of documents, several projects mixed together, copies, scans, photos. The job is to turn them into the brain's notes without getting anything wrong and without missing anything. One agent reading the whole pile does it badly: its memory fills with every subject at once, detail gets summarised away, and nobody can say afterwards which files were read. So look first, pick the method the pile needs, give each subject to an agent with a clear head, and keep a list of every file and what it became.

A few files need none of this: the [upload-point skill](../upload-point/SKILL.md) sorts those. This skill starts where its "Small" row ends.

## The steps
1. **Look first,** before reading anything: run the survey over the pile, then turn its documents into text ([below](#the-look-first-step)). It costs almost none of the owner's plan, and tells you how many files there are, what kinds, which folders hold what, which are copies, and how much reading there is.
2. **Pick the method** from [the table](#picking-the-method), by the survey's numbers and what's in the pile.
3. **Give the owner the plan** (guide mode): what's there in a few lines, the subjects you'd split it into, the method and how many agents, what will only be listed (photos, video), and the questions only they can answer: are the subjects right, what matters most, is there anything to leave out. Wait for their go. More than two agents at once needs their yes, so ask here, once.
4. **Split the pile** into subjects in `split.txt` and run `split` ([below](#splitting)). Cut any subject the script flags as too big for one agent.
5. **Brief one agent per subject** ([the brief](#a-subject-agents-brief)), one or two at a time. Each reads its subject's files, writes that subject's notes, records what every file became, and reports back.
6. **Check each report once** as it lands: read it, open two or three of its notes against the text they came from, and fix or send back what's wrong.
7. **The links agent,** when there were two or more subjects: it reads the reports, not the files, and reports what crosses between subjects ([its brief](#the-links-agents-brief)). It doesn't edit.
8. **The coordinator writes what crosses:** the links, the people's notes, tasks for dates and deadlines, and the questions for the owner, from the reports. Only the coordinator writes outside a subject's own folder, so agents side by side never clash.
9. **Account for every file:** run `check`, fix what it lists, and save the pile's record ([below](#the-file-list)). Run the brain spec's "Before you push", and tell the owner in a few lines what the brain now knows, what was left out and why, and what they need to answer.

## Picking the method
By size, from the survey's last lines. The numbers are starting points: a pile of short letters is lighter than its count, and a tangle of subjects is heavier.

| The pile | About | The method |
|---|---|---|
| **Small** | Up to 30 documents, 100,000 tokens of text | The coordinator sorts it alone, the upload point's way. No agents; the survey is optional |
| **Medium** | Up to 150 documents, 300,000 tokens, one or two subjects | The survey, then one or two subject agents. A links agent only if there are two |
| **Big** | Up to about 1,500 documents, 2 million tokens, several subjects | Every step above: an agent per subject, one or two at a time, then the links agent |
| **Huge** | More than that | Too big for one chat. Ask the owner what matters first, and bring it in a few subjects at a time, with the job's task note brought up to date after each round ([handoff](../handoff/SKILL.md)); the file list carries over, so each chat starts from what's left |

- **One agent reads about 150,000 tokens of text** (the script's `split` says when a subject is over). Past that, cut the subject by year, by sub-folder or by kind into pieces of that size, each with its own agent under the same coordinator, and let the links agent join them. Don't add a second coordinator between: every layer of reports loses detail.
- **A subject is whatever the owner would call it:** a business, a project, a client, the house, tax. The folders usually show them. When they don't (one flat folder of everything), have one agent read the survey and a sample of twenty or so files' first lines and propose the subjects and the patterns for `split.txt`, before any subject agent starts.

By kind, whatever the size:

| Kind | What happens |
|---|---|
| Documents with text (PDF, Word, Excel, PowerPoint, email, web pages, plain text) | Turned into text, read, and made into notes |
| Exact copies | Found by the survey and left out; the list says which file each is a copy of |
| Versions of one document (a draft and a final, an old quote and a new one) | Both read. The note takes the newest as true, and says what the older one said where it differs |
| Scans and photos of documents (a PDF with no text) | A few: the agent opens them itself, if it can read images. Many: text recognition on the PC with a free tool, as a job, with the owner's yes to installing it. Otherwise listed |
| Old formats (.doc, .ppt, .rtf) | Listed with what they seem to be. If they matter, the owner opens and saves them in the newer format, or a job on the PC converts them |
| Photos, video and audio | Listed, not read: what's there, where, how many and from when. Transcribing or describing them is a job of its own on the PC, if the owner asks |
| Spreadsheets of data | The note says what the data is, its columns, its dates and its totals; the data stays in the file |
| Code repos | Learned where they are, one agent each if they're big, the way the upload point's step 4 says. The survey lists a repo as one row and doesn't walk it |
| Zips and other archives | Listed. Ask the owner before unpacking one; unpacked, it's surveyed like any folder |
| Apps' and the system's files | Skipped by the survey, and counted |

## The look-first step
[intake.py](intake.py) is plain Python 3 with nothing to install for the survey. Everything about one pile goes in a **work folder outside the repo** (`C:\AI-Brain-Link\_intake\<name>` on the PC): the file list, the survey, the text and the agents' outcome files. The pile itself is never changed, moved or copied.
```
python3 skills/file-intake/intake.py survey <folder or file>... --work <work folder>
python3 skills/file-intake/intake.py convert --work <work folder>
```
- **`survey`** walks the paths (or `--upload-list knowledge/systems/upload-point.md`, for what's waiting at the upload point) and writes `files.txt`, one row per file, and `survey.md`: counts by kind and by folder, copies, repos, the biggest files.
- **`convert`** writes each document's text to `text/<id>.md`, and adds how much reading there is, and the method that points to, to `survey.md`. Plain text needs nothing. PDF, Word, Excel, PowerPoint and email need [MarkItDown](https://github.com/microsoft/markitdown) (Microsoft's, free, MIT licence): `python -m pip install "markitdown[all]"`. Tell the owner you're installing it. It's safe to run again, and skips what's done.
- **In a session on the owner's computer,** run them directly.
- **In a cloud session,** the files are on the PC, so run both as one job ([my-pc](../my-pc/SKILL.md)) with `checkout` on and `artifact` set to the work folder, then download the artifact into a scratch folder: that copy is your work folder, and the agents you brief read the text from it. If the PC has no Python (the PC's note says), a job installs it first (`winget install --silent Python.Python.3.12`), and the runner restarts before the next job, as the my-pc skill says.
  ```
  # File intake: survey and text for <name>
  $work = 'C:\AI-Brain-Link\_intake\<name>'
  $tool = "$env:GITHUB_WORKSPACE\skills\file-intake\intake.py"
  python $tool survey 'C:\Users\Sam\Documents\Old laptop' --work $work
  python -m pip install --quiet "markitdown[all]"
  python $tool convert --work $work
  ```
- **On a Mac,** the work folder is `~/AI-Brain-Link/_intake/<name>`, Python is `python3`, and the job runs through the Mac's own runner (its skill says how).
- **When the pile came through the upload point,** take its lines off that list once `check` passes, as the upload-point skill's last step says. The files stay where they are.
- **The text stays out of the repo.** It's a working copy, it can be made again, and it may hold passwords the secrets gate keeps out of commits.

## Splitting
Write `split.txt` in the work folder, one line per rule, and run `split`:
```
# subject: the start of a path, a wildcard, or ids from files.txt. The first line that fits wins.
cafe: C:\Users\Sam\Documents\Cafe
cafe: id 31,40-44
house: *\house\*
money: *.xlsx
```
```
python3 skills/file-intake/intake.py split --work <work folder>
```
It puts each file in its subject, writes `subject-<name>.txt` for each agent (its files, each one's kind, and where its text is), prints each subject's size with a flag on any that's over one agent's reading, and lists the files in no subject. Every file ends up in a subject or in the coordinator's own outcomes file, `outcomes-coordinator.txt`.

## A subject agent's brief
A brief is a hand-off with `kind: brief`, in the [handoff skill's](../handoff/SKILL.md#briefs-and-reports) format, and the report comes back the same way. Put in it:
- **The subject, and what the owner said about it,** in their words: what it is to them, what they want the brain to be able to do with it.
- **Its files:** the path of `subject-<name>.txt` and of the work folder. "Read every file in the list: the text where there is one, the file itself where there isn't and you can open it."
- **Where its notes go:** one folder, usually `knowledge/ventures/<subject>/` (an area or a subject of the open library if that's what it is), in the brain spec's shapes: a `README.md` saying what it is, where it stands and what's in the folder, then a note per thing worth its own (a lease, a supplier, a consent, a year's accounts). Update a note that's already there rather than adding a second.
- **The rules that keep it accurate:**
  - Write only what a file says. Date every fact and name the file it came from, by its file name, in the note: `check` looks for the name. Mark anything you worked out as a guess.
  - A note says what's known, not everything in the file: the figures, dates, names, terms and decisions someone would need next year, and where the file is for the rest.
  - Where two files disagree, take the newest as true and say what the older one said.
  - Never copy a password, PIN, key or card number into a note: say which file holds it (the core's secrets gate).
  - Something a document shows the owner decided is written as what the document shows, with its date and file, never as a new decision of theirs (the core's "the owner's voice").
- **Stay in your folder.** People, tasks, decisions and anything belonging to another subject go in the report, not in notes outside the folder: the coordinator writes those. An idea found in the files is a note in your folder, named in the report so the coordinator can move it to the ideas shelf. What a project's `README.md` usually has and the files don't give (its goal, its code repo), say isn't known rather than guess.
- **Before you commit,** run `library.py build`, `library.py check` and `check_links.py`, and fix what they say about your own notes.
- **Record every file** in `outcomes-<subject>.txt` in the work folder, one tab-separated line each: its id, then `note` and the note's path in the brain, or `listed` and the note that lists it (photos, media, old formats, a scan you couldn't read, a file that holds only passwords or codes), or `skipped` and why. Exact copies aren't on your list: the survey dropped them, and `files.txt` says which file each copies. A file on the list that turns out to belong to another subject is still yours to record: note what it says in your folder's `README.md`, and name it under "what crosses" in the report.
- **Commit only your own paths,** in small commits as you go, and push. `library.py build` also rewrites the shelves' indexes outside your folder: leave those uncommitted, and the coordinator commits them.
- **The report:** what the subject is and where it stands, in a short paragraph; the notes written; then four lists, each line naming its file: **people** (name, who they are, contact details), **dates and deadlines** still ahead, **what crosses** into other subjects (a person, a place, money, a dependency), and **questions for the owner** (what a file didn't settle, what looked wrong, what you couldn't read).

## The links agent's brief
- **Its reading:** the subject agents' reports, and each subject's `README.md`. Not the files, and not the other notes unless a report points at one.
- **Its job:** find what crosses between subjects and say where each link belongs: the same person, company or place in two subjects; money moving from one to another; one subject's date that another depends on; two subjects that state the same fact differently, with which file is newer; and the same question asked twice.
- **It doesn't edit.** It reports a list the coordinator can act on line by line: the two notes, the link or fix to make (a link goes in both notes), and the files or report lines it rests on. Then the people who appear in more than one subject, merged, one line each for the people shelf, and the questions for the owner, merged. Where two subjects disagree and no dated file settles it, it says so: both become a guess, and it's a question for the owner.
- **Every subject needs a report for it to read,** the coordinator's own included: a subject the coordinator sorted itself gets the same short report, with the same four lists, or its side of every link is thin. Reports are tagged with their subject.

## The file list
`files.txt` is what makes "nothing was missed" checkable. When the agents are done:
```
python3 skills/file-intake/intake.py check --work <work folder> --record knowledge/areas/the-brain/intake/<date>-<name>.md
```
- It reads every `outcomes-*.txt` and lists each file with no outcome, each note that isn't there, and each note that doesn't name the file it's said to come from. Fix those (finish the file, or give it an outcome and a reason) until it says every file is accounted for.
- `--record` writes the pile's record: where it came from, the tally, the notes by subject, what was left out and why, with the whole list saved beside it. Fill in its "How it went", and give its folder a `README.md` if it's the first (the brain spec's shelves).
- **The owner's files stay where they were.** Each note names its files, and the record's list has every path. Move or delete nothing from a pile unless the owner asks; if they'd like the originals gathered, that's a job of its own, under the upload point's rules for what goes in the repo and what stays on the PC.
- **A huge pile's rounds:** at the end of each round, run `check --record` as it stands. The record says "not finished", and its list is what the next chat starts from: copy it into the new work folder as `files.txt`, and `convert` makes the text again.

## When it lets you down
Add a dated line to a `LESSONS.md` in this folder (the brain spec's "How skills learn"), above all when the table's numbers were wrong for a pile: how many documents and tokens it had, the method used, and what it should have been.
