# AnIdeaLab brain kit: terms of use

**Last changed:** 6 Nov 2026.

These terms are between you and AnIdeaLab, and cover the AnIdeaLab brain kit: the setup script, the brain it makes for you, the brain updates AnIdeaLab sends, and the scripts in this repo. The setup asks you to accept them before it installs or makes anything. If you don't accept them, don't use the kit.

## 1. The kit is free
You don't pay AnIdeaLab anything for the kit or its updates. The kit's own files are under the MIT licence ([LICENSE](LICENSE)). The skills copied into the brain from elsewhere keep their own licences, MIT or Apache 2.0, listed in [brain/skills/lists/sources.md](brain/skills/lists/sources.md). The services the brain uses (GitHub, Claude or another AI tool, Obsidian and anything you connect) are yours to sign up for, under their own terms and prices.

## 2. What AnIdeaLab gets
**Access to your brain.** The setup invites AnIdeaLab's testing account (GitHub: `diagnostics-anidealab`) to your brain's private repo as a collaborator. GitHub has no read-only option for a personal repo, so that account can:
- see everything in your brain, and its history;
- copy it, and AnIdeaLab may keep the copies;
- change it, as any collaborator can;
- run jobs on your PC through the PC runner, whenever the runner is on, since the runner runs the jobs your repo sends it.

AnIdeaLab uses this to see how brains made from the kit are working, and to test, fix and improve the kit.

**Reports.** Your brain sends AnIdeaLab's inbox:
- a setup report when it's set up, holding only the date;
- a report after each brain update you apply: what changed, what clashed, what broke, any code the agent changed and how closely the brain matches the kit. The agent leaves out your own projects, people and notes.

Each report is sent from your repo through GitHub, so it also tells AnIdeaLab which GitHub account and repo sent it.

**What it doesn't get.** The daily check for brain updates only reads the kit's public repo, and sends nothing about you. An update changes your brain only if you say go.

**Taking it off.** You can remove the testing account any time: your repo on GitHub, Settings, Collaborators. From then on it can't see, change or run anything. To stop the reports, delete the brain's "Send brain update reports" workflow (`.github/workflows/update-report.yml`).

## 3. The sign-off
In return for the kit being free, your brain's agents end their messages to the outside (emails, posts, replies to others) with "Assistant built by AnIdeaLab.com", linking AnIdeaLab.com where the message can carry a link, or "Assistant built by AnIdeaLab" in cold outreach. Their replies to you don't carry it. The brain has this as one of its rules: please leave it in while you use the kit.

## 4. Your brain is yours
Your brain lives in a private repo on your own GitHub account, and what you put in it is yours. You're responsible for what's in it, for what you and your agents do with it, and for the accounts and keys it uses. Keep keys and passwords out of its files: the brain's rules say where they go.

The PC runner lets jobs from your repo run on your PC, with your Windows account's rights. Anyone who can change your repo can run jobs on your PC, so keep the repo private and invite only people you trust. You can take the runner off any time: your repo on GitHub, Settings, Actions, Runners.

## 5. No warranty
The kit is given as it is, with no promise that it works, suits your purpose or is free of mistakes. AI agents get things wrong, and a brain can change files, run jobs and send messages for you: check what matters, and keep your own copies of anything you can't lose. You use the kit at your own risk.

## 6. Liability
As far as the law allows, AnIdeaLab isn't liable for any loss or damage from using the kit, or from anything the brain, its agents or the PC runner do, including lost data, lost work, lost money and harm to your PC. Nothing in these terms takes away rights you have under consumer law that can't be taken away.

## 7. Changes, and ending
AnIdeaLab can change these terms. The newest version is always at https://github.com/AnIdeaLab/brain-kit/blob/main/TERMS.md, and this file's history shows every change. A brain update that comes with a change to the terms says so in its summary, and applying it means you accept the new terms.

You can stop using the kit any time: take the testing account and the runner off, and delete the brain if you like. AnIdeaLab can stop offering the kit or its updates any time. Sections 2 (for copies already made), 5 and 6 still apply after either stops.

## 8. Law
These terms are governed by the law of New Zealand, and its courts decide any dispute about them.

## Contact
hello@anidealab.com, or [AnIdeaLab.com](https://anidealab.com).
