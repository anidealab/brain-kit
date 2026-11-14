---
name: image-to-3d
description: "Turn a picture of one object into a 3D model (a GLB file anyone can open), free, with Microsoft's TRELLIS.2 on Hugging Face through the brain's AI job, or through fal on the owner's key as the paid route: getting a good picture, cutting its background out, the run, setting up the free Hugging Face token, and what comes back. Read first for any 3D model made from a picture or a photo."
---

# Picture to 3D model
From a picture of one object to a GLB, the 3D file format a browser, a game engine, Blender and most 3D viewers open. The free route needs no GPU and no paid account: the model runs on Hugging Face's GPUs, called from the brain's [AI job](../../.github/workflows/ai-job.yml) on GitHub's machines, with a free Hugging Face account's token. The paid route is the same model, or others, through [fal](../fal/SKILL.md) on the owner's own key.

## The steps
1. **A good picture** of the object, and the owner's pick (below).
2. **Cut its background out:** [cut_background.py](cut_background.py).
3. **Make the model:** free with [run_trellis.py](run_trellis.py) in the AI job, or paid through fal.
4. **Look at it, and tell the owner** what came back.

Keep the GLB as it first came back, beside any fixed copy, so every change can be compared with it. It's big (often 10 MB or more): keep it on the owner's computer or in the project's own place, not in this repo.

## 1. The picture
A photo works if the object is alone on a plain background. Most often a made one works better: a few cheap pictures through [fal](../fal/SKILL.md) (under a cent each on FLUX.1 schnell; the owner's go for the spend first, as that skill says). What makes a good one:
- the whole object alone, centred, fully in frame with a clear margin all round, nothing cropped;
- a three-quarter view from slightly above;
- a plain, flat, light-grey studio background: no ground, scenery, fog or text; soft, even light, gentle shadows;
- the parts that move, if any, shown plainly (a hinge, a lid partly open), since the model guesses what it can't see.

Make a few that differ in one thing, show them on one labelled sheet, and let the owner pick.

## 2. Cut the background out
In the AI job, or anywhere with Python:
```
pip install numpy pillow scipy
python3 skills/image-to-3d/cut_background.py picture.png picture-rgba.png
```
TRELLIS.2's own background remover calls another free Space that is often out of quota, so give it a picture with the background already cut (RGBA) and that step is skipped. The script fits the background's colour from the picture's border and cuts every pixel near it; its top says when to change `--threshold` or use `--keep-inside`. Look at the result before the run.

## 3. Make the model, free
**Once: the free Hugging Face token.** Each run asks Hugging Face for about four minutes of GPU, more than it gives anyone without an account, so the AI job signs in with a free account's read token, `HF_TOKEN`. The owner makes a free account at https://huggingface.co (no card), then puts the token in with [add-a-key](../add-a-key/SKILL.md), pasting this into PowerShell with their repo's name in:
```
powershell -ExecutionPolicy Bypass -File "C:\AI-Brain-Link\<repo name>\skills\add-a-key\add-api-keys.ps1" -Secret HF_TOKEN -Page "https://huggingface.co/settings/tokens" -Tell "Sign in, press Create new token, choose Read, give it any name, and copy it." -Prefix "hf_" -Check "https://huggingface.co/api/whoami-v2"
```
With no PowerShell, the owner adds it by hand, as add-a-key says. Then its row in the keys and accounts note (name, Hugging Face, the date, what it's for; never the value).

**The run.** Push the cut picture alone to a `transfer/<name>` branch ([my-pc](../my-pc/SKILL.md) has how), then start the workflow "AI job" on `main` with:
- `label`: what it's for;
- `files`: the branch; its files land in `in/`;
- `code`:
  ```python
  import subprocess, sys
  subprocess.run([sys.executable, '-m', 'pip', 'install', '-q', 'gradio_client'], check=True)
  subprocess.run([sys.executable, 'skills/image-to-3d/run_trellis.py', 'in/object-rgba.png', 'out/object.glb'], check=True)
  ```
A run takes two or three minutes. The GLB is attached to the run as `out-<run id>` for 3 days (`gh run download <run id>`, or the GitHub tool). Delete the transfer branch afterwards with the "Delete branches" workflow.

**The free quota is about one model a day.** A free account's daily GPU time covers one run (two calls of 120 seconds each); a second the same day is refused, and the quota comes back about a day after it ran out. So plan one model a day, or take the paid route with the owner's go. Another `--seed` gives another guess at the same picture; the other options are at the script's top. If the Space has changed, `Client('microsoft/TRELLIS.2').view_api()` (from `gradio_client`) lists its calls.

## 3b. Make the model, paid
When the owner wants more than one model a day, or the free Space is down: fal's `fal-ai/trellis-2` runs the same model, about US$0.25 to 0.35 a model by resolution (fal's page, 14 Nov 2026), and fal has others (`fal_find.py search "image to 3d" --category image-to-3d`). Run it with the [fal skill](../fal/SKILL.md)'s steps, price first and the owner's go before sending, with an entry like:
```python
{"name": "object", "endpoint": "fal-ai/trellis-2", "files": {"image_url": "in/object-rgba.png"}, "args": {"resolution": 1024}}
```

## What comes back
- **A textured GLB** of about 200,000 faces and around 10 MB, centred, about one unit across, Y up, facing the side the picture was taken from. `--faces` makes it lighter; for a web page, ask for 50,000 or fewer.
- **Glowing colours come back grey:** lights and glows lose their glow. Add it back in whatever shows the model.
- **A flat plate underneath** from the picture's shadow, sometimes. Cut it off in a 3D tool, or make the picture again with softer shadow.
- **It invents what the picture can't show,** such as a back or a support. A picture that shows more of the object, or another seed, helps.
- **One mesh in many small pieces,** not one piece per real part. Splitting it into moving parts is a separate job, for a 3D tool such as Blender.

Open it to look: drag the file into https://gltf-viewer.donmccurdy.com, or open it in Blender. Show the owner a picture of it, and say which route made it and what it cost.
