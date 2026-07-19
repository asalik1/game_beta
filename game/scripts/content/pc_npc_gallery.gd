# Pixel Crawler asset-extraction pass (2026-07-08) — PLACEHOLDER NPC CONVOS.
#
# TODO(review): one-line placeholder convos for the 9 human sprites wired
# into Maren's Camp (see ch2_hub.gd npcs block). They exist only so the art
# can be reviewed in-game; a later session should give each a real role
# (NPC/quest-giver) or delete both this file and the hub npc entries.
# Human characters are reserved as NPCs (mobs use monster/half-monster art).
#
# No class_name (import-hang trap). Registered via ONE line in
# Story.CONTENT_MODULES.

const _PH := "[Placeholder NPC — Pixel Crawler art, wired 2026-07-08 for review. Give me a role or discard me.]"

const CONVOS := {
	"pc_ph_hunter":     {"start": "a", "nodes": {"a": {"who": "Hunter (placeholder)",       "text": _PH, "next": ""}}},
	"pc_ph_wanderer":   {"start": "a", "nodes": {"a": {"who": "Wanderer (placeholder)",     "text": _PH + " (base body — no outfit yet.)", "next": ""}}},
	"pc_ph_villager_f": {"start": "a", "nodes": {"a": {"who": "Villager (placeholder)",     "text": _PH, "next": ""}}},
	"pc_ph_villager_m": {"start": "a", "nodes": {"a": {"who": "Villager (placeholder)",     "text": _PH, "next": ""}}},
	"pc_ph_elder2":     {"start": "a", "nodes": {"a": {"who": "Elder (placeholder)",        "text": _PH, "next": ""}}},
	"pc_ph_tracker":    {"start": "a", "nodes": {"a": {"who": "Tracker (placeholder)",      "text": _PH + " (reads as a bandit — could be an enemy variant instead.)", "next": ""}}},
	"pc_ph_archer":     {"start": "a", "nodes": {"a": {"who": "Royal Archer (placeholder)", "text": _PH + " (reads as royal guard — could be an enemy variant instead.)", "next": ""}}},
	"pc_ph_scholar_a":  {"start": "a", "nodes": {"a": {"who": "Scholar (placeholder)",      "text": _PH, "next": ""}}},
	"pc_ph_scholar_b":  {"start": "a", "nodes": {"a": {"who": "Scholar (placeholder)",      "text": _PH, "next": ""}}},
	"pc_ph_elder_legacy": {"start": "a", "nodes": {"a": {"who": "Legacy Elder (placeholder)", "text": _PH + " Retired live art; retained for visual comparison only.", "next": ""}}},
}
