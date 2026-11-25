#!/usr/bin/env python3
"""Index my computer: the documents someone worked on in the last year, found on their own computer and turned
into text, for an agent to write up as notes in their brain. AnIdeaLab's set-up (the brain set up for you) uses it
in two stages (25 Nov 2026): the installer maps the computer, an agent picks what to read from the map and the
buyer's answers, and a job on the buyer's runner reads just that. It isn't part of a brain. README.md says more.

It reuses the brain's file-intake tool (brain/skills/file-intake/intake.py): its survey and its text, with this
choosing what goes in. Searched, unless a plan says otherwise:
  - the usual folders: Desktop, Documents, Downloads and every OneDrive folder, and project folders: the other
    folders in the home folder and, on Windows, the other fixed drives' folders (the system's and apps' left out);
  - documents only (PDF, Word, Excel, PowerPoint, email, plain text, notes), changed in the last 12 months;
  - a code project (a folder with .git) as one row: where it is, never its files.
Out, and only counted, never listed by name: photos, video, audio, archives, apps' and the system's files;
anything whose name looks like passwords or keys (passwords.xlsx, Rosie Keys.txt, recovery codes, .env, .pem,
.kdbx), and folders named that way; wallets' folders; backups (a folder or drive named like one, which holds
copies of what's searched anyway) and copies of a brain; apps' caches; the brain's own folder, the runner's,
browsers' and the system's folders. After reading, a document whose text looks like it holds passwords or keys is
dropped, and so is one that's mostly numbers (a data file saved as text).
Every mode writes map.md, a map of the computer from the same walk, for the brain's note on it: each drive's space,
the folders searched and the ones inside them two deep, with what's in each and when it last changed, whatever its
age; the programs' and games' folders; the code projects; backups and cloud drives not searched.
Nothing on the computer is changed, moved or copied: only the work folder is written.

    python index-computer.py --work <work folder> --map              # stage 1: the map, nothing read
    python index-computer.py --work <work folder> --plan <plan.txt>  # stage 2: read what the plan picks
    python index-computer.py --work <work folder> --more [--minutes N]  # read what a time limit left
    python index-computer.py --work <work folder> [--months 12] [folders...]  # map and read it all, as before

--map writes files.txt (the candidate documents, none read), folders.md (them by folder, for picking) and index.md.
A plan is plain text, a line each, # for notes:
    read: <folder>      search this folder (as many as wanted; none means the usual folders)
    skip: <path>        leave this folder or file out, wherever it is
    file: <file>        read this file, whatever its age
    months: 12          how far back a document's last change can be
    minutes: 45         stop reading after this long, newest first; what's left waits for --more
With a plan, files.txt, survey.md and text/<id>.md are as intake.py makes them, and index.md says what was searched,
what went in and what was left out, by reason.
Python 3.8+; MarkItDown for PDF and Office files (the job runs it with uv, so nothing is installed for good).
"""
import argparse
import collections
import datetime
import importlib.util
import os
import platform
import re
import shutil
import string
import sys
import time

KEEP_PLAIN = {".txt", ".md", ".markdown", ".csv", ".tsv"}   # the machine-made plain kinds (.json, .log, .xml...) stay out
LEAVE_RICH = {".html", ".htm", ".ipynb"}                     # saved web pages and notebooks: mostly copies and code
MAX_CHARS = 200_000                                          # one document's text past this is cut, with a line saying so

# Home folders that are never the owner's documents, or are photos, music and video.
HOME_SKIP = {"appdata", "library", "applications", "public", "saved games",
             "contacts", "favorites", "links", "searches", "3d objects", "ai-brain-link", "actions-runner",
             "anaconda3", "miniconda3", "go", "scoop", "ansel", "intelgraphicsprofiles", "creative cloud files",
             # cloud drives' own folders: a later step of their own (reading them downloads every file)
             "dropbox", "google drive", "my drive", "icloud drive", "iclouddrive", "box", "box sync", "mega", "pcloud drive"}
# Top folders of other drives that are the system's or apps'.
DRIVE_SKIP = {"windows", "program files", "program files (x86)", "programdata", "$recycle.bin", "system volume information",
              "recovery", "perflogs", "msocache", "config.msi", "$windows.~bt", "$windows.~ws", "$winreagent", "windowsapps",
              "steam", "steamlibrary", "epic games", "xboxgames", "riot games", "battle.net", "gog games", "origin games",
              "ea games", "ubisoft", "intel", "amd", "nvidia", "drivers", "ai-brain-link", "actions-runner", "msys64",
              "cygwin64", "python", "nodejs", "temp", "tmp", "onedrivetemp"}
