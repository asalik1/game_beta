"""Generate game/scripts/content/capital_hub.gd — the standalone Crownfall hub.

CAPITAL REWORK 2026-07-25 (PROPOSALS/CAPITAL_REWORK.md): 25 rooms -> 9, a 3x3
grid. Crown Plaza (the only grand room) holds every everyday service ringed
around the fountain; every branch room is exactly one door away. The four
faction wards keep their two principals and contracts desk at one room each.

Redundancy rule enforced here: a function is owned by exactly ONE interaction
— an NPC where a person makes sense (services with favor attribution: forge /
lapidary / drill), a prop where it doesn't (portals, vault, archive desks).
Landmarks may now be pure scenery (no uses) when an NPC in front owns the
function. Auto-derives exits from grid adjacency, verifies one connected
component, and emits the GDScript content module (CHAPTER const + CONVOS)."""
import collections, sys

ROOM_W, ROOM_H = 2112, 1248
CX, CY = ROOM_W // 2, ROOM_H // 2  # 1056, 624
# Spawn sits between the spire arch and the fountain — 28px north of center
# so the fountain's corrected body (north edge at 635) clears the hero's
# radius on every arrival (no first-frame physics nudge).
START_Y = CY - 28

# Each room: (id, Name, gx, gy, terrain, room_scale, cast)
# cast entry: (sprite, prompt, ref, kind[, greet])
#   kind: "convo" | "action"
#   convo  -> ref is a convo id (text supplied in CONVOS below)
#   action -> ref is a hub action key handled by game_world._hub_action;
#             optional greet = convo id played once (cap_met_<greet> flag)
#             before the service opens — the NPC keeps a voice without
#             duplicating the access point.
P = "convo"; A = "action"
HUB_ACTIONS = {
    "portal_story", "portal_crucible", "portal_depths",
    "vault", "codex", "daily", "map", "mail", "journal", "records",
    "guild", "potions", "wardrobe", "forge", "lapidary", "drill",
    # Professions craft station (PROFESSIONS §7): trade lock, mastery,
    # blueprints, craft bench. Placed by Herbalist Kesh's gossip hub (the
    # Alchemist trainer); Smith Petra's forge hub also opens it in code.
    "professions",
    # Synthesis bench / the Alkahest Codex (CONSUMABLE_GRADES §9): learn the
    # Codex, then fuse a clean S + a laced A into a Grand potion. Kesh's alembic
    # capstone — placed by her gossip hub alongside the craft bench.
    "synthesis",
    # The black-market FENCE (CONSUMABLE_GRADES §10): the laced lane, sold ONLY
    # by black-market vendors. Placed on a shady peddler in the Sable Court
    # (Cinderborn ward); game_world._cap_fence plays her greet once then opens
    # menus.open_black_market. The occasional road smuggler shares that shelf.
    "blackmarket",
}
ROOMS = [
  # --- CROWN PLAZA: the whole town ritual in one grand room ---
  ("plaza","Crown Plaza",0,0,"capital_civic",1.00,[
      ("factor_imre","E — Ask for directions","cap_citizen",P),
      ("smith_petra","E — Smith Petra","forge",A,"cap_petra"),
      ("archivist_lene","E — Master Lapidary","lapidary",A,"cap_lapidary"),
      ("warden_corin","E — Marshal Corin","drill",A),
      ("clerk_voss","E — Claim the daily alms","daily",A),
      ("capital_vault_chest","E — Open your vault","vault",A)]),
  # --- BRANCHES: one door from the plaza each ---
  ("portal","Wayfinder Sanctum",0,-1,"capital_wayfinder",0.82,[]),
  ("archive","The Grand Archive",1,0,"capital_civic",0.72,[]),
  ("tankard","The Ashen Tankard",-1,0,"capital_civic",0.78,[
      ("peddler_nix","E — Tavern Keeper Nix","cap_tankard",P),
      ("old_fenna","E — Old Fenna","cap_fenna",P)]),
  ("gate","The Emberward Gate",0,1,"capital_approach",0.72,[
      ("warden_sighne","E — Gate Sergeant","cap_gate",P)]),
  # --- FACTION WARDS: one room, two principals, one contracts desk each ---
  ("wf_moot","Fangmoot Circle",-1,-1,"capital_wildfang",0.78,[
      ("callis","E — Warden Callis","cap_callis",P),
      ("skald_ottar","E — Skald Ottar","cap_ottar",P)]),
  ("ch_chapel","The Rot-Chapel",1,-1,"capital_choir",0.78,[
      ("cantor_ilse","E — Cantor Ilse","cap_ilse",P),
      ("deacon_vela","E — Deacon Vela","cap_vela",P)]),
  ("acc_commons","Accord Commons",-1,1,"capital_accord",0.78,[
      ("elder","E — Elder Maren","cap_maren",P),
      ("herbalist_kesh","E — Herbalist Kesh","cap_kesh",P)]),
  ("cin_court","The Sable Court",1,1,"capital_cinderborn",0.78,[
      ("aldric","E — Ser Aldric","cap_aldric",P),
      ("vessa","E — Envoy Vessa","cap_vessa",P),
      # The black-market fence lurks in the ward Crownfall doesn't ledger (§10).
      ("grave_goods_peddler","E — The Fence","blackmarket",A,"cap_fence")]),
]

