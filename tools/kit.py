#!/usr/bin/env python3
"""The kit's own build: check the kit after a change, and make its zip.

This repo is the kit. brain/ is the brain a new owner gets, with {KIT_DATE} and {KIT_ISO} where each brain has its own
start date; install.ps1 and install/ make a brain from it on the owner's PC, and install.sh and install/install-mac.sh
on a Mac, adding install/mac-brain/'s parts; updates/ holds the brain updates that brains made from it get. Change the
kit by changing those files here, then run:

    python3 tools/kit.py build           rebuild brain/'s indexes, copy sign-off-links.md into brain/, then make a brain
                                         from brain/ in a scratch folder and run its own checks and tests, and the kit's
                                         promises (below); then the same for a brain made as the Mac installer makes it
                                         (install/install-mac.sh in its check mode, with bash). Run it after every
                                         change, and fix what it reports.
    python3 tools/kit.py zip [folder]    the zip an owner can install from instead of the one command: the brain as a
                                         git bundle started today, the installer, the setup check and START-HERE.txt

The kit's promises: no one person's names, accounts or setup anywhere in the repo (the copied skills aside, kept as
they came), every date placeholder filled in a new brain, the core under 6 KB (a core may be 8 KB, so each owner has
2 KB for their own lines), and as many skills as START-HERE.txt (and START-HERE-MAC.txt, for a Mac brain) says.

Python 3.8+ and git, nothing else, and bash for the Mac brain's check.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
BRAIN = os.path.join(REPO, "brain")
INSTALL = os.path.join(REPO, "install")
UPDATES = os.path.join(REPO, "updates")
LIBRARY = os.path.join(REPO, "sign-off-links.md")  # the copy brains refresh theirs from each day
BRAIN_LIBRARY = os.path.join("knowledge", "systems", "sign-off-links.md")  # the copy a new brain starts with
TEXT = {".md", ".py", ".ps1", ".yml", ".json", ".txt", ".css", ".js", ".mjs", ".sh", ".gitignore"}
CORE_MAX = 6 * 1024
# A date no brain starts on, filled in for the checks and swapped back to the placeholders after.
SENTINEL = ("9 Sep 1999", "1999-09-09")
# The line in a brain's brain-updates note that brain_update.py and the installer read and write.
UPDATE_LINE = re.compile(r"(?m)^\*\*On kit update:\*\* [^\r\n]*")
UPDATE_FILE = re.compile(r"^(\d{4})-[a-z0-9-]+\.md$")
# One person's names, accounts and setup, which nothing in the kit may carry: it stands alone. The first name counts on
# its own; Matt Pocock, whose skills are copied in, doesn't. The build looks in every text file in the repo and in a new
# brain made from it, except the copied skills, kept as they came, and the pattern's own line here.
PERSONAL = re.compile(r"\bMatt\b(?!\s+Pocock)|matt-pc|matts-pc|big-brain|farm-brain|mjohnsonchung|D:\\AI-Brain-Link|AnIdeaLab-brain-friends-kit", re.I)
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
ONE_COMMAND = "irm https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/install.ps1 | iex"
# The Mac's one command, its installer, and the parts it adds to a brain made on a Mac (files as they go in a brain).
ONE_COMMAND_MAC = '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/AnIdeaLab/brain-kit/main/install.sh)"'
INSTALL_MAC = os.path.join(INSTALL, "install-mac.sh")
MAC_PARTS = os.path.join(INSTALL, "mac-brain")
# START-HERE.txt is for the one command; the zip's copy has the line that unpacks the zip from Downloads instead.
ZIP_START = (
    "2. PASTE THIS LINE into the blue window and press Enter:\n\n" + ONE_COMMAND + "\n",
    "2. SAVE THE ZIP in your Downloads folder, as it came (no need to unzip it). Then PASTE THIS\n"
    "   LINE into the blue window and press Enter:\n\n"
    "$z = Get-ChildItem \"$HOME\\Downloads\" -Filter 'brain-kit-*.zip' | Sort-Object LastWriteTime | Select-Object -Last 1; "
    "Expand-Archive $z.FullName \"$env:TEMP\\brain-kit\" -Force; powershell -ExecutionPolicy Bypass -File "
    "(Get-ChildItem \"$env:TEMP\\brain-kit\" -Recurse -Filter install-windows.ps1 | Select-Object -Last 1).FullName\n")


def run(*cmd, cwd=None, check=True, env=None):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, env=env)
    if check and r.returncode:
        sys.exit(f"{' '.join(cmd)} failed:\n{r.stdout}{r.stderr}")
    return r


def fill(text, day, iso):
    return text.replace("{KIT_DATE}", day).replace("{KIT_ISO}", iso)


def copy_brain(dest, day, iso):
    """brain/ into dest, with the start date filled in, in names and in text files."""
    for dirpath, dirs, files in os.walk(BRAIN):
        dirs[:] = [d for d in dirs if d != "__pycache__"]
        for f in files:
            src = os.path.join(dirpath, f)
            out = os.path.join(dest, fill(os.path.relpath(src, BRAIN), day, iso))
            os.makedirs(os.path.dirname(out), exist_ok=True)
            if os.path.splitext(f)[1] in TEXT or f == ".gitignore":
                open(out, "w", encoding="utf-8", newline="").write(fill(open(src, encoding="utf-8", newline="").read(), day, iso))
                shutil.copymode(src, out)
            else:
                shutil.copy2(src, out)


def unfill(text):
    day, iso = SENTINEL
    return text.replace(day, "{KIT_DATE}").replace(iso, "{KIT_ISO}")


def copied_skills(brain):
    """The folders in a brain's skills/ that the list lines of skills/lists/sources.md link, read as library.py reads
    them: the copied skills and the shared files they use, kept as they came. As paths from the brain's top."""
    path = os.path.join(brain, "skills", "lists", "sources.md")
    if not os.path.isfile(path):
        return ()
    text = re.sub(r"```.*?```", "", open(path, encoding="utf-8").read(), flags=re.S)
    tops = set()
    for line in text.split("\n"):
        if not line.lstrip().startswith("- "):
            continue
        for target in LINK.findall(line):
            if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I):
                continue
            top = os.path.normpath(os.path.join("lists", target.split("#")[0])).split(os.sep)[0]
            if top not in (".", "..", "lists"):
                tops.add(top)
    return tuple(f"skills/{top}/" for top in sorted(tops))


