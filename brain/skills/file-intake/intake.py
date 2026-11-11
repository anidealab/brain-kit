#!/usr/bin/env python3
"""Bringing a big pile of files into the brain: the look-first step and the file list.

How it's used: SKILL.md in this folder. In short, everything about one pile lives in a work folder
outside the repo (on the PC: C:\\AI-Brain-Link\\_intake\\<name>), and the file list in it, files.txt,
has one row for every file found, so nothing is quietly missed.

    intake.py survey PATH... --work DIR      walk the paths (or --upload-list FILE, the upload point's list):
                                             writes files.txt and survey.md. Changes nothing in the pile.
    intake.py convert --work DIR             turn each document into text, text/<id>.md, with MarkItDown
                                             where it's installed (pip install "markitdown[all]"); plain
                                             text needs nothing. Safe to run again: it skips what's done.
    intake.py split --work DIR               read split.txt (subject: pattern, one a line), put each file
                                             in its subject, write subject-<name>.txt for each agent's
                                             brief, and say how big each subject is.
    intake.py check --work DIR --brain ROOT  read every outcomes-*.txt, and report any file with no
                                             outcome, any note that isn't there, and any note that doesn't
                                             name its file. --record NOTE.md also writes the pile's record.

files.txt is tab-separated: id, kind, bytes, modified, text, chars, dup_of, subject, outcome, where, path.
split.txt lines: "subject: pattern", where pattern is the start of a path, a wildcard (*.pdf, *\\Tax\\*) or
"id 12,15,20-30"; the first line that fits a file wins; # starts a comment.
outcomes-<subject>.txt lines, tab-separated: id, outcome (note, listed or skipped), then the note's path in
the brain for note and listed, or the reason for skipped.

Python 3.8+ and nothing else; MarkItDown (Microsoft, MIT) only for convert, and only for non-plain kinds.
"""
import argparse
import collections
import datetime
import fnmatch
import hashlib
import os
import re
import shutil
import sys

COLS = ["id", "kind", "bytes", "modified", "text", "chars", "dup_of", "subject", "outcome", "where", "path"]
PLAIN = {".txt", ".md", ".markdown", ".csv", ".tsv", ".log", ".json", ".xml", ".yml", ".yaml", ".ini", ".srt", ".vtt"}
RICH = {".pdf", ".docx", ".pptx", ".xlsx", ".xls", ".html", ".htm", ".epub", ".msg", ".eml", ".ipynb"}
OLD = {".doc", ".ppt", ".rtf", ".odt", ".ods", ".odp", ".pages", ".numbers", ".key", ".one", ".pub", ".wpd"}
KINDS = {
    "image": {".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic", ".heif", ".tif", ".tiff", ".bmp", ".raw", ".cr2", ".nef", ".arw", ".dng", ".svg", ".psd", ".ai"},
    "audio": {".mp3", ".wav", ".m4a", ".flac", ".ogg", ".aac", ".wma", ".opus", ".aiff"},
    "video": {".mp4", ".mov", ".mkv", ".avi", ".webm", ".wmv", ".m4v", ".mts", ".3gp", ".mpg", ".mpeg"},
    "archive": {".zip", ".7z", ".rar", ".tar", ".gz", ".tgz", ".bz2", ".xz", ".iso"},
    "code": {".py", ".js", ".ts", ".tsx", ".jsx", ".mjs", ".cjs", ".css", ".scss", ".php", ".rb", ".go", ".rs", ".java", ".kt", ".swift", ".c", ".h", ".cpp", ".cs", ".sh", ".ps1", ".bat", ".cmd", ".sql", ".lua", ".r", ".vue", ".svelte", ".toml"},
}
SKIP_DIRS = {"node_modules", "__pycache__", ".venv", "venv", ".git", "$recycle.bin", "system volume information", "appdata",
             ".cache", ".idea", ".vs", ".vscode", "dist", "build", ".next", ".obsidian", ".trash"}
