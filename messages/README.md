# Messages from AnIdeaLab

A message here goes to every brain made from the kit at once, for something every owner should know now: a security fix, a step everyone must take, big news. It changes no file in a brain, so it needs no update and goes out as soon as it's on `main`.

- **One file per message:** `NNNN-<a-few-words>.md`, numbered on from the last (`0001-…`), in plain text or simple Markdown. A brain shows the owner the whole file word for word, line breaks kept, then asks "Can I mark it read, so it isn't repeated by future agents?"
- **How it reaches a brain:** the daily check at session start (`brain_update.py notice`) reads this folder on `main`, and shows each message the brain hasn't marked read in the first session its owner starts. On a yes, `brain_update.py read` adds a row to the brain's `knowledge/systems/brain-updates/messages.md`, so no later session shows it again. A brain made after a message was sent never sees it; a brain checks at most once a day, so allow a day.
- **To withdraw one,** delete its file: brains that haven't shown it yet won't. One already shown stays read.
- **To change one before brains have seen it,** edit the file: a brain fetches its words once, the first time it would show it.

Brains get this check from brain update 12 on; one still on an earlier update doesn't see messages.
