#!/usr/bin/env python3
"""Path-scoped commit guard -- the multi-agent commit etiquette, enforced.

A commit sweeps the WHOLE index, and sibling agents stage concurrently
(CLAUDE.md: an itemization pass once got swallowed into a commit labeled
"cover + boot flow" by exactly this race). The standing convention is
path-scoped commits: `git commit -- <your paths>`. This tool wraps it so
the safe way is also the easy way.

Usage:
    python tools/safe_commit.py -m "message" <path> [path ...]
    python tools/safe_commit.py -m "message" --all-staged --confirm
    add --dry-run to preview without committing.

What it does, path-scoped mode:
  1. `git add -- <paths>`      stage YOUR paths (new files included);
                               path-scoped, cannot touch sibling work
  2. shows what will be committed, and what is staged OUTSIDE your paths
     (sibling work -- listed, left alone, NOT committed)
  3. `git commit -m msg -- <paths>`

--all-staged mode (deliberate full-index commit):
  prints everything staged and refuses without --confirm, so "look at
  what's actually staged before committing" is a mechanical step, not a
  memory test. Use when you MEAN to fold sibling work into one commit --
  the message must then describe all of it.

Also refuses attribution trailers (Co-Authored-By etc.) -- this project
keeps commits authorless; credit lives in the credits file.

Reminder: no commits unless the user asked for one (CLAUDE.md).
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

BANNED_IN_MESSAGE = ("co-authored-by", "generated with", "\U0001f916")


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    r = subprocess.run(["git", *args], capture_output=True, text=True, cwd=ROOT)
    if check and r.returncode != 0:
        sys.exit(f"git {' '.join(args)} failed:\n{r.stderr.strip() or r.stdout.strip()}")
    return r


def under(file: str, paths: list[str]) -> bool:
    f = file.replace("\\", "/").rstrip("/")
    for p in paths:
        p = p.replace("\\", "/").rstrip("/")
        if f == p or f.startswith(p + "/"):
            return True
    return False


def main() -> int:
    ap = argparse.ArgumentParser(description="Path-scoped commit guard (multi-agent etiquette)")
    ap.add_argument("-m", "--message", help="commit message")
    ap.add_argument("-F", "--file", help="read the commit message from a file")
    ap.add_argument("paths", nargs="*", help="the paths that are YOURS to commit")
    ap.add_argument("--all-staged", action="store_true",
                    help="commit the whole index instead of path-scoped")
    ap.add_argument("--confirm", action="store_true",
                    help="required with --all-staged, after reviewing the staged list")
    ap.add_argument("--dry-run", action="store_true", help="show everything, commit nothing")
    args = ap.parse_args()

    if args.file:
        msg = Path(args.file).read_text(encoding="utf-8")
    elif args.message:
        msg = args.message
    else:
        ap.error("a commit message is required (-m or -F)")
    low = msg.lower()
    for banned in BANNED_IN_MESSAGE:
        if banned in low:
            sys.exit("REFUSED: message contains an attribution trailer/marker "
                     f"({banned!r}) -- this project keeps commits authorless (CLAUDE.md).")

    if args.all_staged and args.paths:
        ap.error("--all-staged takes no paths -- it commits the whole index")
    if not args.all_staged and not args.paths:
        ap.error("declare your paths (path-scoped commit), or pass --all-staged --confirm "
                 "for a deliberate full-index commit")

    staged = [l for l in git("diff", "--cached", "--name-only").stdout.splitlines() if l.strip()]

    if args.all_staged:
        if not staged:
            sys.exit("nothing is staged.")
        print("FULL-INDEX commit. Everything below lands in it:")
        for f in staged:
            print(f"  {f}")
        if not args.confirm:
            print("\nIf the message describes ALL of the above (including any sibling agent's "
                  "work), re-run with --confirm. If it doesn't, either widen the message or "
                  "commit path-scoped instead.")
            return 1
        if args.dry_run:
            print("\n--dry-run: would run  git commit -m <msg>")
            return 0
        r = git("commit", "-m", msg)
        print(r.stdout.strip())
        return 0

    # ---- path-scoped mode
    if not args.dry_run:  # a dry run must not touch the index
        git("add", "--", *args.paths)
    mine = [l[3:] for l in git("status", "--porcelain", "--", *args.paths).stdout.splitlines()
            if l.strip()]
    if not mine:
        sys.exit("no changes under the declared paths -- nothing to commit.")
    foreign = [f for f in staged if not under(f, args.paths)]

    print("will commit (yours):")
    for f in mine:
        print(f"  {f}")
    if foreign:
        print("staged by someone else, LEFT ALONE (not in this commit):")
        for f in foreign:
            print(f"  {f}")
    if args.dry_run:
        print("\n--dry-run: would run  git commit -m <msg> -- " + " ".join(args.paths))
        return 0
    r = git("commit", "-m", msg, "--", *args.paths)
    print(r.stdout.strip())
    if foreign:
        print("\nnote: the sibling-staged files above are still staged for their owner.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
