#!/usr/bin/env python3
"""Which computer is this session on, and which of the brain's computers are on right now.

The brain's computers are the rows of the table in knowledge/systems/devices.md: the one whose
header has "Runner" and "Spot it". "Runner" is the label of the computer's GitHub Actions
self-hosted runner (a dash if it has none); "Spot it" holds, in backticks, the names that tell
this computer apart: its host name as Python's socket.gethostname() gives it (a Mac's ".local"
is ignored), or `cloud` for a cloud session (Claude Code on the web sets CLAUDE_CODE_REMOTE).

  python3 skills/brain-spec/devices.py here      which computer this is (the session-start
                                                 script prints it, in one line)
  python3 skills/brain-spec/devices.py status    which computers are on now: about a minute
  python3 skills/brain-spec/devices.py list      the table as this script reads it

How "status" works, with no key of its own: it starts the "Which devices are on" workflow
(.github/workflows/devices.yml) once per runner, as a tiny job on that runner that prints what
the computer has. A computer that's on picks its job up within seconds. After --wait seconds
(60 by default) any job still queued is cancelled, so nothing is left waiting for a computer
that's off. A runner already running another job is reported as on and busy, with that job's
name, from the jobs GitHub lists as in progress. Outside GitHub it calls GitHub through the
gh command line; inside a GitHub Actions job (the workflow's "check" mode, for an agent with
only a run-workflow tool) through the job's own GITHUB_TOKEN. The self-hosted jobs cost no
Actions minutes; the check mode costs one or two of GitHub's minutes each time.

Standard library only, Python 3.9 or newer, so it runs on any computer the brain uses.
"""
import json
import os
import platform
import re
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))  # skills/brain-spec/ is two folders down
NOTE = os.path.join(ROOT, "knowledge", "systems", "devices.md")
NOTE_REL = "knowledge/systems/devices.md"
WORKFLOW = "devices.yml"
PING_TITLE = "Devices: ping {}"
NONE = {"", "-", "—", "–", "none", "n/a"}


# ---------- the table ----------

def plain(cell):
    """A cell's text without links, bold or code marks."""
    cell = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", cell)
    return re.sub(r"[*`_]", "", cell).strip()


def ticked(cell):
    """The names in backticks in a cell; the plain words if there are none."""
    names = re.findall(r"`([^`]+)`", cell)
    if not names and plain(cell).lower() not in NONE:
        names = [w for w in re.split(r"[,\s]+", plain(cell)) if w]
    return [n.strip() for n in names if n.strip().lower() not in NONE]


def read_devices(path=NOTE):
    """The rows of the devices table, as dicts with name, runners, spot and the row's other cells."""
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError:
        return None
    rows, header = [], None
    for line in lines:
        s = line.strip()
        if not s.startswith("|"):
            if header and rows:
                break  # the table has ended
            header = None if not s else header
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if header is None:
            low = [plain(c).lower() for c in cells]
            if "runner" in low and any(c.startswith("spot") for c in low):
                header = low
            continue
        if all(set(c) <= set("-: ") for c in cells):
            continue  # the |---|---| line
        row = dict(zip(header, cells))
        rows.append({
            "name": plain(cells[0]),
            "runners": ticked(row.get("runner", "")),
            "spot": [n.lower() for n in ticked(next((v for k, v in row.items() if k.startswith("spot")), ""))],
            "cells": row,
        })
    return rows


# ---------- here ----------

def short_host(name):
    return name.strip().lower().split(".")[0]


def os_words():
    system = platform.system()
    if system == "Darwin":
        return f"macOS {platform.mac_ver()[0] or platform.release()} ({platform.machine()})"
    if system == "Windows":
        return f"Windows {platform.release()} ({platform.version()}, {platform.machine()})"
    if system == "Linux":
        try:
            with open("/etc/os-release", encoding="utf-8") as f:
                m = re.search(r'^PRETTY_NAME="?([^"\n]*)', f.read(), re.M)
            if m:
                return f"{m.group(1)} ({platform.machine()})"
        except OSError:
            pass
        return f"Linux {platform.release()} ({platform.machine()})"
    return f"{system} {platform.release()}"