def outside_brain():
    """The repo's text files outside brain/, as paths from its top."""
    out = []
    for dirpath, dirs, files in os.walk(REPO):
        dirs[:] = sorted(d for d in dirs if d not in (".git", "__pycache__", "node_modules") and not (dirpath == REPO and d == "brain"))
        for f in sorted(files):
            if os.path.splitext(f)[1] in TEXT or f == ".gitignore" or "." not in f:
                out.append(os.path.relpath(os.path.join(dirpath, f), REPO).replace(os.sep, "/"))
    return out


def names_someone(text, rel):
    """Whether a file's text has PERSONAL in it, leaving out the line here that defines it."""
    if rel == "tools/kit.py":
        text = "\n".join(line for line in text.split("\n") if not line.startswith("PERSONAL = "))
    return bool(PERSONAL.search(text))


def skill_count():
    skills = os.path.join(BRAIN, "skills")
    return len([d for d in os.listdir(skills) if os.path.isfile(os.path.join(skills, d, "SKILL.md"))])


def check(brain):
    """A brain's own checks and tests, run on a new brain made from brain/, and the kit's promises. Returns the problems."""
    run(sys.executable, "skills/brain-spec/library.py", "build", cwd=brain)
    run("git", "init", "-q", "-b", "main", cwd=brain)
    run("git", "add", "-A", cwd=brain)
    lib = run(sys.executable, "skills/brain-spec/library.py", "check", "--strict", cwd=brain, check=False)
    links = run(sys.executable, "skills/brain-spec/check_links.py", cwd=brain, check=False)
    tests = run(sys.executable, "skills/brain-spec/test_library.py", cwd=brain, check=False)
    problems = []
    if lib.returncode:
        problems.append("library check:\n" + lib.stdout)
    if links.returncode or "Notes nothing links to: 0" not in links.stdout:
        problems.append("link check:\n" + links.stdout)
    if tests.returncode:
        problems.append("library tests:\n" + tests.stdout + tests.stderr)
    count = skill_count()
    start = open(os.path.join(INSTALL, "START-HERE.txt"), encoding="utf-8").read()
    if f"{count} skills" not in start:
        problems.append(f"the kit has {count} skills, but install/START-HERE.txt doesn't say \"{count} skills\"")
    files = run("git", "ls-files", cwd=brain).stdout.splitlines()
    kept = copied_skills(brain)
    personal, unfilled = [], []
    for rel in files:
        if os.path.splitext(rel)[1] not in TEXT:
            continue
        text = open(os.path.join(brain, rel), encoding="utf-8", errors="replace").read()
        if not rel.startswith(kept) and names_someone(text, rel):
            personal.append("brain/" + unfill(rel))
        if "{KIT_" in text:
            unfilled.append(rel)
    for rel in outside_brain():
        if names_someone(open(os.path.join(REPO, rel), encoding="utf-8", errors="replace").read(), rel):
            personal.append(rel)
    if personal:
        problems.append("one person's own names, accounts or setup are in: " + ", ".join(personal))
    if unfilled:
        problems.append("a {KIT_...} placeholder isn't filled in a new brain, in: " + ", ".join(unfilled))
    if os.path.getsize(os.path.join(brain, "CLAUDE.md")) > CORE_MAX:
        problems.append("the core is over 6 KB, leaving owners less than their 2 KB of the 8 KB")
    return problems


