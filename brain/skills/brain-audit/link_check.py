#!/usr/bin/env python3
"""The monthly check of the AI-Brain-Link folder (the deep audit's step 3).

The brain's folder on a computer grows by itself: job data, tools and installers, Python environments, logs.
Once a month this lists what's in it by size, what's new or grown since last month and what has sat in the bin
over a month, so the agent can bring the owner a few folders at a time, each with one of three choices:
  backup  Back it up                        (left in the backup: out of my-folders.json's skip list)
  keep    Keep it, but don't back it up     (added to that folder's skip list in my-folders.json)
  bin     Bin it                            (moved to AI-Brain-Link/_trash/<date>/, which the owner empties)

Three commands:
  scan     On the computer, through its runner, from a job's checkout of the brain. Reads only; changes nothing.
           Prints a table and one line starting "LINK-CHECK-RECORD " with this month's sizes.
  save     In the session: reads the job's log (a file) and puts that line's sizes in link-sizes.json beside
           this script, as last month's numbers for next time. The owner's choices are kept.
  choose   In the session, after the owner answers: records the choice in link-sizes.json, changes the skip list
           in ../backup/my-folders.json for backup and keep, and for bin prints the command that moves the folder
           to the bin, for a job on that computer.

It never flags or bins the runner, the bin itself, or a copy of a repo (a folder with .git in it, a worktree's .git file too: the brain's own copy
lives in AI-Brain-Link on a computer set up from the kit). Python 3 only, nothing to install. It never follows links
or junctions, and lists names and sizes, never what's inside a file.
"""
import argparse
import datetime as dt
import json
import os
import platform
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RECORD = os.path.join(HERE, "link-sizes.json")
FOLDERS = os.path.join(HERE, "..", "backup", "my-folders.json")
GB = 1024 ** 3
DEEP_OVER = 10 * GB      # a folder this big is listed one level down too, and so on while they're this big
MAX_DEPTH = 4            # how many levels below AI-Brain-Link the table goes at most
FOLD_UNDER = 100 * 1024 ** 2  # in a listed folder, subfolders smaller than this share one line (the record keeps each)
FLAG_GROWTH = 1 * GB     # new or grown by this much since last month: worth asking about
FLAG_UNDECIDED = 5 * GB  # this big and never asked about: worth asking about
BIN_AGE_DAYS = 30
NEVER_BIN = {"_runner": "the runner itself", "_trash": "the bin"}  # and any copy of a repo (found by scan)
CHOICES = {"backup": "Back it up", "keep": "Keep it, but don't back it up", "bin": "Bin it"}
MARK = "LINK-CHECK-RECORD "
REPOS = set()  # each folder found with .git in it, filled by walk and tally


def computer_name():
    # The same name backup.py uses, so my-folders.json's entry is found.
    name = platform.node().split(".")[0] or platform.system()
    return re.sub(r'[<>:"/\\|?*]', "_", name).strip() or "computer"


def default_root():
    """The AI-Brain-Link folder in use: on Windows the one on any drive that holds the runner (_runner), else the
    first found; on a Mac or Linux ~/AI-Brain-Link."""
    found = []
    if os.name == "nt":
        import string
        found = [f"{d}:\\AI-Brain-Link" for d in string.ascii_uppercase if os.path.isdir(f"{d}:\\AI-Brain-Link")]
    home = os.path.expanduser("~/AI-Brain-Link")
    if os.path.isdir(home):
        found.append(home)
    for p in found:
        if os.path.isdir(os.path.join(p, "_runner")):
            return p
    return found[0] if found else None


def human(n):
    n = float(n)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if abs(n) < 1024 or unit == "TB":
            return f"{n:.0f} {unit}" if unit in ("B", "KB") else f"{n:.1f} {unit}"
        n /= 1024


def is_link(entry):
    try:
        if entry.is_symlink():
            return True
        j = getattr(entry, "is_junction", None)
        return bool(j and j())
    except OSError:
        return True