# merchant rooms (existing shop system): id -> [x,y]. The plaza bazaar is the
# ONE fair-priced shop in the game (daily restock — menus.open_shop specials).
MERCHANTS = {"plaza": [1470, 830]}

# Exact room-local landmark placement (full-cell coords; room_pos scales).
# tuple: (structure id, x, y, clearance radius)
LANDMARKS = {
    "plaza": [
        ("capital_crown_spire_gate", 1056, 500, 430),
        ("capital_crown_fountain", 1056, 765, 250),
        ("capital_ashfire_forge", 430, 560, 260),      # Petra's — she owns the use
        ("capital_grand_archive", 1680, 560, 235),     # the Lapidary's benches
        ("capital_market_stall", 1620, 860, 200),
        ("capital_market_stall", 490, 860, 200),
    ],
    "portal": [
        ("capital_portal_story", 560, 560, 150),
        ("capital_portal_crucible", 1056, 560, 160),
        ("capital_portal_depths", 1552, 560, 145)],
    "archive": [("capital_grand_archive", 1056, 585, 285)],
    "tankard": [("capital_ashen_tankard", 1056, 590, 285),
                ("great_hearth", 620, 560, 175),
                ("capital_alembic_station", 1492, 560, 205)],
    "gate": [("capital_emberward_gate", 1056, 560, 280)],
    "wf_moot": [("capital_wildfang_fangmoot", 1056, 570, 285)],
    "ch_chapel": [("capital_rot_chapel", 1056, 590, 290)],
    "acc_commons": [("capital_accord_longhouse", 1056, 590, 315)],
    "cin_court": [("capital_sable_hall", 1056, 590, 315)],
}

# Wide connected architecture behind the landmarks (no collider; the open
# central arch frames the actual north road, so only rooms WITH a north road
# carry one).
# tuple: (sprite id, x, y, authored width)
BACKDROPS = {
    "plaza": [("capital_city_arcade", 1056, 405, 1653.75)],
    "tankard": [("capital_city_arcade", 1056, 405, 1653.75)],
    "archive": [("capital_city_arcade", 1056, 405, 1653.75)],
    "gate": [("capital_city_arcade", 1056, 405, 1653.75)],
    "acc_commons": [("capital_city_arcade", 1056, 405, 1653.75)],
    "cin_court": [("capital_city_arcade", 1056, 405, 1653.75)],
}

# Exact supporting furniture: deliberate social placements only.
FURNISHINGS = {
    "plaza": [("capital_city_bench", 700, 990, 110),
              ("capital_city_bench", 1410, 990, 110)],
    "tankard": [("capital_city_bench", 760, 810, 110),
                ("capital_city_bench", 1352, 810, 110)],
    "acc_commons": [("capital_city_bench", 760, 815, 110),
                    ("capital_city_bench", 1352, 815, 110)],
    "wf_moot": [("capital_city_bench", 760, 815, 110)],
    "ch_chapel": [("capital_city_bench", 760, 815, 110)],
}

# Landmark affordances. A landmark ABSENT from this dict is scenery — its
# function (if any) is owned by the NPC standing in front of it.
# key: (room id, landmark index) -> list of typed use dictionaries.
def ACTION(prompt, ref, x=0, y=80):
    return {"type": "action", "prompt": prompt, "ref": ref, "x": x, "y": y}

def INSPECT(prompt, title, text, x=0, y=80):
    return {"type": "inspect", "prompt": prompt, "title": title,
            "text": text, "x": x, "y": y}

