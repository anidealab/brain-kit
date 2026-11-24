# AnIdeaLab's set-up tools

For the second brain set up for you (AnIdeaLab's paid set-up), not part of a brain. A brain's own owner brings their files in with the brain's file-intake skill, choosing what goes in; this folder is what AnIdeaLab runs for a set-up buyer, so they don't have to pick out or send any files.

**Index my computer** finds the documents the buyer worked on in the last 12 months and turns them into text, for the agent doing the set-up to write up as notes in their brain with the file-intake skill (from its step 2). It runs as a job on the buyer's runner, which the set-up's command (the kit's installer with `BRAIN_KIT_SETUP=1`) sets up.
- **What's searched:** Desktop, Documents, Downloads, every OneDrive folder, the other folders in the home folder and, on Windows, the other fixed drives' folders. Left out: the system's, apps', browsers' and the brain's own folders, and cloud drives' folders (Dropbox, Google Drive, iCloud Drive: a later step).
- **What goes in:** documents only (PDF, Word, Excel, PowerPoint, email, plain text and notes) changed in the last 12 months, and each code project (a folder with `.git`) as one row saying where it is. Exact copies are found and left out.
- **What's only counted, never listed or read:** photos, video and audio, archives, code and apps' files; anything named like passwords or keys; and a document whose text turns out to hold them, which is dropped after reading.
- **Nothing on the computer is changed, moved or copied.** The job writes only its work folder, `_intake/computer` in the brain's folder on the computer (`C:\AI-Brain-Link`, `~/AI-Brain-Link`), and attaches it to the run for the agent: `index.md` (what was searched, what went in and what was left out), and `files.txt`, `survey.md` and `text/` as the file-intake skill's survey and convert make them. uv, the Python it brings and MarkItDown are put in a folder of their own and taken off again at the end.

The files:
- [index-computer.py](index-computer.py): the search and the text, with the brain's [intake.py](../brain/skills/file-intake/intake.py), which it downloads beside itself.
- [index-computer.ps1](index-computer.ps1) (Windows) and [index-computer.sh](index-computer.sh) (Mac): the job's command, which gets the tools and runs it. Each file's top says the command, with the kit commit to pin it to.
