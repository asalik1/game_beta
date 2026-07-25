"""Generate game/scripts/content/capital_hub.gd — the standalone 25-room
Crownfall hub. Auto-derives exits from grid adjacency, verifies the graph is
one connected component, and emits the GDScript content module (CHAPTER const
+ per-NPC CONVOS). Plaza is room 0 at coord (0,0).

The layout is deliberately compact: a nine-room service heart, four distinct
three-room faction wards, one northern overlook, and a three-room gate
approach. Room scale is authored per zone so gathering spaces feel grand while
private chambers and single-purpose services do not waste a full map cell."""
import collections, sys

ROOM_W, ROOM_H = 2112, 1248
CX, CY = ROOM_W // 2, ROOM_H // 2  # 1056, 624

# Each room: (id, Name, gx, gy, terrain, room_scale, cast)
# cast entry: (sprite, prompt, ref, kind)
#   kind: "convo" | "action" | "hotspot"
#   convo -> ref is a convo id (text supplied in CONVOS below)
#   action -> ref is a hub action key handled by game._hub_action
#   hotspot -> action with an invisible interaction node over landmark art
P = "convo"; A = "action"; H = "hotspot"
HUB_ACTIONS = {
    "portal_story", "portal_crucible", "portal_depths",
    "vault", "codex", "daily", "map", "mail", "journal", "records",
    "guild", "skills", "gear", "shop", "potions", "wardrobe",
}
ROOMS = [
  # --- THE HEART: every everyday service is within one room of the plaza ---
  ("plaza","Crown Plaza",0,0,"capital_civic",1.00,[
      ("factor_imre","E — Ask for directions","cap_citizen",P)]),
  ("portal","Wayfinder Sanctum",0,-1,"capital_wayfinder",0.82,[]),
  # One gear destination: forge, gemcraft, and stash share an artisans' court.
  ("artisans","Artisans' Court",-1,-1,"capital_wayfinder",0.82,[
      ("smith_petra","E — Smith Petra","cap_petra",P),
      ("archivist_lene","E — Master Lapidary","cap_lapidary",P),
      ("capital_vault_chest","E — Open your vault","vault",A)]),
  ("archive","The Grand Archive",1,-1,"capital_civic",0.72,[]),
  ("guild","The Chartered Hall",-1,0,"capital_civic",0.64,[]),
  ("market","Crown Bazaar",1,0,"capital_civic",0.86,[
      ("clerk_voss","E — Claim the daily alms","daily",A)]),  # merchant field below
  # Cooking and alchemy belong together: both consume the garden's harvest.
  ("hearth","The Hearthworks",-1,1,"capital_civic",0.70,[
      ("old_fenna","E — Old Fenna","cap_fenna",P),
      ("apprentice_sorrel","E — Apprentice Sorrel","cap_sorrel",P)]),
  ("tankard","The Ashen Tankard",0,1,"capital_civic",0.68,[
      ("peddler_nix","E — Tavern Keeper Nix","cap_tankard",P)]),
  ("proving","The Proving Grounds",1,1,"capital_wayfinder",0.82,[
      ("warden_corin","E — Proving Marshal Corin","cap_arena",P)]),

  # --- NORTHERN OVERLOOK: a destination, not three duplicate ramparts ---
  ("rampart","Crownwatch Rampart",0,-2,"capital_approach",0.58,[
      ("warden_palla","E — Toll-Warden Palla","cap_palla",P)]),

  # --- WILDFANG ENCLAVE (NW): public moot, living green, old-city descent ---
  ("wf_moot","Fangmoot Circle",-2,-1,"capital_wildfang",0.78,[
      ("callis","E — Warden Callis","cap_callis",P),
      ("skald_ottar","E — Skald Ottar","cap_ottar",P)]),
  ("wf_warren","The Green Warren",-3,-1,"capital_wildfang",0.58,[
      ("npc_hunter","E — The Old Hunter","cap_hunter",P)]),
  ("wf_digger","Digger's Cut",-2,-2,"capital_wildfang",0.56,[
      ("digger_haim","E — Old Digger Haim","cap_haim",P)]),

  # --- CHOIR ENCLAVE (NE): faith, remembrance, and a warm infirmary ---
  ("ch_chapel","The Rot-Chapel",2,-1,"capital_choir",0.78,[
      ("cantor_ilse","E — Cantor Ilse","cap_ilse",P),
      ("deacon_vela","E — Deacon Vela","cap_vela",P)]),
  ("ch_waiting","The Waiting Hall",3,-1,"capital_choir",0.56,[
      ("brother_osk","E — Brother Osk","cap_osk",P),
      ("sera","E — Widow Sera","cap_sera",P)]),
  ("ch_suli","Suli's Hospice",2,-2,"capital_choir",0.58,[
      ("suli","E — Gentle Suli","cap_suli",P)]),

  # --- ACCORD WARD (SW): civic hearth, medicine, and shared water ---
  ("acc_commons","Accord Commons",-2,1,"capital_accord",0.78,[
      ("elder","E — Elder Maren","cap_maren",P),
      ("tinker_osla","E — Tinker Osla","cap_osla",P)]),
  ("acc_menders","The Menders' Row",-3,1,"capital_accord",0.58,[
      ("herbalist_kesh","E — Herbalist Kesh","cap_kesh",P)]),
  ("acc_well","The Wellspring",-2,2,"capital_accord",0.60,[
      ("fisher_dov","E — Fisher Dov","cap_dov",P)]),

  # --- CINDERBORN WARD (SE): court, industry, and disciplined memory ---
  ("cin_court","The Sable Court",2,1,"capital_cinderborn",0.78,[
      ("aldric","E — Ser Aldric","cap_aldric",P),
      ("vessa","E — Envoy Vessa","cap_vessa",P)]),
  ("cin_foundry","Compact Foundry",3,1,"capital_cinderborn",0.58,[
      ("overseer_brann","E — Overseer Brann","cap_brann",P)]),
  ("cin_bastion","The Keeper's Bastion",2,2,"capital_cinderborn",0.60,[
      ("keeper_vasse","E — Retired Keeper Vasse","cap_vasse",P),
      ("commander_ashe","E — Commander Ashe","cap_ashe",P)]),

  # --- SOUTHERN APPROACH: processional road, gate, compact stable yard ---
  ("causeway","Crown Causeway",0,2,"capital_approach",0.72,[
      ("warden_sighne","E — Warden Sighne","cap_sighne",P)]),
  ("gate","The Emberward Gate",0,3,"capital_approach",0.82,[
      ("warden_corin","E — Gate Sergeant Corin","cap_gate",P)]),
  ("stables","Emberward Stables",1,3,"capital_approach",0.56,[
      ("warden_palla","E — Ask about the road","cap_stables",P)]),
]