LANDMARK_USES = {
    ("plaza", 0): [ACTION("E — View the city map", "map", y=30)],
    # Fountain stand-point hugs the basin (its collider circle ends at +64;
    # +60 keeps the prompt adjacency-only — owner report 2026-07-25).
    ("plaza", 1): [INSPECT("E — Inspect the Crown Fountain", "Crown Fountain",
        "The ward roads meet at this basin. Companies use its crown as the city's easiest rally point.", y=60)],
    # plaza 2 (forge) and 3 (lapidary benches) are owned by Petra / the Lapidary.
    ("plaza", 4): [ACTION("E — Browse the Wardrobe", "wardrobe", y=100)],
    ("plaza", 5): [ACTION("E — Check your mailbox", "mail", y=100)],
    ("portal", 0): [ACTION("E — Enter the Story Gate", "portal_story", y=30)],
    ("portal", 1): [ACTION("E — Enter the Crucible Gate", "portal_crucible", y=30)],
    ("portal", 2): [ACTION("E — Enter the Depths Gate", "portal_depths", y=30)],
    ("archive", 0): [
        ACTION("E — Browse the Codex", "codex", x=-170, y=100),
        ACTION("E — Read your journal", "journal", y=100),
        ACTION("E — Review your records", "records", x=170, y=100),
    ],
    # tankard 0 (the hall) and 1 (the hearth) are owned by their PEOPLE now
    # (owner report 2026-07-25: a structure prompt stacked on Old Fenna read
    # as her talking): Nix's gossip hub opens the party lobby, Fenna's offers
    # the warm-up. Only the unattended alembic keeps a prop hotspot.
    ("tankard", 2): [ACTION("E — Prepare your potion loadout", "potions", y=80)],
    ("gate", 0): [ACTION("E — Leave Crownfall", "portal_story", y=80)],
    ("wf_moot", 0): [ACTION("E — Review Wildfang contracts", "journal", y=95)],
    ("ch_chapel", 0): [ACTION("E — Review Choir contracts", "journal", y=90)],
    ("acc_commons", 0): [ACTION("E — Review Accord contracts", "journal", y=95)],
    ("cin_court", 0): [ACTION("E — Review Cinderborn contracts", "journal", y=95)],
}

# Restrained supporting dressing: capital rooms never inherit terrain scatter.
DISTRICT_SCENERY = {
    "heart":    {"obstacles": [], "decor": [], "count": 0, "decor_count": 0},
    "civic":    {"obstacles": [], "decor": [], "count": 0, "decor_count": 0},
    "approach": {"obstacles": [], "decor": [], "count": 0, "decor_count": 0},
    "wild":     {"obstacles": [], "decor": [], "count": 0, "decor_count": 0},
    "choir":    {"obstacles": [], "decor": [], "count": 0, "decor_count": 0},
    "accord":   {"obstacles": [], "decor": [], "count": 0, "decor_count": 0},
    "cinder":   {"obstacles": [], "decor": [], "count": 0, "decor_count": 0},
}

_DISTRICT_EXPLICIT = {
    "plaza": "heart",
    "portal": "civic", "archive": "civic", "tankard": "civic",
    "gate": "approach",
}
def district_of(rid):
    if rid in _DISTRICT_EXPLICIT: return _DISTRICT_EXPLICIT[rid]
    if rid.startswith("wf_"):  return "wild"
    if rid.startswith("ch_"):  return "choir"
    if rid.startswith("acc_"): return "accord"
    if rid.startswith("cin_"): return "cinder"
    return "civic"

# Map marks: spawn star, portal diamond, faction contract dot.
_QUESTGIVERS = {"wf_moot", "ch_chapel", "acc_commons", "cin_court"}
def mark_of(rid):
    if rid == "plaza":  return "★"   # star
    if rid == "portal": return "◆"   # diamond
    if rid in _QUESTGIVERS: return "●"  # dot
    return ""

def cast_fields(entry):
    """(sprite, prompt, ref, kind[, greet]) -> normalized 5-tuple."""
    if len(entry) == 4:
        return entry[0], entry[1], entry[2], entry[3], ""
    return entry

# ---------- verify: unique coords, connected graph ----------
coord_of = {}
by_coord = {}
for i,(rid,name,gx,gy,terr,room_scale,cast) in enumerate(ROOMS):
    if (gx,gy) in by_coord:
        sys.exit("COORD COLLISION at (%d,%d): %s and %s" % (gx,gy,by_coord[(gx,gy)],rid))
    by_coord[(gx,gy)] = rid
    coord_of[rid] = (gx,gy)

DIRS = {"N":(0,-1),"S":(0,1),"E":(1,0),"W":(-1,0)}
def exits_for(gx,gy):
    out = []
    for d,(dx,dy) in DIRS.items():
        if (gx+dx,gy+dy) in by_coord:
            out.append(d)
    return out

# connectivity BFS from plaza
adj = collections.defaultdict(list)
for (gx,gy),rid in by_coord.items():
    for d,(dx,dy) in DIRS.items():
        if (gx+dx,gy+dy) in by_coord:
            adj[rid].append(by_coord[(gx+dx,gy+dy)])
seen = set(["plaza"]); q = collections.deque(["plaza"])
while q:
    c = q.popleft()
    for nb in adj[c]:
        if nb not in seen:
            seen.add(nb); q.append(nb)
if len(seen) != len(ROOMS):
    missing = [r[0] for r in ROOMS if r[0] not in seen]
    sys.exit("GRAPH NOT CONNECTED — unreachable from plaza: %s" % missing)
room_ids = {room[0] for room in ROOMS}
if not set(FURNISHINGS).issubset(room_ids):
    sys.exit("FURNISHINGS reference unknown room(s): %s" %
             sorted(set(FURNISHINGS) - room_ids))
