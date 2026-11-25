#!/usr/bin/env python3
"""The weekly backup to the owner's cold storage drive: the brain, with all its history, and the folders
they chose, copied to an external drive they plug in for the backup and unplug after.

Runs on the owner's computer (Windows, Mac or Linux), through the runner, from the owner's own copy of the
brain (a full clone, so the drive gets every commit). Python 3 and git only, nothing to install.

The rules it keeps:
- It only reads on the computer. It never changes, moves or deletes anything there.
- It never deletes or overwrites anything on the drive. When a file changed on the computer since the last
  backup, its old copy on the drive moves to _older-versions/<date>/ first. A file deleted on the computer
  stays on the drive.
- The tripwire: if more than 10% of a folder's files (and at least 200) changed or vanished since the last
  backup, which is what ransomware looks like, that folder is left alone and the run ends with code 2.
- Nothing private in the job's log: counts and folder names only. File-by-file lists stay on the drive, in
  _backup-log/<date>/.

  python3 backup.py drives                         list the external drives it can see
  python3 backup.py run --drive <path>             back up the brain, and the folders in my-folders.json
  python3 backup.py run --drive <path> --brain-only
  python3 backup.py run --drive <path> --dry-run   say what it would do, and change nothing
  python3 backup.py run --drive <path> --force "Documents"   let one drive folder past the tripwire

--drive can be the drive itself (E:\\, /Volumes/My Drive) or "auto" when exactly one external drive is in.
Exit codes: 0 done (maybe with warnings), 1 something failed, 2 the tripwire stopped a folder, 3 no drive.
"""
import argparse
import datetime
import json
import os
import platform
import plistlib
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LIST_FILE = os.path.join(HERE, "my-folders.json")
ROOT_NAME = "Brain backup"
TRIP_SHARE, TRIP_MIN = 0.10, 200

summary, warnings, failures = [], [], []


def say(text):
    print(text, flush=True)
    summary.append(text)


def warn(text):
    say("  WARNING: " + text)
    warnings.append(text)


def fail(text):
    say("  FAILED: " + text)
    failures.append(text)


def gb(n):
    return f"{n / 1024 ** 3:.1f} GB"


# ---- Finding the drive

def external_drives():
    """[(path, label, free bytes, total bytes)] for drives that look external: USB on Windows, not internal on a
    Mac, mounted under /media, /run/media or /mnt on Linux."""
    found = []
    system = platform.system()
    if system == "Windows":
        ps = ("Get-Partition | Where-Object DriveLetter | ForEach-Object { $d = Get-Disk -Number $_.DiskNumber; "
              "$v = Get-Volume -DriveLetter $_.DriveLetter; [pscustomobject]@{L=[string]$_.DriveLetter; "
              "Bus=[string]$d.BusType; Sys=[bool]($d.IsSystem -or $d.IsBoot); Label=[string]$v.FileSystemLabel} } "
              "| ConvertTo-Json")
        try:
            out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True,
                                 timeout=60).stdout.strip()
            rows = json.loads(out) if out else []
        except Exception:
            rows = []
        for r in rows if isinstance(rows, list) else [rows]:
            if r.get("Bus") == "USB" and not r.get("Sys"):
                found.append((r["L"] + ":\\", r.get("Label") or ""))
    elif system == "Darwin":
        for name in sorted(os.listdir("/Volumes")):
            path = os.path.join("/Volumes", name)
            if not os.path.ismount(path) or os.path.realpath(path) == "/":
                continue
            try:
                info = plistlib.loads(subprocess.run(["diskutil", "info", "-plist", path], capture_output=True,
                                                     timeout=30).stdout)
            except Exception:
                continue
            if not info.get("Internal", True) and info.get("WritableVolume", True) and \
                    info.get("BusProtocol") != "Disk Image" and \
                    info.get("FilesystemType") not in ("udf", "cd9660"):
                found.append((path, name))
    else:
        user = os.environ.get("USER", "")
        for base in (f"/media/{user}", f"/run/media/{user}", "/media", "/mnt"):
            if not os.path.isdir(base):
                continue
            for name in sorted(os.listdir(base)):
                path = os.path.join(base, name)
                if os.path.ismount(path) and all(p != path for p, _ in found):
                    found.append((path, name))
    out = []
    for path, label in found:
        try:
            u = shutil.disk_usage(path)
            out.append((path, label, u.free, u.total))
        except OSError:
            pass
    return out


def pick_drive(arg):
    if arg and arg != "auto":
        if not os.path.isdir(arg):
            say(f"The drive {arg} isn't there. Is it plugged in?")
            sys.exit(3)
        return arg
    drives = external_drives()
    if len(drives) == 1:
        return drives[0][0]
    if not drives:
        say("No external drive is plugged in. Plug the cold storage drive in and run it again.")
    else:
        say("More than one external drive is plugged in; say which with --drive:")
        for p, label, free, total in drives:
            say(f"  {p}  {label}  {gb(free)} free of {gb(total)}")
    sys.exit(3)


# ---- The brain: a full git clone on the drive, updated by fast-forward only