def mac_check(notes):
    """A brain made as the Mac installer makes it: install/install-mac.sh in its check mode, which adds
    install/mac-brain/'s files and adapts a few of brain/'s lines (it stops if one of those lines isn't there any
    more), then the same checks as check(), and START-HERE-MAC.txt's skill count and command. Returns the problems,
    or None if there's no bash here to run it."""
    bash = shutil.which("bash")
    if not bash or os.name == "nt":
        notes.append("no bash here, so the brain the Mac installer makes wasn't checked: run the build where there's bash")
        return None
    problems = []
    both = sorted(os.path.relpath(os.path.join(dirpath, f), MAC_PARTS).replace(os.sep, "/")
                  for dirpath, _, files in os.walk(MAC_PARTS) for f in files
                  if os.path.exists(os.path.join(BRAIN, os.path.relpath(os.path.join(dirpath, f), MAC_PARTS))))
    if both:
        notes.append("brain/ has these Mac parts now, so a Mac brain gets brain/'s copies and install/mac-brain/'s can go: " + ", ".join(both))
    parts = os.path.join(MAC_PARTS, "skills")
    added = [d for d in os.listdir(parts) if os.path.isfile(os.path.join(parts, d, "SKILL.md"))
             and not os.path.isfile(os.path.join(BRAIN, "skills", d, "SKILL.md"))] if os.path.isdir(parts) else []
    start = open(os.path.join(INSTALL, "START-HERE-MAC.txt"), encoding="utf-8").read()
    if f"{skill_count() + len(added)} skills" not in start:
        problems.append(f"a Mac brain has {skill_count() + len(added)} skills, but install/START-HERE-MAC.txt doesn't say \"{skill_count() + len(added)} skills\"")
    if ONE_COMMAND_MAC not in start:
        problems.append("install/START-HERE-MAC.txt doesn't have the Mac's one command: " + ONE_COMMAND_MAC)
    work = tempfile.mkdtemp()
    try:
        env = {k: v for k, v in os.environ.items() if not k.startswith("BRAIN_KIT_")}
        env["BRAIN_KIT_CHECK"] = work
        r = subprocess.run([bash, INSTALL_MAC], env=env, capture_output=True, text=True, stdin=subprocess.DEVNULL)
        if r.returncode:
            out = re.sub(r"\x1b\[[0-9;]*m", "", r.stdout + r.stderr).strip()
            return problems + ["the Mac installer couldn't make a brain (install/install-mac.sh, in its check mode); "
                               "if it says a line isn't there, change that line's Mac version in mac_brain there to match:\n" + out[-2000:]]
        problems += [f"in a brain made by the Mac installer, {p}" for p in check(os.path.join(work, "my-brain"))]
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return problems


def build():
    """Rebuild brain/'s indexes and its copy of the sign-off's links, then check the kit, and a brain made on a Mac."""
    notes = []
    library = os.path.join(BRAIN, BRAIN_LIBRARY)
    if open(LIBRARY, encoding="utf-8").read() != open(library, encoding="utf-8").read():
        shutil.copy2(LIBRARY, library)
        notes.append(f"copied sign-off-links.md to brain/{BRAIN_LIBRARY}")
    work = tempfile.mkdtemp()
    try:
        scratch = os.path.join(work, "brain")
        copy_brain(scratch, *SENTINEL)
        problems = check(scratch)
        # The indexes the build wrote, with the placeholders back, into brain/.
        for dirpath, _, files in os.walk(scratch):
            if "README.md" not in files or os.sep + ".git" in dirpath:
                continue
            built = unfill(open(os.path.join(dirpath, "README.md"), encoding="utf-8", newline="").read())
            rel = unfill(os.path.relpath(os.path.join(dirpath, "README.md"), scratch))
            mine = os.path.join(BRAIN, rel)
            if os.path.isfile(mine) and open(mine, encoding="utf-8", newline="").read() != built:
                open(mine, "w", encoding="utf-8", newline="").write(built)
                notes.append(f"rebuilt brain/{rel}")
    finally:
        shutil.rmtree(work, ignore_errors=True)
    mac = mac_check(notes)
    problems += mac or []
    for n in notes:
        print(n)
    if problems:
        sys.exit("The kit didn't pass its checks.\n\n" + "\n\n".join(problems))
    print(f"The kit passed its checks ({skill_count()} skills)" + (", and so did a brain made on a Mac." if mac is not None else "."))


