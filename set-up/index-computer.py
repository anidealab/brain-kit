#!/usr/bin/env python3
"""Index my computer: the documents someone worked on in the last year, found on their own computer and turned
into text, for an agent to write up as notes in their brain. AnIdeaLab's set-up (the brain set up for you) runs
it as a job on the buyer's runner; it isn't part of a brain. README.md in this folder says how it's started.

It reuses the brain's file-intake tool (brain/skills/file-intake/intake.py): its survey and its text, with this
choosing what goes in. In:
  - the usual folders: Desktop, Documents, Downloads and every OneDrive folder, and project folders: the other
    folders in the home folder and, on Windows, the other fixed drives' folders (the system's and apps' left out);
  - documents only (PDF, Word, Excel, PowerPoint, email, plain text, notes), changed in the last 12 months;
  - a code project (a folder with .git) as one row: where it is, never its files.
Out, and only counted, never listed by name: photos, video, audio, archives, apps' and the system's files;
anything whose name looks like passwords or keys (passwords.xlsx, recovery codes, .env, .pem, .kdbx); a
document whose text looks like it holds them (a private key, an API key, a list of passwords) is dropped
after it's read; the brain's own folder, the runner's, browsers' and the system's folders.
Nothing on the computer is changed, moved or copied: only the work folder is written.

    python index-computer.py --work <work folder> [--intake <intake.py>] [--months 12] [folders...]

With folders given, only those are searched. Writes the work folder as intake.py does (files.txt, survey.md,
text/<id>.md) and index.md: what was searched, what went in and what was left out, by reason.
Python 3.8+; MarkItDown for PDF and Office files (the job runs it with uv, so nothing is installed for good).
"""
import argparse
import collections
import datetime
import importlib.util
import os
import platform
import re
import string
import sys
import time

KEEP_PLAIN = {".txt", ".md", ".markdown", ".csv", ".tsv"}   # the machine-made plain kinds (.json, .log, .xml...) stay out
LEAVE_RICH = {".html", ".htm", ".ipynb"}                     # saved web pages and notebooks: mostly copies and code
MAX_CHARS = 200_000                                          # one document's text past this is cut, with a line saying so

# Home folders that are never the owner's documents, or are photos, music and video.
HOME_SKIP = {"appdata", "library", "pictures", "music", "videos", "movies", "applications", "public", "saved games",
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
             "models", "checkpoints", "lora", "loras", "datasets", "dataset", "renders", "frames", "footage", "proxies"}