# merchant rooms (existing shop system): id -> [x,y]
MERCHANTS = {"market": [CX, 560]}

# Exact room-local landmark placement. The landmark, NPCs, and at most a few
# supporting props form a composed scene; capital rooms never inherit the
# terrain showcase's shuffled buildings/structures.
# tuple: (structure id, x, y, clearance radius)
LANDMARKS = {
    "plaza": [
        ("capital_crown_spire_gate", 1056, 525, 430),
        ("capital_crown_fountain", 1056, 720, 265),
        ("capital_city_directory", 1640, 850, 140),
    ],
    "portal": [
        ("capital_portal_story", 560, 560, 150),
        ("capital_portal_crucible", 1056, 560, 160),
        ("capital_portal_depths", 1552, 560, 145)],
    "artisans": [("capital_ashfire_forge", 610, 585, 270),
                  ("capital_grand_archive", 1500, 585, 235)],
    "archive": [("capital_grand_archive", 1056, 585, 285)],
    "guild": [("capital_chartered_hall", 1056, 590, 285)],
    "market": [("capital_market_stall", 620, 600, 215),
               ("capital_market_stall", 1492, 600, 215)],
    "hearth": [("great_hearth", 620, 560, 175),
               ("capital_alembic_station", 1492, 560, 205)],
    "tankard": [("capital_ashen_tankard", 1056, 590, 285)],
    "proving": [("capital_proving_gate", 1056, 560, 290)],
    "rampart": [("capital_watchtower", 1056, 560, 235)],
    "wf_moot": [("capital_wildfang_fangmoot", 1056, 570, 285)],
    "wf_warren": [("capital_accord_longhouse", 1056, 590, 300)],
    "wf_digger": [("capital_undercroft", 1056, 580, 270)],
    "ch_chapel": [("capital_rot_chapel", 1056, 590, 290)],
    "ch_waiting": [("capital_undercroft", 1056, 590, 260)],
    "ch_suli": [("capital_wellspring", 1056, 590, 265)],
    "acc_commons": [("capital_accord_longhouse", 1056, 590, 315)],
    "acc_menders": [("capital_wellspring", 1056, 590, 260)],
    "acc_well": [("capital_wellspring", 1056, 590, 280)],
    "cin_court": [("capital_sable_hall", 1056, 590, 315)],
    "cin_foundry": [("capital_ashfire_forge", 1056, 590, 285)],
    "cin_bastion": [("capital_grand_archive", 1056, 590, 285)],
    "causeway": [("capital_watchtower", 580, 560, 180),
                 ("capital_watchtower", 1532, 560, 180)],
    "gate": [("capital_emberward_gate", 1056, 560, 280)],
    "stables": [("capital_stables", 1056, 590, 315)],
}