# Folders anywhere that are tools', caches' or installs', on top of intake.py's own list.
DEEP_SKIP = {"site-packages", "lib", "libs", "bin", "obj", "target", "vendor", "bower_components",
             "cache", "caches", "temp", "tmp", "logs", "_runner", "_work", "_intake", "steamapps",
             "env", ".env", "venv", ".venv", "conda", "envs", "pkgs", "installers", "drivers", "fonts",
             "models", "checkpoints", "lora", "loras", "datasets", "dataset", "renders", "frames", "footage", "proxies",
             # tried 25 Nov 2026: DaVinci Resolve's cache, a copy of a brain, a wallet's folder
             "cacheclip", "cache clip", "proxy media", "optimized media", "render cache", "ai-brain-link",
             "monero", "bitcoin", "electrum", "exodus", "wallet", "wallets", "ledger live"}
# A folder or drive named like a backup: copies of what's searched anyway (tried 25 Nov 2026: a backup drive's copy of
# a brain was 61% of a PC's text). Left out whole, and listed in the map.
BACKUP = re.compile(r"back\s*-?ups?\b|\bbackup|time\s*machine", re.I)
NOT_READ = "not read yet: time ran out"

SECRET_NAME = re.compile(
    r"pass\s*words?|passwd|\bpwds?\b|credential|\bcreds\b|secret|recovery[\s._-]*(code|key|phrase)|backup[\s._-]*codes?|"
    r"\b2fa\b|\bmfa\b|seed[\s._-]*phrase|private[\s._-]*key|api[\s._-]*keys?|access[\s._-]*tokens?|wallet|\blogins\b|\bpin\s*(code|number)s?\b|"
    r"\bkeys\b|^akeys$",
    re.I)
SECRET_EXT = {".env", ".pem", ".key", ".ppk", ".pfx", ".p12", ".kdbx", ".kdb", ".1pif", ".agilekeychain", ".keychain",
              ".gpg", ".asc", ".ovpn", ".crt", ".cer", ".jks", ".keystore"}
SECRET_TEXT = [
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),                          # AWS
    re.compile(r"\bsk-(?:ant-|proj-)?[A-Za-z0-9_-]{24,}"),         # OpenAI, Anthropic
    re.compile(r"\b[rs]k_live_[A-Za-z0-9]{16,}"),                 # Stripe
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{30,}"),
    re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}"),                # Slack
    re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b"),                     # Google
]
PASSWORD_LINE = re.compile(r"(?im)^\W*(?:password|passwd|pwd|pin|passcode)\s*[:=\-]\s*\S")
# A folder with a program's own files straight in it is a program's or a game's (Git, a launcher, a game, a portable
# app): left out whole, below the top folders (Downloads keeps its installers' neighbours). Tried on a PC, 24 Nov 2026:
# without it, Git's, CurseForge's, Fortnite's and Tor Browser's readmes and licences were most of the "documents".
PROGRAM_EXT = {".exe", ".dll", ".pak", ".jar", ".so", ".dylib", ".sys", ".asar", ".node", ".pyd", ".ucas", ".utoc",
               ".assets", ".bundle", ".vpk", ".bsa", ".esm", ".esp", ".forge", ".wad"}
# Folders named for games and launchers, which can hold saves and logs without a program in them.
GAME_DIRS = {"games", "my games", "saved games", "curseforge", "epic", "battlestate", "battlestate games", "rockstar",
             "rockstar games", "overwatch", "wpsystem", "zomboid", "minecraft", ".minecraft", "riot games", "steam",
             "steamapps", "ubisoft game launcher", "ea app", "gog galaxy", "battle.net", "game recordings", "xboxgames"}
# Programs' own papers, not the owner's.
PROGRAM_PAPERS = re.compile(r"^(read\s*me|licen[cs]e|eula|change\s*log|changes|copying|notice|third[\s_-]*party|"
                            r"thirdpartynotices|authors|credits|contributing|patents|history|news|install|todo|code_of_conduct)\b", re.I)
BACKUPS = []   # backup folders and drives found, for the map
HIDDEN = 0x2 | 0x4 | 0x400   # Windows' hidden, system and reparse point (a junction, like "Application Data")


