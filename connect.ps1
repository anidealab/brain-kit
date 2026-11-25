# Connects your computer to your second brain, from step 4 of anidealab.com/second-brain. Paste into PowerShell:
#   irm https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/connect.ps1 | iex
# The same setup as install.ps1, which it runs: the runner and, if you'd like it, Obsidian, for the brain you made
# from the template. The one difference: it's run before the brain's first chat, so it ends by sending you back
# to the start page for your first message (BRAIN_KIT_FROM_SITE, which the installer reads), not back to a chat.
# Windows PowerShell 5.1, plain ASCII.
& {
  $ProgressPreference = 'SilentlyContinue'
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
  $env:BRAIN_KIT_FROM_SITE = '1'
  try {
    $script = Invoke-RestMethod -UseBasicParsing 'https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/install.ps1'
    Invoke-Expression $script
  } catch {
    Write-Host "Couldn't get the setup ($($_.Exception.Message)). Check the PC is online, then paste the same line again." -ForegroundColor Yellow
  } finally {
    Remove-Item Env:BRAIN_KIT_FROM_SITE -ErrorAction SilentlyContinue
  }
}
