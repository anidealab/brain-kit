# The AnIdeaLab brain kit

A second brain for working with AI agents: a private GitHub repo of plain Markdown that agents work from. It has a core every agent reads (`CLAUDE.md`), a library of skills for how to do things, and a knowledge library of what the brain knows, with a custom AnIdeaLab Obsidian plugin to see it and a runner on the owner's PC or Mac for jobs that need it. An owner starts one with one command, in PowerShell on Windows or Terminal on a Mac ([Install](#install)).

## Install
**On a Windows PC,** open PowerShell (press the Windows key, type powershell, press Enter), paste this line and press Enter:

```
irm https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/install.ps1 | iex
```

[install.ps1](install.ps1) downloads this repo as a zip (no Git needed yet), unpacks it in a temporary folder and runs [install/install-windows.ps1](install/install-windows.ps1) from it, which:
- asks you to accept AnIdeaLab's [terms of use](TERMS.md) first (Y or N), and stops if you don't;
- installs Git, GitHub's command line and Obsidian if they're missing, and signs you in to GitHub in your browser;
- makes your brain from [brain/](brain/), as of the newest update, with the day you install it as its start, and puts it in a new private repo on your GitHub account;
- invites AnIdeaLab's testing account to that repo, as the terms say;
- puts your copy in `C:\AI-Brain-Link\<your brain's name>`, set up for Obsidian with your edits syncing to GitHub;
- adds the upload point, a desktop shortcut and a Send to entry for giving your brain files;
- sets up the PC runner, so AI agents can run jobs on your PC. It asks for admin rights and your Windows password;
- opens your brain in Obsidian, last, so it can't hide a question in the PowerShell window.

It's safe to run again: it skips what's already done. Its questions show in yellow, and a click in its window can't pause it. At the end it lists each step and how it went, keeps that in `C:\AI-Brain-Link\_logs\install.log` (which the brain's setup check reads), and says what to send Claude to get started. The steps in plain words, to send someone: [install/START-HERE.txt](install/START-HERE.txt).

**On a Mac,** open Terminal (press Command and Space, type terminal, press Enter), paste this line and press Enter:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/install.sh)"
```

[install.sh](install.sh) downloads this repo (no Git needed yet), unpacks it in a temporary folder and runs [install/install-mac.sh](install/install-mac.sh) from it, which takes the same steps in the same order, with the same questions, the Mac's way:
- Git comes with Apple's command line tools, which macOS offers to install in a window of its own; GitHub's command line and Obsidian come from their own releases on GitHub, each checked against its checksum. There's no Homebrew, and nothing asks for your Mac's password;
- your copy goes in `~/AI-Brain-Link/<your brain's name>`, and the log in `~/AI-Brain-Link/_logs/install.log`;
- the brain gets its Mac parts, since [brain/](brain/) is made for a Windows PC: the Mac runner's workflow, skill and note from [install/mac-brain/](install/mac-brain/), and its lines about the PC and PowerShell said for a Mac;
- the Mac runner runs as a LaunchAgent under your account, so agents can run jobs on your Mac while it's on and you're logged in, and it offers to keep the Mac awake on the charger;
- there's no upload point window on a Mac yet: you put files for your brain in `~/AI-Brain-Link/_upload`.

The steps in plain words, to send someone: [install/START-HERE-MAC.txt](install/START-HERE-MAC.txt). GitHub's own Macs try it on each change ([the workflow](.github/workflows/mac-installer.yml)).

## Brain updates
AnIdeaLab sends fixes, new rules and new parts to brains made from the kit. A brain checks for new ones once a day, when its owner starts a session, and its weekly tidy-up checks too; its agent reads the owner a short summary of each, and applies it only if they say go. After applying one, `brain_update.py compare` checks the whole brain against `brain/` as it is at that update, the exemplar.

## What's here
- **[brain/](brain/)**: the kit's brain as a new one gets it, with `{KIT_DATE}` and `{KIT_ISO}` where each brain has its own start date.
- **[install.ps1](install.ps1), [install.sh](install.sh) and [install/](install/)**: the one command's script for Windows and for a Mac, and the installers and START-HEREs they run and point to, with the parts a Mac brain gets in [install/mac-brain/](install/mac-brain/).
- **[sign-off-links.md](sign-off-links.md)**: which AnIdeaLab.com page the sign-off links to, by the reader's field. A brain's daily update check takes the newest copy by itself, without asking its owner.
- **[updates/](updates/)**: one message per update, newest last, each starting with a summary for the owner. The commit that added each one holds `brain/` as of that update, and `brain_update.py` merges the difference into a brain with a three-way merge, so the brain's own changes elsewhere stay.
- **[inbox/](inbox/)**: after each update, a brain sends a report of how it went to AnIdeaLab's private inbox, so the kit gets better.
- **[TERMS.md](TERMS.md)**: AnIdeaLab's terms of use for the kit, which the installer asks each owner to accept.
- **[testing/](testing/)**: AnIdeaLab's scripts for its testing account, which the installer invites to each new brain's repo, as the terms say: `diagnostic-setup.ps1` invites it to a brain made before the installer did, and `copy-brains.ps1` copies the brains it's invited to.
- **[tools/kit.py](tools/kit.py)**: the kit's build, which checks it after each change (a brain made on a Mac too), and makes the zip a Windows owner can install from instead of the one command. How to work on the kit: [CLAUDE.md](CLAUDE.md).
- **[.github/workflows/](.github/workflows/)**: the kit's own workflow, which tries the Mac installer on GitHub's Macs.

## Licence
MIT for the kit's own files ([LICENSE](LICENSE)). The copied skills in `brain/skills/` keep their own licences, MIT or Apache 2.0, listed in [brain/skills/lists/sources.md](brain/skills/lists/sources.md).
