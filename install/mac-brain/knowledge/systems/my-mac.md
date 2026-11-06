---
about: "The owner's Mac: how agents reach it (the my-mac runner), the folder layout in ~/AI-Brain-Link, and what's on it. Read for facts about the Mac; how to run a job is the my-mac skill."
tags: [the-brain]
updated: {KIT_DATE}
---
# The owner's Mac

The Mac is a GitHub Actions self-hosted runner for this brain's repo, labelled `my-mac`, running as a LaunchAgent under the owner's own account, so agents can run jobs on it while it's on, awake and they're logged in. The installer set it up; `skills/my-mac/setup-runner.sh` sets it up again. **How to run a job on it** is the [my-mac skill](../../skills/my-mac/SKILL.md). `skills/my-mac/check-setup.sh` checks the whole setup and changes nothing; with `--send` its report also lands on this shelf, as `setup-check.md`.

## Folder layout
```
~/AI-Brain-Link/
  _runner/        the Actions runner (its checkouts go in _runner/_work/)
  _logs/          the installer's install.log, and mac-run output, one log per run
  _upload/        files and folders the owner puts here for the brain, until they're sorted
  Tools/          GitHub's command line (Tools/bin), watch-jobs.sh and other shared tools
  <repo name>/    the owner's copy of this brain, opened in Obsidian
  <Project>/<Stage>/<job>/   a job's data, made when a job first needs it
  AI Brain Link - live jobs.command   opens Terminal on the jobs as they run
```

## What's on the Mac
*Not checked yet: the first session fills this in from a first job on the Mac (the my-mac skill's "The first session").*
