---
name: my-mac
description: "How to run commands and jobs on the owner's Mac through the my-mac GitHub Actions runner: starting a run, reading its log, getting files to and from the Mac, the Mac's quirks, keeping it safe, where files go, keys on a Mac, setting the runner up again and what to do when it stops; and the Mac's part of a new brain's first session. Use whenever a job needs the owner's Mac (its apps, their files, Xcode, anything a cloud session can't do), or when the brain was set up on a Mac."
---

# Running jobs on the owner's Mac
The owner's Mac is a GitHub Actions self-hosted runner for this brain's repo, with the label `my-mac`. It runs as a LaunchAgent under the owner's own account, so a job can reach their files and apps, and it starts when they log in: the Mac has to be on, awake and logged in. What this Mac has is in the Mac's note, `knowledge/systems/my-mac.md`. The [my-pc skill](../my-pc/SKILL.md) is the same for a Windows PC, if the owner adds one, and most of its rules hold here too. In a new brain's first session, do the getting-started skill's PC steps as [The first session](#the-first-session) below says.

## Running a command
Start the workflow [`mac-run.yml`](../../.github/workflows/mac-run.yml) ("Run on my Mac") on `main` with the GitHub tool's run-workflow method. Inputs:
- `command`: the command or a whole script. Start it with a `# comment` saying what it's for: the run's name in the Actions list starts with it.
- `shell`: `bash` (the default: macOS's own bash 3.2, so no `mapfile`, no `${x,,}` and no associative arrays) or `zsh`.
- `workdir`: where it runs. Default `~/AI-Brain-Link`.
- `timeout`: minutes, default 60, up to 4320 (three days).
- `checkout`: true to get this repo at `$GITHUB_WORKSPACE` first, so the command can run the repo's scripts. Set it whenever the command calls them: without it, the job quietly runs whatever older copy the last checked-out job left in `_runner/_work`.
- `artifact`: a file, folder or wildcard on the Mac to attach to the run for 3 days, so you can look at it. The GitHub tool's artifact download gives a short-lived link.

Then find your run in the workflow's run list, wait until it shows as completed, and read the job log. A copy of each run's output stays on the Mac in `~/AI-Brain-Link/_logs/mac-run-<run id>.log`. The queue and the logs behave as on a PC (the my-pc skill's "How the queue and logs behave"): one job at a time, in order, with no concurrency group; a log can be read only once its job has finished; after a timed-out run-workflow call, check the run list before trying again; and push a script before starting the job that runs it.

## Getting files to and from the Mac
- **From the Mac:** the `artifact` input.
- **To the Mac,** for a file the owner gave a cloud session: the my-pc skill's transfer branch, unpacked in the job with `git archive -o "$RUNNER_TEMP/x.tar" FETCH_HEAD` and `tar -xf "$RUNNER_TEMP/x.tar" -C <folder>`, then the branch deleted with `delete-branch.yml`.
- **Files from the owner:** below, "Giving the brain files".

## Things to know
- **On, awake and logged in.** The runner is a LaunchAgent: it starts when the owner logs in, not at power-on, and stops when they log out. If they said yes at setup, a helper keeps the Mac from sleeping while it's on the charger (`caffeinate -s`, as the LaunchAgent `com.anidealab.brain-keep-awake`); closing the lid still sleeps it, and on battery it sleeps as usual. Runs sitting in "queued" usually mean one of these.
- **No pop-ups, no password.** Nobody is there to click or type. `sudo`, and anything else that asks for the Mac's password, hangs until the timeout: give the owner one command to paste into Terminal instead, and say it will ask for their password. macOS's privacy questions are the same: a job reading `~/Desktop`, `~/Documents` or `~/Downloads`, or driving another app, can be refused or wait on a question nobody sees. Work inside `~/AI-Brain-Link`.
- **A job can open things on the owner's screen** (`open <a link or an app>`), because the runner runs inside their login. Do it only when they expect it.
- **The jobs' PATH was saved at setup,** in `~/AI-Brain-Link/_runner/.path`, so a tool installed later may not be found. Use its full path, or put its folder at the front of `PATH` in the command. GitHub's command line is in `~/AI-Brain-Link/Tools/bin`; Homebrew's tools, if the owner has Homebrew, are in `/opt/homebrew/bin` (Apple silicon) or `/usr/local/bin` (Intel).
- **`gh` in a job can't use the owner's sign-in:** gh keeps it in their login keychain, and on a Mac runner a job's `gh auth status` calls the token invalid. git's pushes from the brain's copy and Obsidian are fine, since they run in the owner's own session. Nothing in the brain needs `gh` in a job; one that does needs a token passed in by its workflow.
- **Code lives in the repo, data lives on the Mac.** Scripts stay in the repo (a skill's folder); a job checks the repo out and reads and writes its data under `~/AI-Brain-Link/<Project>/<Stage>/<job>/`.
- **Deleting the owner's files** needs their say first. A job moves what's going into `~/AI-Brain-Link/_trash/<date>/` instead, since the Trash isn't reliable from a job.
- **Workflows for the Mac** use `runs-on: [self-hosted, my-mac]`. Everything else keeps `ubuntu-latest`, so the index workflow stays on GitHub's machines.
- **Safety.** A runner job can do anything the owner can on their Mac. Mac workflows are started only by `workflow_dispatch` or a schedule, never by a pull request. The repo must stay private, and nobody else gets write access while the runner is attached. Never put a key in a `command`: commands show in the Actions list and the logs; add it as a secret and pass it in the workflow's `env` (the core's secrets gate).

## Seeing what runs
"AI Brain Link - live jobs", in the owner's `~/AI-Brain-Link` folder, opens Terminal on [`watch-jobs.sh`](watch-jobs.sh) (copied to `~/AI-Brain-Link/Tools/`), which follows the newest job's log as it runs: a double-click in Finder opens it. Without it, the owner pastes `bash ~/AI-Brain-Link/Tools/watch-jobs.sh` into Terminal. The full history is the repo's Actions tab, under "Run on my Mac".

## Giving the brain files
The upload point's window and Send to are on Windows only for now. On a Mac, the owner puts files or folders in `~/AI-Brain-Link/_upload` (in Finder: Go, Home, then AI-Brain-Link; the installer made the folder) and tells you what to do with them. List what's there with a job (`ls -la ~/AI-Brain-Link/_upload`), then sort it as the [upload-point skill](../upload-point/SKILL.md)'s "Sorting what's waiting" says, with `mv` in place of its PowerShell and the brain's copy at `~/AI-Brain-Link/<repo name>`. Folders the owner keeps elsewhere, like a code repo, are read where they are, as that skill says; ask them for the path. `_upload` is empty again once everything's sorted.

## Keys on a Mac
The [add-a-key skill](../add-a-key/SKILL.md)'s script is for Windows. On a Mac, give the owner one line to paste into Terminal: it opens the page that makes the key, then `gh` asks for the key without showing it as they paste, and saves it in this repo's Actions secrets. Fill in the page, the name and the repo:
```
open "https://platform.openai.com/api-keys"; gh secret set OPENAI_API_KEY --repo <owner>/<repo>
```
Say in your message what to press on the page, since the line can't. Then add the key's row to keys and accounts (`knowledge/systems/keys-and-accounts.md`), never its value. If Terminal says `gh` isn't found, they open a new Terminal window and paste it again: the installer put `gh` on the path for new windows.

## Setting it up again
[`setup-runner.sh`](setup-runner.sh) sets the runner up, or again from scratch: it downloads GitHub's runner and checks it against its checksum, registers it with this repo under the label `my-mac` (it removes an old registration first), installs it as a LaunchAgent under the owner's account, adds the live jobs file, and offers to keep the Mac awake on the charger. It says it's done only once GitHub sees the runner online. It needs no password. Give the owner this to paste into Terminal:
```
bash ~/AI-Brain-Link/<repo name>/skills/my-mac/setup-runner.sh
```
It needs GitHub's `gh` signed in, which the installer did. `~/AI-Brain-Link/<repo name>` is where the installer puts the brain's copy; a brain cloned somewhere else has its folder in the Mac's note, so use that in this command and the ones below. macOS then says background items were added: that's the runner (and the keep-awake helper).

## If the runner stops picking up jobs
1. **Runs sit in "queued":** the Mac is off, asleep or logged out. Ask the owner to check, then give them this to paste into Terminal, which says whether the runner's LaunchAgent is running and starts it if not: `cd ~/AI-Brain-Link/_runner && ./svc.sh status; ./svc.sh start`.
2. **The runner's own logs** are in `~/AI-Brain-Link/_runner/_diag/`.
3. **Still nothing:** have the owner run `setup-runner.sh` again (above).
4. **To see the Mac's state while the runner is down,** give the owner the setup check with `--send`. It changes nothing, and saves its report in this repo as `knowledge/systems/setup-check.md`, so you can pull and read it:
   ```
   bash ~/AI-Brain-Link/<repo name>/skills/my-mac/check-setup.sh --send
   ```
5. **No runner at all, after the installer:** the setup stopped before its runner step. The installer keeps each step in `~/AI-Brain-Link/_logs/install.log`, and the setup check's "The installer's last run" part says where it stopped. Give the owner the `setup-runner.sh` command (above).

## The first session
A new brain's [getting-started skill](../getting-started/SKILL.md) was written for a Windows PC. On a Mac, follow it, with these in place of its PC parts:
- **What the installer did:** it put the brain's copy in `~/AI-Brain-Link/<repo name>`, opened it in Obsidian with Obsidian Git syncing it, and set up the Mac runner (label `my-mac`, a LaunchAgent under the owner's account), unless they skipped it.
- **Step 1:** the Mac runner lets agents run jobs on their Mac while it's on, awake and they're logged in.
- **Step 4, testing the runner:** start `mac-run.yml`, not `pc-run.yml`, with `workdir` left as it is and this `command`:
  ```
  # Hello from the brain: what this Mac has
  echo "Mac: $(scutil --get ComputerName), macOS $(sw_vers -productVersion), running as $(whoami)"
  echo "Model: $(sysctl -n hw.model) ($(uname -m))"
  echo "CPU: $(sysctl -n machdep.cpu.brand_string)"
  echo "RAM: $(( $(sysctl -n hw.memsize) / 1073741824 )) GB"
  system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/Chipset Model/ {print "GPU: " $2}'
  df -H / | awk 'NR == 2 {print "Disk: " $4 " free of " $2}'
  echo "Developer tools: $(xcode-select -p 2>/dev/null || echo none)"
  for t in git gh python3 node brew ffmpeg; do printf '%s: %s\n' "$t" "$(command -v "$t" || echo 'not found')"; done
  ```
  Put what it found in the Mac's note, `knowledge/systems/my-mac.md`, under "What's on the Mac", dated, and tell the owner in two lines. If it sits in "queued" for more than a few minutes, go through "If the runner stops picking up jobs" above; if they skipped the runner, give them the command in "Setting it up again".
- **Step 5, the tour:** Obsidian's shortcuts use Cmd where the skill says Ctrl (Cmd+G opens the map, Cmd+P the commands). There's no upload point window on a Mac yet: they put files in `~/AI-Brain-Link/_upload` and tell you ("Giving the brain files" above). Keys go in with one line in Terminal ("Keys on a Mac" above).
