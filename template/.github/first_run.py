#!/usr/bin/env python3
"""Starts a brain made from the AnIdeaLab brain kit's template: the no-install way to get one.

A brain made from the template is the kit's brain as it came, with {KIT_DATE} and {KIT_ISO} still where its start
date goes. This fills them in with today's date (UTC), in file names and in text files, as the installers do on a
PC or a Mac, writes the setup report (the day it was started, nothing else), and then deletes itself, so it runs
once. It only changes files: whoever runs it commits and pushes.

    python3 .github/first_run.py                  from the top of the brain
    python3 .github/first_run.py --date 2026-01-31    with a date given, for the kit's own check

The brain's "Start this brain" workflow (.github/workflows/first-run.yml) runs it on GitHub's machines a moment
after the brain is made. If this file is still here when the first session opens, that didn't happen, and the
getting-started skill says to run it by hand. Python 3.8+, nothing else.
"""
import os
import sys
from datetime import datetime, timezone

TOP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# The kit's text files, as tools/kit.py and the installers know them.
TEXT = {".md", ".py", ".ps1", ".yml", ".json", ".txt", ".css", ".js", ".mjs", ".sh"}
MONTHS = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split()
REPORT = os.path.join("knowledge", "systems", "brain-updates", "0000-report.md")


def fill(text, day, iso):
    return text.replace("{KIT_DATE}", day).replace("{KIT_ISO}", iso)


def main():
    args = sys.argv[1:]
    when = datetime.strptime(args[1], "%Y-%m-%d") if args[:1] == ["--date"] and len(args) > 1 else datetime.now(timezone.utc)
    day, iso = f"{when.day} {MONTHS[when.month - 1]} {when.year}", when.strftime("%Y-%m-%d")
    me = os.path.abspath(__file__)
    changed = 0
    # Deepest first, so a folder is renamed after what's in it.
    for dirpath, dirs, files in os.walk(TOP, topdown=False):
        if ".git" in os.path.relpath(dirpath, TOP).split(os.sep):
            continue
        for f in files:
            path = os.path.join(dirpath, f)
            if path == me:
                continue
            if os.path.splitext(f)[1] in TEXT or f == ".gitignore":
                try:
                    text = open(path, encoding="utf-8", newline="").read()
                except UnicodeDecodeError:
                    continue
                new = fill(text, day, iso)
                if new != text:
                    open(path, "w", encoding="utf-8", newline="").write(new)
                    changed += 1
        for name in files + dirs:
            if "{KIT_" in name:
                os.rename(os.path.join(dirpath, name), os.path.join(dirpath, fill(name, day, iso)))
                changed += 1
    report = os.path.join(TOP, REPORT)
    if not os.path.exists(report):
        open(report, "w", encoding="utf-8", newline="").write(
            "---\n"
            "about: \"This brain's setup report: the day it was started from the AnIdeaLab brain kit's template. Sent to AnIdeaLab's inbox.\"\n"
            "tags: [the-brain]\n"
            f"updated: {day}\n"
            "---\n"
            "# Setup report\n\n"
            f"This brain was started from the AnIdeaLab brain kit's template on {day} (UTC).\n")
    os.remove(me)
    print(f"This brain starts on {day}: {changed} files and names filled in, and the setup report written.")


if __name__ == "__main__":
    main()
