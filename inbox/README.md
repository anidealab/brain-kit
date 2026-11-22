# The report inbox

Each time a brain applies a brain update, its agent writes a report of how it went (what went in, what clashed, what broke, any code it had to change) and pushes it to the brain's own repo; a brain made from the template sends a short setup report when it starts. The brain's "Send brain update reports" workflow sends each one to the inbox, which saves it in AnIdeaLab's private reports repo, `AnIdeaLab/brain-reports`, as `reports/<owner>/<repo>/<NNNN>-report.md`, so the kit gets better.

- **No key in any brain.** The workflow sends GitHub's own sign-in token for that run (OIDC, made for the audience `anidealab-brain-reports`). [api/report.js](api/report.js) checks it against GitHub's public keys, and takes the sender's repo from it.
- **Where it runs:** on AnIdeaLab's own site, at `https://anidealab.com/api/report`, since 22 Nov 2026 (a Cloudflare Worker; before that, a Vercel project of its own). The site's copy of [api/report.js](api/report.js) is the live one; the one here is kept so anyone can read what the inbox does. It needs two settings: `REPORTS_REPO`, the reports repo as owner/name, and `REPORTS_TOKEN`, a fine-grained GitHub token with Contents read and write on that repo only.
- **Its address** is in [address.txt](address.txt), which brains read each time they send, so changing it moves every brain at once, with no update. Empty means the inbox isn't open, and reports wait in each brain until it is (running the workflow by hand sends them all).

A quick test that it's up: opening the address in a browser answers "This inbox takes brain update reports", and anything sent without a GitHub Actions token is turned away.