# Wide connected architecture sits behind the accessible landmarks. It has no
# door/service affordance and no collider: existing room walls own the edge,
# while the open central arch frames the actual north road. This makes the city
# feel continuous without adding fake shops or invisible blockers.
# tuple: (sprite id, x, y, authored width)
BACKDROPS = {
    "portal": [("capital_city_arcade", 1056, 405, 1680)],
    "guild": [("capital_city_arcade", 1056, 405, 1680)],
    "market": [("capital_city_arcade", 1056, 405, 1680)],
    "hearth": [("capital_city_arcade", 1056, 405, 1680)],
    "tankard": [("capital_city_arcade", 1056, 405, 1680)],
    "proving": [("capital_city_arcade", 1056, 405, 1680)],
    "causeway": [("capital_city_arcade", 1056, 405, 1680)],
    "gate": [("capital_city_arcade", 1056, 405, 1680)],
}

# Exact supporting furniture. Capital rooms do not use generic furniture
# scatter: every bench has a deliberate social-space placement and enough
# clearance to remain inside the authored walls.
FURNISHINGS = {
    "plaza": [("capital_city_bench", 650, 825, 110),
              ("capital_city_bench", 1330, 825, 110)],
    "hearth": [("capital_city_bench", 1056, 820, 110)],
    "tankard": [("capital_city_bench", 760, 810, 110),
                ("capital_city_bench", 1352, 810, 110)],
    "acc_commons": [("capital_city_bench", 760, 815, 110),
                    ("capital_city_bench", 1352, 815, 110)],
    "acc_well": [("capital_city_bench", 760, 825, 110),
                 ("capital_city_bench", 1352, 825, 110)],
}

# Every foreground landmark owns its affordance. Actions open a real game
# surface or destination; inspect is reserved for genuine monuments/lookouts.
# A landmark may expose several separated stations (the archive has three).
# key: (room id, landmark index) -> list of typed use dictionaries.
def ACTION(prompt, ref, x=0, y=80):
    return {"type": "action", "prompt": prompt, "ref": ref, "x": x, "y": y}

def INSPECT(prompt, title, text, x=0, y=80):
    return {"type": "inspect", "prompt": prompt, "title": title,
            "text": text, "x": x, "y": y}