def here(brief=False):
    rows = read_devices()
    host = socket.gethostname()
    cloud = os.environ.get("CLAUDE_CODE_REMOTE", "").lower() == "true"
    check = "python3 skills/brain-spec/devices.py status"
    if os.environ.get("GITHUB_ACTIONS") == "true":
        runner = os.environ.get("RUNNER_NAME", "?")
        return f"Device: a GitHub Actions job on the runner {runner} ({os_words()}, {host})."
    if rows is None:
        return (f"Device: {os_words()}, named {host}" + (", a cloud session" if cloud else "") +
                f". This brain has no {NOTE_REL} yet to say what that means.")
    key = "cloud" if cloud else short_host(host)
    match = next((r for r in rows if key in [short_host(s) for s in r["spot"]]), None)
    if match and cloud:
        return (f"Device: a cloud session ({os_words()}), not one of the brain's own computers: "
                f"it can reach them only through their runners. Which are on now: {check} (about a minute). "
                f"Every device, how to reach it and when it's on: {NOTE_REL}.")
    if match:
        line = (f"Device: you're on {match['name']} ({os_words()}, {host}), in {os.getcwd()}. "
                f"What it can do, and the brain's other computers: {NOTE_REL}.")
        return line if brief else line + f" Which are on now: {check}."
    if cloud:
        return (f"Device: a cloud session ({os_words()}), and {NOTE_REL} has no `cloud` row yet. "
                f"Add one (brain-spec, \"Devices\").")
    return (f"Device: this computer isn't in {NOTE_REL} yet: {os_words()}, named {host}, user "
            f"{os.environ.get('USER') or os.environ.get('USERNAME') or '?'}. Add its row (brain-spec, \"Devices\"), "
            f"asking the owner what it is if that isn't clear.")


# ---------- talking to GitHub ----------

def find_repo():
    if os.environ.get("GITHUB_REPOSITORY"):
        return os.environ["GITHUB_REPOSITORY"]
    try:
        url = subprocess.run(["git", "-C", ROOT, "remote", "get-url", "origin"],
                             capture_output=True, text=True, timeout=10).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        url = ""
    m = re.search(r"(?:github\.com[:/]|/git/)([^/]+/[^/]+?)(?:\.git)?/?$", url)
    return m.group(1) if m else None


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


