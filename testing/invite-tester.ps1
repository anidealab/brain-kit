# Invites AnIdeaLab's testing account to your second brain's repo, for a brain set up before 27 Oct 2026,
# when the kit's installer started doing it. Paste into PowerShell on your PC:
#   irm https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/testing/invite-tester.ps1 | iex
#
# AnIdeaLab's testing account (GitHub: diagnostics-anidealab) can then see your brain and copy it, to test the
# kit while it's in testing; AnIdeaLab accepts the invitation within a day. GitHub lets a collaborator change
# the repo too; there's no read-only option for a personal repo. To take the account off any time: your repo
# on GitHub, Settings, Collaborators. It installs GitHub's command line with winget if it's missing and signs
# you in to GitHub the first time, finds your brain, and invites the account; it changes nothing else, and
# prints only "Success", or what went wrong. Your brain is the repo of yours with the kit's update script,
# skills/brain-spec/brain_update.py, which every brain from the kit has had since brain update 1. It does
# nothing for AnIdeaLab's own people, the members of its GitHub organisation, as the installer does.
# Safe to run again. Windows PowerShell 5.1, plain ASCII.
& {
  $ErrorActionPreference = 'Continue'
  $tester = 'diagnostics-anidealab'
  function Fail($t) { Write-Host $t -ForegroundColor Red }

  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Fail "winget (Windows' app installer) isn't on this PC. Install 'App Installer' from the Microsoft Store, then paste the same command again."; return }
    winget install -e --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements | Out-Null
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Fail "GitHub's command line installed, but this window can't see it yet. Close PowerShell, open it again, and paste the same command."; return }
  }
  gh auth status --hostname github.com 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) { Fail "GitHub sign-in didn't finish. Paste the same command again to retry."; return }
  }
  $me = "$(gh api user --jq .login 2>$null)".Trim()
  # AnIdeaLab's own people, the members of its GitHub organisation: the testing account is for owners' brains
  # only, and mustn't reach their repos, or their PCs through a runner.
  $state = "$(gh api user/memberships/orgs/AnIdeaLab --jq .state 2>$null)".Trim()
  $ours = ($LASTEXITCODE -eq 0 -and $state -eq 'active')
  if ($ours -or $me -eq $tester) { Fail "It's signed in as $me, one of AnIdeaLab's own accounts, so it does nothing: the testing account is only for owners' brains."; return }

  $repos = @(gh repo list --limit 200 --json nameWithOwner --jq '.[].nameWithOwner') | Where-Object { $_ }
  $brains = @($repos | Where-Object { gh api "repos/$_/contents/skills/brain-spec/brain_update.py" --silent 2>$null; $LASTEXITCODE -eq 0 })
  if (-not $brains.Count) { Fail "None of $me's repos is a brain from the kit. If your brain is on another GitHub account, run gh auth login --web, sign in as that account, and paste the same command again."; return }

  $failed = @()
  foreach ($r in $brains) {
    gh api -X PUT "repos/$r/collaborators/$tester" --silent 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { $failed += $r }
  }
  if ($failed.Count) { Fail "Couldn't invite the account to $($failed -join ', '). Paste the same command again to retry." }
  else { Write-Host 'Success' -ForegroundColor Green }
}
