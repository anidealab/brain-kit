#!/usr/bin/env python3
"""The weekly backup to the owner's cold storage drive: the brain, with all its history, any other repos the
owner named, and the folders or files they asked for, copied to an external drive they plug in for the backup and
unplug after.

Runs on the owner's computer (Windows, Mac or Linux), through the runner, from the owner's own copy of the
brain (a full clone, so the drive gets every commit; from a job's shallow checkout it clones the brain from GitHub
instead). Python 3 and git only, nothing to install.

What it saves is in my-folders.json beside it: "repos", other repos to keep a full copy of (cloned from GitHub,
by "owner/name"), and for each computer the "folders" (or single files) the owner asked for. A folder marked
"sometimes" (on a Mac, Desktop and Documents kept in iCloud, which take long since macOS downloads any it keeps
only in iCloud) is left out unless the run has --sometimes, which the agent adds when the owner says yes that week.
A private repo is reached with the computer's own git sign-in, or with the read-only token in the environment
variable BACKUP_GITHUB_TOKEN when the job passes one (from the brain's Actions secrets; never written anywhere).

The rules it keeps:
- It only reads on the computer. It never changes, moves or deletes anything there.
- It never deletes or overwrites anything on the drive. When a file changed on the computer since the last
  backup, its old copy on the drive moves to _older-versions/<date>/ first. A file deleted on the computer
  stays on the drive.
- The tripwire: if more than 10% of a folder's files (and at least 200) changed or vanished since the last
  backup, which is what ransomware looks like, that folder is left alone and the run ends with code 2.
- Nothing private in the job's log: counts and folder names only. File-by-file lists stay on the drive, in
  <computer>/_backup-log/<date>/.
- It never formats a drive. A drive that isn't exFAT (the one format Windows and Macs can both write) stops the
  run with code 4, and the agent tells the owner what that means and what they can do.

On the drive, in "Brain backup/": brain/<repo>/ is the one copy of the brain, which every computer brings up to
date, beside the other repos (brain/<name>/ too); each computer has its own folder, by its own name, with its
chosen folders, _older-versions, _backup-log and _backup-state.json, so two computers' "Documents" never mix.

  python3 backup.py drives                         list the external drives it can see
  python3 backup.py run --drive <path>             back up the brain, the repos and the folders in my-folders.json
  python3 backup.py run --drive <path> --sometimes   the same, with the folders marked "sometimes" too
  python3 backup.py run --drive <path> --brain-only  the brain and the repos, no folders
  python3 backup.py run --drive <path> --no-brain    the folders only, when another computer keeps the brain there
  python3 backup.py run --drive <path> --dry-run   say what it would do, and change nothing
  python3 backup.py run --drive <path> --force "Documents"   let one drive folder past the tripwire

--drive can be the drive itself (E:\\, /Volumes/My Drive) or "auto" when exactly one external drive is in.
Exit codes: 0 done (maybe with warnings), 1 something failed, 2 the tripwire stopped a folder, 3 no drive,
4 the drive isn't exFAT (or can't be written to), so nothing was copied.
"""
import argparse
import base64
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
GOOD_FORMAT = "exfat"
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


def lp(path):
    """On Windows, the long-path form, so files deeper than 260 characters can still be read and written."""
    if platform.system() != "Windows":
        return path
    path = os.path.abspath(path)
    if path.startswith("\\\\?\\"):
        return path
    return "\\\\?\\UNC\\" + path[2:] if path.startswith("\\\\") else "\\\\?\\" + path


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


