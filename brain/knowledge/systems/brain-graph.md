---
about: "The brain graph, the Obsidian view that replays the brain's growth from git history: opening it, reading it, its settings, and the rules for changing it. Read before touching its plugin or explaining it."
tags: [the-brain]
updated: {KIT_DATE}
---
# The brain graph

A view inside Obsidian that shows the brain growing, which came with the kit. Every folder with more than one note is a circle, every note is a dot that appears when it was written, and every link is a line that forms when it was made. It all comes from the repo's git history, so agents don't log anything extra for it. This brain's history starts on {KIT_DATE}, so its graph grows from the first day.

## Opening it
- On the PC, click the brain icon in Obsidian's left ribbon, or press Ctrl+P and run "Brain graph: Open brain graph".
- The first time, run "Reload app without saving" once from Ctrl+P. If it still doesn't show, switch on "Brain graph" under Settings, then Community plugins.
- It needs Git on the computer, and doesn't run on a phone.
- **The first time, it reads the whole history from git,** which takes a few seconds in a new brain and longer as it grows; after that it opens in a second or two. What it read is saved in `.git/brain-graph-cache.json`, which is never committed or synced. If it ever looks wrong, press Ctrl+P and run "Brain graph: Rebuild brain graph from scratch": it forgets that file and reads everything from git again.

## Reading it
- **Dots are notes, circles are folders.** The core sits in the middle; the skills and knowledge libraries are the two big branches. Bigger dots have more links.
- **Lines are links,** bundled along the branches, faint until you point at a note.
- **The accent colour is activity:** a new note sends out a ring, a new link flashes, and an edited note pulses. The owner's own edits from Obsidian show in a second colour.
- **The timeline box,** bottom centre, shows the commit the replay is on and a smoothed curve of how busy each commit was.

## Using it
- **Play** with the round button or the space bar. Drag along the curve, scroll over it or use the arrow keys to move through commits; the list button opens every commit.
- **Point at a dot** to see its links; click it to open the note. Drag a dot and its circle follows (physics on).
- **Zoom** with the scroll wheel; double-click or press F to recentre.
- **Live:** while it's open it checks for new commits every 15 seconds and plays them in.
- **Options** (the sliders button, top right): speed, replay when opened, skill links on hover or always, physics and hold shape, theme and accent colour. They save to `.obsidian/plugins/brain-graph/data.json`. The replay always shows the whole history.

## For agents
- The code is `.obsidian/plugins/brain-graph/main.js`, with its look in `styles.css`. Don't change it unless the owner asks.
- **How it stays quick, and why it can be trusted.** After each commit only the links it could have changed are worked out again (`LinkBook`): those in the notes it wrote, moved or removed, and those pointing at a path it added, removed or moved. Every 500 commits and at the end it works every link out the full way and compares; if they ever differ, it builds the whole replay the full way. The saved history file files each commit under its git hash and each note version's facts under its blob hash, so an entry can't go out of date; it's set aside if it can't be read or came from a different version of the code that reads git (`CACHE_VERSION` changes by itself).
- **After any change to how the replay is built** (`LinkBook`, `assemble`, `readModel`), run `node .obsidian/plugins/brain-graph/test/same-as-full.mjs`: it builds the replay the quick way and the full way from the whole history and says SAME or DIFFERENT.
- `test/run.mjs` runs it in Chromium with a stand-in for Obsidian, against this repo's history, and takes screenshots: `node .obsidian/plugins/brain-graph/test/run.mjs .obsidian/plugins/brain-graph/main.js <scratch folder>` (it needs Playwright).