SKIP_FILES = {"thumbs.db", "desktop.ini", ".ds_store"}
MAX_CONVERT = 50 * 1024 * 1024   # bytes: a bigger document is listed, not read
AGENT_TOKENS = 150_000           # about what one agent can read of a subject and still write its notes with a clear head
# The method table's lines (SKILL.md): documents, and tokens of their text. Starting guesses; lessons tune them.
SIZES = [("small", 30, 100_000), ("medium", 150, 300_000), ("big", 1500, 2_000_000)]


def kind_of(name):
    ext = os.path.splitext(name)[1].lower()
    if ext in PLAIN or ext in RICH or ext in OLD:
        return "document"
    for kind, exts in KINDS.items():
        if ext in exts:
            return kind
    return "other"


def size_text(b):
    for unit, step in (("GB", 1 << 30), ("MB", 1 << 20), ("KB", 1 << 10)):
        if b >= step:
            return f"{b / step:.1f} {unit}"
    return f"{b} bytes"


def today():
    d = datetime.date.today()
    return f"{d.day} {d:%b} {d.year}"


def read_rows(work):
    path = os.path.join(work, "files.txt")
    if not os.path.isfile(path):
        sys.exit(f"No files.txt in {work}: run survey first.")
    rows = []
    with open(path, encoding="utf-8") as fh:
        next(fh)
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            parts += [""] * (len(COLS) - len(parts))
            rows.append(dict(zip(COLS, parts)))
    return rows