def drive_format(path):
    """The drive's format, lower case (exfat, ntfs, msdos for FAT32, apfs, hfs, ...), or "" if it can't be told."""
    system = platform.system()
    try:
        if system == "Windows":
            letter = os.path.splitdrive(os.path.abspath(path))[0].rstrip(":")
            out = subprocess.run(["powershell", "-NoProfile", "-Command",
                                  f"(Get-Volume -DriveLetter {letter}).FileSystem"],
                                 capture_output=True, text=True, timeout=60).stdout.strip()
            return {"fat32": "msdos", "fat": "msdos"}.get(out.lower(), out.lower())
        if system == "Darwin":
            info = plistlib.loads(subprocess.run(["diskutil", "info", "-plist", path], capture_output=True,
                                                 timeout=30).stdout)
            return str(info.get("FilesystemType") or info.get("FilesystemName") or "").lower()
        out = subprocess.run(["findmnt", "-no", "FSTYPE", "--target", path], capture_output=True, text=True,
                             timeout=30).stdout.strip().lower()
        return {"vfat": "msdos", "ntfs3": "ntfs", "fuseblk": "ntfs"}.get(out, out)
    except Exception:
        return ""


FORMAT_NAMES = {"exfat": "exFAT", "ntfs": "NTFS (Windows only: a Mac can read it but not write to it)",
                "msdos": "FAT32 (no file over 4 GB)", "apfs": "APFS (Mac only: Windows can't read it)",
                "hfs": "Mac OS Extended (Mac only: Windows can't read it)"}


def check_format(drive, label_ok):
    """Stop with code 4 unless the drive is exFAT and can be written to. Never formats anything."""
    fmt = drive_format(drive)
    writable = True
    probe = os.path.join(drive, ".backup-write-test")
    try:
        with open(probe, "w") as f:
            f.write("ok")
        os.remove(probe)
    except OSError:
        writable = False
    if fmt == GOOD_FORMAT and writable:
        return
    shown = FORMAT_NAMES.get(fmt, fmt or "a format this script can't tell")
    if fmt != GOOD_FORMAT and label_ok and writable:
        say(f"{drive} is {shown}, not exFAT; going on, as the owner chose (--any-format).")
        return
    say(f"FORMAT: {drive} is {shown}{'' if writable else ', and it can not be written to from here'}. "
        "The backup needs exFAT, which Windows and Macs can both read and write, with no limit on file size. "
        "Nothing was copied and nothing on the drive was changed. Turning it into exFAT erases everything on it, "
        "so that's the owner's choice (the backup skill says what to tell them).")
    sys.exit(4)


def computer_name():
    return safe_name(platform.node().split(".")[0] or platform.system())


# ---- The brain: a full git clone on the drive, updated by fast-forward only

def git_env():
    """Never wait on a password prompt; with a token, send it to github.com only, through git's environment settings
    (not the command line or any file), with the computer's own credential helper out of the way."""
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0")
    token = os.environ.get("BACKUP_GITHUB_TOKEN", "").strip()
    if token:
        basic = base64.b64encode(f"x-access-token:{token}".encode()).decode()
        env.update(GIT_CONFIG_COUNT="2", GIT_CONFIG_KEY_0="http.https://github.com/.extraheader",
                   GIT_CONFIG_VALUE_0="AUTHORIZATION: basic " + basic,
                   GIT_CONFIG_KEY_1="credential.helper", GIT_CONFIG_VALUE_1="")
    return env


def git(*args, cwd=None):
    r = subprocess.run(["git", "-c", "safe.directory=*", *args], cwd=cwd, capture_output=True, text=True,
                       env=git_env())
    return r.returncode, (r.stdout + r.stderr).strip()


def last_line(out, code):
    return out.splitlines()[-1] if out else str(code)


