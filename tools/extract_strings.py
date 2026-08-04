#!/usr/bin/env python3
"""Extract user-visible English UI strings from the Ollama desktop app source.

Scans:
  1. Frontend: upstream/app/ui/app/src/**/*.tsx *.ts
     - JSX text nodes
     - placeholder / title / aria-label attributes
     - window.confirm(...) and window.menu([{label: ...}]) calls
     - new ErrorEvent({ error: "...", message: "..." }) style literals
  2. Go backend: upstream/app/**/*.go
     - string literals passed to known UI functions (menu labels, dialog titles)
"""
import os, re, sys, json

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "upstream")
OUT = []

def add(f, line, s):
    s = s.strip()
    if not s or len(s) < 2:
        return
    # skip pure-code / non-text strings
    if re.fullmatch(r"[a-zA-Z0-9_\-\./\s]+", s):
        # keep readable english sentences/phrases (has a space and a lowercase word)
        pass
    OUT.append((f, line, s))

def scan_tsx(f):
    with open(f, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().splitlines()
    for i, line in enumerate(lines, 1):
        # JSX text nodes: text between > and < (may span, keep simple single-line)
        for m in re.finditer(r">([^<>{}]{2,120})<", line):
            t = m.group(1)
            if re.search(r"[a-zA-Z]{3,}", t) and not re.match(r"^\s*(/|\w+:|\d)", t):
                add(f, i, t)
        # attributes with visible text
        for m in re.finditer(r'(placeholder|title|aria-label)\s*=\s*"([^"]{2,120})"', line):
            add(f, i, m.group(2))
        # window.confirm / menu labels / setMessage text
        for m in re.finditer(r'(confirm|label)\s*:\s*"([^"]{2,120})"', line):
            add(f, i, m.group(2))
        for m in re.finditer(r'window\.confirm\(`([^`]{2,160})`', line):
            add(f, i, m.group(1))
        for m in re.finditer(r'(error|message|title|details)\s*:\s*"([^"]{3,160})"', line):
            add(f, i, m.group(2))
        for m in re.finditer(r'[=:]\s*"([A-Z][^"]{3,100})"', line):
            t = m.group(1)
            if re.search(r"[a-z]{3,}", t) and not re.search(r"[{}<>&]", t):
                add(f, i, t)

def scan_go(f):
    with open(f, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().splitlines()
    for i, line in enumerate(lines, 1):
        for m in re.finditer(r'"((?:[^"\\]|\\.){3,140})"', line):
            t = m.group(1)
            if re.search(r"[a-z]{3,}", t) and re.search(r"\s", t):
                add(f, i, t)

files_tsx = []
for dirpath, _, filenames in os.walk(os.path.join(ROOT, "app", "ui", "app", "src")):
    for fn in filenames:
        if fn.endswith((".tsx", ".ts")) and not fn.endswith((".gen.ts", ".stories.tsx", ".test.tsx", ".test.ts", "vite-env.d.ts")):
            files_tsx.append(os.path.join(dirpath, fn))

files_go = []
for dirpath, _, filenames in os.walk(os.path.join(ROOT, "app")):
    for fn in filenames:
        if fn.endswith(".go") and not fn.endswith("_test.go"):
            files_go.append(os.path.join(dirpath, fn))

for f in sorted(files_tsx):
    scan_tsx(f)
for f in sorted(files_go):
    scan_go(f)

seen = {}
for f, line, s in OUT:
    rel = os.path.relpath(f, ROOT).replace("\\", "/")
    seen.setdefault(s, []).append(f"{rel}:{line}")

for s in sorted(seen):
    print(f"{s}\t{' | '.join(seen[s][:3])}")
