---
about: "The upload point: the owner right-clicks files or folders on their PC and picks Send to, My brain, and each path goes on a plain text list on the PC, C:/AI-Brain-Link/_upload/waiting.txt, for an agent to sort into the brain. Read when the owner mentions sending or dropping something."
tags: [the-brain]
updated: {KIT_DATE}
---
# The upload point

The owner selects files or folders in File Explorer, right-clicks, and picks Send to, then My brain. Each one's path is added to a list on the PC, and an agent sorts them into the brain when the owner says what to do: the [upload-point skill](../../skills/upload-point/SKILL.md).

- **The list** is `C:\AI-Brain-Link\_upload\waiting.txt`, a plain text file on the PC, outside this repo: one line per thing, the time it was sent, a tab, and its path. It isn't in the brain, so nothing here says what's waiting.
- **Reading it:** a session on the PC opens the file; a cloud session runs one job on the PC, `skills/upload-point/look.ps1`, which also takes a line off once its thing is sorted (`-Done`).
- **A USB stick's files** are copied to `C:\AI-Brain-Link\_upload\<date>\` first, and the copy is what's listed.
- **Send to's entry** is "My brain" in the owner's Send to folder; `skills/upload-point/setup-upload-point.ps1` makes it again.