if not set(BACKDROPS).issubset(room_ids):
    sys.exit("BACKDROPS reference unknown room(s): %s" %
             sorted(set(BACKDROPS) - room_ids))
for rid in BACKDROPS:
    if "N" not in exits_for(*coord_of[rid]):
        sys.exit("BACKDROP central arch has no north road: %s" % rid)
landmark_keys = {
    (rid, landmark_index)
    for rid, landmarks in LANDMARKS.items()
    for landmark_index in range(len(landmarks))
}
if not set(LANDMARK_USES).issubset(landmark_keys):
    sys.exit("LANDMARK_USES references unknown landmark(s): %s" %
             sorted(set(LANDMARK_USES) - landmark_keys))
for landmark_key, uses in LANDMARK_USES.items():
    if not uses:
        sys.exit("LANDMARK_USES entry is empty (delete it instead): %s" % (landmark_key,))
    for use in uses:
        use_type = use.get("type", "")
        if use_type not in ["action", "inspect"]:
            sys.exit("LANDMARK_USES has invalid type %r: %s" %
                     (use_type, landmark_key))
        if use_type == "action" and use.get("ref", "") not in HUB_ACTIONS:
            sys.exit("LANDMARK_USES has unhandled action %r: %s" %
                     (use.get("ref", ""), landmark_key))
        if use_type == "inspect" and (not use.get("title") or not use.get("text")):
            sys.exit("LANDMARK_USES inspect is incomplete: %s" % (landmark_key,))
# the ONE-ACCESS-POINT rule: no action ref may appear twice in the same room,
# and the service actions owned by plaza NPCs may not also hang off landmarks.
for rid, *_rest in ROOMS:
    refs = [use["ref"] for key, uses in LANDMARK_USES.items() if key[0] == rid
            for use in uses if use["type"] == "action"]
    npc_refs = [cast_fields(e)[2] for room in ROOMS if room[0] == rid
                for e in room[6] if cast_fields(e)[3] == A]
    dupes = {r for r in refs + npc_refs
             if (refs + npc_refs).count(r) > 1 and not r.startswith("portal_")}
    if dupes:
        sys.exit("DUPLICATE ACCESS POINT in %s: %s" % (rid, sorted(dupes)))
for district, scenery in DISTRICT_SCENERY.items():
    if "bench2" in scenery["obstacles"] or "garden_bench" in scenery["obstacles"]:
        sys.exit("legacy bench leaked into capital district %s" % district)
if sum(map(len, FURNISHINGS.values())) < 8:
    sys.exit("capital polish coverage too low: furnishings")
print("OK: %d rooms, unique coords, single connected component" % len(ROOMS))

# ---------- emit GDScript ----------
SLOTS = [(CX, CY+190), (CX-360, CY+90), (CX+360, CY+90), (CX-560, CY-140),
         (CX+560, CY-140), (CX, CY+220)]
NPC_SLOT_OVERRIDES = {
    # Plaza stations sit in front of the landmark each NPC owns.
    # Petra and the Lapidary stand outside the two south-stall roof spans.
    # Their old x=470/1640 positions put their bodies behind the awnings.
    "plaza": [(1290, 830), (300, 700), (1810, 700), (1240, 580), (830, 830), (1056, 950)],
    "tankard": [(1056, 814), (650, 650)],
    "gate": [(1056, 814)],
    "wf_moot": [(720, 650), (1390, 650)],
    "ch_chapel": [(720, 650), (1390, 650)],
    "acc_commons": [(720, 650), (1390, 650)],
    # Aldric + Vessa flank the Sable Hall; the fence keeps to the shadow-market
    # south of it (clear of the hall's clearance radius).
    "cin_court": [(720, 650), (1390, 650), (1056, 940)],
}

