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
REPLIES = {
    "virtue": "The Ember answers with heat, then yields. For once, you carry it instead of being carried.",
    "temptation": "The Ember warms as if recognized. The chapter ahead has heard your answer.",
    "deflection": "The question follows when you decline to answer it. Silence is still a direction.",
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
            appended = (
                "The cutting in your pack turned over in the night. "
                "It is pointing at the city like a compass needle."
            )
            spec["n1_variants"] = [{
                "flag": "ch6_answered_green",
                "text": f"{spec['n1']} {appended}",
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


def build_conversations(specs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    conversations: dict[str, Any] = {}
    stance_names = ("virtue", "temptation", "deflection")
    for chapter_id, spec in specs.items():
        for class_id in CLASSES:
            turn = spec["classes"][class_id]
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
                    "next": "n4",
                },
                "n4": {
                    "who": "You",
                    "text": "Before the first step, the Ember asks what you will make of what waits ahead.",
                    "choices": [],
                },
            }
            if spec["n1_variants"]:
                nodes["n1"]["variants"] = spec["n1_variants"]
            if spec["n2_variants"]:
                nodes["n2"]["variants"] = spec["n2_variants"]
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
                    "text": REPLIES[stance],
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
