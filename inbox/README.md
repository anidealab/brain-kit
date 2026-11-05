# The report inbox

Each time a brain applies a brain update, its agent writes a report of how it went (what went in, what clashed, what broke, any code it had to change) and pushes it to the brain's own repo. The brain's "Send brain update reports" workflow then sends it here, and this saves it in AnIdeaLab's private reports repo as `reports/<owner>/<repo>/<NNNN>-report.md`, so the kit gets better.

- **No key in any brain.** The workflow sends GitHub's own sign-in token for that run (OIDC, made for the audience `anidealab-brain-reports`). [api/report.js](api/report.js) checks it against GitHub's public keys, and takes the sender's repo from it.
- **Where it runs:** Vercel, from this folder (the project's root directory is `inbox`). It needs two settings: `REPORTS_REPO`, the reports repo as owner/name, and `REPORTS_TOKEN`, a fine-grained GitHub token with Contents read and write on that repo only.
- **Its address** is in [address.txt](address.txt), which brains read each time they send. Empty means the inbox isn't open yet, and reports wait in each brain until it is (running the workflow by hand sends them all).

## Setting it up (once)
1. **The reports repo:** a private GitHub repo with something in it, so it isn't empty. The live inbox saves to `AnIdeaLab/brain-reports`, made 26 Oct 2026 and moved into the AnIdeaLab organisation on 6 Nov 2026, when the inbox got its token for it.
2. **The rest is one command,** pasted into PowerShell on a Windows PC ([setup-windows.ps1](setup-windows.ps1)):
   ```
   irm https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/inbox/setup-windows.ps1 | iex
   ```
   It installs Node if it's missing, logs in to Vercel (a browser page, the first time), asks which repo the reports go in (as owner/name, or set `$env:REPORTS_REPO` first), and opens GitHub's token form, filled in: under "Repository access" choose "Only select repositories" and pick that repo (GitHub can't pre-fill that part), generate it, and paste it back. It deploys this folder as the Vercel project `anidealab-brain-inbox` with the repo as `REPORTS_REPO` and the token as `REPORTS_TOKEN`, checks it answers, and copies its address. Running it again replaces the token and deploys again, which is also how a change to [api/report.js](api/report.js) goes live.
3. **The address:** an agent puts it, with `/api/report` on the end, as the only line of [address.txt](address.txt), and pushes. Brains read it the next time they send.

The other way is Vercel's site: add a project, import this repo, set its root directory to `inbox` (the import's default is the repo's top, which has no inbox), add `REPORTS_REPO` and `REPORTS_TOKEN`, and deploy. Its address is the project's `.vercel.app` one, not a deployment's own, which Vercel keeps behind a login.

A quick test that it's up: opening the address in a browser answers "This inbox takes brain update reports", and anything sent without a GitHub Actions token is turned away.
