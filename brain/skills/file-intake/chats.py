#!/usr/bin/env python3
"""An AI chat export, one Markdown file per chat, ready for intake.py's survey (26 Nov 2026).

ChatGPT's and Claude's exports are a zip with one conversations.json holding every chat, often tens of MB:
one file no agent can read and the survey can't split. This writes each chat to its own file, named by its
date and title, with who said what, so the survey counts them, split.txt can sort them by subject, and the
file list accounts for each chat.

    python3 chats.py <export .zip, folder or conversations.json>... --out <folder>

- ChatGPT (Settings, Data controls, Export data): conversations.json, each chat a tree of messages
  ("mapping"); the branch that was last shown ("current_node") is the one written.
- Claude (Settings, Privacy, Export data): conversations.json, each chat a list ("chat_messages").
- Anything else in the export (Gemini's Google Takeout pages, chat.html, images) isn't touched: survey the
  export's folder too, and convert reads its HTML like any page.

Each file starts with the chat's title, the app, its dates, and "Who's who": "You" is the export's owner and
"Assistant" the AI, so the subject agent keeps their words apart (SKILL.md). Plain Python 3, nothing to install.
"""
import argparse
import datetime
import json
import os
import re
import sys
import zipfile


def when(v):
    if v in (None, ""):
        return ""
    try:
        if isinstance(v, (int, float)):
            return datetime.datetime.fromtimestamp(v, datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
        return datetime.datetime.fromisoformat(str(v).replace("Z", "+00:00")).strftime("%Y-%m-%d %H:%M UTC")
    except (ValueError, OverflowError, OSError):
        return str(v)


def gpt_text(content):
    parts = []
    for p in (content or {}).get("parts") or []:
        if isinstance(p, str):
            parts.append(p)
        elif isinstance(p, dict):
            parts.append(p.get("text") or f"[{p.get('content_type', 'attachment')}]")
    if not parts and (content or {}).get("text"):
        parts.append(content["text"])
    return "\n".join(x for x in parts if x).strip()


def chatgpt(conv):
    mapping = conv.get("mapping") or {}
    node, chain = conv.get("current_node"), []
    while node and node in mapping:
        chain.append(mapping[node])
        node = mapping[node].get("parent")
    out = []
    for n in reversed(chain):
        m = n.get("message") or {}
        role = (m.get("author") or {}).get("role")
        text = gpt_text(m.get("content"))
        if role in ("user", "assistant") and text and not (m.get("metadata") or {}).get("is_visually_hidden_from_conversation"):
            out.append(("You" if role == "user" else "Assistant", when(m.get("create_time")), text))
    return conv.get("title") or "Untitled", conv.get("create_time"), conv.get("update_time"), out


def claude(conv):
    out = []
    for m in conv.get("chat_messages") or []:
        text = (m.get("text") or "").strip()
        if not text:
            text = "\n".join(c.get("text", "") for c in m.get("content") or [] if c.get("type") == "text").strip()
        for a in m.get("attachments") or []:
            text += f"\n\n[attached: {a.get('file_name', 'a file')}]"
        if text:
            out.append(("You" if m.get("sender") == "human" else "Assistant", when(m.get("created_at")), text.strip()))
    return conv.get("name") or "Untitled", conv.get("created_at"), conv.get("updated_at"), out


def loads(path):
    """Yield (source, conversations list) from a zip, a folder or a json file."""
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as z:
            for n in z.namelist():
                if os.path.basename(n) == "conversations.json":
                    yield f"{path}:{n}", json.loads(z.read(n).decode("utf-8"))
    elif os.path.isdir(path):
        for root, _, files in os.walk(path):
            for f in files:
                if f == "conversations.json" or f.endswith(".zip"):
                    yield from loads(os.path.join(root, f))
    elif path.endswith(".json"):
        with open(path, encoding="utf-8") as fh:
            yield path, json.load(fh)


def safe(s):
    return re.sub(r"[^\w\- ]+", "", s).strip()[:60].strip() or "Untitled"


def main():
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    ap = argparse.ArgumentParser(description="An AI chat export, one Markdown file per chat.")
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--out", required=True, help="a folder outside the repo, then survey it")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    total = 0
    for path in args.paths:
        for source, convs in loads(path):
            if not isinstance(convs, list):
                print(f"{source}: not a list of chats, left as it is")
                continue
            app = "ChatGPT" if any("mapping" in c for c in convs[:5]) else "Claude"
            n = 0
            for conv in convs:
                title, start, end, msgs = (chatgpt if app == "ChatGPT" else claude)(conv)
                if not msgs:
                    continue
                day = (when(start) or "undated")[:10]
                name = f"{day} {safe(title)}"
                dest, i = os.path.join(args.out, app, name + ".md"), 2
                while os.path.exists(dest):
                    dest, i = os.path.join(args.out, app, f"{name} ({i}).md"), i + 1
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                lines = [f"# {title}", "", f"- App: {app} (from {os.path.basename(source)})",
                         f"- Started: {when(start) or 'not given'}; last message: {when(end) or 'not given'}",
                         "- Who's who: \"You\" is the export's owner; \"Assistant\" is the AI. Its advice is history, not the owner's decision.", ""]
                for who, at, text in msgs:
                    lines += [f"## {who}" + (f" ({at})" if at else ""), "", text, ""]
                with open(dest, "w", encoding="utf-8") as fh:
                    fh.write("\n".join(lines))
                n += 1
            total += n
            print(f"{source}: {n} {app} chats")
    print(f"{total} chats written under {args.out}. Next: intake.py survey {args.out} --work <work folder>")


if __name__ == "__main__":
    main()