LANDMARK_USES = {
    ("plaza", 0): [ACTION("E — View services at the Crown Spire", "map", y=30)],
    ("plaza", 1): [INSPECT("E — Inspect the Crown Fountain", "Crown Fountain",
        "The four ward roads meet at this basin. Companies use its crown as the city's easiest rally point.", y=105)],
    ("plaza", 2): [ACTION("E — View the city map", "map", y=65)],
    ("portal", 0): [ACTION("E — Enter the Story Gate", "portal_story", y=30)],
    ("portal", 1): [ACTION("E — Enter the Crucible Gate", "portal_crucible", y=30)],
    ("portal", 2): [ACTION("E — Enter the Depths Gate", "portal_depths", y=30)],
    ("artisans", 0): [ACTION("E — Manage gear and reforging", "gear", y=70)],
    ("artisans", 1): [ACTION("E — Manage gems and sockets", "gear", y=70)],
    ("archive", 0): [
        ACTION("E — Browse the Codex", "codex", x=-170, y=100),
        ACTION("E — Read your journal", "journal", y=100),
        ACTION("E — Review your records", "records", x=170, y=100),
    ],
    ("guild", 0): [ACTION("E — Open Play Together", "guild", y=90)],
    # The shop stall doubles as the outfitter's: gold goods on one side,
    # the Renown Wardrobe (skins/chromas) on the other.
    ("market", 0): [ACTION("E — Browse the bazaar", "shop", x=-90, y=100),
                    ACTION("E — Browse the Wardrobe", "wardrobe", x=90, y=100)],
    ("market", 1): [ACTION("E — Check your mailbox", "mail", y=100)],
    ("hearth", 0): [INSPECT("E — Warm yourself", "The Great Hearth",
        "A public fire for cooking, waiting, and finding companions between expeditions.", y=90)],
    ("hearth", 1): [ACTION("E — Prepare your potion loadout", "potions", y=80)],
    ("tankard", 0): [ACTION("E — Find a company at the Tankard", "guild", y=95)],
    ("proving", 0): [ACTION("E — Open your skill tree", "skills", y=70)],
    ("rampart", 0): [INSPECT("E — Survey the rampart", "Crownwatch Rampart",
        "The watch records every caravan, returning company, and threat on the southern road.", y=75)],
    ("wf_moot", 0): [ACTION("E — Review Wildfang contracts", "journal", y=95)],
    ("wf_warren", 0): [ACTION("E — Find a hunting company", "guild", y=90)],
    ("wf_digger", 0): [ACTION("E — Descend into the Depths", "portal_depths", y=85)],
    ("ch_chapel", 0): [ACTION("E — Review Choir contracts", "journal", y=90)],
    ("ch_waiting", 0): [ACTION("E — Read the sleepers' roll", "records", y=85)],
    ("ch_suli", 0): [ACTION("E — Prepare your potion loadout", "potions", y=105)],
    ("acc_commons", 0): [ACTION("E — Review Accord contracts", "journal", y=95)],
    ("acc_menders", 0): [ACTION("E — Review gathering contracts", "journal", y=105)],
    ("acc_well", 0): [INSPECT("E — Inspect the Wellspring", "The Wellspring",
        "A civic reservoir, quiet meeting place, and the Accord ward's clean-water reserve.", y=105)],
    ("cin_court", 0): [ACTION("E — Review Cinderborn contracts", "journal", y=95)],
    ("cin_foundry", 0): [ACTION("E — Manage gear and reforging", "gear", y=95)],
    ("cin_bastion", 0): [ACTION("E — Review the keepers' records", "records", y=90)],
    ("causeway", 0): [INSPECT("E — Inspect the west watch", "Causeway Watch",
        "One half of the gate watch, positioned to keep the market road clear.", y=75)],
    ("causeway", 1): [INSPECT("E — Inspect the east watch", "Causeway Watch",
        "One half of the gate watch, positioned to keep the proving road clear.", y=75)],
    ("gate", 0): [ACTION("E — Leave Crownfall", "portal_story", y=80)],
    ("stables", 0): [ACTION("E — Ride back to the campaign", "portal_story", y=90)],
}

# Restrained supporting dressing. Landmarks and people carry the composition;
# these props only reinforce district material language. Counts are deliberately
# below combat-terrain density and scale again with the authored room footprint.
DISTRICT_SCENERY = {
    "heart":    {"obstacles": [], "decor": [], "count": 0, "decor_count": 0},
    "craft":    {"obstacles": [], "decor": [], "count": 0, "decor_count": 0},
    "civic":    {"obstacles": [], "decor": [], "count": 0, "decor_count": 0},
    "approach": {"obstacles": [], "decor": [], "count": 0, "decor_count": 0},
    "wild":     {"obstacles": [], "decor": [], "count": 0, "decor_count": 0},
    "choir":    {"obstacles": [], "decor": [], "count": 0, "decor_count": 0},
    "accord":   {"obstacles": [], "decor": [], "count": 0, "decor_count": 0},
    "cinder":   {"obstacles": [], "decor": [], "count": 0, "decor_count": 0},
    "outer":    {"obstacles": [], "decor": [], "count": 0, "decor_count": 0},
}

