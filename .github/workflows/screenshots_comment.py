"""Builds the body of the PR comment that shows the screenshots inline.

Used by screenshots.yml (UI item U15). Not a workflow itself: GitHub only
runs the .yml files in this folder.

Usage:
  python3 screenshots_comment.py <repo> <commit-sha> <pr-head-sha> <changes-file> <out-file>

<changes-file> is the output of
  git diff --name-status <base> <commit> -- 'test/goldens/*.png'
(A = new, M = changed, D = removed; anything not listed is unchanged).
Every PNG in test/goldens/ (not failures/) is listed in the comment.
"""

import os
import sys
from collections import OrderedDict

MARKER = "<!-- screenshots-comment -->"
GOLDENS = "test/goldens"
SIZES = ("phone", "landscape", "laptop")
WIDTHS = {"phone": 160, "landscape": 320, "laptop": 320}
# GitHub refuses comments over 65536 characters; keep well under.
MAX_BODY = 60000


def parse(name):
    """'home_loaded-320_phone.png' -> ('home', 'loaded-320', 'phone')."""
    stem = name[:-4]
    parts = stem.split("_")
    if len(parts) >= 3 and parts[-1] in SIZES:
        return parts[0], "_".join(parts[1:-1]), parts[-1]
    if len(parts) == 2 and parts[-1] in SIZES:
        return parts[0], "", parts[-1]
    return parts[0], "_".join(parts[1:]), ""


def read_changes(path):
    changes = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            bits = line.rstrip("\n").split("\t")
            if len(bits) < 2:
                continue
            status, file = bits[0][:1], bits[-1]
            changes[os.path.basename(file)] = status
    return changes


def build(repo, sha, head_sha, changes, files, compact=False):
    def blob(name):
        return f"https://github.com/{repo}/blob/{sha}/{GOLDENS}/{name}"

    def cell(name, size):
        if name is None:
            return ""
        label = {"A": " (new)", "M": " (changed)"}.get(changes.get(name), "")
        if compact:
            return f"[{size}{label}]({blob(name)})"
        return (
            f'<a href="{blob(name)}"><img src="{blob(name)}?raw=true" '
            f'width="{WIDTHS.get(size, 320)}" alt="{name}"></a>{label}'
        )

    # screen -> state -> size -> file name, in name order.
    screens = OrderedDict()
    for name in sorted(files):
        screen, state, size = parse(name)
        screens.setdefault(screen, OrderedDict()).setdefault(state, {})[
            size or "other"
        ] = name

    def table(states):
        cols = [s for s in SIZES if any(s in v for v in states.values())]
        if any("other" in v for v in states.values()):
            cols.append("other")
        rows = ["| State | " + " | ".join(c.capitalize() for c in cols) + " |",
                "|---|" + "---|" * len(cols)]
        for state, by_size in states.items():
            rows.append(
                f"| {state or '–'} | "
                + " | ".join(cell(by_size.get(c), c) for c in cols)
                + " |"
            )
        return "\n".join(rows)

    def touched(states):
        return any(changes.get(n) in ("A", "M")
                   for v in states.values() for n in v.values())

    new = sum(1 for n in files if changes.get(n) == "A")
    changed = sum(1 for n in files if changes.get(n) == "M")
    removed = sorted(n for n, s in changes.items() if s == "D")
    total = len(files)

    out = [MARKER, "## Screenshots", ""]
    out.append(
        f"Rendered for commit `{head_sha[:7]}`: {total} screenshots, "
        f"{new} new and {changed} changed compared with the base branch. "
        "Tap an image to open it full size."
    )
    if compact:
        out.append("")
        out.append("_Too many to show inline, so these are links._")
    out.append("")

    changed_screens = [(s, st) for s, st in screens.items() if touched(st)]
    other_screens = [(s, st) for s, st in screens.items() if not touched(st)]

    if changed_screens:
        out.append("### New or changed")
        out.append("")
        for screen, states in changed_screens:
            out.append(f"#### {screen}")
            out.append("")
            out.append(table(states))
            out.append("")
    else:
        out.append("No screenshot is new or changed in this PR.")
        out.append("")

    if removed:
        out.append("### Removed")
        out.append("")
        out.append(", ".join(f"`{n}`" for n in removed))
        out.append("")

    if other_screens:
        out.append("### Unchanged")
        out.append("")
        for screen, states in other_screens:
            out.append(f"<details><summary>{screen}</summary>")
            out.append("")
            out.append(table(states))
            out.append("")
            out.append("</details>")
            out.append("")

    out.append("_Posted by the screenshots workflow; updated on every push._")
    return "\n".join(out) + "\n"


def main():
    repo, sha, head_sha, changes_path, out_path = sys.argv[1:6]
    files = [
        n for n in os.listdir(GOLDENS)
        if n.endswith(".png") and os.path.isfile(os.path.join(GOLDENS, n))
    ]
    changes = read_changes(changes_path)
    body = build(repo, sha, head_sha, changes, files)
    if len(body) > MAX_BODY:
        body = build(repo, sha, head_sha, changes, files, compact=True)
    if len(body) > MAX_BODY:
        body = body[: MAX_BODY - 200] + "\n\n_…cut short: too many screenshots._\n"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(body)


if __name__ == "__main__":
    main()