def gd_zone(i, room):
    rid,name,gx,gy,terr,room_scale,cast = room
    ex = exits_for(gx,gy)
    exs = ", ".join('"%s"' % d for d in ex)
    lines = []
    lines.append('\t{"name": "%s", "terrain": "%s", "type": "safe",' % (name, terr))
    lines.append('\t\t"coord": [%d, %d], "room_scale": %.2f, "exits": [%s], "enemies": [], "boss": "",' %
                 (gx, gy, room_scale, exs))
    lines.append('\t\t"district": "%s", "mark": "%s",' % (district_of(rid), mark_of(rid)))
    scenery = DISTRICT_SCENERY[district_of(rid)]
    obstacle_names = ", ".join('"%s"' % value for value in scenery["obstacles"])
    decor_names = ", ".join('"%s"' % value for value in scenery["decor"])
    lines.append('\t\t"obstacles": [%s], "obstacle_count": %d,' %
                 (obstacle_names, scenery["count"]))
    lines.append('\t\t"decor": [%s], "decor_count": %d, "accents": [], "structures": [],' %
                 (decor_names, scenery["decor_count"]))
    landmark_lines = []
    for landmark_index,(landmark_name,x,y,clearance) in enumerate(LANDMARKS.get(rid, [])):
        fields = ['"name": "%s"' % landmark_name, '"x": %d' % x, '"y": %d' % y,
                  '"clearance": %d' % clearance]
        use_lines = []
        for use in LANDMARK_USES.get((rid, landmark_index), []):
            use_fields = ['"type": "%s"' % use["type"],
                          '"prompt": "%s"' % use["prompt"],
                          '"x": %d' % int(use.get("x", 0)),
                          '"y": %d' % int(use.get("y", 80))]
            if use["type"] == "action":
                use_fields.append('"ref": "%s"' % use["ref"])
            else:
                use_fields.extend(['"title": "%s"' % use["title"],
                                   '"text": "%s"' % use["text"]])
            use_lines.append("{" + ", ".join(use_fields) + "}")
        fields.append('"uses": [%s]' % ", ".join(use_lines))
        landmark_lines.append("{" + ", ".join(fields) + "}")
    lines.append('\t\t"landmarks": [%s],' % ", ".join(landmark_lines))
    furnishing_lines = [
        '{"name": "%s", "x": %d, "y": %d, "clearance": %d}' % item
        for item in FURNISHINGS.get(rid, [])
    ]
    lines.append('\t\t"furnishings": [%s],' % ", ".join(furnishing_lines))
    backdrop_lines = [
        '{"name": "%s", "x": %d, "y": %d, "w": %s}' %
        (item[0], item[1], item[2], item[3])
        for item in BACKDROPS.get(rid, [])
    ]
    lines.append('\t\t"backdrops": [%s],' % ", ".join(backdrop_lines))
    if rid in MERCHANTS:
        mx,my = MERCHANTS[rid]
        lines.append('\t\t"merchant": [%d, %d],' % (mx, my))
    if cast:
        npc_lines = []
        slots = NPC_SLOT_OVERRIDES.get(rid, SLOTS)
        for j,entry in enumerate(cast):
            spr,prompt,ref,kind,greet = cast_fields(entry)
            x,y = slots[j % len(slots)]
            if kind == A:
                greet_field = ', "greet": "%s"' % greet if greet else ''
                npc_lines.append('\t\t\t{"sprite": "%s", "x": %d, "y": %d, "prompt": "%s", "action": "%s"%s}'
                                 % (spr, x, y, prompt, ref, greet_field))
            else:
                npc_lines.append('\t\t\t{"sprite": "%s", "x": %d, "y": %d, "prompt": "%s", "convo": "%s"}'
                                 % (spr, x, y, prompt, ref))
        lines.append('\t\t"npcs": [\n' + ",\n".join(npc_lines) + '],')
    else:
        lines.append('\t\t"npcs": [],')
    return "\n".join(lines) + "\n\t},"