def keep_clone(dst, source, label, dry):
    """A full clone of source (a GitHub address or a folder) at dst, every branch, brought up to date by fetching
    every branch and fast-forwarding the checked-out one, so history on the drive is never rewritten."""
    if dry:
        code, out = git("ls-remote", "--heads", source)
        reach = "can be reached" if not code else f"can NOT be reached ({last_line(out, code)})"
        say(f"{label}: {reach}; would {'update' if os.path.isdir(os.path.join(dst, '.git')) else 'clone'} it")
        if code:
            failures.append(label)
        return
    if not os.path.exists(dst):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        code, out = git("clone", "--no-hardlinks", "--quiet", source, dst)
        if code:
            shutil.rmtree(dst, ignore_errors=True)  # a half-made clone of ours, nothing of the owner's
            return fail(f"{label} couldn't be cloned: {last_line(out, code)}")
        _, count = git("rev-list", "--count", "--all", cwd=dst)
        say(f"{label} cloned: {count} commits, all branches")
        return
    if not os.path.isdir(os.path.join(dst, ".git")):
        return fail(f"{label}: {dst} is on the drive but isn't a git clone; left alone")
    hcode, before = git("rev-parse", "--verify", "--quiet", "HEAD", cwd=dst)
    # By the source's address, not origin, so one copy can be brought up to date from any computer.
    code, out = git("fetch", "--quiet", "--tags", source, "+refs/heads/*:refs/remotes/origin/*", cwd=dst)
    if code:
        return fail(f"{label} fetch failed: {last_line(out, code)}")
    if hcode:
        return say(f"{label} fetched: every branch (nothing checked out on the drive's copy)")
    _, branch = git("rev-parse", "--abbrev-ref", "HEAD", cwd=dst)
    code, out = git("merge", "--ff-only", "--quiet", f"origin/{branch}", cwd=dst)
    if code:
        warn(f"{label}: {branch} doesn't follow on from the copy on the drive (history rewritten?); "
             "kept the drive's copy, and fetched the rest")
    _, new = git("rev-list", "--count", f"{before}..HEAD", cwd=dst)
    say(f"{label} updated: {new} new commits on {branch}; other branches fetched")


def github_url(spec, owner):
    """'owner/name', or a bare 'name' under the brain's own owner, or a full address, as a clone address."""
    spec = spec.strip().rstrip("/")
    if "://" in spec or spec.startswith("git@"):
        return spec
    if "/" not in spec:
        if not owner:
            return ""
        spec = f"{owner}/{spec}"
    return f"https://github.com/{spec[:-4] if spec.endswith('.git') else spec}.git"


def repo_name(url):
    name = os.path.basename(url.rstrip("/").replace(":", "/"))
    return name[:-4] if name.endswith(".git") else name


def brain_origin():
    """(the brain's top folder, its GitHub address), from the copy this script is in."""
    code, top = git("rev-parse", "--show-toplevel", cwd=HERE)
    if code:
        return "", ""
    ocode, origin = git("remote", "get-url", "origin", cwd=top)
    return top, ("" if ocode else origin)


def owner_of(url):
    parts = url.rstrip("/").replace(":", "/").split("/")
    return parts[-2] if len(parts) >= 2 else ""


def backup_repos(root, repos, dry):
    _, origin = brain_origin()
    brain = repo_name(origin) if origin else ""
    for r in repos:
        spec = r.get("repo", "") if isinstance(r, dict) else str(r)
        url = github_url(spec, (r.get("owner") if isinstance(r, dict) else "") or owner_of(origin))
        if not url:
            fail(f"repo {spec}: no owner given, and the brain's own couldn't be told; write it as owner/name")
            continue
        name = repo_name(url)
        if name == brain:
            continue  # the brain itself, done above
        label = f"Repo {name}"
        keep_clone(os.path.join(root, "brain", name), url, label, dry)
        if not dry and os.path.isdir(os.path.join(root, "brain", name, ".git")):
            git("config", "backup.github", url, cwd=os.path.join(root, "brain", name))
    if repos and not os.environ.get("BACKUP_GITHUB_TOKEN", "").strip() and \
            any(f.startswith("Repo ") for f in failures):
        say("  (A repo that couldn't be reached may be private, and this job had no BACKUP_GITHUB_TOKEN: "
            "the backup skill says how to give it one.)")


