#!/usr/bin/env python3
"""Checks that every key in this brain's GitHub Actions secrets still answers, and writes the date into the keys table.

Run by the "Check keys" workflow (.github/workflows/check-keys.yml), monthly and by hand, on GitHub's machines.
The workflow hands it every secret as JSON in ALL_SECRETS (toJSON(secrets)); this never prints, saves or sends a
value anywhere but the service the key is for, and it never prints an answer's body (some services echo part of a
key back in an error), only the HTTP status.

The check is only "does it answer": one free, read-only call per key (a "who am I", a verify, a list), the kind
that costs nothing. It doesn't show what a key is allowed to do. That's the "Can do" column, written by the job
that tested it.

How each key is checked: key-checks.json, beside this script, one entry per secret name:
  {"url": "https://...", "auth": "bearer"}           Authorization: Bearer <key> (the default)
  "auth": "token" | "key" | "basic"                  Authorization: Token <key> / Key <key> / Basic (key as user)
  "auth": "header:X-Api-Key"                         the key alone in that header
  "url": [..., ...]                                  tried in order; the first that answers wins
  "headers": {...}                                   more headers to send
  "dead_if": "regex"                                 a 2xx whose body matches is a dead key (some say 200 "login fail")
  "alive_if": "regex"                                a 401 or 403 whose body matches means the key is real
                                                     but not allowed that call
  {"kind": "imap", "host": "...", "user": "..."}    a mailbox password: logs in and out
  {"kind": "google-service-account"}                 a service account's JSON key: swaps it for a token at Google
  {"kind": "github-app", "id_secret": "NAME"}        a GitHub App's private key (base64'd PEM), with its ID in NAME
  {"skip": "why"}                                    nothing to call (an email list, a webhook signing secret,
                                                     half of a pair); shown as "no check" with the reason

  python3 check-keys.py [--note knowledge/systems/keys-and-accounts.md] [--checks key-checks.json]

It edits the note's keys table (between <!-- keys:start --> and <!-- keys:end -->): the "Last check" cell of each
row, by the secret names in its "Secret" cell. Secrets with no row are listed between <!-- keys-new:start --> and
<!-- keys-new:end -->, for an agent to give rows. Plain Python, no packages; openssl for the two signed kinds.
"""

import argparse
import base64
import datetime
import imaplib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
UA = "brain-key-check"


def today():
    """Today in the owner's time zone (routines.md's "Time zone" line), or UTC if it isn't set."""
    tz = datetime.timezone.utc
    try:
        from zoneinfo import ZoneInfo
        with open("knowledge/systems/routines.md", encoding="utf-8") as f:
            m = re.search(r"\*\*Time zone:\*\*\s*([A-Za-z_]+/[A-Za-z_/]+)", f.read())
        if m:
            tz = ZoneInfo(m.group(1))
    except Exception:
        pass
    d = datetime.datetime.now(tz).date()
    return f"{d.day} {d.strftime('%b %Y')}"