# ---------- CONVOS: one short node per named NPC ----------
# A value is either ("Who", "text") -> one linear node, or a full convo dict
# (start/nodes, the story.gd schema) -> emitted verbatim as JSON. Dict convos
# are the GOSSIP HUBS (owner 2026-07-25): an NPC who owns several functions
# opens ONE splash dialogue whose choices route to each — a choice may carry
# "hub_action": <game_world._hub_action ref> to open a game surface when its
# path ends.
GOSSIP = {
 "cap_fenna": {"start": "a", "nodes": {
    "a": {"who": "Old Fenna",
          "text": "Warmth or words, dear? The hearth gives both, and neither costs a thing.",
          "choices": [
             {"text": "Warm yourself at the Great Hearth", "next": "warm"},
             {"text": "\"Tell me about this place.\"", "next": "talk"},
             {"text": "(Leave)", "next": ""}]},
    "warm": {"who": "Narrator",
          "text": "You stand a while at the Great Hearth — a public fire for cooking, waiting, and finding companions between expeditions. The road's cold lets go of your shoulders.",
          "next": ""},
    "talk": {"who": "Old Fenna",
          "text": "Kitchen on this side, Alembic on that — supper or medicine without crossing the square. Sit by the hearth if you're waiting on friends; someone always knows who just came through a gate.",
          "next": ""}}},
 "cap_tankard": {"start": "a", "nodes": {
    "a": {"who": "Tavern Keeper",
          "text": "The Ashen Tankard — warmth, rumour, a fire that behaves. First cup's on the house for a shard-bearer. Looking for company, or just the fire?",
          "choices": [
             {"text": "Find a company  (Play Together)", "hub_action": "guild", "next": "gates"},
             {"text": "\"Just the news, Nix.\"", "next": "talk"},
             {"text": "(Leave)", "next": ""}]},
    "gates": {"who": "Tavern Keeper",
          "text": "Aye — the whole city drifts through here after dark. Let's see who's drinking.",
          "next": ""},
    "talk": {"who": "Tavern Keeper",
          "text": "News? The wards keep their corners, the plaza keeps the coin, and the gates keep out exactly as much of the wild as the wild allows. Same as ever. Stay for a cup.",
          "next": ""}}},
 # Herbalist Kesh is the ALCHEMIST trainer (PROFESSIONS §7): a gossip hub whose
 # craft-bench choice opens the trade-agnostic Professions panel.
 "cap_kesh": {"start": "a", "nodes": {
    "a": {"who": "Herbalist Kesh",
          "text": "Cures for the ward, reagents for the Alembic across the plaza. I keep the Alchemist's bench — charms and gloves worked from bone and cloth. And if you've found the Codex, the alembic answers to it. Craft, synthesise, or after the day's leaves?",
          "choices": [
             {"text": "Open the craft bench  (Professions)", "hub_action": "professions", "next": "craft"},
             {"text": "The synthesis bench  (Alkahest Codex)", "hub_action": "synthesis", "next": "synth"},
             {"text": "\"Tell me about the gathering.\"", "next": "talk"},
             {"text": "(Leave)", "next": ""}]},
    "craft": {"who": "Herbalist Kesh",
          "text": "Lock a trade at the bench — only your own trade's work will take. Mastery keeps, though, whatever you swap to.",
          "next": ""},
    "synth": {"who": "Herbalist Kesh",
          "text": "The Codex is the one text that marries a legend's clean half to the street's rotted twin. Bring me both bottles and the fee, and I'll draw off something greater than either. No single legend ever managed it — they each made one half and vanished.",
          "next": ""},
    "talk": {"who": "Herbalist Kesh",
          "text": "I set the day's gathering. Bring back the right leaves and no one dies of the wrong ones.",
          "next": ""}}},
}
CONVOS = {
 "cap_citizen": ("A Citizen", "First visit? Everything a returning company needs rings this plaza — Petra's forge west, the Lapidary east, your vault by the fountain, the bazaar and mail at the south stalls. Gates north, Tankard west, Archive east, the four ward halls at the corners."),
 "cap_petra": ("Smith Petra", "The city's one forge worth the name. Quench, reforge, transmute — bring me the piece and the coin and I'll bring the fire. Spend enough seasons at my bench and you'll find my rates soften for a regular."),
 "cap_lapidary": ("Master Lapidary", "Petra handles metal; I handle what lives inside it. Stones, sockets, synthesis — all of it at these benches and nowhere else. Gems are patient work; patrons who keep coming back get my patient prices."),
 "cap_gate": ("Gate Sergeant", "The Emberward Gate. Portcullis stays up in peacetime; the wild stays out on its honour. You came in clean — most do."),
 "cap_callis": ("Warden Callis", "The tribes hold this enclave by truce, not welcome. Honest work, then: survey what the Waking's made of the east, and bring us word. Daily, if you're able."),
 "cap_ottar": ("Skald Ottar", "A fire that never dies and a skald who never stops. Go do a thing worth singing — I'll trade you the doing for the song. Come back with a story."),
 "cap_ilse": ("Cantor Ilse", "The Choir does not bury its dead — rot is the land's honest truth, and the dead keep their own vigil here. Tend them with me. It's patient work. Daily work."),
 "cap_vela": ("Deacon Vela", "Quieter tasks than the Cantor's: recover a relic, carry a name north to the sleepers, witness a thing and return unbroken. The blight rewards the faithful."),
 "cap_maren": ("Elder Maren", "So — the shards still choosing, and the factions still counting. The Accord holds this ward and half this city's conscience. There's honest work daily, if you want it. Sit; the fire doesn't bite."),
 "cap_aldric": ("Ser Aldric", "The Cinderborn keep the forms of a court that lost its crown. I keep its sword arm. There's work in the old key — recover, restore, avenge — for a crown that might yet find a head. Daily, if you've the stomach."),
 "cap_vessa": ("Envoy Vessa", "Work with us and be paid, protected, and remembered. I've a commission most days — a courier run, a quiet errand, imperial paper with teeth. First one's waiting."),
 # The black-market fence's one-time greet (CONSUMABLE_GRADES §10 street voice):
 # the discount is diluted blightwater, and she'll tell you it's fine — lying by
 # less than you'd hope. Played once (cap_met_fence), then the laced shelf opens.
 "cap_fence": ("The Fence", "Keep it down. The Accord won't stamp what I sell — which is why it's a third off their chartered rate, every bottle. Aye, it's cut. Blightwater, thinned near to nothing. Closes the wound just the same; the rest is a little rot, and rot never yet collected off anyone who paid on time. Come see the shelf."),
}

# ---------- content integrity before write ----------
used_convos = set()
used_actions = set()
for *_x, cast in ROOMS:
    for entry in cast:
        spr, prompt, ref, kind, greet = cast_fields(entry)
        if kind == P:
            used_convos.add(ref)
        else:
            used_actions.add(ref)
            if greet:
                used_convos.add(greet)
