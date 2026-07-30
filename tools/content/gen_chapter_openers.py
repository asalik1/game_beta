#!/usr/bin/env python3
"""Generate the chapter-opener content module from PROPOSALS/CHAPTER_OPENERS.md.

The proposal is deliberately the prose source of truth. This generator keeps
the 78 class-reflected choices, resonance shifts, and flags from drifting when
the document is edited. It emits ordinary content-module data; the game never
parses Markdown at runtime.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "PROPOSALS" / "CHAPTER_OPENERS.md"
OUTPUT = ROOT / "game" / "scripts" / "content" / "chapter_openers.gd"

CLASSES = ("warrior", "assassin", "mage", "archer", "paladin", "warlock")
CLASS_RE = "Warrior|Assassin|Mage|Archer|Paladin|Warlock"
CUES = {
    "ch2": "shatter",
    "ch3": "vale",
    "ch4": "foundry",
    "ch5": "sledge",
    "ch6": "bloom",
    "ch7": "relay",
    "ch8": "ashfall",
    "ch9": "drowned",
    "ch10": "singing_ice",
    "ch11": "two_fires",
    "ch12": "roothold",
    "ch13": "storm_scar",
    "ch14": "convergence",
}
TRAVEL_HOOKS = {
    "ch2": "The road bends toward Maren's Camp. The Waking is waiting there.",
    "ch3": "East: the Vigil Gate, the endless procession, and Saint Varo's hill.",
    "ch4": "South: the Cinder Gate. The foundries do not bank their fires.",
    "ch5": "North: the Last Fire, where the ice keeps what the living cannot.",
    "ch6": "The plank road enters the Pilgrim Gate. Everything beyond it grows.",
    "ch7": "Upward: Summit Camp, the relay, and the sky coming apart.",
    "ch8": "Ash falls on the foundry city. Somewhere below it, the Judge is awake.",
    "ch9": "Green water covers the old southern gate. The drowned streets wait below.",
    "ch10": "The crystal shelf is singing. Elara sleeps beneath every note.",
    "ch11": "Two armies light their fires. The road between them belongs to refugees.",
    "ch12": "The map ends at the treeline. The country beyond has five hearts.",
    "ch13": "The weather tears open ahead. Three voices are still holding its corners.",
    "ch14": "The old capital opens before you. The first throne waits at the last road.",
}
# The n4 prompt per chapter — transcribed from the doc's "The asker (n4)" /
# "The trigger + n4 (INTERNAL)" blocks (§1 two-prompt-modes rule). PUBLIC
# chapters: a Narrator setup node stages the asker, then the asker speaks the
# prompt. INTERNAL chapters (ch2/5/9/10/13): who is "You", the text is the
# deliberation trigger, and the doc's CAPS temptation options carry the vice's
# voice. Update these WITH the doc blocks — never invent a stem.
ASKERS = {
    "ch2": {
        "who": "You",
        "text": "\"I got mine in the spring,\" says the stranger across the fire, shard-glow still fresh under their wrist. \"You've had yours a while, haven't you. …How did you carry it?\" You look into the fire instead of answering. The shard was there for all of it — and it has an account of its own, ready.",
    },
    "ch3": {
        "who": "Gate-Cantor",
        "setup": "At the gate, the counting-cantor looks up from her ledger as the procession shuffles past.",
        "text": "State your business with the unburied, pilgrim.",
    },
    "ch4": {
        "who": "Crew-Boss",
        "setup": "At the furnace corridor's mouth a crew-boss blocks your way, her roped crew filing past behind her.",
        "text": "You're not signed. So what's a foundry to you, stranger?",
    },
    "ch5": {
        "who": "You",
        "text": "At the sledge line a Long Sleep sister offers the open ledger and the pen, and says nothing at all. The pen hangs there. The deliberation is yours — and the shard gets a word in.",
    },
    "ch6": {
        "who": "Glad-Eyed Kneeler",
        "setup": "At the gate a kneeler catches your sleeve — glad-eyed, mud to the knees, utterly at peace.",
        "text": "It gives, stranger. It only ever gives. Will you not take?",
    },
    "ch7": {
        "who": "Apprentice Sorrel",
        "setup": "Apprentice Sorrel falls in step beside you on the summit road.",
        "text": "Everyone up there asks about the drake. Nobody asks about the SENTENCE. What are words, to you?",
    },
    "ch8": {
        "who": "Journeyman Smith",
        "setup": "At the defectors' cold fire, a journeyman who walked out mid-indenture feeds the embers one splinter at a time.",
        "text": "Going in, then. To cool it, to copy it, or just to kill it — which?",
    },
    "ch9": {
        "who": "You",
        "text": "The cure-seekers' map-runner shows you a chart the city corrected overnight, then wades off to re-survey. You stand at the waterline holding the wrong map. Below is a god that talks. The shard has opinions about gods that talk.",
    },
    "ch10": {
        "who": "You",
        "text": "The singer barring the shaft mouth breaks off mid-hymn: \"If you go down to her — go down carrying WHAT?\" You push past without answering. The answer happens on the long climb down, in the blue dark, where the shard's voice carries best.",
    },
    "ch11": {
        "who": "Refugee",
        "setup": "On the road between the armies, a man with his front door on his back passes you without stopping.",
        "text": "Two armies, both right. Where will you be standing when they stop being polite about it?",
    },
    "ch12": {
        "who": "Wildfang Scout",
        "setup": "At the treeline a Wildfang scout hammers in a warning-post — the third replacement this month.",
        "text": "Signs don't hold it. What is YOUR answer to a land that will not die?",
    },
    "ch13": {
        "who": "You",
        "text": "The youngest of the three speakers, hoarse between recitations, asks what a name is in your hands. You open your mouth to answer — and realize you have been mouthing storm-words all morning without choosing to. Some of the voice below is yours. Some is not.",
    },
    "ch14": {
        "who": "Elara",
        "setup": "At the causeway's foot a girl of fifteen stands her ground — awake, steady, watching the god pass.",
        "text": "That is my mother's walk it is wearing. When you reach the throne — what did you come for?",
    },
}

# Post-choice reply beats, chapter-flavored and stance-true (generator glue,
# same category as TRAVEL_HOOKS — the scene answers, never a generic Ember).
REPLIES = {
    "ch2": {
        "virtue": "The fire spits. Across it, the stranger nods slowly, as if you had answered a harder question than the one they asked.",
        "temptation": "The shard settles, satisfied — a ledger initialed. Across the fire, the stranger looks away first.",
        "deflection": "The shard says nothing. It has waited years; it can wait one chapter more.",
    },
    "ch3": {
        "virtue": "The cantor holds your gaze a moment, then inks a mark that is not a number in her ledger.",
        "temptation": "The cantor's pen pauses. \"The saint draws your kind,\" she says, and it is not a compliment.",
        "deflection": "The cantor waves you through. The procession does not look up.",
    },
    "ch4": {
        "virtue": "The crew-boss studies you, then steps aside. \"Crews first,\" she repeats, like a coin she is testing with her teeth.",
        "temptation": "\"Then you'll fit right in below,\" the crew-boss says, and does not smile.",
        "deflection": "The crew-boss shrugs and turns back to her rope-line. Strangers' business is strangers' business.",
    },
    "ch5": {
        "virtue": "You hand back the pen. The sister's face does not change — but she writes nothing, and that is its own entry.",
        "temptation": "The pen goes back untouched. The shard hums the sister's silence all the way up the ice.",
        "deflection": "You leave the ledger open to the wind. Let the snow sign it.",
    },
    "ch6": {
        "virtue": "The kneeler lets go of your sleeve, puzzled. Refusal is the one gift the green never taught them to read.",
        "temptation": "The kneeler beams and turns back to the light. Somewhere under the moss, something files your answer.",
        "deflection": "The kneeler recoils as if scorched. The green closes gently over the place your shadow fell.",
    },
    "ch7": {
        "virtue": "Sorrel nods hard, twice — a girl keeping a tally she has been keeping alone too long.",
        "temptation": "Sorrel stops walking. You are three steps gone before she follows, further behind than before.",
        "deflection": "\"The drake. Right.\" Sorrel's voice does the thing voices do when they stop expecting.",
    },
    "ch8": {
        "virtue": "The journeyman feeds the fire another splinter. \"Cool it, then. Some of us would like our hands back.\"",
        "temptation": "The journeyman looks at you the way a man looks at his own old mistake wearing new boots.",
        "deflection": "\"Kill it, then.\" The journeyman turns back to the cold fire — one job's honest, at least.",
    },
    "ch9": {
        "virtue": "The wrong map folds easier than the right one would have. Wire first. Roots after.",
        "temptation": "Below the waterline, something adjusts its terms. The shard calls it progress.",
        "deflection": "You leave the map on a piling for the next fool. The water is already correcting it.",
    },
    "ch10": {
        "virtue": "The climb feels shorter with your answer decided. Behind you, the singer resumes the hymn — a note higher, as if relieved.",
        "temptation": "The shard goes quiet the way a blade goes quiet in a sheath. The blue dark says nothing either.",
        "deflection": "Above you the hymn falters, then holds. The cult will keep. The ice will not.",
    },
    "ch11": {
        "virtue": "The refugee does not stop — but he shifts the door on his back, as if making room on the road beside him.",
        "temptation": "The refugee spits, hitches the door higher, and walks faster. Receipts warm no one.",
        "deflection": "The refugee nods once — the tired nod of a man who has heard every answer and carried his door through all of them.",
    },
    "ch12": {
        "virtue": "The scout stops hammering. \"An ending.\" She tries the word like a foreign coin, then pockets it.",
        "temptation": "The scout's hammer stops mid-swing. She looks at you the way her elders look at the green.",
        "deflection": "The scout drives the post the rest of the way down. \"Border it is. I'll cut more signs.\"",
    },
    "ch13": {
        "virtue": "The young speaker exhales — half the weight of a god-sized sentence sliding onto readier shoulders.",
        "temptation": "The wind drops. Out on the plain, one loose word changes direction — toward you.",
        "deflection": "The young speaker turns back to the recitation. Ammunition, then. The storm prices it the same.",
    },
    "ch14": {
        "virtue": "Elara steps out of your way. \"Then bring her back out,\" she says — an order, from a girl of fifteen, and you take it.",
        "temptation": "Elara does not move. You walk around her. Her eyes follow you the way ice follows heat.",
        "deflection": "Elara looks at the throne a long moment. \"Good,\" she says. \"Break everything.\" And steps aside.",
    },
}

# Spine flag-variants — the doc's italic "*(flag variants …)*" bullets, which
# the Markdown parser deliberately skips. Each entry APPENDS a line to the
# node's base text for the flagged players; per-class overrides carry the
# ch6_answered_green deed rule (warrior LOOSED, archer ASKED — they never
# pocket a cutting).
SPINE_VARIANTS = {
    "ch8": {"n2": [
        {"flag": "joined_cinderborn", "append": {"default": "These are YOUR people's fires. That is either a reason to look away or the only reason to look closely."}},
        {"flag": "joined_accord", "append": {"default": "Your writ says infiltrate. The ash does not care whose seal is on your papers."}},
    ]},
    "ch9": {"n1": [
        {"flag": "ch6_answered_green", "append": {
            "default": "The cutting in your pack turned over in the night. It is pointing at the city like a compass needle.",
            "warrior": "What you loosed in the green has been restless all night. It knows this city.",
            "archer": "What you asked the green has been growing an answer. It is ahead of you now.",
        }},
    ]},
    "ch10": {"n2": [
        {"flag": "ch5_vowed_morning", "append": {"default": "You promised the north a real morning once. She is what the promise looks like now."}},
        {"flag": "ch5_felt_pull", "append": {"default": "The hush you leaned toward under the ice — it has a name now, and the name is a child's."}},
    ]},
    "ch12": {"n2": [
        {"flag": "ch6_answered_green", "append": {
            "default": "The cutting you took in the Deep is heavier every day now. It is not growing. It is REPORTING.",
            "warrior": "What you loosed in the Deep went quiet a day's march out. The Roothold heard you coming.",
            "archer": "What you asked the green in the Deep — the Roothold has been growing the answer ever since. It is the size of a country now.",
        }},
    ]},
    "ch13": {"n2": [
        {"flag": "ch7_would_speak", "append": {"default": "You said once that some sentences deserve finishing. The plain ahead is where you find out if you meant it."}},
        {"flag": "ch7_let_it_end", "append": {"default": "You wanted to hear the world unmuzzled. Listen, then. It is saying something."}},
    ]},
}


def clean(text: str) -> str:
    value = text.strip().replace("**", "").replace("`", "")
    if value.startswith('"') and value.endswith('"'):
        value = value[1:-1]
    return value.strip()


def continuation(lines: list[str], start: int, initial: str) -> tuple[str, int]:
    parts = [initial.strip()]
    index = start
    while index < len(lines) and re.match(r"^  \S", lines[index]):
        parts.append(lines[index].strip())
        index += 1
    return clean(" ".join(parts)), index


def parse_source() -> dict[str, dict[str, Any]]:
    lines = SOURCE.read_text(encoding="utf-8").splitlines()
    specs: dict[str, dict[str, Any]] = {}
    index = 0
    while index < len(lines):
        heading = re.match(r"^### (ch\d+) — (.+)$", lines[index])
        if not heading:
            index += 1
            continue
        chapter_id = heading.group(1)
        chapter_num = int(chapter_id[2:])
        end = index + 1
        while end < len(lines) and not re.match(r"^### ch\d+ — ", lines[end]):
            end += 1
        if not 2 <= chapter_num <= 14:
            index = end
            continue

        segment = lines[index:end]
        spec: dict[str, Any] = {
            "id": chapter_id,
            "title": heading.group(2),
            "cue": CUES[chapter_id],
            "plates": [],
            "n1": "",
            "n2": "",
            "n1_variants": [],
            "n2_variants": [],
            "classes": {},
        }
        cursor = 0
        while cursor < len(segment):
            line = segment[cursor]
            plate = re.match(r"^- `(opening_ch\d+_[012])`.*?—\s*(.*)$", line)
            if plate:
                description, cursor = continuation(
                    segment, cursor + 1, plate.group(2)
                )
                spec["plates"].append(
                    {"name": plate.group(1), "description": description}
                )
                continue

            narration = re.match(
                r"^- n([12])(?:\s+\*.*?\*)?\s+—\s*(.*)$", line
            )
            if narration:
                text, cursor = continuation(
                    segment, cursor + 1, narration.group(2)
                )
                spec[f"n{narration.group(1)}"] = text
                continue

            class_heading = re.match(
                rf"^\*\*({CLASS_RE}) — (.*?)\.\*\* Plate:\s*(.*)$", line
            )
            if not class_heading:
                cursor += 1
                continue

            class_id = class_heading.group(1).lower()
            description_parts = [class_heading.group(3).strip()]
            cursor += 1
            while cursor < len(segment) and not re.match(
                r"^- n3(?:\s+\*.*?\*)?:", segment[cursor]
            ):
                if segment[cursor].strip():
                    description_parts.append(segment[cursor].strip())
                cursor += 1
            if cursor >= len(segment):
                raise ValueError(f"{chapter_id}/{class_id}: missing n3")

            n3_match = re.match(
                r"^- n3(?:\s+\*.*?\*)?:\s*(.*)$", segment[cursor]
            )
            if not n3_match:
                raise ValueError(f"{chapter_id}/{class_id}: malformed n3")
            n3_parts = [n3_match.group(1).strip()]
            cursor += 1
            while (
                cursor < len(segment)
                and not segment[cursor].startswith('- "')
                and not segment[cursor].startswith("- n3 variants")
            ):
                if segment[cursor].strip():
                    n3_parts.append(segment[cursor].strip())
                cursor += 1

            n3_variants: list[dict[str, str]] = []
            if cursor < len(segment) and segment[cursor].startswith("- n3 variants"):
                variant_parts = [segment[cursor]]
                cursor += 1
                while cursor < len(segment) and not segment[cursor].startswith('- "'):
                    if segment[cursor].strip():
                        variant_parts.append(segment[cursor].strip())
                    cursor += 1
                variant_text = " ".join(variant_parts)
                for flag, text in re.findall(
                    r"`([^`]+)`\s+—\s+\"(.*?)(?=\";\s*`|\"$)",
                    variant_text,
                ):
                    n3_variants.append({"flag": flag, "text": clean(f'"{text}"')})

            choices: list[dict[str, Any]] = []
            while cursor < len(segment) and len(choices) < 3:
                if not segment[cursor].startswith('- "'):
                    cursor += 1
                    continue
                choice_parts = [segment[cursor].removeprefix("- ").strip()]
                cursor += 1
                while (
                    cursor < len(segment)
                    and not segment[cursor].startswith('- "')
                    and not segment[cursor].startswith("**")
                ):
                    if segment[cursor].strip():
                        choice_parts.append(segment[cursor].strip())
                    cursor += 1
                choice_text = " ".join(choice_parts)
                choice = re.match(
                    r"^(.*?)\s*→\s*\*\*([+−–-]?\d+)\*\*\s*`([^`]+)`",
                    choice_text,
                )
                if not choice:
                    raise ValueError(
                        f"{chapter_id}/{class_id}: cannot parse choice {choice_text!r}"
                    )
                choices.append(
                    {
                        "text": clean(choice.group(1)),
                        "resonance": float(
                            choice.group(2).replace("−", "-").replace("–", "-")
                        ),
                        "flag": choice.group(3),
                    }
                )

            spec["classes"][class_id] = {
                "plate": clean(" ".join(description_parts)),
                "n3": clean(" ".join(n3_parts)),
                "n3_variants": n3_variants,
                "choices": choices,
            }

        # The Drowned Reaches' second shared beat is deliberately conditional
        # on the ch6 finale. Emit regular dialogue variants so the runtime
        # remains chapter-agnostic.
        if chapter_id == "ch9":
            conditional = re.match(
                r'^spared:\s*"(.*?)"\s*/\s*killed:\s*"(.*?)"$',
                spec["n2"],
            )
            if not conditional:
                raise ValueError("ch9: cannot parse conditional n2")
            spared, killed = conditional.groups()
            spec["n2"] = clean(f'"{killed}"')
            spec["n2_variants"] = [{
                "flag": "chose_kaethra_sheathed",
                "text": clean(f'"{spared}"'),
            }]
        specs[chapter_id] = spec
        index = end

    validate(specs)
    return specs


def validate(specs: dict[str, dict[str, Any]]) -> None:
    expected_chapters = {f"ch{number}" for number in range(2, 15)}
    if set(specs) != expected_chapters:
        raise ValueError(
            f"chapter set mismatch: expected {sorted(expected_chapters)}, "
            f"got {sorted(specs)}"
        )
    if set(ASKERS) != expected_chapters:
        raise ValueError("ASKERS table does not cover ch2-ch14")
    if set(REPLIES) != expected_chapters:
        raise ValueError("REPLIES table does not cover ch2-ch14")
    internal = {"ch2", "ch5", "ch9", "ch10", "ch13"}
    for chapter_id, asker in ASKERS.items():
        if (chapter_id in internal) != (asker["who"] == "You"):
            raise ValueError(
                f"{chapter_id}: prompt mode does not match the doc's "
                "public/private split"
            )
    for chapter_id, spec in specs.items():
        expected_shared = 3 if chapter_id == "ch14" else 2
        if len(spec["plates"]) != expected_shared:
            raise ValueError(
                f"{chapter_id}: expected {expected_shared} shared plates, "
                f"got {len(spec['plates'])}"
            )
        if not spec["n1"] or not spec["n2"]:
            raise ValueError(f"{chapter_id}: missing shared narration")
        if set(spec["classes"]) != set(CLASSES):
            raise ValueError(f"{chapter_id}: class set is incomplete")
        for class_id, turn in spec["classes"].items():
            if len(turn["choices"]) != 3:
                raise ValueError(f"{chapter_id}/{class_id}: needs three choices")
            flags = {choice["flag"] for choice in turn["choices"]}
            if len(flags) != 3:
                raise ValueError(f"{chapter_id}/{class_id}: stance flags drifted")

    shared_count = sum(len(spec["plates"]) for spec in specs.values())
    class_count = sum(len(spec["classes"]) for spec in specs.values())
    if shared_count != 27 or class_count != 78:
        raise ValueError(
            f"plate count mismatch: {shared_count} shared + {class_count} class"
        )


def spine_variants(
    chapter_id: str, node_id: str, base: str, class_id: str
) -> list[dict[str, str]]:
    """Per-class flag variants that APPEND a line to the node's base text."""
    variants: list[dict[str, str]] = []
    for entry in SPINE_VARIANTS.get(chapter_id, {}).get(node_id, []):
        line = entry["append"].get(class_id, entry["append"]["default"])
        variants.append({"flag": entry["flag"], "text": f"{base} {line}"})
    return variants