SECRET_NAME = re.compile(
    r"pass\s*words?|passwd|\bpwds?\b|credential|\bcreds\b|secret|recovery[\s._-]*(code|key|phrase)|backup[\s._-]*codes?|"
    r"\b2fa\b|\bmfa\b|seed[\s._-]*phrase|private[\s._-]*key|api[\s._-]*keys?|access[\s._-]*tokens?|wallet|\blogins\b|\bpin\s*(code|number)s?\b",
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


def tidy(tops, never):
    """Real folders only, each once, none inside another (Documents inside OneDrive is searched with OneDrive)."""
    seen, out = set(), []
    for t in tops:
        if not t or not os.path.isdir(t) or os.path.islink(t):
            continue
        name = os.path.basename(os.path.normpath(t)).lower()
        try:
            if getattr(os.stat(t, follow_symlinks=False), "st_file_attributes", 0) & HIDDEN:
                continue   # "Application Data", "Local Settings": junctions into AppData
        except OSError:
            continue
        if name in GAME_DIRS or name in DEEP_SKIP or name in {"node_modules", "appdata"}:
            continue
        real = norm(os.path.realpath(t))
        if real in seen or any(real == n or real.startswith(n + os.sep) for n in never):
            continue
        seen.add(real)
        out.append(os.path.realpath(t))
    out = [t for t in out if not any(norm(t).startswith(norm(o) + os.sep) for o in out if o != t)]
    return out


def main():
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    ap = argparse.ArgumentParser(description="Index my computer: a year of documents, as text for the brain's agent.")
    ap.add_argument("folders", nargs="*")
    ap.add_argument("--work", required=True)
    ap.add_argument("--intake", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "intake.py"))
    ap.add_argument("--months", type=int, default=12)
    args = ap.parse_args()
    started = time.time()
    # PDF readers' notes ("should not allow text extraction", font warnings) would fill the window: errors only.
    import logging
    import warnings
    logging.disable(logging.WARNING)
    warnings.filterwarnings("ignore")
    intake = load_intake(args.intake)
    home = os.path.expanduser("~")
    since = time.time() - args.months * 30.44 * 86400
    work = os.path.abspath(args.work)
    never = {norm(work)}
    for root in (os.path.join(home, "AI-Brain-Link"), "C:\\AI-Brain-Link", "D:\\AI-Brain-Link", os.environ.get("RUNNER_WORKSPACE", ""),
                 os.environ.get("INDEX_BRAIN_ROOT", "")):
        if root and os.path.isdir(root):
            never.add(norm(os.path.realpath(root)))
    tops = tidy(args.folders or default_folders(home), never)
    left = collections.Counter()
    walked = [0]
    found = [0]
    bar = Progress()
    where = [0, ""]   # which top folder it's in, for the bar

    def keep(kind, path):
        """A walked row: in, or only counted."""
        walked[0] += 1
        pct = 100 * where[0] / max(1, len(tops))
        bar.show("Finding your documents", f"Finding your documents: {walked[0]:,} files looked at, {found[0]:,} found so far ({where[1]})", pct)
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
        if ext in intake.PLAIN and ext not in KEEP_PLAIN or ext in LEAVE_RICH:
            left["machine-made text (.json, .log, .xml, web pages)"] += 1
            return False
        if PROGRAM_PAPERS.match(os.path.splitext(name)[0]):
            left["programs' readmes, licences and change logs"] += 1
            return False
        try:
            st = os.stat(path)
        except OSError:
            return False
        if st.st_mtime < since:
            left["not changed in the time"] += 1
            return False
        if st.st_size == 0:
            left["empty"] += 1
            return False
        found[0] += 1
        return True

    skip_dirs = set(intake.SKIP_DIRS) | DEEP_SKIP | GAME_DIRS

    def walk(top):
        """intake.walk's way (a folder with .git is one row), plus a whole computer's rules: hidden folders and
        junctions, programs' and games' folders, and tools' and caches' folders are left out."""
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
                if keep("repo", folder):
                    yield "repo", folder
                continue
            if depth > 0 and any(os.path.splitext(e.name)[1].lower() in PROGRAM_EXT for e in entries):
                left["programs' and games' folders (left out whole)"] += 1
                continue
            for e in entries:
                try:
                    if e.is_symlink() or hidden(e):
                        continue
                    if e.is_dir():
                        if e.name.lower() not in skip_dirs:
                            todo.append((e.path, depth + 1))
                    elif e.is_file() and e.name.lower() not in intake.SKIP_FILES and not e.name.startswith("~$"):
                        kind = intake.kind_of(e.name)
                        if keep(kind, e.path):
                            yield kind, e.path
                except OSError:
                    continue

    # intake's survey and convert, quietly (their own reports would flood the window), with the bar instead.
    intake.walk = walk
    intake.print = lambda *a, **k: None
    print("Searching: " + "; ".join(tops), flush=True)
    intake.survey(argparse.Namespace(paths=tops, upload_list=None, work=work))
    bar.show("Finding your documents", f"Found {found[0]:,} documents in {walked[0]:,} files.", 100, force=True)
    bar.end()
    rows = intake.read_rows(work)
    total = sum(1 for r in rows if r["kind"] == "document" and not r["dup_of"])
    read_so_far = [0]
    reading_started = time.time()
    text_dir = os.path.join(work, "text")
    real_open = open

    def counting_open(path, mode="r", *a, **k):
        # convert writes each document's text once: that's one more read
        if "w" in mode and os.path.dirname(os.path.abspath(str(path))) == os.path.abspath(text_dir):
            read_so_far[0] += 1
            n = read_so_far[0]
            per = (time.time() - reading_started) / n
            mins = per * (total - n) / 60
            left_text = "under a minute left" if mins < 1 else f"about {mins:.0f} minute{'s' if mins >= 1.5 else ''} left"
            bar.show("Reading your documents", f"Reading your documents: {n:,} of {total:,}, {left_text}", 100 * n / max(1, total))
        return real_open(path, mode, *a, **k)

    intake.open = counting_open
    intake.convert(argparse.Namespace(work=work))
    bar.show("Reading your documents", f"Read {read_so_far[0]:,} documents.", 100, force=True)
    bar.end()
    del intake.open

    # After reading: drop a document whose text holds passwords or keys, and cut a very long one.
    rows = intake.read_rows(work)
    text_dir = os.path.join(work, "text")
    for r in rows:
        p = os.path.join(text_dir, f"{r['id']}.md")
        if not os.path.isfile(p):
            continue
        with open(p, encoding="utf-8", errors="replace") as fh:
            body = fh.read()
        if any(rx.search(body) for rx in SECRET_TEXT) or len(PASSWORD_LINE.findall(body)) >= 2:
            os.remove(p)
            r.update(text="", chars="", outcome="skipped", where="its text looks like it holds passwords or keys, so it wasn't kept")
            left["held passwords or keys inside"] += 1
            continue
        if len(body) > MAX_CHARS:
            with open(p, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(body[:MAX_CHARS] + f"\n\n<!-- cut at {MAX_CHARS:,} characters of {len(body):,}: the rest is in the file -->\n")
            r["chars"] = MAX_CHARS
    intake.write_rows(work, rows)
    intake.write_survey(work, rows)

    live = [r for r in rows if not r["dup_of"] and r["outcome"] != "skipped"]
    docs = [r for r in live if r["kind"] == "document"]
    read = [r for r in docs if r["text"] in ("ok", "plain")]
    minutes = (time.time() - started) / 60
    out = [f"# Index my computer, {intake.today()}", "",
           f"Documents changed since {datetime.date.fromtimestamp(since).isoformat()} ({args.months} months), on {os.environ.get('COMPUTERNAME') or platform.node()}.",
           f"Took {minutes:.0f} minutes; {walked[0]:,} files looked at.", "", "## Searched"] + [f"- `{t}`" for t in tops]
    out += ["", "## In",
            f"- {len(docs)} documents, {len(read)} of them read into text (about {sum(int(r['chars'] or 0) for r in read) // 4:,} tokens)",
            f"- {sum(1 for r in live if r['kind'] == 'repo')} code projects, as where they are",
            f"- {len(rows) - len([r for r in rows if not r['dup_of']])} exact copies found and left out"]
    states = collections.Counter(r["text"].split(":")[0] for r in docs if r["text"] not in ("ok", "plain"))
    if states:
        out.append("- Not read: " + ", ".join(f"{n} {s or 'not tried'}" for s, n in states.most_common()))
    out += ["", "## Left out (counted, not listed)"] + [f"- {n:,} {why}" for why, n in left.most_common()]
    out += ["", "Every document in is in `files.txt`, with its text in `text/`; `survey.md` has them by folder and kind.",
            "Next: the file-intake skill, from its step 2, with this work folder."]
    with open(os.path.join(work, "index.md"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")
    print("\n".join(out))


if __name__ == "__main__":
    main()