def walk(path):
    """Bytes, files and newest change under path, never following links."""
    size = files = errors = 0
    newest = 0.0
    stack = [path]
    while stack:
        d = stack.pop()
        try:
            with os.scandir(d) as it:
                for e in it:
                    try:
                        if is_link(e):
                            continue
                        if e.is_dir(follow_symlinks=False):
                            if e.name == ".git":
                                REPOS.add(d)
                            stack.append(e.path)
                        else:
                            if e.name == ".git":  # a worktree's .git is a file
                                REPOS.add(d)
                            st = e.stat(follow_symlinks=False)
                            size += st.st_size
                            files += 1
                            newest = max(newest, st.st_mtime)
                    except OSError:
                        errors += 1
        except OSError:
            errors += 1
    return size, files, newest, errors


def split(rel, sub):
    """Whether a big folder is worth listing by its parts: it holds more than one folder (one inside one is the same
    thing, so the question stays on the outer one)."""
    return sum(1 for k in sub if k.count(os.sep) == rel.count(os.sep) + 1) > 1


def tally(path, rel, depth):
    """Bytes, files, newest change and errors under path (at this depth below AI-Brain-Link), and rows for its
    subfolders: each one, and theirs while a subfolder is over DEEP_OVER, down to MAX_DEPTH."""
    size = files = errors = 0
    newest = 0.0
    rows = {}
    try:
        with os.scandir(path) as it:
            entries = list(it)
    except OSError:
        return 0, 0, 0.0, 1, {}
    for e in entries:
        try:
            if is_link(e):
                continue
            if e.is_dir(follow_symlinks=False):
                if e.name == ".git":
                    REPOS.add(path)
                r = rel + os.sep + e.name
                if depth + 1 < MAX_DEPTH:
                    s, f, n, er, sub = tally(e.path, r, depth + 1)
                else:
                    (s, f, n, er), sub = walk(e.path), {}
                errors += er
                rows[r] = [s, f, n]
                if s >= DEEP_OVER and split(r, sub):
                    rows.update(sub)
            else:
                if e.name == ".git":  # a worktree's .git is a file
                    REPOS.add(path)
                st = e.stat(follow_symlinks=False)
                s, f, n = st.st_size, 1, st.st_mtime
        except OSError:
            errors += 1
            continue
        size += s
        files += f
        newest = max(newest, n)
    return size, files, newest, errors, rows


def measure(root):
    """{relative path: [bytes, files, newest]} for each top folder, loose top files as one row, and the folders
    inside any folder over DEEP_OVER (down to MAX_DEPTH levels) and inside the bin."""
    rows, errors = {}, 0
    loose = [0, 0, 0.0]
    with os.scandir(root) as it:
        tops = sorted(it, key=lambda e: e.name.lower())
    for top in tops:
        if is_link(top):
            continue
        if not top.is_dir(follow_symlinks=False):
            try:
                st = top.stat(follow_symlinks=False)
                loose[0] += st.st_size
                loose[1] += 1
                loose[2] = max(loose[2], st.st_mtime)
            except OSError:
                errors += 1
            continue
        s, f, n, er, sub = tally(top.path, top.name, 1)
        errors += er
        rows[top.name] = [s, f, n]
        if (s >= DEEP_OVER and split(top.name, sub)) or top.name == "_trash":
            rows.update(sub)
    if loose[1]:
        rows["(files at the top)"] = loose
    return rows, errors


def norm(p):
    return os.path.normcase(os.path.normpath(p.replace("\\", os.sep).replace("/", os.sep)))


