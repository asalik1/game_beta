"""Shared paths for the prop STYLE-UNIFY lane (tools/art/style_unify/).
Everything is repo-relative so the scripts run from any checkout/worktree."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SPR = os.path.join(REPO, "game", "assets", "sprites")
TOOLS_ART = os.path.join(HERE, "..")


def stage_root(default_name: str) -> str:
    """Stage dirs live OUTSIDE the repo (a scratchpad): STYLE_UNIFY_STAGES env
    var, else <repo>/../style_unify_stages/<default_name>."""
    base = os.environ.get("STYLE_UNIFY_STAGES") or os.path.join(REPO, "..", "style_unify_stages")
    return os.path.abspath(os.path.join(base, default_name))