class Progress:
    """One line that says how far it's got: a bar that updates in place in a terminal, PROGRESS| lines that
    index-computer.ps1 turns into Windows' own progress bar, or a plain line now and then in a job's log."""
    def __init__(self):
        self.mode = "ps" if os.environ.get("INDEX_PROGRESS") == "ps" else ("tty" if sys.stdout.isatty() else "log")
        self.last = 0.0
        self.shown = False

    def show(self, phase, status, pct=None, force=False):
        now = time.time()
        if not force and now - self.last < (2 if self.mode != "log" else 30):
            return
        self.last = now
        if self.mode == "ps":
            print(f"PROGRESS|{phase}|{-1 if pct is None else int(pct)}|{status}", flush=True)
            if not force and now - getattr(self, "plain", 0) >= 60:   # and a plain line a minute, for a job's log
                self.plain = now
                print(status, flush=True)
        elif self.mode == "tty":
            bar = "" if pct is None else "[" + "#" * int(pct // 5) + "-" * (20 - int(pct // 5)) + f"] {int(pct)}%  "
            sys.stdout.write("\r\033[K" + (bar + status)[:150])
            sys.stdout.flush()
            self.shown = True
        else:
            print(status, flush=True)

    def end(self):
        if self.mode == "tty" and self.shown:
            sys.stdout.write("\n")
            self.shown = False
        elif self.mode == "ps":
            print("PROGRESS|done|100|done", flush=True)


def hidden(entry):
    if entry.name.startswith("."):
        return True
    try:
        return bool(getattr(entry.stat(follow_symlinks=False), "st_file_attributes", 0) & HIDDEN)
    except OSError:
        return True


def load_intake(path):
    spec = importlib.util.spec_from_file_location("intake", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def norm(p):
    return os.path.normcase(os.path.abspath(p))


def windows_drives():
    if os.name != "nt":
        return []
    try:
        import ctypes
        get_type = ctypes.windll.kernel32.GetDriveTypeW
        system = norm(os.environ.get("SystemDrive", "C:") + "\\")
        out = []
        for d in string.ascii_uppercase:
            root = f"{d}:\\"
            if not os.path.isdir(root) or get_type(root) != 3 or norm(root) == system:   # 3: a fixed drive
                continue
            label = ctypes.create_unicode_buffer(261)
            fs = ctypes.create_unicode_buffer(261)
            ctypes.windll.kernel32.GetVolumeInformationW(root, label, 261, None, None, None, fs, 261)
            if re.search(r"google|drive file stream|dropbox|box|icloud", label.value, re.I):
                continue   # a cloud drive that looks like a disk: a later step of its own
            if BACKUP.search(label.value):
                BACKUPS.append(f"{root} ({label.value})")
                continue   # a backup drive: copies
            out.append(root)
        return out
    except Exception:
        return []


def default_folders(home):
    """The usual folders first, then project folders: the home folder's others, and other fixed drives' folders."""
    tops = []
    for name in ("Desktop", "Documents", "Downloads"):
        tops.append(os.path.join(home, name))
    for extra in (os.environ.get("INDEX_DESKTOP"), os.environ.get("INDEX_DOCUMENTS"), os.environ.get("INDEX_DOWNLOADS")):
        if extra:
            tops.append(extra)   # Windows' own idea of where they are: often inside OneDrive
    try:
        names = sorted(os.listdir(home))
    except OSError:
        names = []
    for name in names:
        if name.lower().startswith("onedrive"):
            tops.append(os.path.join(home, name))
    cloud = os.path.join(home, "Library", "CloudStorage")   # a Mac's OneDrive
    if os.path.isdir(cloud):
        tops += [os.path.join(cloud, n) for n in sorted(os.listdir(cloud)) if n.lower().startswith("onedrive")]
    for name in names:
        p = os.path.join(home, name)
        if name.startswith(".") or name.lower() in HOME_SKIP or name.lower().startswith("onedrive") or not os.path.isdir(p):
            continue
        tops.append(p)
    for drive in windows_drives():
        try:
            for name in sorted(os.listdir(drive)):
                p = os.path.join(drive, name)
                if not name.startswith((".", "$")) and name.lower() not in DRIVE_SKIP and os.path.isdir(p):
                    tops.append(p)
        except OSError:
            pass
    return tops


def tidy(tops, never, chosen=False):
    """Real folders only, each once, none inside another (Documents inside OneDrive is searched with OneDrive).
    Folders a plan chose are taken as they are, whatever their names."""
    seen, out = set(), []
    for t in tops:
        if not t or not os.path.isdir(t) or os.path.islink(t):
            continue
        name = os.path.basename(os.path.normpath(t)).lower()
        try:
            if not chosen and getattr(os.stat(t, follow_symlinks=False), "st_file_attributes", 0) & HIDDEN:
                continue   # "Application Data", "Local Settings": junctions into AppData
        except OSError:
            continue
        if not chosen and (name in GAME_DIRS or name in DEEP_SKIP or name in {"node_modules", "appdata"}):
            continue
        if not chosen and BACKUP.search(name):
            BACKUPS.append(t)
            continue
        real = norm(os.path.realpath(t))
        if real in seen or any(real == n or real.startswith(n + os.sep) for n in never):
            continue
        seen.add(real)
        out.append(os.path.realpath(t))
    out = [t for t in out if not any(norm(t).startswith(norm(o) + os.sep) for o in out if o != t)]
    return out


KIND_WORDS = {"document": "documents", "image": "photos and pictures", "video": "videos", "audio": "audio",
              "code": "code files", "archive": "archives", "other": "other files"}


def write_map(work, tops, fmap, programs, repos, clouds, today):
    """map.md: where things are on the computer, from the walk."""
    def size(b):
        for unit, step in (("TB", 1 << 40), ("GB", 1 << 30), ("MB", 1 << 20), ("KB", 1 << 10)):
            if b >= step:
                return f"{b / step:.1f} {unit}"
        return f"{b} bytes"

    def line(st):
        kinds = ", ".join(f"{n:,} {KIND_WORDS.get(k, k)}" for k, n in st["kinds"].most_common() if n)
        newest = datetime.date.fromtimestamp(st["newest"]).isoformat() if st["newest"] else "never"
        return f"{sum(st['kinds'].values()):,} files, {size(st['bytes'])}: {kinds or 'empty'}; last changed {newest}"

    out = [f"# Map of {os.environ.get('COMPUTERNAME') or platform.node()}, {today}", "",
           "Where things are on this computer, from the index's walk: every file counted, whatever its age (the index",
           "itself only read the documents of the past year). Hidden folders, apps' and the system's folders aren't in it.", "", "## Drives"]
    drives = windows_drives() + ([os.environ.get("SystemDrive", "C:") + "\\"] if os.name == "nt" else ["/"])
    for d in sorted(set(drives)):
        try:
            u = shutil.disk_usage(d)
            out.append(f"- `{d}`: {size(u.free)} free of {size(u.total)}")
        except OSError:
            pass
    out += ["", "## Folders", "Each folder searched, then the biggest folders inside it, two deep."]
    for top in tops:
        mine = {k: v for k, v in fmap.items() if k[0] == top}
        if not mine:
            continue
        total = {"kinds": collections.Counter(), "bytes": 0, "newest": 0}
        for st in mine.values():
            total["kinds"].update(st["kinds"]); total["bytes"] += st["bytes"]; total["newest"] = max(total["newest"], st["newest"])
        out += ["", f"### `{top}`", line(total)]
        subs = sorted(((k[1], v) for k, v in mine.items() if k[1]), key=lambda kv: -kv[1]["bytes"])
        for sub, st in subs[:25]:
            out.append(f"- `{sub}`: {line(st)}")
        if len(subs) > 25:
            out.append(f"- ...and {len(subs) - 25} more folders")
    if repos:
        out += ["", "## Code projects (folders with .git)"] + [f"- `{r}`" for r in sorted(repos)]
    if programs:
        out += ["", "## Programs and games (left out of the index)"] + [f"- `{p}`" for p in sorted(programs)[:80]]
        if len(programs) > 80:
            out.append(f"- ...and {len(programs) - 80} more")
    if clouds:
        out += ["", "## Cloud drives found, not searched"] + [f"- `{c}`" for c in sorted(clouds)]
    if BACKUPS:
        out += ["", "## Backups found, not searched (copies of what's searched anyway)"] + [f"- `{b}`" for b in sorted(set(BACKUPS))]
    with open(os.path.join(work, "map.md"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")


def read_plan(path):
    """A plan's lines: read:, skip:, file:, months:, minutes:. Anything else is a note."""
    plan = {"read": [], "skip": [], "file": [], "months": None, "minutes": None}
    with open(path, encoding="utf-8-sig") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            key, _, val = line.partition(":")
            key, val = key.strip().lower(), val.strip().strip('"').strip("'")
            if key in ("read", "skip", "file") and val:
                plan[key].append(os.path.expanduser(val))
            elif key in ("months", "minutes") and val:
                try:
                    plan[key] = float(val)
                except ValueError:
                    pass
    return plan


def read_one(md, r, intake):
    """One document's text, the way intake.py's convert reads it; None when there's nothing to keep."""
    ext = os.path.splitext(r["path"])[1].lower()
    try:
        if int(r["bytes"] or 0) > intake.MAX_CONVERT:
            r["text"] = "too big: listed, not read"
            return None
        if ext in intake.PLAIN:
            with open(r["path"], "rb") as fh:
                raw = fh.read()
            r["text"] = "plain"
            return raw.decode("utf-8-sig", errors="replace") if b"\x00" not in raw[:2000] else raw.decode("utf-16", errors="replace")
        if ext in intake.OLD:
            r["text"] = "old format: open it on the computer and save it as a newer one, or read it there"
            return None
        if md is None:
            r["text"] = "needs markitdown"
            return None
        body = md.convert(r["path"]).text_content or ""
        r["text"] = "ok"
        if len(body.strip()) < 80 and ext == ".pdf":
            r["text"] = "no text: likely a scan"
        return body
    except Exception as e:   # one bad file mustn't stop the pile
        r["text"] = "failed: " + re.sub(r"\s+", " ", str(e))[:120]
        return None


def read_docs(work, intake, bar, left, deadline, only_unread, first=()):
    """Read the documents in files.txt, newest first (the plan's own files before them), until the deadline.
    What's left is marked NOT_READ for --more. Drops a text that holds passwords or keys, or is mostly numbers."""
    rows = intake.read_rows(work)
    text_dir = os.path.join(work, "text")
    os.makedirs(text_dir, exist_ok=True)
    try:
        from markitdown import MarkItDown
        md = MarkItDown()
    except Exception:
        md = None
    first = {norm(f) for f in first}
    todo = [r for r in rows if r["kind"] == "document" and not r["dup_of"] and r["outcome"] != "skipped"
            and (r["text"] == NOT_READ if only_unread else r["text"] in ("", NOT_READ))]
    todo.sort(key=lambda r: (norm(r["path"]) in first, r["modified"]), reverse=True)
    started = time.time()
    done = 0
    for i, r in enumerate(todo):
        if deadline and time.time() > deadline:
            for rest in todo[i:]:
                rest["text"] = NOT_READ
            break
        body = read_one(md, r, intake)
        done += 1
        if body is not None:
            sample = body[:20000]
            letters = sum(c.isalpha() for c in sample)
            if any(rx.search(body) for rx in SECRET_TEXT) or len(PASSWORD_LINE.findall(body)) >= 2:
                r.update(text="", chars="", outcome="skipped", where="its text looks like it holds passwords or keys, so it wasn't kept")
                left["held passwords or keys inside"] += 1
            elif len(body) > 2000 and letters < 0.3 * len(sample):
                r.update(text="", chars="", outcome="skipped", where="its text is mostly numbers: a data file, not a document")
                left["mostly numbers (data saved as text)"] += 1
            else:
                if len(body) > MAX_CHARS:
                    body = body[:MAX_CHARS] + f"\n\n<!-- cut at {MAX_CHARS:,} characters of {len(body):,}: the rest is in the file -->\n"
                r["chars"] = min(len(body), MAX_CHARS)
                with open(os.path.join(text_dir, f"{r['id']}.md"), "w", encoding="utf-8", newline="\n") as fh:
                    fh.write(f"<!-- file {r['id']}: {r['path']} -->\n{body}")
        per = (time.time() - started) / done
        mins = per * (len(todo) - done) / 60
        if deadline:
            mins = min(mins, max(0, (deadline - time.time()) / 60))
        left_text = "under a minute left" if mins < 1 else f"about {mins:.0f} minute{'s' if mins >= 1.5 else ''} left"
        bar.show("Reading your documents", f"Reading your documents: {done:,} of {len(todo):,}, {left_text}", 100 * done / max(1, len(todo)))
        if done % 50 == 0:
            intake.write_rows(work, rows)
    bar.show("Reading your documents", f"Read {done:,} documents.", 100, force=True)
    bar.end()
    intake.write_rows(work, rows)
    intake.write_survey(work, rows)
    return rows


def write_folders(work, rows, since):
    """folders.md: the candidate documents by folder, for the agent picking what to read."""
    docs = [r for r in rows if r["kind"] == "document" and not r["dup_of"] and r["outcome"] != "skipped"]
    by = collections.defaultdict(list)
    for r in docs:
        by[os.path.dirname(r["path"])].append(r)
    out = ["# Documents by folder, for picking what to read", "",
           f"{len(docs):,} documents changed since {datetime.date.fromtimestamp(since).isoformat()}, none read yet, in "
           f"{len(by):,} folders (exact copies not counted). Each line: the folder, its documents, their size, the newest "
           "change, the kinds and a few names, newest first. Every one is in `files.txt`.", ""]

    def size(b):
        return f"{b / (1 << 20):.1f} MB" if b >= 1 << 20 else f"{b / 1024:.0f} KB"
    for folder in sorted(by, key=str.lower):
        rs = sorted(by[folder], key=lambda r: r["modified"], reverse=True)
        kinds = collections.Counter(os.path.splitext(r["path"])[1].lower().lstrip(".") or "none" for r in rs)
        names = "; ".join(os.path.basename(r["path"])[:60] for r in rs[:4]) + ("; ..." if len(rs) > 4 else "")
        out.append(f"- `{folder}`: {len(rs)} document{'s' if len(rs) != 1 else ''}, {size(sum(int(r['bytes'] or 0) for r in rs))}, "
                   f"newest {rs[0]['modified']} ({', '.join(f'{k} {n}' for k, n in kinds.most_common())}): {names}")
    with open(os.path.join(work, "folders.md"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")


def main():
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    ap = argparse.ArgumentParser(description="Index my computer: map it, then read what a plan picks, as text for the brain's agent.")
    ap.add_argument("folders", nargs="*")
    ap.add_argument("--work", required=True)
    ap.add_argument("--intake", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "intake.py"))
    ap.add_argument("--months", type=float, default=12)
    ap.add_argument("--map", action="store_true", help="stage 1: map the computer and list the candidates; read nothing")
    ap.add_argument("--plan", help="stage 2: read what this plan picks")
    ap.add_argument("--more", action="store_true", help="read what a time limit left, in the same work folder")
    ap.add_argument("--minutes", type=float, help="stop reading after this long (a plan's minutes: line otherwise)")
    args = ap.parse_args()
    started = time.time()
    # PDF readers' notes ("should not allow text extraction", font warnings) would fill the window: errors only.
    import logging
    import warnings
    logging.disable(logging.WARNING)
    warnings.filterwarnings("ignore")
    intake = load_intake(args.intake)
    intake.print = lambda *a, **k: None   # intake's own reports would flood the window: the bar instead
    home = os.path.expanduser("~")
    work = os.path.abspath(args.work)
    computer = os.environ.get("COMPUTERNAME") or platform.node()
    system = {"Darwin": "Mac", "Windows": "Windows PC"}.get(platform.system(), platform.system())
    bar = Progress()
    leftfile = os.path.join(work, "left.json")
    import json

    if args.more:   # the rest of a read a time limit stopped
        with open(leftfile, encoding="utf-8") as fh:
            saved = json.load(fh)
        left = collections.Counter(saved["left"])
        deadline = started + args.minutes * 60 if args.minutes else 0
        rows = read_docs(work, intake, bar, left, deadline, only_unread=True)
        finish(work, rows, left, saved, started, intake)
        return

    plan = read_plan(args.plan) if args.plan else {"read": [], "skip": [], "file": [], "months": None, "minutes": None}
    months = plan["months"] or args.months
    minutes = args.minutes or plan["minutes"] or 0
    since = time.time() - months * 30.44 * 86400
    never = {norm(work)}
    for root in (os.path.join(home, "AI-Brain-Link"), "C:\\AI-Brain-Link", "D:\\AI-Brain-Link", os.environ.get("RUNNER_WORKSPACE", ""),
                 os.environ.get("INDEX_BRAIN_ROOT", "")):
        if root and os.path.isdir(root):
            never.add(norm(os.path.realpath(root)))
    skips = {norm(os.path.realpath(s)) for s in plan["skip"]}
    never |= skips
    explicit = {norm(os.path.realpath(f)) for f in plan["file"] if os.path.isfile(f)}
    if plan["read"] or plan["file"]:
        tops = tidy(plan["read"], never, chosen=True) + [os.path.realpath(f) for f in plan["file"] if os.path.isfile(f)]
    else:
        tops = tidy(args.folders or default_folders(home), never)
    left = collections.Counter()
    walked = [0]
    found = [0]
    where = [0, ""]   # which top folder it's in, for the bar
    phase = "Mapping your computer" if args.map else "Finding your documents"

    def keep(kind, path):
        """A walked row: in, or only counted."""
        walked[0] += 1
        pct = 100 * where[0] / max(1, len(tops))
        bar.show(phase, f"{phase}: {walked[0]:,} files looked at, {found[0]:,} documents so far ({where[1]})", pct)
        name = os.path.basename(path)
        ext = os.path.splitext(name)[1].lower()
        if kind == "repo":
            stamp = max((os.path.getmtime(os.path.join(path, ".git", f)) for f in ("index", "HEAD", "FETCH_HEAD")
                         if os.path.exists(os.path.join(path, ".git", f))), default=0)
            if stamp < since:
                left["code projects not touched in the time"] += 1
                return False
            return True
        if kind in ("image", "audio", "video"):
            left["photos, video and audio"] += 1
            return False
        if kind != "document":
            left["archives, code and apps' files" if kind in ("archive", "code") else "apps' and the system's files"] += 1
            return False
        if ext in SECRET_EXT or SECRET_NAME.search(os.path.splitext(name)[0]):
            left["named like passwords or keys"] += 1
            return False
        mine = norm(path) in explicit
        if not mine and (ext in intake.PLAIN and ext not in KEEP_PLAIN or ext in LEAVE_RICH):
            left["machine-made text (.json, .log, .xml, web pages)"] += 1
            return False
        if not mine and PROGRAM_PAPERS.match(os.path.splitext(name)[0]):
            left["programs' readmes, licences and change logs"] += 1
            return False
        try:
            st = os.stat(path)
        except OSError:
            return False
        if st.st_mtime < since and not mine:
            left["not changed in the time"] += 1
            return False
        if st.st_size == 0:
            left["empty"] += 1
            return False
        found[0] += 1
        return True

    skip_dirs = set(intake.SKIP_DIRS) | DEEP_SKIP | GAME_DIRS
    fmap = collections.defaultdict(lambda: {"kinds": collections.Counter(), "bytes": 0, "newest": 0})
    programs, repos = [], []
    clouds = [os.path.join(home, n) for n in (os.listdir(home) if os.path.isdir(home) else [])
              if n.lower() in {"dropbox", "google drive", "my drive", "icloud drive", "iclouddrive", "box", "box sync", "mega", "pcloud drive"}]

    def mapped(top, folder, kind, st):
        rel = os.path.relpath(folder, top)
        parts = [] if rel == "." else rel.split(os.sep)
        st_ = fmap[(top, os.sep.join(parts[:2]))]
        st_["kinds"][kind] += 1
        st_["bytes"] += st.st_size
        st_["newest"] = max(st_["newest"], st.st_mtime)

    def walk(top):
        """intake.walk's way (a folder with .git is one row), plus a whole computer's rules: hidden folders and
        junctions, programs' and games' folders, backups, folders named like passwords or keys, the plan's skips,
        and tools' and caches' folders are left out."""
        if top in tops:
            where[0], where[1] = tops.index(top), top
        if os.path.isfile(top):
            if keep(intake.kind_of(top), top):
                yield intake.kind_of(top), top
            return
        todo = [(top, 0)]
        while todo:
            folder, depth = todo.pop()
            try:
                entries = sorted(os.scandir(folder), key=lambda e: e.name.lower())
            except OSError:
                continue
            if any(e.name == ".git" for e in entries):
                repos.append(folder)
                if keep("repo", folder):
                    yield "repo", folder
                continue
            if depth > 0 and any(os.path.splitext(e.name)[1].lower() in PROGRAM_EXT for e in entries):
                left["programs' and games' folders (left out whole)"] += 1
                programs.append(folder)
                continue
            for e in entries:
                try:
                    if e.is_symlink() or hidden(e):
                        continue
                    if e.is_dir():
                        low = e.name.lower()
                        if norm(e.path) in never:
                            if norm(e.path) in skips:
                                left["folders the plan left out"] += 1
                        elif BACKUP.search(e.name):
                            BACKUPS.append(e.path)
                            left["backups' folders (left out whole)"] += 1
                        elif SECRET_NAME.search(e.name):
                            left["folders named like passwords or keys (left out whole)"] += 1
                        elif low not in skip_dirs:
                            todo.append((e.path, depth + 1))
                        elif low in GAME_DIRS:
                            programs.append(e.path)
                    elif e.is_file() and e.name.lower() not in intake.SKIP_FILES and not e.name.startswith("~$"):
                        kind = intake.kind_of(e.name)
                        mapped(top, folder, kind, e.stat())
                        if skips and norm(e.path) in skips:
                            left["files the plan left out"] += 1
                            continue
                        if keep(kind, e.path):
                            yield kind, e.path
                except OSError:
                    continue

    intake.walk = walk
    print("Searching: " + "; ".join(tops), flush=True)
    intake.survey(argparse.Namespace(paths=tops, upload_list=None, work=work))
    bar.show(phase, f"Found {found[0]:,} documents in {walked[0]:,} files.", 100, force=True)
    bar.end()
    write_map(work, tops, fmap, programs, repos, clouds, intake.today())
    saved = {"left": {}, "tops": tops, "since": since, "months": months, "computer": computer, "system": system,
             "walked": walked[0], "mode": "map" if args.map else ("plan" if args.plan else "all"), "plan": plan,
             "backups": sorted(set(BACKUPS))}
    if args.map:
        rows = intake.read_rows(work)
        write_folders(work, rows, since)
        saved["left"] = dict(left)
        with open(leftfile, "w", encoding="utf-8") as fh:
            json.dump(saved, fh)
        finish(work, rows, left, saved, started, intake)
        return
    deadline = started + minutes * 60 if minutes else 0
    rows = read_docs(work, intake, bar, left, deadline, only_unread=False, first=plan["file"])
    saved["left"] = dict(left)
    with open(leftfile, "w", encoding="utf-8") as fh:
        json.dump(saved, fh)
    finish(work, rows, left, saved, started, intake)


def finish(work, rows, left, saved, started, intake):
    """index.md: what was searched, what went in and what was left out, by reason."""
    live = [r for r in rows if not r["dup_of"] and r["outcome"] != "skipped"]
    docs = [r for r in live if r["kind"] == "document"]
    read = [r for r in docs if r["text"] in ("ok", "plain")]
    waiting = [r for r in docs if r["text"] == NOT_READ]
    mapping = saved["mode"] == "map"
    minutes = (time.time() - started) / 60
    out = [f"# Index my computer, {intake.today()}{': the map' if mapping else ''}", "",
           f"Computer: {saved['computer']}, a {saved['system']}.",
           f"Documents changed since {datetime.date.fromtimestamp(saved['since']).isoformat()} ({saved['months']:g} months).",
           f"Took {minutes:.0f} minute{'s' if round(minutes) != 1 else ''}; {saved['walked']:,} files looked at.", "", "## Searched"]
    out += [f"- `{t}`" for t in saved["tops"]]
    plan = saved.get("plan") or {}
    if plan.get("skip"):
        out += ["", "## Left out by the plan"] + [f"- `{s}`" for s in plan["skip"]]
    out += ["", "## In"]
    if mapping:
        out.append(f"- {len(docs)} documents found, none read yet (`folders.md` has them by folder, `files.txt` each one)")
    else:
        out.append(f"- {len(docs)} documents, {len(read)} of them read into text (about {sum(int(r['chars'] or 0) for r in read) // 4:,} tokens)")
        if waiting:
            out.append(f"- **{len(waiting)} not read yet: the time limit came first.** Read them with `--more` in this work folder.")
    out += [f"- {sum(1 for r in live if r['kind'] == 'repo')} code projects, as where they are",
            f"- {len(rows) - len([r for r in rows if not r['dup_of']])} exact copies found and left out"]
    states = collections.Counter(r["text"].split(":")[0] for r in docs if r["text"] not in ("ok", "plain", NOT_READ, ""))
    if states and not mapping:
        out.append("- Not read: " + ", ".join(f"{n} {s}" for s, n in states.most_common()))
    out += ["", "## Left out (counted, not listed)"] + [f"- {n:,} {why}" for why, n in left.most_common()]
    backups = saved.get("backups") or []
    if backups:
        out.append(f"- {len(backups)} backup folders or drives, left out whole (listed in `map.md`)")
    if mapping:
        out += ["", "Next: an agent picks what to read from `folders.md` and `map.md` with what the owner wants, and writes a plan;",
                "then this script reads it with `--plan` (a job on the owner's runner)."]
    else:
        out += ["", "Every document in is in `files.txt`, with its text in `text/`; `survey.md` has them by folder and kind.",
                "Next: the file-intake skill, from its step 2, with this work folder."]
    out += ["", "`map.md` is a map of the computer from the same walk, for the brain's note on it."]
    with open(os.path.join(work, "index.md"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")
    print("\n".join(out))


if __name__ == "__main__":
    main()