used_actions.update(
    use["ref"]
    for uses in LANDMARK_USES.values()
    for use in uses
    if use["type"] == "action"
)
# Gossip-hub choices place hub actions too (Nix's "Find a company" IS the
# guild access point).
for convo in GOSSIP.values():
    for node in convo["nodes"].values():
        for choice in node.get("choices", []):
            if "hub_action" in choice:
                used_actions.add(choice["hub_action"])
if set(CONVOS) & set(GOSSIP):
    sys.exit("CONVO DEFINED TWICE — %s" % sorted(set(CONVOS) & set(GOSSIP)))
if used_convos != set(CONVOS) | set(GOSSIP):
    sys.exit("CONVO COVERAGE MISMATCH — %s" % sorted(used_convos ^ (set(CONVOS) | set(GOSSIP))))
if not used_actions.issubset(HUB_ACTIONS):
    sys.exit("UNHANDLED HUB ACTIONS — %s" % sorted(used_actions - HUB_ACTIONS))
missing_actions = HUB_ACTIONS - used_actions
if missing_actions:
    sys.exit("HUB ACTIONS NEVER PLACED — %s" % sorted(missing_actions))
# One-access-point holds through the gossip hubs too: a convo choice's
# hub_action must not duplicate a landmark/NPC access in the same room.
for room in ROOMS:
    rid, cast = room[0], room[6]
    room_refs = [use["ref"] for key, uses in LANDMARK_USES.items() if key[0] == rid
                 for use in uses if use["type"] == "action"]
    room_refs += [cast_fields(e)[2] for e in cast if cast_fields(e)[3] == A]
    for e in cast:
        _spr, _prompt, ref, kind, _greet = cast_fields(e)
        if kind == P and ref in GOSSIP:
            for node in GOSSIP[ref]["nodes"].values():
                for choice in node.get("choices", []):
                    if choice.get("hub_action", "") in room_refs:
                        sys.exit("GOSSIP DUPLICATES A ROOM ACCESS POINT — %s: %s"
                                 % (rid, choice["hub_action"]))

for rid,*_rest,scale,cast in ROOMS:
    if not 0.55 <= scale <= 1.0:
        sys.exit("INVALID ROOM SCALE — %s: %.2f" % (rid, scale))
    if rid not in LANDMARKS:
        sys.exit("ROOM HAS NO LANDMARK — %s" % rid)
    if not cast and rid not in MERCHANTS \
            and not any(key[0] == rid for key in LANDMARK_USES):
        sys.exit("ROOM HAS NO INTERACTION — %s" % rid)
print("OK: authored scale, landmark, interaction, convo, and action coverage")

# ---------- write the file ----------
import json
zones = "\n".join(gd_zone(i, r) for i, r in enumerate(ROOMS))
convo_lines = []
for cid,(who,text) in CONVOS.items():
    t = text.replace('"', '\\"')
    convo_lines.append('\t"%s": {"start": "a", "nodes": {"a": {"who": "%s", "text": "%s", "next": ""}}},' % (cid, who, t))
# Gossip hubs emit verbatim — JSON literals are valid GDScript dicts.
for cid, convo in GOSSIP.items():
    convo_lines.append('\t"%s": %s,' % (cid, json.dumps(convo)))
convos = "\n".join(convo_lines)