def backup_brain(root, dry):
    top, origin = brain_origin()
    if not top:
        fail("this script isn't in a git copy of the brain, so the brain can't be backed up")
        return
    # Named after the repo on GitHub, not this computer's folder, so every computer updates the same copy.
    name = (repo_name(origin) if origin else "") or os.path.basename(top)
    source = top
    _, shallow = git("rev-parse", "--is-shallow-repository", cwd=top)
    if shallow == "true":
        # A job's checkout has only the last commit, so take the brain from GitHub, with all its history.
        if not origin.startswith("https://github.com/"):
            fail(f"the copy of the brain at {top} is shallow (only recent history) and its GitHub address is "
                 "unknown. Run this from the owner's own copy, not a job's checkout")
            return
        source = github_url(origin, "")
    keep_clone(os.path.join(root, "brain", name), source, f"Brain {name}", dry)
    # Where it came from, for a restore: the drive's clone may point at a computer's copy, so keep GitHub's too.
    if origin and not dry and os.path.isdir(os.path.join(root, "brain", name, ".git")):
        git("config", "backup.github", origin, cwd=os.path.join(root, "brain", name))


# ---- The folders: copied, never deleting or overwriting on the drive

def scan(src, skip_named, skip=()):
    """{relative path: (size, mtime)} for every file under src (or src itself, if it's a file), leaving out folders
    named in skip_named at any depth and the folders in skip (paths inside src)."""
    files = {}
    if os.path.isfile(src):
        st = os.stat(src)
        return {os.path.basename(src): (st.st_size, int(st.st_mtime))}
    skip = {os.path.normcase(os.path.normpath(x)) for x in skip}
    for dirpath, dirnames, filenames in os.walk(src):
        rel_dir = os.path.relpath(dirpath, src)
        dirnames[:] = [d for d in dirnames if d not in skip_named and
                       os.path.normcase(os.path.normpath(os.path.join(rel_dir, d))) not in skip]
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


def backup_folder(root, entry, state, stamp, dry, force, logdir, sometimes):
    # root here is this computer's own folder on the drive.
    src = os.path.expanduser(os.path.expandvars(entry["from"]))
    to = entry.get("to") or os.path.basename(src.rstrip("/\\"))
    label = to
    if entry.get("sometimes") and not sometimes:
        say(f"{label}: a sometimes folder, left out this time (the owner said yes to it with --sometimes)")
        return
    if entry.get("once") and os.path.isdir(os.path.join(root, to)) and (state.get(to) or not os.path.exists(src)):
        say(f"{label}: copied once already; left as it is")
        return
    if not os.path.exists(src):
        warn(f"{label}: {entry['from']} isn't on this computer; nothing copied for it")
        return
    if os.path.isdir(src):
        try:
            os.listdir(src)
        except OSError:
            # On a Mac, macOS's privacy settings: the runner wasn't allowed into this folder.
            warn(f"{label}: this computer refused to let the backup read {entry['from']} (on a Mac: System Settings > "
                 "Privacy & Security > Files and Folders); nothing copied for it")
            return
    now = scan(lp(src), set(entry.get("skipNamed", [])), entry.get("skip", []))
    dst = os.path.join(root, to)
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
        s = lp(src if single else os.path.join(src, rel))
        d = lp(os.path.join(dst, rel))
        if os.path.isfile(d):
            st = os.stat(d)
            if same((st.st_size, int(st.st_mtime)), meta):
                same_n += 1
                continue
            upd_n += 1
            lines.append("changed  " + rel)
            if not dry:
                aside = lp(os.path.join(root, "_older-versions", stamp, to, rel))
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
    """(the repos, this computer's folders), or (None, None) when there's no my-folders.json yet."""
    if not os.path.exists(LIST_FILE):
        return None, None
    with open(LIST_FILE, encoding="utf-8") as f:
        cfg = json.load(f)
    repos = cfg.get("repos", [])
    computers = cfg.get("computers", {})
    me = computer_name()
    for name, entry in computers.items():
        if safe_name(name.split(".")[0]).lower() == me.lower():
            return repos, entry.get("folders", [])
    return repos, cfg.get("folders", [])


