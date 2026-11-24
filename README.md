# The AnIdeaLab brain kit

A second brain for working with AI agents: a private GitHub repo of plain Markdown that agents work from. It has a core every agent reads (`CLAUDE.md`), a library of skills for how to do things, and a knowledge library of what the brain knows. It's free, and an owner starts one in three steps, with nothing to install ([Start a brain](#start-a-brain)). Two extras go on the owner's PC or Mac, if they'd like them: a runner for jobs that need their computer, and Obsidian with a custom AnIdeaLab plugin to see the brain as a map ([On your computer](#on-your-computer-if-you-like)).

## Start a brain
Three steps, and a phone will do. Your brain is kept on GitHub, in a private repo that's yours, and your AI agent works in it from your browser.

1. **Get a Claude Pro plan,** or above: [claude.com/pricing](https://claude.com/pricing). Your agent is Claude, and working in a brain needs a paid plan. If you have one already, go on to step 2.
2. **[Make your brain](https://github.com/new?template_owner=AnIdeaLab&template_name=second-brain&name=my-brain-ail&visibility=private).** The link opens GitHub, where your brain is kept. Sign in, or make a free account, then press "Create repository". Leave it set to Private.
3. **Send your first message.** Open [claude.ai/code](https://claude.ai/code). If it asks, connect GitHub and let it see `my-brain-ail`. Start a session with `my-brain-ail` selected, and send this:

   ```
   This is my new second brain. Read CLAUDE.md and get me set up.
   ```

It asks you a few questions and sets everything up from there. Every chat after that starts the same way: a new session with `my-brain-ail` selected.

The same three steps are on AnIdeaLab's site, [anidealab.com/second-brain](https://anidealab.com/second-brain), with tutorials for your first days with a brain, and you can have AnIdeaLab set yours up for you there if you'd rather.

What those steps do:
- step 2 copies the template repo, [AnIdeaLab/second-brain](https://github.com/AnIdeaLab/second-brain), into a new private repo on your GitHub account. The template is [brain/](brain/) as it is on this repo's `next` branch, so a new brain has the newest work;
- a moment later a workflow in your new repo runs once, on GitHub's machines: it fills in that day as your brain's start, sends AnIdeaLab a setup report (the day the brain was started, nothing else), so new brains can be counted, and turns itself off;
- your first chat follows the brain's [getting-started skill](brain/skills/getting-started/SKILL.md): it checks the repo is private, asks who you are and what you'd like the brain for, writes your first notes, offers the two extras for your computer, and shows you around;
- the kit is free under AnIdeaLab's [terms of use](TERMS.md), which your first chat points you to.

## On your computer, if you like
A brain works with nothing on your computer. There are two extras, a few minutes each, and your first chat offers both:
- **Your computer:** then you can ask your agent to do things on your PC or Mac from any chat, even from your phone: make a video, sort out a folder, set up a program. It only does what you ask, and you can watch each one as it happens. It works best on a computer that's usually on, but it doesn't have to be: a job asked for while it's off runs once it's back on.
- **Obsidian:** a free app that shows your brain as a map on your computer, where you can read and edit your notes.

Both come from one command, below, which your first chat gives you along with what to answer. Every brain is called `my-brain-ail` (the name in step 2's link), so there's no name to type: the command finds your brain, puts a copy of it on your computer and adds what you chose. The command also makes a brain by itself, for anyone who'd rather start from their computer: if you have no `my-brain-ail` yet, it makes one. A brain made before 22 Nov 2026, or one you renamed, has its own name, so your first chat gives you the command with that name in it, `$env:BRAIN_KIT_NAME='<your brain>';` in front on a PC, `BRAIN_KIT_NAME=<your brain>` in front on a Mac:

```
$env:BRAIN_KIT_NAME='<your brain>'; irm https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/install.ps1 | iex
```
```
BRAIN_KIT_NAME=<your brain> /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/install.sh)"
```

**On a Windows PC,** open PowerShell (press the Windows key, type powershell, press Enter), paste this line and press Enter:

```
irm https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/install.ps1 | iex
```

[install.ps1](install.ps1) downloads this repo as a zip (no Git needed yet), unpacks it in a temporary folder and runs [install/install-windows.ps1](install/install-windows.ps1) from it, which:
- asks you to accept AnIdeaLab's [terms of use](TERMS.md) first (Y or N), and stops if you don't;
- opens Claude in your browser, to sign in or make an account and choose a paid plan (you can skip it if you're already set up);
- asks whether you'd like Obsidian (Enter is yes): it's an extra, and the brain works without it;
- installs Git and GitHub's command line if they're missing, and Obsidian if you said yes, and signs you in to GitHub in your browser;
- uses your brain, `my-brain-ail` (or the name in `BRAIN_KIT_NAME`), if you've made it already; if not, makes it from [brain/](brain/), as of the newest update, with the day you install it as its start, in a new private repo on your GitHub account;
- invites AnIdeaLab's testing account to that repo, as the terms say;
- puts your copy in `C:\AI-Brain-Link\<your brain's name>`, set up for Obsidian with your edits syncing to GitHub, if you chose Obsidian;
- adds the upload point, a Send to entry for giving your brain files with a right-click;
- sets up the PC runner, if you say yes to it, so you can ask your agent to do things on your PC. It asks for admin rights and your Windows password, then whether to keep the PC awake while it's plugged in, and says to answer yes: a sleeping PC can't run jobs, and its runner can stay disconnected after it wakes until it's restarted by hand;
- opens your brain in Obsidian, if you chose it, last, so it can't hide a question in the PowerShell window.
- then opens AnIdeaLab's tutorials page in your browser, for connecting Claude and the rest (anidealab.com/second-brain/tutorials, or the site's preview address until the site moves there).

It's safe to run again: it skips what's already done. Its questions show in yellow, and a click in its window can't pause it. At the end it lists each step and how it went, keeps that in `C:\AI-Brain-Link\_logs\install.log` (which the brain's setup check reads), and says what to send Claude to get started. The steps in plain words, to send someone: [install/START-HERE.txt](install/START-HERE.txt).

**On a Mac,** open Terminal (press Command and Space, type terminal, press Enter), paste this line and press Enter:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/install.sh)"
```

[install.sh](install.sh) downloads this repo (no Git needed yet), unpacks it in a temporary folder and runs [install/install-mac.sh](install/install-mac.sh) from it, which takes the same steps in the same order, with the same questions, the Mac's way:
- if Apple's tools go in while it waits, it says so before it carries on, since their window can still be finishing;
- Git comes with Apple's command line tools, which macOS offers to install in a window of its own; GitHub's command line and Obsidian come from their own releases on GitHub, each checked against its checksum. There's no Homebrew, and nothing asks for your Mac's password;
- your copy goes in `~/AI-Brain-Link/<your brain's name>`, and the log in `~/AI-Brain-Link/_logs/install.log`;
- the brain gets its Mac parts, since [brain/](brain/) is made for a Windows PC: the Mac runner's workflow, skill and note from [install/mac-brain/](install/mac-brain/), and its lines about the PC and PowerShell said for a Mac;
- the Mac runner runs as a LaunchAgent under your account, so your agent can do what you ask on your Mac while it's on and you're logged in, and it offers to keep the Mac awake on the charger;
- there's no Send to on a Mac: you put files for your brain in `~/AI-Brain-Link/_upload`.

The steps in plain words, to send someone: [install/START-HERE-MAC.txt](install/START-HERE-MAC.txt). GitHub's own Macs try it on each change ([the workflow](.github/workflows/mac-installer.yml)).

## Brain updates
AnIdeaLab sends fixes, new rules and new parts to brains made from the kit. A brain checks for new ones once a day, when its owner starts a session, and its weekly tidy-up checks too; its agent reads the owner a short summary of each, and applies it only if they say go. After applying one, `brain_update.py compare` checks the whole brain against `brain/` as it is at that update, the exemplar.

## What's here
- **[brain/](brain/)**: the kit's brain as a new one gets it, with `{KIT_DATE}` and `{KIT_ISO}` where each brain has its own start date.
- **[install.ps1](install.ps1), [install.sh](install.sh) and [install/](install/)**: the one command for a brain's extras on a computer, which can also make a brain by itself: its script for Windows and for a Mac, and the installers and START-HEREs they run and point to, with the parts a Mac brain gets in [install/mac-brain/](install/mac-brain/).
- **[template/](template/)**: what a brain made the no-install way ([Start a brain](#start-a-brain)) has on top of `brain/`: the script that fills in its start date and writes its setup report, the workflow that runs it once, and the template repo's page for visitors (`.github/README.md`, which GitHub shows ahead of the brain's own front door, and which the script takes out when a brain starts). The kit's "Publish the template" workflow puts `brain/` (as it is on the `next` branch) and these in the template repo, [AnIdeaLab/second-brain](https://github.com/AnIdeaLab/second-brain), which an owner makes their brain from with GitHub's "Use this template". `tools/template-setup.ps1` sets that repo up.
- **[sign-off-links.md](sign-off-links.md)**: which AnIdeaLab.com page the sign-off links to, by the reader's field. A brain's daily update check takes the newest copy by itself, without asking its owner.
- **[updates/](updates/)**: one message per update, newest last, each starting with a summary for the owner. The commit that added each one holds `brain/` as of that update, and `brain_update.py` merges the difference into a brain with a three-way merge, so the brain's own changes elsewhere stay.
- **[inbox/](inbox/)**: after each update, a brain sends a report of how it went to AnIdeaLab's private inbox, so the kit gets better.
- **[TERMS.md](TERMS.md)**: AnIdeaLab's terms of use for the kit, which the installer asks each owner to accept.
- **[testing/](testing/)**: AnIdeaLab's scripts for its testing account, which the installer invites to each new brain's repo, as the terms say: `diagnostic-setup.ps1` invites it to a brain made before the installer did, and `copy-brains.ps1` copies the brains it's invited to. `network-check.ps1` is for a PC whose install stops on a download: it changes nothing, and saves and copies a report of the PC's antivirus, proxy, DNS and how GitHub's downloads answer.
- **[set-up/](set-up/)**: what AnIdeaLab runs for its paid set-up, not part of a brain: "index my computer", the job that finds a set-up buyer's documents from the last year and turns them into text for their brain.
- **[tools/kit.py](tools/kit.py)**: the kit's build, which checks it after each change (a brain made on a Mac too), and makes the zip a Windows owner can install from instead of the one command. How to work on the kit: [CLAUDE.md](CLAUDE.md).
- **[.github/workflows/](.github/workflows/)**: the kit's own workflows: one tries the Mac installer on GitHub's Macs, one publishes the template.

## Licence
MIT for the kit's own files ([LICENSE](LICENSE)). The copied skills in `brain/skills/` keep their own licences, MIT or Apache 2.0, listed in [brain/skills/lists/sources.md](brain/skills/lists/sources.md).