def call(url, headers, data=None, method=None):
    req = urllib.request.Request(url, data=data, headers={"User-Agent": UA, "Accept": "application/json", **headers}, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, r.read(20000).decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read(20000).decode("utf-8", "replace")
    except Exception as e:  # network trouble, not the key's fault
        return None, type(e).__name__


def verdict(code, body, spec):
    if code is None:
        return "error", f"couldn't reach it ({body})"
    if 200 <= code < 300:
        if spec.get("dead_if") and re.search(spec["dead_if"], body, re.I):
            return "dead", f"refused ({code}, says the key is bad)"
        return "ok", "answers"
    if code in (401, 403) and spec.get("alive_if") and re.search(spec["alive_if"], body, re.I):
        return "ok", f"answers, but not allowed this call ({code})"
    if code == 403:
        return "ok?", "answers, but not allowed this call (403)"
    if code == 401:
        return "dead", "refused (401)"
    return "error", f"error ({code})"


def check_http(key, spec):
    auth = spec.get("auth", "bearer")
    headers = dict(spec.get("headers", {}))
    if auth == "bearer":
        headers["Authorization"] = f"Bearer {key}"
    elif auth == "token":
        headers["Authorization"] = f"Token {key}"
    elif auth == "key":
        headers["Authorization"] = f"Key {key}"
    elif auth == "basic":
        headers["Authorization"] = "Basic " + base64.b64encode(f"{key}:".encode()).decode()
    elif auth.startswith("header:"):
        headers[auth.split(":", 1)[1]] = key
    urls = spec["url"] if isinstance(spec["url"], list) else [spec["url"]]
    best = None
    for url in urls:
        code, body = call(url, headers)
        best = verdict(code, body, spec)
        if best[0] == "ok":
            break
    return best


def check_imap(key, spec):
    try:
        box = imaplib.IMAP4_SSL(spec["host"], 993, timeout=30)
    except Exception as e:
        return "error", f"couldn't reach {spec['host']} ({type(e).__name__})"
    try:
        box.login(spec["user"], key)
        box.logout()
        return "ok", "answers (logs in)"
    except imaplib.IMAP4.error:
        return "dead", "refused (login failed)"


def b64u(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def rs256(payload, pem):
    head = b64u(json.dumps({"alg": "RS256", "typ": "JWT"}).encode()) + "." + b64u(json.dumps(payload).encode())
    with tempfile.NamedTemporaryFile("w", delete=False, suffix=".pem") as f:
        f.write(pem)
        path = f.name
    try:
        os.chmod(path, 0o600)
        sig = subprocess.run(["openssl", "dgst", "-sha256", "-sign", path], input=head.encode(), capture_output=True, check=True).stdout
    finally:
        os.remove(path)
    return head + "." + b64u(sig)


def check_google_sa(key, spec):
    try:
        info = json.loads(key)
        now = int(time.time())
        jwt = rs256({"iss": info["client_email"], "scope": "https://www.googleapis.com/auth/cloud-platform.read-only",
                     "aud": "https://oauth2.googleapis.com/token", "iat": now, "exp": now + 600}, info["private_key"])
    except Exception as e:
        return "dead", f"not a service account key ({type(e).__name__})"
    data = urllib.parse.urlencode({"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": jwt}).encode()
    code, body = call("https://oauth2.googleapis.com/token", {"Content-Type": "application/x-www-form-urlencoded"}, data, "POST")
    if code == 400 and "invalid_grant" in body:
        return "dead", "refused (Google says invalid_grant: key deleted or account disabled)"
    return verdict(code, body, {})


def check_github_app(key, spec, secrets):
    app_id = secrets.get(spec["id_secret"], "")
    try:
        pem = base64.b64decode(key).decode() if "PRIVATE KEY" not in key else key
        now = int(time.time())
        jwt = rs256({"iat": now - 60, "exp": now + 540, "iss": str(app_id)}, pem)
    except Exception as e:
        return "dead", f"not a private key ({type(e).__name__})"
    code, body = call("https://api.github.com/app", {"Authorization": f"Bearer {jwt}", "Accept": "application/vnd.github+json"})
    return verdict(code, body, {})


def check(name, key, spec, secrets):
    if "skip" in spec:
        return "skip", f"no check: {spec['skip']}"
    kind = spec.get("kind", "http")
    if kind == "imap":
        return check_imap(key, spec)
    if kind == "google-service-account":
        return check_google_sa(key, spec)
    if kind == "github-app":
        return check_github_app(key, spec, secrets)
    return check_http(key, spec)


def update_note(path, results, date):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    m = re.search(r"<!-- keys:start -->\n(.*?)<!-- keys:end -->", text, re.S)
    if not m:
        print(f"{path} has no <!-- keys:start --> table; not updated.")
        return
    lines = m.group(1).split("\n")
    head = [c.strip() for c in lines[0].strip().strip("|").split("|")]
    try:
        si, li = head.index("Secret"), head.index("Last check")
    except ValueError:
        print("The keys table needs 'Secret' and 'Last check' columns; not updated.")
        return
    seen = set()
    for i, line in enumerate(lines[2:], 2):
        if not line.startswith("|"):
            continue
        cells = line.strip().strip("|").split("|")
        names = re.findall(r"`([A-Z0-9_]+)`", cells[si])
        seen.update(names)
        got = [results[n] for n in names if n in results]
        if not names:
            continue
        if not got:
            cells[li] = f" not in the secrets, {date} "
        else:
            real = [g for g in got if g[0] != "skip"] or got
            cells[li] = f" {real[0][1]}, {date} "
        lines[i] = "|" + "|".join(cells) + "|"
    text = text[:m.start(1)] + "\n".join(lines) + text[m.end(1):]
    new = sorted(n for n in results if n not in seen)
    block = "\n".join(f"- `{n}`: {results[n][1]}, {date}" for n in new) or f"- None: every secret has a row ({date})."
    text = re.sub(r"(<!-- keys-new:start -->\n).*?(<!-- keys-new:end -->)", lambda mm: mm.group(1) + block + "\n" + mm.group(2), text, flags=re.S)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--note", default="knowledge/systems/keys-and-accounts.md")
    ap.add_argument("--checks", default=os.path.join(HERE, "key-checks.json"))
    a = ap.parse_args()
    secrets = {k: v for k, v in json.loads(os.environ.get("ALL_SECRETS") or "{}").items() if k.lower() != "github_token"}
    with open(a.checks, encoding="utf-8") as f:
        checks = json.load(f)
    date = today()
    results = {}
    for name in sorted(secrets):
        spec = checks.get(name)
        if spec is None:
            results[name] = ("none", "no check yet: add one to key-checks.json")
        else:
            results[name] = check(name, secrets[name], spec, secrets)
    report = ["| Secret | Result |", "|---|---|"] + [f"| `{n}` | {r[1]} |" for n, r in results.items()]
    for n in sorted(set(checks) - set(secrets)):
        report.append(f"| `{n}` | has a check but isn't in the secrets |")
    out = f"### Keys checked {date}\nOnly \"does it answer\": one free call each, not what a key may do.\n\n" + "\n".join(report) + "\n"
    print(out)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as f:
            f.write(out)
    if os.path.exists(a.note):
        update_note(a.note, results, date)
    return 0


if __name__ == "__main__":
    sys.exit(main())