def git(*args, cwd=None):
    r = subprocess.run(["git", "-c", "safe.directory=*", *args], cwd=cwd, capture_output=True, text=True)
    return r.returncode, (r.stdout + r.stderr).strip()


def backup_brain(root, dry):
    code, top = git("rev-parse", "--show-toplevel", cwd=HERE)
    if code:
        fail("this script isn't in a git copy of the brain, so the brain can't be backed up")
        return
    name = os.path.basename(top)
    _, shallow = git("rev-parse", "--is-shallow-repository", cwd=top)
    if shallow == "true":
        fail(f"the copy of the brain at {top} is shallow (only recent history). Run this from the owner's own "
             "copy, not a job's checkout")
        return
    dst = os.path.join(root, "brain", name)
    _, origin = git("remote", "get-url", "origin", cwd=top)
    if dry:
        say(f"Brain {name}: would {'update' if os.path.isdir(os.path.join(dst, '.git')) else 'clone'} "
            f"{dst}")
        return
    if not os.path.exists(dst):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        code, out = git("clone", "--no-hardlinks", "--quiet", top, dst)
        if code:
            fail(f"brain {name} couldn't be cloned: {out.splitlines()[-1] if out else code}")
            return
        _, count = git("rev-list", "--count", "--all", cwd=dst)
        say(f"Brain {name} cloned: {count} commits, all branches")
    elif not os.path.isdir(os.path.join(dst, ".git")):
        fail(f"brain {name}: {dst} is on the drive but isn't a git clone; left alone")
        return
    else:
        git("remote", "set-url", "origin", top, cwd=dst)
        _, before = git("rev-parse", "HEAD", cwd=dst)
        code, out = git("fetch", "--quiet", "--tags", "origin", cwd=dst)
        if code:
            fail(f"brain {name} fetch failed: {out.splitlines()[-1] if out else code}")
            return
        _, branch = git("rev-parse", "--abbrev-ref", "HEAD", cwd=dst)
        code, out = git("merge", "--ff-only", "--quiet", f"origin/{branch}", cwd=dst)
        if code:
            warn(f"brain {name}: {branch} doesn't follow on from the copy on the drive (history rewritten?); "
                 "kept the drive's copy, and fetched the rest")
        _, new = git("rev-list", "--count", f"{before}..HEAD", cwd=dst)
        say(f"Brain {name} updated: {new} new commits on {branch}; other branches fetched")
    # Where it came from, for a restore: the drive's clone points at the computer's copy, so keep GitHub's too.
    if origin:
        git("config", "backup.github", origin, cwd=dst)


# ---- The folders: copied, never deleting or overwriting on the drive

def scan(src, skip_named):
    """{relative path: (size, mtime)} for every file under src (or src itself, if it's a file)."""
    files = {}
    if os.path.isfile(src):
        st = os.stat(src)
        return {os.path.basename(src): (st.st_size, int(st.st_mtime))}
    for dirpath, dirnames, filenames in os.walk(src):
        dirnames[:] = [d for d in dirnames if d not in skip_named]
        for f in filenames:
            p = os.path.join(dirpath, f)
            try:
                st = os.stat(p)
            except OSError:
                continue
            if os.path.isfile(p):
                files[os.path.relpath(p, src)] = (st.st_size, int(st.st_mtime))
    return files


def same(a, b):
    # Two seconds' slack: FAT and exFAT drives keep times to the nearest two seconds.
    return a[0] == b[0] and abs(a[1] - b[1]) <= 2


