---
name: fal
description: "Make and change pictures, video, sound, voices and 3D models with any of the 1,000+ AI models fal.ai hosts, on the owner's own fal key, through this brain's AI job: find a model and read its inputs free, read the price, get the owner's go for the spend, run it and bring the files back. Use for any ask to generate or edit a picture, a video clip, audio, a voice or a 3D model, for cheap concept pictures and clips to pick a look from, and to set fal up the first time."
---

# fal: any AI model on the owner's key

fal.ai hosts most of the well-known image, video, audio and 3D models (1,475 on 14 Nov 2026) behind one pay-as-you-go key. The owner's key lives in this repo's GitHub Actions secrets as `FAL_KEY` (the core's secrets gate), so every paid call runs in the [AI job](../../.github/workflows/ai-job.yml): a workflow on GitHub's machines that runs a short Python script with the brain's keys. Finding models and reading their inputs needs no key and works from anywhere.

- [fal_find.py](fal_find.py) finds models and reads their inputs. Free, no key, standard library only.
- [run_fal.py](run_fal.py) reads prices, holds a batch to the figure the owner agreed, runs the models and saves the files. It needs the key, so it runs in the AI job.

## Money
The core's money gate: spending needs the owner's go. fal bills the owner's own account for each run.
- **Before each paid batch,** read its price (free), tell the owner the estimate in US dollars and what it buys ("four pictures, about 2 cents"), and wait for their go. Then send it with `--cap` at that figure. `run_fal.py` sends nothing without `--cap`, and nothing over it.
- **The estimate runs low,** so leave about 40% room over it when a batch is near the owner's limit or the account's balance, most of all on cheap per-unit models. It's one price per endpoint, so it misses a dearer resolution than the price line's, output bigger than asked (a "480p" video that comes out larger uses more tokens), and price lines that don't say what a unit is; estimates have come in up to a third under the bill. `--cap` holds the estimate, not the bill.
- **Any paid job, fal or not** (a rented machine, anything billed by the run): when new input lands mid-run, work out what it changes before cancelling, and if its meaning is unclear, ask the owner while the run goes on; a cancel on a misread loses what was spent. After any cancel, run the job's stop and list what's still running: a cancel can kill the script before its clean-up, and rented machines go on billing.
- **If the owner has set a limit of their own** ("fal is fine under a dollar a job"), a batch under it needs no ask: pass their limit as `--cap`, and say afterwards what it cost. When they give one, save it first as a decision on the decisions shelf, in their words, so every later agent finds it. With no such note, ask each time.
- **Never split a batch** into small ones to stay under a figure, and never raise `--cap` yourself.
- **Say what was spent** at the end of a job: the estimate the script printed. It's fal's price times what was asked for, not the bill; `--balance` shows what's left on the account when fal shares it.
- **Free:** finding models, reading their inputs, and reading prices: `--price` with the key, or with no key from a model's `docs` page (its Pricing lines). The AI job runs on the free minutes GitHub gives an account each month; a job takes a few.

## Set it up (once)
1. **A fal account with credit.** The owner signs up at https://fal.ai and adds credit under Billing. fal charges only for what's run, and a few dollars makes hundreds of pictures. How much to put in is theirs to say.
2. **Their key into the brain,** with [add-a-key](../add-a-key/SKILL.md). Give them this to paste into PowerShell, with their repo's name in:
   ```
   powershell -ExecutionPolicy Bypass -File "C:\AI-Brain-Link\<repo name>\skills\add-a-key\add-api-keys.ps1" -Secret FAL_KEY -Page "https://fal.ai/dashboard/keys" -Tell "Sign in to fal, make a new key (any name), and copy it."
   ```
   Leave `-Prefix` and `-Check` out: fal's keys have no fixed start, and fal reads a key as `Authorization: Key <key>`, which the script's check doesn't send. On a Mac, give the Mac's line for the same key, `add-api-keys.sh` with `--secret FAL_KEY` and the same page and words (the my-mac skill's "Keys on a Mac"). With no computer set up yet, the owner adds it by hand: this repo on GitHub, then Settings, Secrets and variables, Actions, New repository secret, with the name `FAL_KEY`. Never ask for the key in the chat. If they paste it there, have them delete that key on fal's keys page and make a new one.
3. **Check it,** spending nothing: start the AI job (step 4 below) with this code. A 200 and the account's credit means the key works.
   ```python
   import subprocess, sys
   subprocess.run([sys.executable, "skills/fal/run_fal.py", "--balance"], check=True)
   ```
4. **Write it down:** `FAL_KEY`'s row in the brain's keys and accounts note (its name, fal, the date, what it's for; never the value), and the owner's answer to "ask me each time, or a limit of your own?" as a decision.

## How
1. **Find a model,** free, from any machine:
   ```
   python3 skills/fal/fal_find.py search "image to video" --category image-to-video
   ```
   The search matches keywords, not sentences, so turn the ask into a kind of job first: "a short product video from this photo" is `"image to video"`. Categories include text-to-image, image-to-image, text-to-video, image-to-video, video-to-video, text-to-audio, text-to-speech, speech-to-text, image-to-3d and text-to-3d; `fal_find.py count` lists them all, with how many models each holds.
2. **Read its inputs:** `python3 skills/fal/fal_find.py schema <endpoint>`. Use the input names exactly as printed, or the run fails with a 422. Then `fal_find.py docs <endpoint>` for fal's own page: its Pricing lines give the price at each size or resolution, and it says what lengths and sizes the model takes, which `schema` doesn't. A video model refuses a clip shorter than its shortest (a refused run isn't billed).
3. **Write the job** as the AI job's `code`: a list with one entry for each run, handed to `run_fal.py`.
   ```python
   import json, subprocess, sys
   json.dump([
     {"name": "banner-1", "endpoint": "fal-ai/flux/schnell",
      "args": {"prompt": "...", "image_size": "landscape_16_9"}},      # a picture of a megapixel or under: 1 unit
     {"name": "hero-move", "endpoint": "<an image-to-video endpoint>",
      "files": {"image_url": "in/hero.png"}, "args": {"prompt": "..."}, "units": 5},   # units: seconds of video
   ], open("jobs.json", "w"))
   subprocess.run([sys.executable, "skills/fal/run_fal.py", "jobs.json", "out", "--price"], check=True)
   ```
   - `name` names the files that come back, and `args` are the model's inputs.
   - `files` are inputs that are files: each is uploaded to fal first, and its link passed under that input's name.
   - `units` is how many of the price's units the run uses: seconds for most video, images, megapixels, or thousands of characters. Set it to what the run will really use, from the docs' rate for the size asked, so the estimate is honest. It's 1 if left out.
   - **Keep code that spends inside the job's `code`,** as here, or in a subfolder of its own, never as a script at the top of a shared folder like the session's scratchpad: another agent's script run from there can import it by its name (Python looks in the script's own folder first) and spend. Run Python with `-I`, or from a folder of your own.
4. **Price it.** Start the workflow "AI job" (`ai-job.yml`) on `main` with the GitHub tool's run-workflow method, then read the job's log when the run has finished ([my-pc](../my-pc/SKILL.md) has how runs and logs behave). Its inputs:
   - `label`: what the job is for, shown in the Actions list;
   - `code`: the Python above, ending in `--price`. It prints each model's price, its unit and the batch's estimate, and sends nothing;
   - `files`: a branch whose files land in `in/`, for input pictures and the like. Push them alone to a `transfer/<name>` branch, and delete it afterwards with the "Delete branches" workflow (both in the my-pc skill). Empty for none.
5. **Get the owner's go** for that estimate (Money, above), then start the job again with `"--cap", "0.25"` (their figure) in place of `"--price"`. It prints the estimate again, sends every run at once, and saves each result as `out/<name>.<ext>` with `out/<name>.json` beside it (the request, the result and the request id). A picture takes seconds; a video can take minutes. It waits up to 24 of the job's 30 minutes.
6. **Get the files:** they're attached to the run as `out-<run id>` for 3 days. Download them with the GitHub tool, or `gh run download <run id> -D <folder>`, and look at each before showing it. Keep what's worth keeping where any agent can get it: a small picture in the repo beside the project that uses it, and video or anything big on the owner's computer through its runner (a job there that runs `gh run download <run id> -R <owner>/<repo> -D <folder>`), with a line in the project's notes saying where.
7. **Tell the owner** what came back, which model made each file, and what the batch cost.

**If a run is still going when the wait ends,** it isn't lost and isn't paid for twice: its request id is in the log. Start the job again with `"request_id": "<id>"` added to that run's entry and `"--fetch"` in place of `--cap`.

**With the key in a session's own environment** (the secrets gate allows a copy there), the same commands run where you are: `python3 skills/fal/run_fal.py jobs.json out --price`. The money rules don't change.

## What it's good for
fal's prices on 13 Nov 2026, as a guide to what's cheap; they change, and `--price` reads today's.
- **Pictures** for a page, a post or a product, and moodboards. Per picture of about a megapixel: FLUX.1 schnell US$0.003, FLUX.2 klein US$0.006, FLUX.1 dev US$0.025, Flux 2 Pro US$0.03, Nano Banana 2 US$0.08.
- **Video from words or from a picture.** Per second: PixVerse V6 Max US$0.009, MiniMax H3 Max Turbo US$0.0175, Kling 2.5 Turbo Pro US$0.07, Kling 3.0 Pro US$0.14. So a 5-second clip costs between about 5 and 80 cents.
- **Picture fixes:** background removal, upscaling, editing by instruction, inpainting, try-on, restoration.
- **Sound:** voices, music, sound effects, lip sync, speech to text.
- **3D:** a picture or a sentence to a model.
- **A look to choose from:** a few cheap stills or 5-second clips of a style, a camera move or a mood, made before a build and shown to the owner to pick.

## Getting good results cheaply
- **Make several cheap ones, not one dear one.** Four clips on a cheap model cost less than one on the dearest. Vary one thing in each (the camera, the light, the pace), show them side by side on one labelled sheet, and let the owner pick.
- **Image to video keeps a look steady.** Make the still first, which is cheap and quick to try again, then animate the pick.
- **Price a model you haven't used** before planning a batch around it. Some are priced per token or per "unit", where the estimate is rougher: read the docs page's Pricing lines, and start with one run.
- **Model names and ids change.** If an endpoint named here isn't found, search for it.
- **For better prompts, fal publishes skills of its own** at [fal-ai-community/skills](https://github.com/fal-ai-community/skills): how to word a prompt for each model family, shots and camera moves, and which model suits a job. When a job would go better with one, copy it in with [find-skills](../find-skills/SKILL.md). Take their advice on models and prompts, but run every model through `run_fal.py` in the AI job, not the `genmedia` tool they name, so the key stays in the repo's secrets and the money rules hold.

## When something goes wrong
| What you see | What it means |
|---|---|
| `FAL_KEY is not set` | The key isn't in the repo's Actions secrets yet (Set it up, step 2), or the script ran outside the AI job |
| `Not sent: no --cap` | Nothing is sent without the owner's figure. Tell them the estimate and wait for their go |
| `Not sent: the estimate is over the cap` | Tell the owner the new estimate; run again with `--cap` at the figure they agree |
| `price unknown` | fal's price list has no line for that endpoint: check its id with `search`. The script doesn't send what it can't price |
| A 401 or 403 from fal | The key is wrong or was deleted, or the account has no credit |
| A 422 | An input's name or value is wrong, or outside what the model takes: read `schema` and `docs` again |
| `prices not read` | fal was busy (the script retries) or the key can't read prices. Nothing is sent until a price is read |
| The run isn't in the Actions list | If the run-workflow call timed out, the run may still have been queued: check the list before starting it again |