def load(path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return default


def dump(path, data):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def link_entry(folders, computer, root):
    """The my-folders.json entry that backs up this computer's AI-Brain-Link folder, or None."""
    comp = folders.get("computers", {}).get(computer, {})
    for entry in comp.get("folders", []):
        src = os.path.expandvars(os.path.expanduser(entry.get("from", "")))
        if norm(src) == norm(root) or re.split(r"[\\/]", src.rstrip("\\/"))[-1].lower() == "ai-brain-link":
            return entry
    return None


def backed_up(rel, entry):
    if entry is None:
        return False
    parts = norm(rel).split(os.sep)
    skips = {norm(s) for s in entry.get("skip", [])}
    if any(os.sep.join(parts[:i]) in skips for i in range(1, len(parts) + 1)):
        return False
    return not any(p in entry.get("skipNamed", []) for p in parts)


def record_root():
    return load(RECORD, {"about": "", "computers": {}})


# ---- scan

def cmd_scan(a):
    root = a.root or default_root()
    if not root or not os.path.isdir(root):
        print("No AI-Brain-Link folder found on this computer" + (f" at {root}" if root else "") + ".")
        return 3
    computer = a.computer or computer_name()
    today = dt.date.today()
    rows, errors = measure(root)
    repos = sorted({os.path.relpath(p, root) for p in REPOS})
    rec = record_root().get("computers", {}).get(computer, {})
    last, last_date, choices = rec.get("sizes", {}), rec.get("checked"), rec.get("choices", {})
    last = {norm(k): v for k, v in last.items()}
    choices_n = {norm(k): v for k, v in choices.items()}
    folders = load(FOLDERS, {})
    entry = link_entry(folders, computer, root)
    own = {norm(os.path.expandvars(os.path.expanduser(e.get("from", ""))))
           for e in folders.get("computers", {}).get(computer, {}).get("folders", [])}

    def taken(k):
        parts = k.split(os.sep)
        return backed_up(k, entry) or any(norm(os.path.join(root, *parts[:i])) in own for i in range(1, len(parts) + 1))

    print(f"== AI-Brain-Link on {computer}: {root}, {today.isoformat()}")
    print(f"Last month's numbers: {last_date or 'none yet (the first check)'}")
    if entry is None:
        print("The backup doesn't take this whole folder: only folders added to it one by one (my-folders.json).")
    try:
        import shutil
        du = shutil.disk_usage(root)
        print(f"The drive: {human(du.free)} free of {human(du.total)}")
    except OSError:
        pass
    total = sum(v[0] for k, v in rows.items() if os.sep not in k)
    print(f"In all: {human(total)}" + (f"; {errors} items couldn't be read" if errors else ""))
    print()
    print(f"{'Folder':<48} {'Size':>10} {'Change':>12} {'Files':>9}  {'Last changed':<12} {'Backed up':<9} Choice")
    flags = []

    def kids(k):
        pre = k + os.sep
        return sorted((c for c in rows if c.startswith(pre) and os.sep not in c[len(pre):]), key=lambda c: -rows[c][0])

    def line(k, label):
        s, f, n = rows[k]
        prev = last.get(norm(k))
        if prev is None:
            change = "new" if last_date else ""
        elif abs(s - prev) < 1024 ** 2:
            change = ""
        else:
            change = ("+" if s >= prev else "-") + human(abs(s - prev))
        when = dt.date.fromtimestamp(n).isoformat() if n else ""
        bu = "" if k.startswith("(") else ("yes" if taken(k) else "no")
        choice = choices_n.get(norm(k), {}).get("choice", "")
        if in_repo(k, repos):
            choice = choice or "(a repo: never binned)"
        print(f"{label[:48]:<48} {human(s):>10} {change:>12} {f:>9}  {when:<12} {bu:<9} {choice}")

    def show(k, depth):
        line(k, "  " * depth + k.rsplit(os.sep, 1)[-1])
        ks = kids(k)
        small = [c for c in ks if rows[c][0] < FOLD_UNDER and not k.startswith("_trash")]
        for c in ks:
            if c not in small or len(small) < 3:
                show(c, depth + 1)
        if len(small) >= 3:
            print(f"{'  ' * (depth + 1) + f'({len(small)} smaller folders)':<48} {human(sum(rows[c][0] for c in small)):>10}")

    for top in sorted((k for k in rows if os.sep not in k), key=lambda k: -rows[k][0]):
        show(top, 0)
    for k in sorted(rows, key=lambda k: -rows[k][0]):
        if in_repo(k, repos):
            continue
        flags.extend(flag(k, rows[k][0], last.get(norm(k)), last_date, chosen(k, choices_n), today, rows[k][2],
                          any(c.startswith(k + os.sep) for c in rows)))
    print()
    print("Worth asking about:" if flags else "Nothing new or big enough to ask about this month.")
    for k, why in flags:
        print(f"- {k} ({human(rows[k][0])}): {why}")
    sizes = {k.replace(os.sep, "\\"): v[0] for k, v in rows.items()}
    if repos:
        print()
        print("Copies of repos (never flagged or binned): " + ", ".join(repos))
    print()
    print(MARK + json.dumps({"computer": computer, "root": root, "checked": today.isoformat(), "sizes": sizes,
                             "repos": [r.replace(os.sep, "\\") for r in repos]},
                            ensure_ascii=False, separators=(",", ":")))
    return 0


def in_repo(k, repos):
    """Whether folder k is a copy of a repo or inside one."""
    nk = norm(k)
    return any(nk == norm(r) or nk.startswith(norm(r) + os.sep) for r in repos)


def chosen(k, choices_n):
    """The owner's choice for this folder, or for the nearest folder above it: a choice covers what's inside."""
    parts = norm(k).split(os.sep)
    for i in range(len(parts), 0, -1):
        c = choices_n.get(os.sep.join(parts[:i]), {}).get("choice")
        if c:
            return c
    return ""


def flag(k, s, prev, last_date, choice, today, newest, listed_inside):
    top = k.split(os.sep)[0]
    if k.startswith("_trash" + os.sep):
        if k.count(os.sep) > 1:
            return []
        m = re.match(r"(\d{4}-\d{2}-\d{2})", k.split(os.sep, 1)[1])
        day = dt.date.fromisoformat(m.group(1)) if m else (dt.date.fromtimestamp(newest) if newest else today)
        age = (today - day).days
        return [(k, f"in the bin {age} days: the owner can empty it")] if age > BIN_AGE_DAYS else []
    if top in NEVER_BIN or k.startswith("("):
        return []
    if listed_inside:
        return []  # a big folder is asked about by its parts, listed under it
    if prev is None and last_date and s >= FLAG_GROWTH:
        return [(k, "new since last month")]
    if prev is not None and s - prev >= FLAG_GROWTH:
        return [(k, f"grew {human(s - prev)} since last month")]
    if not choice and s >= FLAG_UNDECIDED:
        return [(k, "big, and never asked about")]
    return []


# ---- save

def cmd_save(a):
    found = None
    with open(a.log, encoding="utf-8", errors="replace") as f:
        for line in f:
            i = line.find(MARK)
            if i >= 0:
                found = json.loads(line[i + len(MARK):].strip())
    if not found:
        print(f"No {MARK.strip()} line in {a.log}.")
        return 1
    rec = record_root()
    rec["about"] = ABOUT
    comp = rec.setdefault("computers", {}).setdefault(found["computer"], {})
    comp["root"], comp["checked"], comp["sizes"] = found["root"], found["checked"], found["sizes"]
    comp["repos"] = found.get("repos", [])
    comp.setdefault("choices", {})
    dump(RECORD, rec)
    print(f"Saved {len(found['sizes'])} sizes for {found['computer']} ({found['checked']}) in {RECORD}.")
    return 0


ABOUT = ("The monthly AI-Brain-Link check's record, by link_check.py beside it: for each computer, the folder, the "
         "date of the last check, each folder's size in bytes then (last month's numbers for the next check), and "
         "the owner's choice for a folder: backup (Back it up), keep (Keep it, but don't back it up) or bin (Bin it), "
         "with the date and why.")


# ---- choose

def folder_entry(folders, computer, root, rel):
    """The my-folders.json entry that backs up just this folder of AI-Brain-Link, or None."""
    comp = folders.get("computers", {}).get(computer, {})
    want = norm(os.path.join(root, rel))
    for entry in comp.get("folders", []):
        if norm(os.path.expandvars(os.path.expanduser(entry.get("from", "")))) == want:
            return entry
    return None


def cmd_choose(a):
    rec = record_root()
    rec["about"] = ABOUT
    comp = rec.setdefault("computers", {}).get(a.computer)
    if comp is None:
        print(f"No check saved for {a.computer} yet: run scan there and save it first.")
        return 1
    rel = a.folder.replace("/", "\\").strip("\\")
    top = rel.split("\\")[0]
    repos = comp.get("repos", [])
    if a.choice == "bin":
        if top in NEVER_BIN:
            print(f"{rel} is {NEVER_BIN[top]}: it isn't binned.")
            return 1
        if in_repo(rel.replace("\\", os.sep), [r.replace("\\", os.sep) for r in repos]):
            print(f"{rel} is a copy of a repo (it has .git in it), maybe the brain's own: it isn't binned.")
            return 1
        inside = [r for r in repos if norm(r.replace("\\", os.sep)).startswith(norm(rel.replace("\\", os.sep)) + os.sep)]
        if inside:
            print(f"Careful: {rel} holds a copy of a repo ({', '.join(inside)}). Bin it only if the owner said so knowing that.")
    today = dt.date.today().isoformat()
    comp.setdefault("choices", {})[rel] = {"choice": a.choice, "date": today, **({"why": a.why} if a.why else {})}
    dump(RECORD, rec)
    print(f"{rel}: {CHOICES[a.choice]} (recorded in {os.path.relpath(RECORD)}).")

    root = comp["root"]
    folders = load(FOLDERS, None)
    if folders is None:
        if a.choice == "backup":
            print("The backup isn't set up yet (no my-folders.json): the choice is kept, and the first backup asks "
                  "about it (the backup skill).")
    else:
        entry = link_entry(folders, a.computer, root)
        own = folder_entry(folders, a.computer, root, rel)
        changed = False
        if entry is not None:
            skip = [s for s in entry.get("skip", []) if norm(s) != norm(rel)]
            if a.choice == "keep":
                skip.append(rel)
            if skip != entry.get("skip", []):
                entry["skip"] = skip
                changed = True
                print(f"my-folders.json: {rel} {'left out of' if a.choice == 'keep' else 'back in'} the backup.")
            elif a.choice == "backup" and not backed_up(rel, entry):
                print(f"Note: a folder above {rel} is skipped, so it still isn't backed up: change that one too.")
        elif a.choice == "backup" and own is None:
            # No entry for the whole folder: back up just this one, beside the computer's other folders.
            comp_f = folders.setdefault("computers", {}).setdefault(a.computer, {}).setdefault("folders", [])
            comp_f.append({"from": root + "\\" + rel if "\\" in root else root + "/" + rel.replace("\\", "/"),
                           "to": "AI-Brain-Link" + ("\\" if "\\" in root else "/") + rel})
            changed = True
            print(f"my-folders.json: {rel} added to {a.computer}'s backup.")
        if own is not None and a.choice in ("keep", "bin"):
            folders["computers"][a.computer]["folders"].remove(own)
            changed = True
            print(f"my-folders.json: {rel} taken out of {a.computer}'s backup.")
        if changed:
            dump(FOLDERS, folders)
    if a.choice == "bin":
        win = "\\" in root or re.match(r"^[A-Za-z]:", root)
        if win:
            src, dst = f"{root}\\{rel}", f"{root}\\_trash\\{today}\\{rel}"
            print("For a job on that computer (shell powershell):")
            print(f"$s = '{src}'; $d = '{dst}'; New-Item -ItemType Directory -Force (Split-Path $d) | Out-Null; "
                  f"Move-Item -LiteralPath $s -Destination $d; \"Moved to $d\"")
        else:
            r2 = rel.replace(chr(92), '/')
            src, dst = f"{root}/{r2}", f"{root}/_trash/{today}/{r2}"
            print("For a job on that computer (shell bash):")
            print(f"mkdir -p \"$(dirname '{dst}')\" && mv '{src}' '{dst}' && echo 'Moved to {dst}'")
    return 0


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = p.add_subparsers(dest="cmd")
    s = sub.add_parser("scan", help="on the computer: list the folder by size (changes nothing)")
    s.add_argument("--root", help="the AI-Brain-Link folder (default: D:, C:, then ~)")
    s.add_argument("--computer", help="the computer's name (default: its own)")
    v = sub.add_parser("save", help="in the session: keep this month's sizes from a job log")
    v.add_argument("log")
    c = sub.add_parser("choose", help="in the session: record the owner's choice for a folder")
    c.add_argument("computer")
    c.add_argument("folder", help="the folder inside AI-Brain-Link, as the table shows it (Tools\\venv-3d)")
    c.add_argument("choice", choices=list(CHOICES))
    c.add_argument("--why", help="the reason, in a few words")
    a = p.parse_args()
    if a.cmd is None:
        a = p.parse_args(["scan"] + sys.argv[1:])
    return {"scan": cmd_scan, "save": cmd_save, "choose": cmd_choose}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
