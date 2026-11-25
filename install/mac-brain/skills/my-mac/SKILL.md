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

Then find your run in the workflow's run list, wait until it shows as completed, and read the job log. A copy of each run's output stays on the Mac in `~/AI-Brain-Link/_logs/mac-run-<run id>.log`. The queue and the logs behave as on a PC (the my-pc skill's "How the queue and logs behave"): one job at a time, in order, with no concurrency group; a log can be read only once its job has finished, so to follow a long job as it runs, read the issue "Mac job live log" (its last 80 lines every 30 seconds, made on the first job, skipped on a public repo); after a timed-out run-workflow call, check the run list before trying again; and push a script before starting the job that runs it.

## Getting files to and from the Mac
- **From the Mac:** the `artifact` input.
- **To the Mac,** for a file the owner gave a cloud session: the my-pc skill's transfer branch, unpacked in the job with `git archive -o "$RUNNER_TEMP/x.tar" FETCH_HEAD` and `tar -xf "$RUNNER_TEMP/x.tar" -C <folder>`, then the branch deleted with `delete-branch.yml`.
- **Files from the owner:** below, "Giving the brain files".

## Things to know
- **On, awake and logged in.** The runner is a LaunchAgent: it starts when the owner logs in, not at power-on, and stops when they log out. If they said yes at setup, a helper keeps the Mac from sleeping while it's on the charger (`caffeinate -s`, as the LaunchAgent `com.anidealab.brain-keep-awake`); closing the lid still sleeps it, and on battery it sleeps as usual. Runs sitting in "queued" usually mean one of these.
- **No pop-ups, no password.** Nobody is there to click or type. `sudo`, and anything else that asks for the Mac's password, hangs until the timeout: give the owner one command to paste into Terminal instead, and say it will ask for their password. macOS's privacy questions are the same: a job reading `~/Desktop`, `~/Documents` or `~/Downloads`, or driving another app, can be refused or wait on a question nobody sees. Work inside `~/AI-Brain-Link`. **Check before you say a folder is out of reach:** list it (`ls ~/Documents`); an error like "Operation not permitted" is a refusal, a listing isn't. A Spotlight search by file name (`mdfind -name`) can miss files in a folder synced with iCloud Drive, so search by what's in them too (`mdfind -onlyin ~ 'kMDItemTextContent == "*words*"cd'`) or walk the folder with `find`. An owner's MacBook Air on 23 Nov 2026: a name search found almost nothing, the runner could read every folder, and a search by text found the file at once.
- **A job can open things on the owner's screen** (`open <a link or an app>`), because the runner runs inside their login. Do it only when they expect it.
- **The jobs' PATH was saved at setup,** in `~/AI-Brain-Link/_runner/.path`, so a tool installed later may not be found. Use its full path, or put its folder at the front of `PATH` in the command. GitHub's command line is in `~/AI-Brain-Link/Tools/bin`; Homebrew's tools, if the owner has Homebrew, are in `/opt/homebrew/bin` (Apple silicon) or `/usr/local/bin` (Intel).
- **`gh` in a job can't use the owner's sign-in:** gh keeps it in their login keychain, and on a Mac runner a job's `gh auth status` calls the token invalid. git's pushes from the brain's copy and Obsidian are fine, since they run in the owner's own session. Nothing in the brain needs `gh` in a job; one that does needs a token passed in by its workflow.
- **The owner's copy of the brain,** `~/AI-Brain-Link/<repo name>`, is synced by Obsidian's Git plugin where the owner has Obsidian. Where they don't, each job brings it up to date before its command runs (a fast-forward only, in `mac-run.yml`), so the setup scripts in it are current once any job has run. Nothing sends the owner's own edits in that copy without Obsidian: a job commits and pushes them when they ask.
- **Code lives in the repo, data lives on the Mac.** Scripts stay in the repo (a skill's folder); a job checks the repo out and reads and writes its data under `~/AI-Brain-Link/<Project>/<Stage>/<job>/`.
- **Deleting the owner's files** needs their say first. A job moves what's going into `~/AI-Brain-Link/_trash/<date>/` instead, since the Trash isn't reliable from a job.
- **Workflows for the Mac** use `runs-on: [self-hosted, my-mac]`. Everything else keeps `ubuntu-latest`, so the index workflow stays on GitHub's machines.
- **Safety.** A runner job can do anything the owner can on their Mac. Mac workflows are started only by `workflow_dispatch` or a schedule, never by a pull request. The repo must stay private, and nobody else gets write access while the runner is attached. Never put a key in a `command`: commands show in the Actions list and the logs; add it as a secret and pass it in the workflow's `env` (the core's secrets gate).

## Seeing what runs
"AI Brain Link - live jobs", in the owner's `~/AI-Brain-Link` folder, opens Terminal on [`watch-jobs.sh`](watch-jobs.sh) (copied to `~/AI-Brain-Link/Tools/`), which follows the newest job's log as it runs: a double-click in Finder opens it. Without it, the owner pastes `bash ~/AI-Brain-Link/Tools/watch-jobs.sh` into Terminal. The full history is the repo's Actions tab, under "Run on my Mac".

## Giving the brain files
In a chat, the owner attaches them, or says where they are on the Mac (in Finder, holding Option while right-clicking a file gives "Copy as Pathname"), and a job reads them there. A job reading `~/Desktop`, `~/Documents` or `~/Downloads` can be refused by macOS's privacy settings ("Things to know"): if it is, ask the owner to move them into `~/AI-Brain-Link`, or give them a command to paste that does.

## Keys on a Mac
The [add-a-key skill](../add-a-key/SKILL.md) works on a Mac as on a PC, with [`add-api-keys.sh`](../add-a-key/add-api-keys.sh) in place of its PowerShell script: the same options, written `--secret`, `--page`, `--tell`, `--prefix`, `--check`, `--header` and `--repo`, and the same steps (it opens the page, says what to press, reads the key hidden, checks how it starts and tries it on the service, then saves it in this repo's Actions secrets). Give the owner one line to paste into Terminal, with the parts filled in:
```
bash ~/AI-Brain-Link/<repo name>/skills/add-a-key/add-api-keys.sh --secret OPENAI_API_KEY --page "https://platform.openai.com/api-keys" --tell "Sign in, press Create new secret key, and copy it." --prefix "sk-" --check "https://api.openai.com/v1/models"
```
Wherever a skill gives the PowerShell line for a key, give this one with the same values. Then add the key's row to keys and accounts (`knowledge/systems/keys-and-accounts.md`), never its value. If Terminal says the file isn't there, the owner's copy hasn't caught up: give them `git -C ~/AI-Brain-Link/<repo name> pull` first. If it says `gh` isn't found, they open a new Terminal window and paste it again: the installer put `gh` on the path for new windows.

## Setting it up again
[`setup-runner.sh`](setup-runner.sh) sets the runner up, or again from scratch: it downloads GitHub's runner and checks it against its checksum, registers it with this repo under the label `my-mac` (it removes an old registration first), installs it as a LaunchAgent under the owner's account, adds the live jobs file, and offers to keep the Mac awake on the charger. It says it's done only once GitHub sees the runner online. It needs no password. Give the owner this to paste into Terminal:
```
bash ~/AI-Brain-Link/<repo name>/skills/my-mac/setup-runner.sh
```
It needs GitHub's `gh` signed in, which the installer did. `~/AI-Brain-Link/<repo name>` is where the installer puts the brain's copy; a brain cloned somewhere else has its folder in the Mac's note, so use that in this command and the ones below. macOS then says background items were added: that's the runner (and the keep-awake helper).

## If the runner stops picking up jobs
0. **Before telling the owner the Mac can't be reached** (devices.md has no Mac row, the session-start line says no computer has a runner, the Claude app's own list of computers is empty: none of these settles it), run `devices.py status`, which also tries `my-mac` when it has no row, and look at the tasks shelf for the setup task and at `git log` for the installer's commits ("Added the Mac parts", "This Mac's runner is set up"). A Mac set up after the last session ended answers though nothing lists it: test it and add its row as "The first session" says, then do the job.
1. **Runs sit in "queued":** the Mac is off, asleep or logged out, or busy with another job; where the brain has `skills/brain-spec/devices.py`, its `status` tells which in about a minute. If it's off, ask the owner to check, then give them this to paste into Terminal, which says whether the runner's LaunchAgent is running and starts it if not: `cd ~/AI-Brain-Link/_runner && ./svc.sh status; ./svc.sh start`.
2. **The runner's own logs** are in `~/AI-Brain-Link/_runner/_diag/`.
3. **Still nothing:** have the owner run `setup-runner.sh` again (above).
4. **To see the Mac's state while the runner is down,** give the owner the setup check with `--send`. It changes nothing, and saves its report in this repo as `knowledge/systems/setup-check.md`, so you can pull and read it:
   ```
   bash ~/AI-Brain-Link/<repo name>/skills/my-mac/check-setup.sh --send
   ```
5. **No runner at all, after the installer:** the setup stopped before its runner step. The installer keeps each step in `~/AI-Brain-Link/_logs/install.log`, and the setup check's "The installer's last run" part says where it stopped. Give the owner the `setup-runner.sh` command (above).

## The first session
A new brain's [getting-started skill](../getting-started/SKILL.md) was written for a Windows PC. On a Mac, follow it, with these in place of its PC parts:
- **What the installer did:** it put the brain's copy in `~/AI-Brain-Link/<repo name>`; opened it in Obsidian with Obsidian Git syncing it, if they said yes to Obsidian; and set up the Mac runner (label `my-mac`, a LaunchAgent under the owner's account), unless they skipped it. Its questions on a Mac are the same as on a PC, with "Keep this Mac awake" for the PC's.
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
  Put what it found in the Mac's note, `knowledge/systems/my-mac.md`, under "What's on the Mac", dated, and tell the owner in two lines. Then, if the brain has `knowledge/systems/devices.md`, check the Mac's row (the installer adds it once the runner is online, with what the Mac has; add it if it isn't there) and run the devices check, as getting-started's step 4 says (Runner `my-mac`, Spot it the Mac's `hostname -s`), so later sessions know which computer they're on and whether it's on. If it sits in "queued" for more than a few minutes, go through "If the runner stops picking up jobs" above; if they skipped the runner, give them the command in "Setting it up again".
- **Step 5, the tour:** Obsidian's shortcuts use Cmd where the skill says Ctrl (Cmd+G opens the map, Cmd+P the commands). Keys go in with one line in Terminal ("Keys on a Mac" above).
- **Step 4, if the command stopped:** what it showed, and `~/AI-Brain-Link/_logs/install.log`, which has each step and the versions of the tools it found; then `bash ~/AI-Brain-Link/<repo name>/skills/my-mac/check-setup.sh` once the Mac parts are in.
- **Step 7, their files:** "on their PC" is on their Mac ("Giving the brain files" above).