def write_rows(work, rows):
    tmp = os.path.join(work, "files.txt.tmp")
    with open(tmp, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\t".join(COLS) + "\n")
        for r in rows:
            fh.write("\t".join(str(r.get(c, "")).replace("\t", " ").replace("\n", " ") for c in COLS) + "\n")
    os.replace(tmp, os.path.join(work, "files.txt"))


def fingerprint(path, size):
    h = hashlib.sha1()
    try:
        with open(path, "rb") as fh:
            if size <= 200 * 1024 * 1024:
                for block in iter(lambda: fh.read(1 << 20), b""):
                    h.update(block)
            else:  # a huge file: its size, start and end are enough to call it the same
                h.update(str(size).encode())
                h.update(fh.read(1 << 20))
                fh.seek(-(1 << 20), os.SEEK_END)
                h.update(fh.read(1 << 20))
    except OSError:
        return ""
    return h.hexdigest()


def upload_list(path):
    """The paths in the upload point's list on the PC: on each line the time it was sent, a tab, the path."""
    with open(path, encoding="utf-8-sig") as fh:
        return [ln.split("\t", 1)[-1].strip() for ln in fh.read().splitlines() if ln.strip()]


def walk(top):
    """Every file under top as (kind, path). A folder with a .git in it is one 'repo' row, and isn't walked."""
    if os.path.isfile(top):
        yield kind_of(top), top
        return
    todo = [top]
    while todo:
        folder = todo.pop()
        try:
            entries = sorted(os.scandir(folder), key=lambda e: e.name.lower())
        except OSError:
            continue
        if any(e.name == ".git" for e in entries):
            yield "repo", folder
            continue
        for e in entries:
            try:
                if e.is_symlink():
                    continue
                if e.is_dir():
                    if e.name.lower() not in SKIP_DIRS:
                        todo.append(e.path)
                elif e.is_file() and e.name.lower() not in SKIP_FILES and not e.name.startswith("~$"):
                    yield kind_of(e.name), e.path
            except OSError:
                continue


def survey(args):
    paths = list(args.paths) + (upload_list(args.upload_list) if args.upload_list else [])
    if not paths:
        sys.exit("Nothing to survey: give paths, or --upload-list with the upload point's list.")
    os.makedirs(args.work, exist_ok=True)
    rows, missing = [], []
    for top in paths:
        top = os.path.abspath(top)
        if not os.path.exists(top):
            missing.append(top)
            continue
        for kind, path in walk(top):
            try:
                st = os.stat(path)
            except OSError:
                continue
            row = dict.fromkeys(COLS, "")
            row.update(kind=kind, path=path, bytes=0 if kind == "repo" else st.st_size,
                       modified=datetime.date.fromtimestamp(st.st_mtime).isoformat())
            rows.append(row)
    rows.sort(key=lambda r: r["path"].lower())
    by_size = collections.defaultdict(list)
    for i, r in enumerate(rows, 1):
        r["id"] = i
        if r["kind"] not in ("repo",) and r["bytes"]:
            by_size[r["bytes"]].append(r)
    for same in by_size.values():  # only files of the same size can be copies, so only those are read
        if len(same) < 2:
            continue
        first = {}
        # the plainest name is kept as the file, and "Copy of x" or "x (1)" marked as its copy
        for r in sorted(same, key=lambda r: (bool(re.search(r"copy|\(\d+\)", os.path.basename(r["path"]), re.I)), len(r["path"]))):
            mark = fingerprint(r["path"], r["bytes"])
            if mark and mark in first:
                r["dup_of"] = first[mark]["id"]
                r["outcome"], r["where"] = "duplicate", f"the same as file {first[mark]['id']}"
            elif mark:
                first[mark] = r
    for r in rows:
        if r["kind"] == "other" and not r["outcome"]:
            r["outcome"], r["where"] = "skipped", "not a document, media or code: an app's or the system's file"
    write_rows(args.work, rows)
    with open(os.path.join(args.work, "paths.txt"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(paths) + "\n")
    write_survey(args.work, rows, missing)
    print(open(os.path.join(args.work, "survey.md"), encoding="utf-8").read())


def method(docs, tokens, converted):
    for name, max_docs, max_tokens in SIZES:
        if docs <= max_docs and (not converted or tokens <= max_tokens):
            return name
    return "huge"


def write_survey(work, rows, missing=()):
    tops = [p for p in open(os.path.join(work, "paths.txt"), encoding="utf-8").read().splitlines() if p]
    live = [r for r in rows if not r["dup_of"]]
    docs = [r for r in live if r["kind"] == "document"]
    converted = any(r["text"] for r in docs)
    chars = sum(int(r["chars"] or 0) for r in docs)
    tokens = chars // 4
    out = [f"# The pile, surveyed {today()}", ""]
    out.append(f"{len(rows)} files, {size_text(sum(int(r['bytes']) for r in rows))}, from: " + "; ".join(f"`{t}`" for t in tops) + ".")
    dups = len(rows) - len(live)
    if dups:
        out.append(f"{dups} are exact copies of another file here, and are left out of everything below.")
    if missing:
        out.append("Not found: " + "; ".join(f"`{m}`" for m in missing) + ".")
    dates = sorted(r["modified"] for r in live if r["modified"])
    if dates:
        out.append(f"Last changed between {dates[0]} and {dates[-1]}.")
    out += ["", "## By kind", "| Kind | Files | Size |", "|---|---|---|"]
    kinds = collections.Counter(r["kind"] for r in live)
    for kind, n in kinds.most_common():
        out.append(f"| {kind} | {n} | {size_text(sum(int(r['bytes']) for r in live if r['kind'] == kind))} |")
    exts = collections.Counter(os.path.splitext(r["path"])[1].lower() or "(none)" for r in docs)
    if exts:
        out += ["", "Documents by type: " + ", ".join(f"{e} {n}" for e, n in exts.most_common(15)) + "."]
    out += ["", "## By folder", "| Folder | Files | Documents | Text (tokens) | Size |", "|---|---|---|---|---|"]
    folders = collections.defaultdict(list)
    for r in live:
        top = next((t for t in tops if r["path"].lower().startswith(os.path.abspath(t).lower())), "")
        rel = os.path.relpath(r["path"], os.path.abspath(top)) if top and os.path.isdir(top) else os.path.basename(r["path"])
        parts = rel.split(os.sep)
        key = os.sep.join(parts[:2]) if len(parts) > 2 else (parts[0] if len(parts) > 1 else "(loose files)")
        folders[(os.path.basename(os.path.abspath(top)) if len(tops) > 1 else "") + ("\\" if len(tops) > 1 else "") + key].append(r)
    for key, group in sorted(folders.items(), key=lambda kv: -len(kv[1]))[:40]:
        d = [r for r in group if r["kind"] == "document"]
        t = sum(int(r["chars"] or 0) for r in d) // 4
        out.append(f"| `{key}` | {len(group)} | {len(d)} | {t if converted else ''} | {size_text(sum(int(r['bytes']) for r in group))} |")
    if len(folders) > 40:
        out.append(f"| ...and {len(folders) - 40} more folders | | | | |")
    repos = [r for r in live if r["kind"] == "repo"]
    if repos:
        out += ["", "## Code repos (learned where they are, never walked)"] + [f"- `{r['path']}` (file {r['id']})" for r in repos]
    big = sorted(live, key=lambda r: -int(r["bytes"]))[:8]
    out += ["", "## Biggest files"] + [f"- {size_text(int(r['bytes']))}: `{r['path']}`" for r in big if int(r["bytes"])]
    out += ["", "## Text"]
    if converted:
        states = collections.Counter(r["text"].split(":")[0] for r in docs)
        out.append(f"{len(docs)} documents: " + ", ".join(f"{n} {s or 'not tried'}" for s, n in states.most_common()) + f". About {tokens:,} tokens of text in all.")
    else:
        out.append(f"{len(docs)} documents, not turned into text yet: run convert for how much reading there is.")
    name = method(len(docs), tokens, converted)
    out += ["", "## The method this points to",
            f"**{name.capitalize()}**" + ("" if converted else " (by the count of documents alone; convert first for a truer answer)")
            + f": {len(docs)} documents" + (f", about {tokens:,} tokens of text" if converted else "")
            + (f", about {max(1, -(-tokens // AGENT_TOKENS))} agents' worth of reading" if converted and name in ("big", "huge") else "")
            + ". The table in the file-intake skill says what that means; the subjects and kinds in the pile can move it a row."]
    with open(os.path.join(work, "survey.md"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")


def convert(args):
    rows = read_rows(args.work)
    text_dir = os.path.join(args.work, "text")
    os.makedirs(text_dir, exist_ok=True)
    try:
        from markitdown import MarkItDown
        md = MarkItDown()
    except Exception:
        md = None
    done = 0
    for r in rows:
        if r["kind"] != "document" or r["dup_of"]:
            continue
        if r["text"] in ("ok", "plain") and os.path.isfile(os.path.join(text_dir, f"{r['id']}.md")):
            continue
        ext = os.path.splitext(r["path"])[1].lower()
        body = None
        try:
            if int(r["bytes"]) > MAX_CONVERT:
                r["text"] = "too big: listed, not read"
            elif ext in PLAIN:
                with open(r["path"], "rb") as fh:
                    raw = fh.read()
                body = raw.decode("utf-8-sig", errors="replace") if b"\x00" not in raw[:2000] else raw.decode("utf-16", errors="replace")
                r["text"] = "plain"
            elif ext in OLD:
                r["text"] = "old format: open it on the PC and save it as a newer one, or read it there"
            elif md is None:
                r["text"] = "needs markitdown"
            else:
                body = md.convert(r["path"]).text_content or ""
                r["text"] = "ok"
                if len(body.strip()) < 80 and ext == ".pdf":
                    r["text"] = "no text: likely a scan"
        except Exception as e:  # one bad file mustn't stop the pile
            r["text"] = "failed: " + re.sub(r"\s+", " ", str(e))[:120]
        if body is not None:
            r["chars"] = len(body)
            with open(os.path.join(text_dir, f"{r['id']}.md"), "w", encoding="utf-8", newline="\n") as fh:
                fh.write(f"<!-- file {r['id']}: {r['path']} -->\n{body}")
            done += 1
            if done % 50 == 0:
                write_rows(args.work, rows)
                print(f"{done} turned into text...", flush=True)
    write_rows(args.work, rows)
    write_survey(args.work, rows)
    if md is None and any(r["text"] == "needs markitdown" for r in rows):
        print('MarkItDown isn\'t installed, so only plain text was read. Install it, then run convert again: pip install "markitdown[all]"')
    print(open(os.path.join(args.work, "survey.md"), encoding="utf-8").read())


def safe(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def ids_of(spec):
    found = set()
    for part in spec.replace(" ", "").split(","):
        if "-" in part:
            a, b = part.split("-", 1)
            found.update(str(i) for i in range(int(a), int(b) + 1))
        elif part:
            found.add(part)
    return found


def split(args):
    rows = read_rows(args.work)
    rules_path = os.path.join(args.work, "split.txt")
    if not os.path.isfile(rules_path):
        sys.exit(f"No split.txt in {args.work}: write it first, one 'subject: pattern' a line.")
    rules = []
    for line in open(rules_path, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        subject, pattern = (s.strip() for s in line.split(":", 1))
        rules.append((safe(subject), ids_of(pattern[3:]) if pattern.lower().startswith("id ") else pattern.lower()))
    for r in rows:
        r["subject"] = ""
        if r["dup_of"] or r["outcome"] == "skipped":
            continue
        low = r["path"].lower()
        for subject, pattern in rules:
            if isinstance(pattern, set):
                hit = r["id"] in pattern
            elif any(c in pattern for c in "*?["):
                hit = fnmatch.fnmatch(low, pattern)
            else:
                hit = low.startswith(pattern) or (os.sep + pattern.strip("\\/") + os.sep) in low
            if hit:
                r["subject"] = subject
                break
    write_rows(args.work, rows)
    for old in os.listdir(args.work):
        if old.startswith("subject-") and old.endswith(".txt"):
            os.remove(os.path.join(args.work, old))
    print("| Subject | Files | Documents | Text (tokens) | |\n|---|---|---|---|---|")
    for subject in dict.fromkeys(s for s, _ in rules):
        mine = [r for r in rows if r["subject"] == subject]
        docs = [r for r in mine if r["kind"] == "document"]
        tokens = sum(int(r["chars"] or 0) for r in docs) // 4
        flag = f"over one agent's {AGENT_TOKENS:,}: cut it smaller" if tokens > AGENT_TOKENS else ""
        print(f"| {subject} | {len(mine)} | {len(docs)} | {tokens:,} | {flag} |")
        with open(os.path.join(args.work, f"subject-{subject}.txt"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write("id\tkind\ttext\tchars\ttext_file\tpath\n")
            for r in mine:
                text_file = f"text/{r['id']}.md" if r["text"] in ("ok", "plain") else ""
                fh.write(f"{r['id']}\t{r['kind']}\t{r['text']}\t{r['chars']}\t{text_file}\t{r['path']}\n")
    loose = [r for r in rows if not r["subject"] and not r["dup_of"] and r["outcome"] != "skipped"]
    print(f"\nIn no subject: {len(loose)}" + (" (every file needs one, or a line in the coordinator's own outcomes file)" if loose else ""))
    for r in loose[:25]:
        print(f"  {r['id']}\t{r['kind']}\t{r['path']}")
    if len(loose) > 25:
        print(f"  ...and {len(loose) - 25} more: see files.txt")


def check(args):
    rows = read_rows(args.work)
    by_id = {r["id"]: r for r in rows}
    problems = []
    for name in sorted(os.listdir(args.work)):
        if not (name.startswith("outcomes-") and name.endswith(".txt")):
            continue
        for n, line in enumerate(open(os.path.join(args.work, name), encoding="utf-8"), 1):
            parts = [p.strip() for p in line.rstrip("\n").split("\t")]
            if not parts[0] or parts[0] == "id" or parts[0].startswith("#"):
                continue
            if len(parts) < 3 or parts[0] not in by_id or parts[1] not in ("note", "listed", "skipped") or not parts[2]:
                problems.append(f"{name} line {n}: not 'id, note|listed|skipped, where or why': {line.strip()[:80]}")
                continue
            r = by_id[parts[0]]
            r["outcome"], r["where"] = parts[1], parts[2]
    write_rows(args.work, rows)
    texts = {}
    for r in rows:
        if not r["outcome"]:
            problems.append(f"no outcome: file {r['id']} ({r['subject'] or 'no subject'}): {r['path']}")
        elif r["outcome"] in ("note", "listed"):
            note = r["where"].split("#")[0].replace("\\", "/")
            full = os.path.join(args.brain, note)
            if not os.path.isfile(full):
                problems.append(f"file {r['id']}: its note isn't there: {note}")
                continue
            if note not in texts:
                texts[note] = open(full, encoding="utf-8", errors="replace").read().lower()
            base = os.path.basename(r["path"]).lower()
            folder = os.path.basename(os.path.dirname(r["path"])).lower()
            if r["outcome"] == "note" and base not in texts[note]:
                problems.append(f"file {r['id']}: {note} doesn't name it ({os.path.basename(r['path'])})")
            elif r["outcome"] == "listed" and base not in texts[note] and folder not in texts[note]:
                problems.append(f"file {r['id']}: {note} names neither it nor its folder ({r['path']})")
    tally = collections.Counter(r["outcome"] or "no outcome" for r in rows)
    line = f"{len(rows)} files: " + ", ".join(f"{n} {o}" for o, n in tally.most_common()) + "."
    print(line)
    for p in problems[:200]:
        print("  " + p)
    if len(problems) > 200:
        print(f"  ...and {len(problems) - 200} more")
    print("Every file is accounted for." if not problems else f"{len(problems)} to fix.")
    if args.record:
        write_record(args, rows, line, problems)
    sys.exit(1 if problems else 0)


def write_record(args, rows, line, problems):
    """The pile's record: a note for the brain, with the file list saved beside it."""
    tops = open(os.path.join(args.work, "paths.txt"), encoding="utf-8").read().split("\n")
    name = os.path.splitext(os.path.basename(args.record))[0]
    notes = collections.Counter(r["where"].split("#")[0].replace("\\", "/") for r in rows if r["outcome"] in ("note", "listed"))
    out = ["---", f'about: "The record of a pile of files brought into the brain on {today()}: where they came from, how many became notes, '
           'what was left out and why. Read to find what a file became, or before bringing in more from the same place."',
           "tags: [the-brain]", "status: current", f"updated: {today()}", "---", f"# Files brought in, {today()}", "",
           "From: " + "; ".join(f"`{t}`" for t in tops if t) + ".", "", line,
           f"The whole list, one row a file with what it became, is beside this note: `{name}-files.txt` "
           "(tab-separated: id, kind, bytes, modified, text, chars, dup_of, subject, outcome, where, path). "
           "The files themselves are where they were; each note names the ones it came from.", ""]
    if problems:
        out += [f"**Not finished:** {len(problems)} files still have no outcome, or a note that doesn't name them.", ""]
    out += ["## By subject", "| Subject | Files | Became notes | Listed | Skipped |", "|---|---|---|---|---|"]
    for subject in sorted({r["subject"] for r in rows if r["subject"]}):
        mine = collections.Counter(r["outcome"] for r in rows if r["subject"] == subject)
        out.append(f"| {subject} | {sum(mine.values())} | {mine['note']} | {mine['listed']} | {mine['skipped']} |")
    rel = lambda note: os.path.relpath(os.path.join(args.brain, note), os.path.dirname(os.path.abspath(args.record))).replace("\\", "/")
    out += ["", "## The notes they became"] + [f"- [{n}]({rel(n)}): {c} file{'s' if c != 1 else ''}" for n, c in sorted(notes.items())]
    why = collections.Counter(r["where"] for r in rows if r["outcome"] == "skipped")
    if why:
        out += ["", "## Left out, and why"] + [f"- {c}: {w}" for w, c in why.most_common()]
    out += ["", "## How it went", "*The coordinator's lines: the method used, the agents and their reports, and what the owner was asked.*"]
    os.makedirs(os.path.dirname(os.path.abspath(args.record)), exist_ok=True)
    with open(args.record, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")
    shutil.copyfile(os.path.join(args.work, "files.txt"), os.path.splitext(args.record)[0] + "-files.txt")
    print(f"Wrote {args.record} and its file list.")


def main():
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    ap = argparse.ArgumentParser(description="The look-first step and the file list for bringing a pile of files into the brain.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("survey")
    p.add_argument("paths", nargs="*")
    p.add_argument("--upload-list")
    p = sub.add_parser("convert")
    p = sub.add_parser("split")
    p = sub.add_parser("check")
    p.add_argument("--brain", default=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    p.add_argument("--record")
    for p in sub.choices.values():
        p.add_argument("--work", required=True, help="the pile's work folder, outside the repo")
    args = ap.parse_args()
    {"survey": survey, "convert": convert, "split": split, "check": check}[args.cmd](args)


if __name__ == "__main__":
    main()