# District per room (colours the in-game capital map). Derived by id prefix +
# explicit for the core/civic/approach rooms.
_DISTRICT_EXPLICIT = {
    "plaza": "heart",
    "portal": "civic", "artisans": "craft", "hearth": "craft",
    "guild": "civic", "archive": "civic", "market": "civic",
    "tankard": "civic", "proving": "civic",
    "causeway": "approach", "gate": "approach", "stables": "approach",
    "rampart": "outer",
}
def district_of(rid):
    if rid in _DISTRICT_EXPLICIT: return _DISTRICT_EXPLICIT[rid]
    if rid.startswith("wf_"):  return "wild"
    if rid.startswith("ch_"):  return "choir"
    if rid.startswith("acc_"): return "accord"
    if rid.startswith("cin_"): return "cinder"
    return "civic"

# Map marks: spawn star, portal diamond, quest-giver dot.
_QUESTGIVERS = {"acc_commons","acc_menders","cin_court",
                "wf_moot","ch_chapel"}
def mark_of(rid):
    if rid == "plaza":  return "★"   # star
    if rid == "portal": return "◆"   # diamond
    if rid in _QUESTGIVERS: return "●"  # dot
    return ""

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
if set(LANDMARK_USES) != landmark_keys:
    sys.exit("LANDMARK_USES coverage mismatch — missing=%s extra=%s" %
             (sorted(landmark_keys - set(LANDMARK_USES)),
              sorted(set(LANDMARK_USES) - landmark_keys)))
for landmark_key, uses in LANDMARK_USES.items():
    if not uses:
        sys.exit("LANDMARK_USES has no affordance: %s" % (landmark_key,))
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
for district, scenery in DISTRICT_SCENERY.items():
    if "bench2" in scenery["obstacles"] or "garden_bench" in scenery["obstacles"]:
        sys.exit("legacy bench leaked into capital district %s" % district)
if len(LANDMARK_USES) != len(landmark_keys) or sum(map(len, FURNISHINGS.values())) < 8:
    sys.exit("capital polish coverage too low: landmark uses / furnishings")
print("OK: %d rooms, unique coords, single connected component" % len(ROOMS))

# ---------- emit GDScript ----------
# NPC local placement: the default station is in front of a centred landmark,
# not directly on top of its facade.
SLOTS = [(CX, CY+190), (CX-360, CY+90), (CX+360, CY+90), (CX-560, CY-140),
         (CX+560, CY-140), (CX, CY+220)]
PORTAL_SLOTS = [(CX-480, CY-30), (CX, CY-90), (CX+480, CY-30)]
NPC_SLOT_OVERRIDES = {
    # Keep the first citizen off the fountain silhouette; the portal action
    # cores sit directly in front of their three authored arches.
    "plaza": [(1400, 650), (1056, 850)],
    "portal": [(560, 590), (1056, 570), (1552, 590)],
    "market": [(720, 790), (1390, 790)],
    "archive": [(620, 760), (1056, 760), (1492, 760)],
    # Two-sided workshops and hearths read as a shared court, not a queue.
    "artisans": [(660, 690), (1450, 690), (1056, 800), (610, 520)],
    "hearth": [(650, 650), (1460, 650)],
    "proving": [(1056, 800), (1056, 535)],
    # Faction public rooms keep their two principals flanking the landmark.
    "wf_moot": [(720, 650), (1390, 650)],
    "ch_chapel": [(720, 650), (1390, 650)],
    "acc_commons": [(720, 650), (1390, 650)],
    "cin_court": [(720, 650), (1390, 650)],
    "cin_bastion": [(720, 650), (1390, 650)],
    "ch_waiting": [(720, 650), (1390, 650)],
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
        for use in LANDMARK_USES[(rid, landmark_index)]:
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
        '{"name": "%s", "x": %d, "y": %d, "w": %d}' % item
        for item in BACKDROPS.get(rid, [])
    ]
    lines.append('\t\t"backdrops": [%s],' % ", ".join(backdrop_lines))
    if rid in MERCHANTS:
        mx,my = MERCHANTS[rid]
        lines.append('\t\t"merchant": [%d, %d],' % (mx, my))
    if cast:
        npc_lines = []
        is_portal = any(k == A and ref.startswith("portal") for (_,_,ref,k) in cast)
        slots = NPC_SLOT_OVERRIDES.get(rid, PORTAL_SLOTS if is_portal else SLOTS)
        for j,(spr,prompt,ref,kind) in enumerate(cast):
            x,y = slots[j % len(slots)]
            if kind in [A, H]:
                hidden = ', "hidden": true' if rid == "portal" or kind == H else ''
                npc_lines.append('\t\t\t{"sprite": "%s", "x": %d, "y": %d, "prompt": "%s", "action": "%s"%s}'
                                 % (spr, x, y, prompt, ref, hidden))
            else:
                npc_lines.append('\t\t\t{"sprite": "%s", "x": %d, "y": %d, "prompt": "%s", "convo": "%s"}'
                                 % (spr, x, y, prompt, ref))
        lines.append('\t\t"npcs": [\n' + ",\n".join(npc_lines) + '],')
    else:
        lines.append('\t\t"npcs": [],')
    return "\n".join(lines) + "\n\t},"