def backup_folder(root, entry, state, stamp, dry, force, logdir):
    src = os.path.expanduser(os.path.expandvars(entry["from"]))
    to = entry.get("to") or os.path.basename(src.rstrip("/\\"))
    label = to
    if not os.path.exists(src):
        warn(f"{label}: {entry['from']} isn't on this computer; nothing copied for it")
        return
    now = scan(src, set(entry.get("skipNamed", [])))
    dst = os.path.join(root, "files", to)
    if entry.get("once") and os.path.isdir(dst) and state.get(to):
        say(f"{label}: copied once already; left as it is")
        return
    last = {k: tuple(v) for k, v in state.get(to, {}).items()}
    changed = [k for k in last if k in now and not same(last[k], now[k])]
    vanished = [k for k in last if k not in now]
    hit = len(changed) + len(vanished)
    if last and hit > TRIP_SHARE * len(last) and hit >= TRIP_MIN:
        if to in force:
            say(f"{label}: tripwire passed by --force: {len(changed)} changed, {len(vanished)} vanished")
        else:
            say(f"{label}: TRIPWIRE. {len(changed)} of its {len(last)} files changed and {len(vanished)} vanished "
                "since the last backup, which is what ransomware looks like, so it was left alone.")
            failures.append(f"tripwire: {label}")
            return "tripwire"
    new_n = upd_n = same_n = 0
    size = 0
    lines = []
    single = os.path.isfile(src)
    for rel, meta in sorted(now.items()):
        s = src if single else os.path.join(src, rel)
        d = os.path.join(dst, rel)
        if os.path.isfile(d):
            st = os.stat(d)
            if same((st.st_size, int(st.st_mtime)), meta):
                same_n += 1
                continue
            upd_n += 1
            lines.append("changed  " + rel)
            if not dry:
                aside = os.path.join(root, "_older-versions", stamp, "files", to, rel)
                os.makedirs(os.path.dirname(aside), exist_ok=True)
                if os.path.exists(aside):
                    aside += ".2"
                shutil.move(d, aside)
        else:
            new_n += 1
            lines.append("new      " + rel)
        size += meta[0]
        if not dry:
            try:
                os.makedirs(os.path.dirname(d), exist_ok=True)
                shutil.copy2(s, d)
            except OSError as e:
                warn(f"{label}: one file couldn't be copied ({e.strerror})")
    for rel in vanished:
        lines.append("gone from the computer, kept on the drive  " + rel)
    say(f"{label}: {new_n} new, {upd_n} changed (old copies kept), {same_n} the same, {len(vanished)} gone from "
        f"the computer and kept; {gb(size)} {'would be ' if dry else ''}copied")
    if not dry:
        state[to] = {k: list(v) for k, v in now.items()}
        with open(os.path.join(logdir, safe_name(to) + ".txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")


def safe_name(to):
    return "".join(" - " if c in '\\/:*?"<>|' else c for c in to).strip()


def read_list():
    if not os.path.exists(LIST_FILE):
        return None
    with open(LIST_FILE, encoding="utf-8") as f:
        cfg = json.load(f)
    computers = cfg.get("computers", {})
    me = platform.node().split(".")[0]
    for name, entry in computers.items():
        if name.lower() == me.lower():
            return entry.get("folders", [])
    return cfg.get("folders", [])


def run(args):
    drive = pick_drive(args.drive)
    try:
        here_dev = os.stat(os.path.expanduser("~")).st_dev
        if os.stat(drive).st_dev == here_dev and not args.same_disk_ok:
            say(f"{drive} is on the same disk as this computer's own files, so it isn't a separate drive. Stopping.")
            sys.exit(3)
    except OSError:
        pass
    root = os.path.join(drive, ROOT_NAME)
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H%M")
    say(f"== Backup to {drive} ({'dry run, nothing changed' if args.dry_run else stamp}) on {platform.node()}")
    logdir = os.path.join(root, "_backup-log", stamp)
    if not args.dry_run:
        os.makedirs(logdir, exist_ok=True)
        readme = os.path.join(root, "README.txt")
        if not os.path.exists(readme):
            with open(readme, "w", encoding="utf-8") as f:
                f.write("Your brain's cold storage backup, made by its weekly tidy-up.\n\n"
                        "brain\\   a full git copy of your brain, every commit: `git clone \"<this folder>\\brain\\<name>\" <name>`\n"
                        "          gives a working copy, and it can be pushed to a new GitHub repo if the old one is gone.\n"
                        "files\\   the folders you chose, by the names you gave them.\n"
                        "_older-versions\\<date>\\   the old copy of any file that changed, from that backup.\n"
                        "_backup-log\\<date>\\       what each backup copied, file by file.\n"
                        "Nothing here is ever deleted or overwritten by the backup. Keep the drive unplugged between backups.\n")
    backup_brain(root, args.dry_run)
    tripped = False
    if not args.brain_only:
        folders = read_list()
        if folders is None:
            say("No my-folders.json yet, so only the brain was backed up. The first backup with the runner asks "
                "the owner what to save.")
        else:
            state_path = os.path.join(root, "_backup-state.json")
            state = {}
            if os.path.exists(state_path):
                try:
                    with open(state_path, encoding="utf-8") as f:
                        state = json.load(f)
                except (OSError, ValueError):
                    warn("_backup-state.json on the drive couldn't be read; the tripwire starts fresh")
            for entry in folders:
                if backup_folder(root, entry, state, stamp, args.dry_run, set(args.force), logdir) == "tripwire":
                    tripped = True
            if not args.dry_run:
                with open(state_path + ".new", "w", encoding="utf-8") as f:
                    json.dump(state, f)
                os.replace(state_path + ".new", state_path)
    u = shutil.disk_usage(drive)
    say(f"== Drive: {gb(u.free)} free of {gb(u.total)}. {len(warnings)} warnings, {len(failures)} failures.")
    if tripped:
        sys.exit(2)
    sys.exit(1 if failures else 0)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("drives", help="list the external drives")
    r = sub.add_parser("run", help="back up")
    r.add_argument("--drive", default="auto")
    r.add_argument("--brain-only", action="store_true")
    r.add_argument("--dry-run", action="store_true")
    r.add_argument("--force", nargs="*", default=[], help="drive folders to let past the tripwire")
    r.add_argument("--same-disk-ok", action="store_true", help=argparse.SUPPRESS)  # for testing only
    args = ap.parse_args()
    if args.cmd == "drives":
        drives = external_drives()
        if not drives:
            print("No external drive found.")
        for p, label, free, total in drives:
            print(f"{p}\t{label}\t{gb(free)} free of {gb(total)}")
        return
    run(args)


if __name__ == "__main__":
    main()