def build_conversations(specs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    conversations: dict[str, Any] = {}
    stance_names = ("virtue", "temptation", "deflection")
    for chapter_id, spec in specs.items():
        asker = ASKERS[chapter_id]
        for class_id in CLASSES:
            turn = spec["classes"][class_id]
            has_setup = "setup" in asker
            nodes: dict[str, Any] = {
                "n1": {
                    "who": "Narrator",
                    "cue": spec["cue"],
                    "text": spec["n1"],
                    "next": "n2",
                },
                "n2": {
                    "who": "Narrator",
                    "text": spec["n2"],
                    "next": "n3",
                },
                "n3": {
                    "who": "Narrator",
                    "cue": f"{spec['cue']}_{class_id}",
                    "text": turn["n3"],
                    "next": "n4s" if has_setup else "n4",
                },
                "n4": {
                    "who": asker["who"],
                    "text": asker["text"],
                    "choices": [],
                },
            }
            if has_setup:
                nodes["n4s"] = {
                    "who": "Narrator",
                    "text": asker["setup"],
                    "next": "n4",
                }
            n1_variants = list(spec["n1_variants"]) + spine_variants(
                chapter_id, "n1", spec["n1"], class_id
            )
            n2_variants = list(spec["n2_variants"]) + spine_variants(
                chapter_id, "n2", spec["n2"], class_id
            )
            if n1_variants:
                nodes["n1"]["variants"] = n1_variants
            if n2_variants:
                nodes["n2"]["variants"] = n2_variants
            if turn["n3_variants"]:
                nodes["n3"]["variants"] = turn["n3_variants"]
            if chapter_id == "ch14":
                nodes["n2"]["cue"] = "crown_hollow"
            for stance, choice in zip(stance_names, turn["choices"], strict=True):
                reply_id = f"reply_{stance}"
                nodes["n4"]["choices"].append(
                    {
                        "text": choice["text"],
                        "resonance": choice["resonance"],
                        "flags": {choice["flag"]: True},
                        "next": reply_id,
                    }
                )
                nodes[reply_id] = {
                    "who": "Narrator",
                    "text": REPLIES[chapter_id][stance],
                    "next": "n_end",
                }
            nodes["n_end"] = {
                "who": "Narrator",
                "cue": "fade",
                "text": TRAVEL_HOOKS[chapter_id],
            }
            conversations[f"{chapter_id}_opening_{class_id}"] = {
                "start": "n1",
                "nodes": nodes,
            }
    return conversations


def gdscript(value: Any, indent: int = 0) -> str:
    pad = "\t" * indent
    child = "\t" * (indent + 1)
    if isinstance(value, dict):
        if not value:
            return "{}"
        rows = []
        for key, item in value.items():
            rows.append(f"{child}{json.dumps(str(key), ensure_ascii=False)}: "
                        f"{gdscript(item, indent + 1)}")
        return "{\n" + ",\n".join(rows) + f",\n{pad}}}"
    if isinstance(value, list):
        if not value:
            return "[]"
        rows = [f"{child}{gdscript(item, indent + 1)}" for item in value]
        return "[\n" + ",\n".join(rows) + f",\n{pad}]"
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        return f"{value:.1f}"
    if value is None:
        return "null"
    return str(value)


def render(specs: dict[str, dict[str, Any]]) -> str:
    conversations = build_conversations(specs)
    flags = sorted(
        {
            choice["flag"]
            for spec in specs.values()
            for turn in spec["classes"].values()
            for choice in turn["choices"]
        }
    )
    plate_manifest: dict[str, str] = {}
    for chapter_id, spec in specs.items():
        for plate in spec["plates"]:
            plate_manifest[plate["name"]] = plate["description"]
        for class_id, turn in spec["classes"].items():
            plate_manifest[f"opening_{chapter_id}_{class_id}"] = turn["plate"]

    return (
        "## GENERATED by tools/content/gen_chapter_openers.py from\n"
        "## PROPOSALS/CHAPTER_OPENERS.md. Edit the proposal, then regenerate.\n"
        "## Plain content module: no class_name.\n\n"
        f"const CONVOS := {gdscript(conversations)}\n\n"
        f"const CHAPTER_OPENER_FLAGS := {gdscript(flags)}\n\n"
        f"const CHAPTER_OPENER_PLATES := {gdscript(plate_manifest)}\n"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail when the generated module is missing or stale",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="write game/scripts/content/chapter_openers.gd",
    )
    args = parser.parse_args()
    if not args.check and not args.write:
        parser.error("choose --check or --write")

    specs = parse_source()
    generated = render(specs)
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != generated:
            print(f"STALE: {OUTPUT.relative_to(ROOT)}")
            return 1
        print("chapter openers: generated module is current (105 plates, 78 convos)")
        return 0

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(generated, encoding="utf-8", newline="\n")
    print(f"wrote {OUTPUT.relative_to(ROOT)} (105 plates, 78 convos)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
