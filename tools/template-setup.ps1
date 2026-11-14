# Sets up the template, the no-install way to get a brain, from a Windows PC. Paste into PowerShell:
#   irm https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/tools/template-setup.ps1 | iex
#
# It needs GitHub's command line (gh), signed in as an owner of the AnIdeaLab organisation. It makes the
# public repo AnIdeaLab/second-brain if it isn't there, gives it a deploy key that can push, puts the
# key's private half in the kit repo's secret TEMPLATE_DEPLOY_KEY, marks the repo as a template, and
# starts the kit's "Publish the template" workflow, which fills it, unless it's filled already. If the
# organisation has deploy keys turned off, it turns them on, asking for that permission in the browser.
# Safe to run again: it adds a new key and replaces the secret. The key is made in a temporary folder and deleted at the end; nothing
# is kept in a file.
# Kept to Windows PowerShell 5.1 and plain ASCII.
& {
  $ErrorActionPreference = 'Continue'
  $kit = 'AnIdeaLab/brain-kit'
  $template = 'AnIdeaLab/second-brain'
  $gh = (Get-Command gh.exe -ErrorAction SilentlyContinue).Source
  if (-not $gh) { $gh = @("$env:ProgramFiles\GitHub CLI\gh.exe", "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1 }
  if (-not $gh) { Write-Host "GitHub's command line (gh) isn't on this PC. Install it with: winget install -e --id GitHub.cli" -ForegroundColor Red; return }

  Write-Host "`n1. The template's repo"
  & $gh repo view $template --json name 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    # No double quotes inside the description: Windows PowerShell 5.1 doesn't pass them on to a program, and
    # the words between them arrive as arguments of their own.
    & $gh repo create $template --public --description 'Your own second brain for working with AI agents, from the AnIdeaLab brain kit. Press Use this template to make yours.'
    if ($LASTEXITCODE -ne 0) { Write-Host "Couldn't make $template. Is gh signed in as an owner of AnIdeaLab? (gh auth status)" -ForegroundColor Red; return }
  } else { Write-Host "$template is already there." }

  Write-Host "`n2. Its deploy key, and the kit's secret"
  $dir = Join-Path $env:TEMP ('template-key-' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $key = Join-Path $dir 'key'
  try {
    # Windows PowerShell 5.1 drops an empty argument, so the empty passphrase is written with its quotes.
    & ssh-keygen -q -t ed25519 -N '""' -C 'brain-kit publishes the template' -f $key
    if (-not (Test-Path "$key.pub")) { Write-Host "Couldn't make a key: ssh-keygen didn't run (it comes with Windows 10 and 11's OpenSSH client)." -ForegroundColor Red; return }
    $title = 'brain-kit publishes the template, ' + (Get-Date).ToString('yyyy-MM-dd')
    & $gh repo deploy-key add "$key.pub" --repo $template --allow-write --title $title
    if ($LASTEXITCODE -ne 0) {
      # An organisation can have deploy keys turned off for its repos ("Deploy keys are disabled for this
      # repository"). Turning them on is an owner's setting, which gh's usual sign-in can't change: it asks
      # for that permission in the browser first.
      Write-Host "Turning deploy keys on for the AnIdeaLab organisation's repos..."
      & $gh api -X PATCH orgs/AnIdeaLab -F deploy_keys_enabled_for_repositories=true --silent 2>$null
      if ($LASTEXITCODE -ne 0) {
        Write-Host 'GitHub needs one more permission for that. Copy the code shown, press Enter, and paste it in your browser.' -ForegroundColor Yellow
        & $gh auth refresh --hostname github.com --scopes admin:org
        & $gh api -X PATCH orgs/AnIdeaLab -F deploy_keys_enabled_for_repositories=true --silent
      }
      & $gh repo deploy-key add "$key.pub" --repo $template --allow-write --title $title
      if ($LASTEXITCODE -ne 0) { Write-Host "Couldn't add the deploy key to $template. In the organisation's settings on GitHub, under Deploy keys, allow them, then paste this command again." -ForegroundColor Red; return }
    }
    Get-Content -LiteralPath $key -Raw | & $gh secret set TEMPLATE_DEPLOY_KEY --repo $kit
    if ($LASTEXITCODE -ne 0) { Write-Host "Couldn't save the secret in $kit." -ForegroundColor Red; return }
  } finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }

  Write-Host "`n3. Filling it"
  & $gh api "repos/$template/contents/CLAUDE.md" --silent 2>$null
  $filled = $LASTEXITCODE -eq 0
  if ($filled) { Write-Host 'It has the brain in it already; the kit fills it again at its next change.' }
  else {
    & $gh workflow run template.yml --repo $kit --ref main
    if ($LASTEXITCODE -ne 0) { Write-Host "Couldn't start the kit's Publish the template workflow. Start it by hand: https://github.com/$kit/actions/workflows/template.yml" -ForegroundColor Yellow }
    foreach ($i in 1..30) {
      Start-Sleep -Seconds 6
      & $gh api "repos/$template/contents/CLAUDE.md" --silent 2>$null
      if ($LASTEXITCODE -eq 0) { $filled = $true; break }
    }
  }
  if (-not $filled) { Write-Host "The template hasn't filled yet. Look at https://github.com/$kit/actions, then paste this command again." -ForegroundColor Yellow; return }

  Write-Host "`n4. Marking it as a template"
  & $gh repo edit $template --template
  if ($LASTEXITCODE -ne 0) { Write-Host "Couldn't mark $template as a template. Tick Template repository in its Settings." -ForegroundColor Yellow; return }

  $link = "https://github.com/new?template_owner=AnIdeaLab&template_name=second-brain&name=my-brain&visibility=private"
  Write-Host "`nSuccess. The link that makes a brain:" -ForegroundColor Green
  Write-Host $link
  try { Set-Clipboard -Value $link; Write-Host '(copied)' } catch { }
}