# ---------- CONVOS: one short node per named NPC ----------
CONVOS = {
 "cap_citizen": ("A Citizen", "First visit? The Wayfinder gates are north. Your vault, forge, and lapidary share the northwest court; Codex east, bazaar southeast. The four faction wards begin at the corners. Meet your company back here when you're done."),
 "cap_petra": ("Smith Petra", "One court for one kit: blades and armour at my forge, stones at the lapidary opposite, personal vault between us. No more marching across Crownfall because one buckle and one gemstone answer to different roofs."),
 "cap_sorrel": ("Apprentice Sorrel", "Herbalist Kesh lets me mind the Alembic when she's at the Menders' Row. Don't touch the green one. ...You touched the green one."),
 "cap_fenna": ("Old Fenna", "Kitchen on this side, Alembic on that. Kesh's herbs become supper or medicine without crossing the square. Sit by the hearth if you're waiting on friends; someone always knows who just came through a gate."),
 "cap_arena": ("Proving Marshal Corin", "Crownfall's companies drill here before they take the northern gates. For live trials, use the Crucible arch in the Wayfinder Sanctum. For bragging, use the rail — everyone in the plaza can hear you from there."),
 "cap_lapidary": ("Master Lapidary", "Petra handles metal; I handle what lives inside it. Raw stones, synthesis, sockets, enchantment — all in this half of the court. Your vault chest is between our benches so nothing needs carrying through the streets."),
 "cap_tankard": ("Tavern Keeper", "The Ashen Tankard — warmth, rumour, a fire that behaves. The whole city drifts through after dark. First cup's on the house for a shard-bearer."),
 "cap_gate": ("Gate Sergeant", "The Emberward Gate. Portcullis stays up in peacetime; the wild stays out on its honour. You came in clean — most do."),
 "cap_sighne": ("Warden Sighne", "This causeway is the city's spine: gate south, plaza north, Tankard to the west and Proving Grounds east. I mark who comes and goes. You go a lot, by the look of that gear."),
 "cap_palla": ("Toll-Warden Palla", "Stamps, seals, the gate ledger. No toll for the crowned and shard-touched — the city's glad enough you came back breathing."),
 "cap_stables": ("Stable Warden Palla", "Mounts, messengers, and caravan tack stay in this little yard beside the gate — close to the road and out of the plaza. If you're leaving on foot, take the centre causeway and keep the watchfires to your right."),
 "cap_callis": ("Warden Callis", "The tribes hold this enclave by truce, not welcome. Honest work, then: survey what the Waking's made of the east, and bring us word. Daily, if you're able."),
 "cap_ottar": ("Skald Ottar", "A fire that never dies and a skald who never stops. Go do a thing worth singing — I'll trade you the doing for the song. Come back with a story."),
 "cap_hunter": ("The Old Hunter", "This green's transplanted wildwood — the city lets us keep a scrap of the world we came from. Sit. Watch the treeline. It watches back."),
 "cap_haim": ("Old Digger Haim", "Sank this shaft under the enclave, into the old city's bones. I know what's down there. Guiding costs — knowing's free: don't go alone."),
 "cap_ilse": ("Cantor Ilse", "The Choir does not bury its dead — rot is the land's honest truth, and the dead keep their own vigil here. Tend them with me. It's patient work. Daily work."),
 "cap_vela": ("Deacon Vela", "Quieter tasks than the Cantor's: recover a relic, carry a name north to the sleepers, witness a thing and return unbroken. The blight rewards the faithful."),
 "cap_osk": ("Brother Osk", "I tend the ones lying down to wait for the Waking. I was something else, before. Ask me nothing; the sleepers dislike questions."),
 "cap_suli": ("Gentle Suli", "Even a cold faith gets sick. I mend the Choir's living — the one warm corner of the enclave. You look whole. Stay that way out there."),
 "cap_sera": ("Widow Sera", "I keep the Sexton's Gate down into the undercroft, among the dead. I decide who goes. I mostly say no. ...You've the look of a yes."),
 "cap_maren": ("Elder Maren", "So — the shards still choosing, and the factions still counting. The Accord holds this ward and half this city's conscience. There's honest work daily, if you want it. Sit; the fire doesn't bite."),
 "cap_kesh": ("Herbalist Kesh", "The Menders' Row — cures for the ward, reagents for the Alembic. I set the day's gathering. Bring back the right leaves and no one dies of the wrong ones."),
 "cap_osla": ("Tinker Osla", "Osla's yard — half-mended things and honest barter. There — seated. You've a strong shoulder for someone armed to the teeth. Flame keep you."),
 "cap_dov": ("Fisher Dov", "Still fish the cistern-water, if you can believe it. Ansa watches a tide that isn't there and swears it'll come back. Maybe it will. Odd city, this."),
 "cap_aldric": ("Ser Aldric", "The Cinderborn keep the forms of a court that lost its crown. I keep its sword arm. There's work in the old key — recover, restore, avenge — for a crown that might yet find a head. Daily, if you've the stomach."),
 "cap_vessa": ("Envoy Vessa", "Work with us and be paid, protected, and remembered. I've a commission most days — a courier run, a quiet errand, imperial paper with teeth. First one's waiting."),
 "cap_brann": ("Overseer Brann", "Here's the honest ledger: the Compact reopened these foundries, best ore two years running. The Forge upstairs eats what we dig. Good trade, if you can haul."),
 "cap_vasse": ("Retired Keeper Vasse", "Pre-Vargoth history, all of it — the Cinderborn's whole claim, written in old ink. A crown is a thing that can be re-forged, if you read the right page. I guard the page."),
 "cap_ashe": ("Warden-Commander Ashe", "This bastion keeps both the old rolls and the soldiers who still answer them. Vasse guards the memory; I drill the line. Read if you came for history. Fall in if you came to make it."),
}