OUT = r"C:/Users/asali/Projects/MMO/game/scripts/content/capital_hub.gd"
header = '''## capital_hub — Crownfall, the capital (reworked 2026-07-25, see
## PROPOSALS/CAPITAL_REWORK.md). A STANDALONE 9-room authored city on a 3x3
## grid: Crown Plaza holds every everyday service (forge, lapidary, vault,
## bazaar + wardrobe, mail, alms), and every branch room — portals, archive,
## tavern, gate, and the four faction wards — is exactly one door away.
## Reached via the Travel button, the dev panel, and (first ch1 clear) the
## campaign routing; Story.chapter("capital") resolves this CHAPTER.
##
## Fixed layout: every zone carries an authored "coord" + "exits", so
## game_world._prepare_rooms lays them out verbatim (no seeded spine).
## All zones are "safe" (no packs). ONE ACCESS POINT PER FUNCTION: services
## with favor attribution live on NPCs (action + optional one-time "greet"
## convo); props own the impersonal functions (portals, vault, desks);
## landmarks with no "uses" are scenery for the NPC in front of them.
## GENERATED by tools/content/gen_capital.py — edit the generator, not this file.
class_name CapitalHub

# The standalone world. Story.chapter("capital") returns this; it is kept OUT of
# CHAPTER_LIST so campaign machinery (chapter select, weekly rotation, act gating)
# never sees it — exactly like the endgame arenas.
const CHAPTER := {
\t"name": "Crownfall",
\t"sub": "A gathering city — every service one plaza, every road one door",
\t"standalone": true,
\t"loot_cap": "C",
\t"start_quest": "",
\t"final_boss": "",
\t"start_pos": [@START_X@, @START_Y@],
\t"zones": [
@ZONES@
\t],
}

# One short line per named resident (the ch2-hub CONVOS pattern). Merged into
# Story.ALL_CONVOS via the CONTENT_MODULES registration.
const CONVOS := {
@CONVOS@
}


## Merge + integrity selftest: the world resolves, every zone is safe, scaled,
## composed around a landmark, and has an interaction; NPC refs are wired.
## Landmarks MAY be pure scenery (empty uses) when an NPC owns the function.
static func selftest(_game: Node2D) -> String:
\tvar ch: Dictionary = Story.chapter("capital")
\tif ch.get("zones", []).size() != @NZONES@:
\t\treturn "capital: expected @NZONES@ zones, got %d" % ch.get("zones", []).size()
\tvar coords := {}
\tvar known_actions := [@ACTIONS@]
\tfor z in ch["zones"]:
\t\tif z.get("type", "") != "safe":
\t\t\treturn "capital: zone %s is not safe" % z.get("name", "?")
\t\tif not Terrains.DATA.has(String(z.get("terrain", ""))):
\t\t\treturn "capital: zone %s has unknown terrain %s" % [z.get("name","?"), z.get("terrain","")]
\t\tvar room_scale: float = float(z.get("room_scale", 1.0))
\t\tif room_scale < 0.55 or room_scale > 1.0:
\t\t\treturn "capital: zone %s has invalid room_scale %.2f" % [z.get("name","?"), room_scale]
\t\tif z.get("landmarks", []).is_empty():
\t\t\treturn "capital: zone %s has no authored landmark" % z.get("name", "?")
\t\tvar has_interaction: bool = z.has("merchant") or not z.get("npcs", []).is_empty()
\t\tfor landmark in z.get("landmarks", []):
\t\t\tfor use in landmark.get("uses", []):
\t\t\t\thas_interaction = true
\t\t\t\tvar use_type := String(use.get("type", ""))
\t\t\t\tif use_type not in ["action", "inspect"]:
\t\t\t\t\treturn "capital: landmark %s has invalid interaction type" % landmark.get("name", "?")
\t\t\t\tif use_type == "action" and String(use.get("ref", "")) not in known_actions:
\t\t\t\t\treturn "capital: landmark action %s is not handled" % use.get("ref", "")
\t\tif not has_interaction:
\t\t\treturn "capital: zone %s has no interaction" % z.get("name", "?")
\t\tvar c: Array = z.get("coord", [])
\t\tvar key := "%d,%d" % [int(c[0]), int(c[1])]
\t\tif coords.has(key):
\t\t\treturn "capital: duplicate coord %s" % key
\t\tcoords[key] = true
\t\tfor npc in z.get("npcs", []):
\t\t\tif npc.has("convo") and not Story.ALL_CONVOS.has(String(npc["convo"])):
\t\t\t\treturn "capital: NPC convo %s not registered" % npc["convo"]
\t\t\tif npc.has("greet") and not Story.ALL_CONVOS.has(String(npc["greet"])):
\t\t\t\treturn "capital: NPC greet convo %s not registered" % npc["greet"]
\t\t\tif npc.has("action") and String(npc["action"]) not in known_actions:
\t\t\t\treturn "capital: NPC action %s is not handled" % npc["action"]
\t\t\tif Art.tex(String(npc["sprite"])) == null:
\t\t\t\treturn "capital: NPC sprite %s missing" % npc["sprite"]
\t\t\t# Gossip hubs: every hub_action a choice can fire must be handled.
\t\t\tif npc.has("convo"):
\t\t\t\tvar cv: Dictionary = Story.ALL_CONVOS.get(String(npc["convo"]), {})
\t\t\t\tfor nid in cv.get("nodes", {}):
\t\t\t\t\tfor chc in (cv["nodes"][nid] as Dictionary).get("choices", []):
\t\t\t\t\t\tif chc.has("hub_action") and String(chc["hub_action"]) not in known_actions:
\t\t\t\t\t\t\treturn "capital: gossip hub_action %s is not handled" % chc["hub_action"]
\treturn ""
'''

body = (header.replace("@START_X@", str(CX)).replace("@START_Y@", str(START_Y))
        .replace("@ZONES@", zones).replace("@CONVOS@", convos)
        .replace("@NZONES@", str(len(ROOMS)))
        .replace("@ACTIONS@", ", ".join('"%s"' % action for action in sorted(HUB_ACTIONS))))
open(OUT, "w", encoding="utf-8", newline="\n").write(body)
print("wrote", OUT)
print("zones:", len(ROOMS), "| convos:", len(CONVOS) + len(GOSSIP), "| start_pos:", [CX, START_Y])
