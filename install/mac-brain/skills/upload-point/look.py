#!/usr/bin/env python3
"""Upload point on a Mac: a look at what's waiting, for an agent sorting it (SKILL.md in this folder), and the
way to take what's been dealt with off the list. The Mac's version of look.ps1. From a cloud session, run it as
a job on the Mac runner with checkout on (the my-mac skill), with this command:
    python3 -I "$GITHUB_WORKSPACE/skills/upload-point/look.py"
It reads the list My brain (Finder's right-click, Quick Actions) writes on the Mac, _upload/waiting.txt in the
folder that holds the brain's copy (~/AI-Brain-Link/_upload/waiting.txt): one line per thing, the time it was
sent, a tab, and its path. For each path it says whether it's there, its kind and size, and a peek inside: a
folder's top two levels, a text file's first lines, and for a code repo its remote, latest commits, what isn't
committed, and the start of its README and CLAUDE.md. A look changes nothing.
    python3 -I "$GITHUB_WORKSPACE/skills/upload-point/look.py" --done '/a path' '/another'
takes those paths' lines off the list instead, and says what's left. --list <file> names the list when the
brain's copy isn't in ~/AI-Brain-Link. Python 3.9, as Apple's command line tools have it; nothing to install.
"""
import argparse, os, re, shutil, subprocess, sys, time

READABLE = re.compile(r"\.(txt|md|markdown|csv|tsv|json|ya?ml|xml|html?|css|js|ts|py|ps1|sh|ini|cfg|conf|toml|log|sql)$", re.I)


def find_list():
    # Up from this folder to the one that has the list: from the brain's copy, or from the runner's checkout.
    d = os.path.dirname(os.path.abspath(__file__))
    while True:
        try_ = os.path.join(d, "_upload", "waiting.txt")
        if os.path.isfile(try_):
            return try_
        up = os.path.dirname(d)
        if up == d:
            return os.path.expanduser("~/AI-Brain-Link/_upload/waiting.txt")
        d = up


def size_text(b):
    for unit, n, fmt in (("GB", 1 << 30, "%.1f"), ("MB", 1 << 20, "%.1f"), ("KB", 1 << 10, "%.0f")):
        if b >= n:
            return (fmt % (b / n)) + " " + unit
    return "%d bytes" % b


def measure(p, seconds):
    # Files and bytes under a folder, counted for so many seconds at most, then marked with a +.
    files, size, more, start = 0, 0, False, time.monotonic()
    todo = [p]
    while todo:
        if time.monotonic() - start > seconds:
            more = True
            break
        d = todo.pop()
        try:
            with os.scandir(d) as it:
                for e in it:
                    try:
                        if e.is_dir(follow_symlinks=False):
                            todo.append(e.path)
                        elif e.is_file(follow_symlinks=False):
                            files += 1
                            size += e.stat(follow_symlinks=False).st_size
                    except OSError:
                        pass
        except OSError:
            pass
    plus = "+" if more else ""
    word = " file" if files == 1 and not more else " files"
    return "%s%s in %s%s%s" % (size_text(size), plus, format(files, ","), plus, word)


def peek(path, count):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f):
                if i >= count:
                    break
                print("    | " + line.rstrip("\n"))
    except OSError:
        pass


def path_of(line):
    # A line of the list is the time it was sent, a tab, and the path.
    return line.split("\t", 1)[1].strip() if "\t" in line else line.strip()


def changed(p):
    return time.strftime("%d %b %Y", time.localtime(os.path.getmtime(p))).lstrip("0")


def main():
    ap = argparse.ArgumentParser(description="A look at what's waiting at the upload point, or --done to take paths off.")
    ap.add_argument("--list", default="")
    ap.add_argument("--done", nargs="*", default=[])
    a = ap.parse_args()
    lst = a.list or find_list()
    lines = []
    if os.path.isfile(lst):
        with open(lst, encoding="utf-8-sig") as f:
            lines = [l.rstrip("\r\n") for l in f if l.strip()]

    if a.done:
        gone = {p.strip().rstrip("/").lower() for p in a.done if p.strip()}
        keep = [l for l in lines if path_of(l).rstrip("/").lower() not in gone]
        if len(keep) == len(lines):
            print("None of those paths is on the list, %s: nothing taken off." % lst)
        else:
            with open(lst, "w", encoding="utf-8") as f:
                f.write("".join(l + "\n" for l in keep))
            print("Taken off the list: %d." % (len(lines) - len(keep)))
        if keep:
            print("Still waiting:")
            for l in keep:
                print("  " + l)
        else:
            print("Nothing waiting.")
        return 0

    if not lines:
        print("Nothing waiting. (The list: %s)" % lst)
        return 0
    print("The list: " + lst)
    git = shutil.which("git")
    for line in lines:
        p = path_of(line)
        when = "   (sent %s)" % line.split("\t", 1)[0].strip() if "\t" in line else ""
        print("")
        print("== " + p + when)
        if not os.path.lexists(p):
            print("  not there: moved, deleted, or on a drive that is unplugged")
            continue
        if not os.path.isdir(p):
            try:
                n = os.path.getsize(p)
            except OSError:
                n = 0
            print("  file, %s, changed %s" % (size_text(n), changed(p)))
            if READABLE.search(p) and n < 5 << 20:
                peek(p, 20)
            continue
        is_repo = os.path.exists(os.path.join(p, ".git"))
        print("  %s, %s, changed %s" % ("git repo" if is_repo else "folder", measure(p, 5), changed(p)))
        try:
            kids = sorted(os.scandir(p), key=lambda e: (not e.is_dir(follow_symlinks=False), e.name.lower()))[:40]
        except OSError:
            kids = []
        for c in kids:
            if not c.is_dir(follow_symlinks=False):
                try:
                    print("  %s  %s" % (c.name, size_text(c.stat(follow_symlinks=False).st_size)))
                except OSError:
                    print("  " + c.name)
                continue
            print("  %s/  (%s)" % (c.name, measure(c.path, 1.5)))
            if is_repo:
                continue
            try:
                for cc in sorted(os.scandir(c.path), key=lambda e: e.name.lower())[:12]:
                    if cc.is_dir(follow_symlinks=False):
                        print("    %s/" % cc.name)
                    else:
                        try:
                            print("    %s  %s" % (cc.name, size_text(cc.stat(follow_symlinks=False).st_size)))
                        except OSError:
                            print("    " + cc.name)
            except OSError:
                pass
        if is_repo and git:
            for title, args, most in (("remote", ["remote", "-v"], 50), ("latest commits", ["log", "--oneline", "-15"], 50),
                                      ("not committed", ["status", "--short"], 15)):
                print("  -- %s:" % title)
                r = subprocess.run([git, "-C", p] + args, capture_output=True, text=True)
                for l in (r.stdout + r.stderr).splitlines()[:most]:
                    print("    " + l)
        for n in ("README.md", "README.txt", "README", "CLAUDE.md"):
            f = os.path.join(p, n)
            if os.path.isfile(f):
                print("  -- %s:" % n)
                peek(f, 30)
    return 0


if __name__ == "__main__":
    sys.exit(main())