# ---------- content integrity before write ----------
used_convos = {ref for *_,ref,kind in (cast_item for *_,cast in ROOMS for cast_item in cast)
               if kind == P}
used_actions = {ref for *_,ref,kind in (cast_item for *_,cast in ROOMS for cast_item in cast)
                if kind in [A, H]}
used_actions.update(
    use["ref"]
    for uses in LANDMARK_USES.values()
    for use in uses
    if use["type"] == "action"
)
if used_convos != set(CONVOS):
    sys.exit("CONVO COVERAGE MISMATCH — %s" % sorted(used_convos ^ set(CONVOS)))
if not used_actions.issubset(HUB_ACTIONS):
    sys.exit("UNHANDLED HUB ACTIONS — %s" % sorted(used_actions - HUB_ACTIONS))
for rid,*_,scale,cast in ROOMS:
    if not 0.55 <= scale <= 1.0:
        sys.exit("INVALID ROOM SCALE — %s: %.2f" % (rid, scale))
    if rid not in LANDMARKS:
        sys.exit("ROOM HAS NO LANDMARK — %s" % rid)
    if not cast and rid not in MERCHANTS \
            and not any(key[0] == rid for key in LANDMARK_USES):
        sys.exit("ROOM HAS NO INTERACTION — %s" % rid)
print("OK: authored scale, landmark, interaction, convo, and action coverage")

