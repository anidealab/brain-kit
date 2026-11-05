# Working on the AnIdeaLab brain kit

This repo is the brain kit: the brain a new owner starts with, the installer that sets it up on their PC, and the brain updates that brains made from it get. You're working on the kit, not in a brain. What each folder is: [README.md](README.md#whats-here).

**brain/CLAUDE.md is not for you.** It's the core a new owner's agents read, so if it shows up in your context, it's the file you're editing, and its instructions (getting started, guide mode, the owner's defaults) are for their brain. `{KIT_DATE}` and `{KIT_ISO}` in brain/ stand where each brain gets its own start date: leave them as they are.

**The kit stands alone.** Nothing in it names or depends on any one person, their brain or their accounts: it's AnIdeaLab's. A rule's reason is given in the kit's own words. What owners' brains report back, and what AnIdeaLab learns from its own use, comes in as a change made here, never as a copy of someone's files.

## Changing the kit
1. **Change the files here directly.** brain/ is the source: nothing else writes it.
2. **Run `python3 tools/kit.py build`** after every change. It rebuilds brain/'s indexes, copies [sign-off-links.md](sign-off-links.md) into brain/, makes a new brain from brain/ in a scratch folder, and runs that brain's own checks and tests, and the kit's promises: no one person's names, accounts or setup anywhere in the repo (the copied skills aside, kept as they came), every date placeholder filled, the core under 6 KB (a core may be 8 KB, so each owner has 2 KB for their own lines), and as many skills as START-HERE.txt says. Fix what it reports before you commit.
3. **Copied skills** are kept as they came, and brought up to date from their own sources: from brain/, run `python3 skills/brain-spec/skill_updates.py check`, then `update --source <owner/repo>` for a set that changed, read the diff, and run the build. Where each came from: [brain/skills/lists/sources.md](brain/skills/lists/sources.md).
4. **Commit to `main`** in small commits with plain messages, with `git pull --rebase origin main` before you start and before you push. Never force-push.

## How a change reaches owners
A new brain is made from brain/ as it is on `main`, and marked with the newest update in updates/. A brain already made gets a change only through a brain update, which its owner says go to. Nothing here reaches a brain yet: the kit has no owners until its installer is handed out and brains made elsewhere are pointed here.