def run(args):
    drive = pick_drive(args.drive)
    try:
        here_dev = os.stat(os.path.expanduser("~")).st_dev
        if os.stat(drive).st_dev == here_dev and not args.same_disk_ok:
            say(f"{drive} is on the same disk as this computer's own files, so it isn't a separate drive. Stopping.")
            sys.exit(3)
    except OSError:
        pass
    check_format(drive, args.any_format)
    root = os.path.join(drive, ROOT_NAME)
    me = computer_name()
    mine = os.path.join(root, me)
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H%M")
    say(f"== Backup to {drive} ({'dry run, nothing changed' if args.dry_run else stamp}) from {me}")
    logdir = os.path.join(mine, "_backup-log", stamp)
    if not args.dry_run:
        os.makedirs(logdir, exist_ok=True)
        with open(os.path.join(root, "README.txt"), "w", encoding="utf-8") as f:
            f.write("Your brain's cold storage backup, made by its weekly tidy-up.\n\n"
                    "brain/<name>/   one full git copy of your brain, and of each repo you added, every commit, kept up to\n"
                    "                date by each of your computers: `git clone \"<this folder>/brain/<name>\" <name>` gives\n"
                    "                a working copy, and it can be pushed to a new GitHub repo if the old one is gone.\n"
                    "<computer>/     one folder for each computer, by its own name, holding the folders you chose on it,\n"
                    "                by the names you gave them, and its own:\n"
                    "  _older-versions/<date>/   the old copy of any file that changed, from that backup\n"
                    "  _backup-log/<date>/       what each backup copied, file by file\n"
                    "Nothing here is ever deleted or overwritten by the backup. Keep the drive unplugged between backups.\n")
    repos, folders = read_list()
    if args.no_brain:
        say("Brain and repos: left to the other computer that backs them up to this drive (--no-brain)")
    else:
        backup_brain(root, args.dry_run)
        backup_repos(root, repos or [], args.dry_run)
    tripped = False
    if not args.brain_only:
        if folders is None:
            say("No my-folders.json yet, so only the brain was backed up. The first backup asks the owner what "
                "else to save.")
        else:
            state_path = os.path.join(mine, "_backup-state.json")
            state = {}
            if os.path.exists(state_path):
                try:
                    with open(state_path, encoding="utf-8") as f:
                        state = json.load(f)
                except (OSError, ValueError):
                    warn("_backup-state.json on the drive couldn't be read; the tripwire starts fresh")
            for entry in folders:
                if backup_folder(mine, entry, state, stamp, args.dry_run, set(args.force), logdir,
                                 args.sometimes) == "tripwire":
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
    r.add_argument("--brain-only", action="store_true", help="the brain and the repos, no folders")
    r.add_argument("--no-brain", action="store_true",
                   help="the folders only; another computer keeps the brain and the repos here")
    r.add_argument("--sometimes", action="store_true",
                   help='also the folders marked "sometimes", when the owner said yes to them this time')
    r.add_argument("--dry-run", action="store_true")
    r.add_argument("--force", nargs="*", default=[], help="drive folders to let past the tripwire")
    r.add_argument("--any-format", action="store_true",
                   help="go on with a drive that isn't exFAT, when the owner has said so (one computer only)")
    r.add_argument("--same-disk-ok", action="store_true", help=argparse.SUPPRESS)  # for testing only
    args = ap.parse_args()
    if args.cmd == "drives":
        drives = external_drives()
        if not drives:
            print("No external drive found.")
        for p, label, free, total in drives:
            fmt = drive_format(p)
            print(f"{p}\t{label}\t{gb(free)} free of {gb(total)}\t{FORMAT_NAMES.get(fmt, fmt or 'format unknown')}"
                  f"{'' if fmt == GOOD_FORMAT else '  <- not exFAT: the backup would stop'}")
        return
    run(args)


if __name__ == "__main__":
    main()