# ---------- write the file ----------
zones = "\n".join(gd_zone(i, r) for i, r in enumerate(ROOMS))
convo_lines = []
for cid,(who,text) in CONVOS.items():
    t = text.replace('"', '\\"')
    convo_lines.append('\t"%s": {"start": "a", "nodes": {"a": {"who": "%s", "text": "%s", "next": ""}}},' % (cid, who, t))
convos = "\n".join(convo_lines)

OUT = r"C:/Users/asali/Projects/MMO/game/scripts/content/capital_hub.gd"
header = '''## capital_hub — Crownfall, the spawn-hub capital (2026-07-24). A STANDALONE
## 25-room authored city: a dense service heart, four compact faction wards,
## one northern overlook, and the southern gate approach. Dev-only for now —
## reached via the dev panel "Go To Capital" button (Story.chapter("capital")
## resolves this CHAPTER; game_world.switch_chapter allows it as a standalone).
##
## Fixed layout: every zone carries an authored "coord" + "exits", so
## game_world._prepare_rooms lays them out verbatim (no seeded spine). Authored
## room_scale makes social halls grand and single-purpose chambers intimate.
## All zones are "safe" (no packs). Exact landmarks and restrained district
## scenery replace inherited terrain scatter. NPCs use the ch2-hub data pattern;
## portal props leave for Story / Crucible / Depths, and civic interactables
## open the existing shop, gear, skills, social, mail, journal, records, vault,
## Codex, map, and daily-service screens.
## GENERATED by tools/content/gen_capital.py — edit the generator, not this file.
class_name CapitalHub

# The standalone world. Story.chapter("capital") returns this; it is kept OUT of
# CHAPTER_LIST so campaign machinery (chapter select, weekly rotation, act gating)
# never sees it — exactly like the endgame arenas.
const CHAPTER := {
\t"name": "Crownfall",
\t"sub": "A gathering city — services at the heart, four wards at the corners",
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
## furnished around a landmark, and has an interaction; NPC refs are wired.
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
\t\tvar landmark_interaction := false
\t\tfor landmark in z.get("landmarks", []):
\t\t\tvar uses: Array = landmark.get("uses", [])
\t\t\tif uses.is_empty():
\t\t\t\treturn "capital: landmark %s has no direct interaction" % landmark.get("name", "?")
\t\t\tlandmark_interaction = true
\t\t\tfor use in uses:
\t\t\t\tvar use_type := String(use.get("type", ""))
\t\t\t\tif use_type not in ["action", "inspect"]:
\t\t\t\t\treturn "capital: landmark %s has invalid interaction type" % landmark.get("name", "?")
\t\t\t\tif use_type == "action" and String(use.get("ref", "")) not in known_actions:
\t\t\t\t\treturn "capital: landmark action %s is not handled" % use.get("ref", "")
\t\tif z.get("npcs", []).is_empty() and not z.has("merchant") and not landmark_interaction:
\t\t\treturn "capital: zone %s has no interaction" % z.get("name", "?")
\t\tvar c: Array = z.get("coord", [])
\t\tvar key := "%d,%d" % [int(c[0]), int(c[1])]
\t\tif coords.has(key):
\t\t\treturn "capital: duplicate coord %s" % key
\t\tcoords[key] = true
\t\tfor npc in z.get("npcs", []):
\t\t\tif npc.has("convo") and not Story.ALL_CONVOS.has(String(npc["convo"])):
\t\t\t\treturn "capital: NPC convo %s not registered" % npc["convo"]
\t\t\tif npc.has("action") and String(npc["action"]) not in known_actions:
\t\t\t\treturn "capital: NPC action %s is not handled" % npc["action"]
\t\t\tif Art.tex(String(npc["sprite"])) == null:
\t\t\t\treturn "capital: NPC sprite %s missing" % npc["sprite"]
\treturn ""
'''

body = (header.replace("@START_X@", str(CX)).replace("@START_Y@", str(CY))
        .replace("@ZONES@", zones).replace("@CONVOS@", convos)
        .replace("@NZONES@", str(len(ROOMS)))
        .replace("@ACTIONS@", ", ".join('"%s"' % action for action in sorted(HUB_ACTIONS))))
open(OUT, "w", encoding="utf-8", newline="\n").write(body)
print("wrote", OUT)
print("zones:", len(ROOMS), "| convos:", len(CONVOS), "| start_pos:", [CX, CY])