class GitHub:
    """GitHub's REST API, through GITHUB_TOKEN inside Actions, or the gh command line elsewhere."""

    def __init__(self, repo):
        self.repo = repo
        self.token = os.environ.get("GITHUB_TOKEN") if os.environ.get("GITHUB_ACTIONS") == "true" else None

    def call(self, method, path, body=None, raw=False):
        path = f"repos/{self.repo}/{path}"
        if self.token:
            return self._http(method, path, body, raw)
        cmd = ["gh", "api", "-X", method, path]
        if body is not None:
            cmd += ["--input", "-"]
        r = subprocess.run(cmd, input=json.dumps(body) if body is not None else None,
                           capture_output=True, text=True, timeout=60)
        if r.returncode != 0:
            raise RuntimeError(f"gh api {method} {path}: {(r.stderr or r.stdout).strip()[:300]}")
        if raw:
            return r.stdout
        return json.loads(r.stdout) if r.stdout.strip() else {}

    def _http(self, method, path, body, raw):
        req = urllib.request.Request(
            f"https://api.github.com/{path}", method=method,
            data=json.dumps(body).encode() if body is not None else None,
            headers={"Authorization": f"Bearer {self.token}", "Accept": "application/vnd.github+json",
                     "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "brain-devices"})
        opener = urllib.request.build_opener(NoRedirect)
        try:
            with opener.open(req, timeout=60) as resp:
                data = resp.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            if e.code in (301, 302, 303, 307, 308) and e.headers.get("Location"):
                # a job's log: a short-lived link to storage, fetched without the token
                with urllib.request.urlopen(e.headers["Location"], timeout=60) as resp:
                    return resp.read().decode("utf-8", "replace")
            raise RuntimeError(f"GitHub {method} {path}: {e.code} {e.read().decode('utf-8', 'replace')[:300]}")
        if raw:
            return data
        return json.loads(data) if data.strip() else {}


def when(text):
    return datetime.fromisoformat(text.replace("Z", "+00:00")) if text else None


# ---------- status ----------

def jobs_now(gh):
    """{label: [(state, run title, started), ...]} for every job in progress or waiting, by runner label."""
    out = {}
    for state in ("in_progress", "queued"):
        runs = gh.call("GET", f"actions/runs?status={state}&per_page=30").get("workflow_runs", [])
        for run in runs:
            if run.get("name", "").startswith(PING_TITLE.format("")):
                continue  # an earlier check's ping
            for job in gh.call("GET", f"actions/runs/{run['id']}/jobs?per_page=30").get("jobs", []):
                if job.get("status") not in ("in_progress", "queued"):
                    continue
                for label in job.get("labels", []):
                    out.setdefault(label, []).append((job["status"], run.get("name", ""), job.get("started_at")))
    return out


def facts_from_log(text):
    """The DEVICE lines the ping job printed, outside the log's groups (which echo the script itself)."""
    facts, in_group = [], False
    for line in text.splitlines():
        line = re.sub(r"^﻿?\d{4}-\d\d-\d\dT[\d:.]+Z ", "", line)
        if line.startswith("##[group]"):
            in_group = True
        elif line.startswith("##[endgroup]"):
            in_group = False
        elif not in_group:
            m = re.match(r"\s*DEVICE (\w+): (.*)$", line)
            if m and m.group(2).strip():
                facts.append((m.group(1), m.group(2).strip()))
    return facts


def status(wait=60, ref="main"):
    rows = read_devices()
    if rows is None:
        print(f"No {NOTE_REL} in this brain, so there are no computers to check.")
        return 1
    targets = [(r["name"], label) for r in rows for label in r["runners"]]
    if not targets:
        print(f"No computer in {NOTE_REL} has a runner yet, so none can be checked. A cloud session is always on.")
        return 0
    repo = find_repo()
    if not repo:
        print("Couldn't tell which GitHub repo this brain is (no GITHUB_REPOSITORY, and git's origin isn't GitHub).")
        return 1
    gh = GitHub(repo)
    busy = jobs_now(gh)
    started = datetime.now(timezone.utc).replace(microsecond=0)
    for _, label in targets:
        gh.call("POST", f"actions/workflows/{WORKFLOW}/dispatches", {"ref": ref, "inputs": {"label": label}})
    print(f"Pinging {', '.join(l for _, l in targets)}; waiting up to {wait} s for each to answer...", flush=True)
    found = {}
    deadline = time.time() + wait
    while True:
        runs = gh.call("GET", f"actions/workflows/{WORKFLOW}/runs?event=workflow_dispatch&per_page=50").get("workflow_runs", [])
        for _, label in targets:
            for run in runs:  # newest first
                created = when(run.get("created_at"))
                if run.get("name") == PING_TITLE.format(label) and created and (created - started).total_seconds() > -15:
                    found[label] = run  # this check's ping, not an earlier one's
                    break
        done = [l for _, l in targets if l in found and found[l].get("status") == "completed"]
        if len(done) == len(targets) or time.time() > deadline:
            break
        time.sleep(5)

    lines = ["| Device | Runner | Now | What it reported |", "|---|---|---|---|"]
    for name, label in targets:
        run = found.get(label)
        jobs = busy.get(label, [])
        running = [j for j in jobs if j[0] == "in_progress"]
        waiting = [j for j in jobs if j[0] == "queued"]
        details = ""
        if run and run.get("status") == "completed" and run.get("conclusion") == "success":
            took = (when(run.get("updated_at")) - when(run.get("created_at"))).total_seconds()
            now = f"**on**, answered in {took:.0f} s"
            try:
                job = gh.call("GET", f"actions/runs/{run['id']}/jobs").get("jobs", [{}])[0]
                facts = facts_from_log(gh.call("GET", f"actions/jobs/{job['id']}/logs", raw=True))
                details = "; ".join(f"{k}: {v}" for k, v in facts)
            except (RuntimeError, IndexError, KeyError) as e:
                details = f"(couldn't read its log: {str(e)[:120]})"
        elif run and run.get("status") == "completed":
            now = f"answered, but its job ended {run.get('conclusion')}"
            details = run.get("html_url", "")
        elif run and run.get("status") == "in_progress":
            now = "**on**, its job started but hadn't finished"
            details = run.get("html_url", "")
        else:
            if run:
                try:
                    gh.call("POST", f"actions/runs/{run['id']}/cancel")
                except RuntimeError:
                    pass
            if running:
                title, since = running[0][1], running[0][2]
                now = f"**on, busy**: running \"{title[:80]}\"" + (f" since {since[11:16]} UTC" if since else "")
                if waiting:
                    now += f", {len(waiting)} more waiting"
            else:
                now = "**off or not answering**: asleep, off, logged out (a login runner), or its runner stopped"
                if waiting:
                    now += f"; {len(waiting)} job(s) waiting for it"
        lines.append(f"| {name} | `{label}` | {now} | {details.replace('|', '/')} |")
    stamp = datetime.now(timezone.utc).strftime("%d %b %Y %H:%M UTC")
    out = f"Devices, {stamp} (from {NOTE_REL}):\n\n" + "\n".join(lines)
    print(out)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(out + "\n")
    return 0


def main(argv):
    args = argv[1:] or ["here"]
    cmd = args[0]
    if cmd == "here":
        print(here(brief="--brief" in args))
        return 0
    if cmd == "list":
        for r in read_devices() or []:
            print(f"{r['name']}: runner {', '.join(r['runners']) or '-'}; spot it by {', '.join(r['spot']) or '-'}")
        return 0
    if cmd == "status":
        wait = 60
        if "--wait" in args:
            wait = int(args[args.index("--wait") + 1])
        ref = args[args.index("--ref") + 1] if "--ref" in args else "main"
        try:
            return status(wait, ref)
        except RuntimeError as e:
            print(f"The check couldn't talk to GitHub: {e}\nInstead, start the workflow \"Which devices are on\" "
                  f"({WORKFLOW}) on main with the label left empty, and read its log.")
            return 1
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