def newest_update():
    """The newest brain update in updates/, or 0 if there's none yet."""
    found = [UPDATE_FILE.match(f) for f in os.listdir(UPDATES)] if os.path.isdir(UPDATES) else []
    return max((int(m.group(1)) for m in found if m), default=0)


def zip_kit(out):
    os.makedirs(out, exist_ok=True)
    now = datetime.now(timezone.utc)
    day, iso = f"{now.day} {now:%b %Y}", f"{now:%Y-%m-%d}"
    name = f"brain-kit-{iso}"
    work = tempfile.mkdtemp()
    try:
        brain = os.path.join(work, "brain")
        copy_brain(brain, day, iso)
        # The brain has every update in updates/, so its note says the newest, as the installer writes it.
        n = newest_update()
        if n:
            path = os.path.join(brain, "knowledge", "systems", "brain-updates", "README.md")
            text = open(path, encoding="utf-8", newline="").read()
            text, found = UPDATE_LINE.subn(f"**On kit update:** {n} (in the kit this brain started from, made on {day})", text, count=1)
            if not found:
                sys.exit("The \"**On kit update:**\" line isn't in brain/knowledge/systems/brain-updates/README.md any more; "
                         "change zip_kit here, and New-BrainRepo in install/install-windows.ps1, to match.")
            open(path, "w", encoding="utf-8", newline="").write(text)
        problems = check(brain)
        if problems:
            sys.exit("The kit didn't pass its checks, so there's no zip.\n\n" + "\n\n".join(problems))
        env = dict(os.environ, GIT_AUTHOR_NAME="AnIdeaLab brain kit", GIT_AUTHOR_EMAIL="brain-kit@anidealab.com",
                   GIT_COMMITTER_NAME="AnIdeaLab brain kit", GIT_COMMITTER_EMAIL="brain-kit@anidealab.com")
        run("git", "-C", brain, "commit", "-q", "-m", f"Started this brain from the AnIdeaLab brain kit, {day}", env=env)
        kit = os.path.join(work, name)
        os.makedirs(kit)
        run("git", "-C", brain, "bundle", "create", os.path.join(kit, f"{name}.bundle"), "main")
        test = os.path.join(work, "unpacked")
        run("git", "clone", "-q", "-b", "main", os.path.join(kit, f"{name}.bundle"), test)
        if run("git", "-C", test, "ls-files").stdout != run("git", "-C", brain, "ls-files").stdout:
            sys.exit("The bundle didn't unpack to the same files.")
        shutil.copy2(os.path.join(INSTALL, "install-windows.ps1"), kit)
        shutil.copy2(os.path.join(BRAIN, "skills", "my-pc", "check-setup.ps1"), kit)
        start = fill(open(os.path.join(INSTALL, "START-HERE.txt"), encoding="utf-8").read(), day, iso)
        if ZIP_START[0] not in start:
            sys.exit("install/START-HERE.txt's step 2 isn't the one command any more; change ZIP_START in tools/kit.py to match.")
        open(os.path.join(kit, "START-HERE.txt"), "w", encoding="utf-8", newline="\r\n").write(start.replace(*ZIP_START))
        zpath = os.path.join(out, f"{name}.zip")
        with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
            for f in sorted(os.listdir(kit)):
                z.write(os.path.join(kit, f), f"{name}/{f}")
        print(f"{zpath} ({os.path.getsize(zpath) / 1e6:.1f} MB, {skill_count()} skills)")
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main():
    args = sys.argv[1:]
    if args[:1] == ["build"]:
        return build()
    if args[:1] == ["zip"]:
        return zip_kit(os.path.abspath(args[1] if len(args) > 1 else "."))
    sys.exit(__doc__)


if __name__ == "__main__":
    main()
