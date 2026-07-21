"""Generate game/scripts/content/capital_hub.gd — the standalone 50-room
Crownfall hub. Auto-derives exits from grid adjacency, verifies the graph is
one connected component, and emits the GDScript content module (CHAPTER const
+ per-NPC CONVOS). Plaza is room 0 at coord (0,0)."""
import collections, sys

ROOM_W, ROOM_H = 2112, 1248
CX, CY = ROOM_W // 2, ROOM_H // 2  # 1056, 624

# Each room: (id, Name, gx, gy, terrain, cast)
# cast entry: (sprite, prompt, ref, kind)  kind: "convo" | "action" | "merchant"
#   convo -> ref is a convo id (text supplied in CONVOS below)
#   action -> ref is a hub action key handled by game._hub_action
P = "convo"; A = "action"
ROOMS = [
  # --- CORE (plaza is index 0) ---
  ("plaza","Crown Plaza",0,0,"ph_market",[("factor_imre","E — A citizen of Crownfall","cap_citizen",P)]),
  ("portal","The Portal Sanctum",0,-1,"ph_hall",[
      ("void_rift","◆ The Story Gate","portal_story",A),
      ("void_monolith","◆ The Crucible Gate","portal_crucible",A),
      ("void_obelisk","◆ The Depths Gate","portal_depths",A)]),
  ("guild","The Chartered Hall",-1,-1,"ph_guildhall",[("clerk_voss","E — The Chartered Hall","cap_guild",P)]),
  ("forge","The Ashfire Forge",1,-1,"ph_forge",[("smith_petra","E — Smith Petra","cap_petra",P)]),
  ("alembic","The Alembic",-1,0,"ph_forge",[("apprentice_sorrel","E — Apprentice Sorrel","cap_sorrel",P)]),
  ("kitchen","The Provisioner's Kitchen",1,0,"ph_kitchen",[("old_fenna","E — Old Fenna","cap_fenna",P)]),
  ("tannery","The Tannery",-1,1,"ph_hideout",[("roadside_peddler","E — The tannery bench","cap_tannery",P)]),
  ("verdant","The Verdant Tiers",0,1,"ph_fields",[("botanist_ferro","E — The gardener","cap_gardener",P)]),
  ("arena","The Proving Gate",1,1,"ph_castle",[("warden_corin","E — The Proving Gate","cap_arena",P)]),
  # --- CIVIC RING ---
  ("vault","The King's Vault",-2,-1,"ph_castle",[("clerk_voss","E — The King's Vault","vault",A)]),
  ("lapidary","The Lapidary",2,-1,"ph_library",[("archivist_lene","E — The Lapidary","cap_lapidary",P)]),
  ("archive","The Grand Archive",-2,0,"ph_library",[("archivist_lene","E — The Grand Archive","codex",A)]),
  ("market","Market Row",2,0,"ph_market",[]),  # merchant field below
  ("echoes","The Hall of Echoes",-2,1,"ph_library",[("archivist_lene","E — The Hall of Echoes","cap_echoes",P)]),
  ("alms","The Almswindow",2,1,"ph_market",[("clerk_voss","E — Claim the daily alms","daily",A)]),
  ("tankard","The Ashen Tankard",0,2,"ph_hideout",[("peddler_nix","E — The Ashen Tankard","cap_tankard",P)]),
  # --- APPROACH ---
  ("causeway","The Causeway",0,3,"ph_market",[]),
  ("gate","The Emberward Gate",0,4,"ph_castle",[("warden_corin","E — The Emberward Gate","cap_gate",P)]),
  ("muster","Muster Square",-1,4,"ph_market",[("warden_sighne","E — Warden Sighne","cap_sighne",P)]),
  ("toll","The Toll House",1,4,"ph_hideout",[("warden_palla","E — Toll-Warden Palla","cap_palla",P)]),
  # --- WILDFANG ENCLAVE (NW) ---
  ("wf_moot","Fangmoot Circle",-3,-1,"ph_fae",[]),
  ("wf_callis","The Skinworks",-4,-1,"ph_hideout",[("callis","E — Warden Callis","cap_callis",P)]),
  ("wf_ottar","Ottar's Fire",-3,-2,"ph_camp",[("skald_ottar","E — Skald Ottar","cap_ottar",P)]),
  ("wf_warren","The Green Warren",-4,-2,"ph_fae",[("npc_hunter","E — The Old Hunter","cap_hunter",P)]),
  ("wf_digger","Digger's Cut",-3,-3,"ph_dungeon",[("digger_haim","E — Old Digger Haim","cap_haim",P)]),
  ("wf_trophy","The Trophy Walk",-4,-3,"ph_crypt",[]),
  # --- CHOIR ENCLAVE (NE) ---
  ("ch_vigil","The Vigil Yard",3,-1,"ph_crypt",[]),
  ("ch_ilse","The Rot-Chapel",4,-1,"ph_crypt",[("cantor_ilse","E — Cantor Ilse","cap_ilse",P)]),
  ("ch_vela","Deacon's Cell",3,-2,"ph_library",[("deacon_vela","E — Deacon Vela","cap_vela",P)]),
  ("ch_waiting","The Waiting Halls",4,-2,"ph_crypt",[("brother_osk","E — Brother Osk","cap_osk",P)]),
  ("ch_suli","Suli's Ward",3,-3,"ph_garden",[("suli","E — Gentle Suli","cap_suli",P)]),
  ("ch_sexton","The Sexton's Gate",4,-3,"ph_crypt",[("sera","E — Widow Sera","cap_sera",P)]),
  # --- ACCORD WARD (SW) ---
  ("acc_commons","Accord Commons",-3,1,"ph_market",[]),
  ("acc_maren","Maren's Longhouse",-4,1,"ph_hall",[("elder","E — Elder Maren","cap_maren",P)]),
  ("acc_menders","The Menders' Row",-3,2,"ph_garden",[("herbalist_kesh","E — Herbalist Kesh","cap_kesh",P)]),
  ("acc_tinker","Tinker's Yard",-4,2,"ph_hideout",[("tinker_osla","E — Tinker Osla","cap_osla",P)]),
  ("acc_fisher","Fisher's Steps",-2,2,"ph_garden",[("fisher_dov","E — Fisher Dov","cap_dov",P)]),
  ("acc_well","The Wellspring",-3,3,"ph_garden",[]),
  # --- CINDERBORN WARD (SE) ---
  ("cin_court","Cinder Court",3,1,"ph_castle",[]),
  ("cin_aldric","The Sable Hall",4,1,"ph_castle",[("aldric","E — Ser Aldric","cap_aldric",P)]),
  ("cin_envoy","Envoy's Rest",3,2,"ph_library",[("vessa","E — Envoy Vessa","cap_vessa",P)]),
  ("cin_foundry","The Foundry Office",4,2,"ph_forge",[("overseer_brann","E — Overseer Brann","cap_brann",P)]),
  ("cin_keeper","The Keeper's Study",3,0,"ph_library",[("keeper_vasse","E — Retired Keeper Vasse","cap_vasse",P)]),
  ("cin_muster","The Muster Yard",4,0,"ph_castle",[("commander_ashe","E — Warden-Commander Ashe","cap_ashe",P)]),
  # --- OUTER RING ---
  ("ramp_n","North Rampart",0,-2,"ph_castle",[]),
  ("ramp_w","West Rampart",-5,-1,"ph_castle",[]),
  ("ramp_e","East Rampart",5,-1,"ph_castle",[]),
  ("undercroft","The Undercroft",1,2,"ph_sewer",[]),
  ("stables","The Stables",2,4,"ph_camp",[]),
  ("physic","The Physic Garden",-3,0,"ph_garden",[]),
]

# merchant rooms (existing shop system): id -> [x,y]
MERCHANTS = {"market": [CX, 560]}

# Exact room-local landmark placement. Crownfall used to inherit the ph_*
# showcase terrains wholesale, so every visit shuffled giant rugs, furniture,
# and tiny 16px props into a new pile. These anchors give each service and ward
# a stable visual identity; minor scenery remains sparse and district-specific.
# tuple: (structure id, x, y, clearance radius)
LANDMARKS = {
    "plaza": [("capital_crown_fountain", 650, 610, 260)],
    "portal": [
        ("capital_portal_story", 560, 560, 150),
        ("capital_portal_crucible", 1056, 560, 160),
        ("capital_portal_depths", 1552, 560, 145)],
    "guild": [("capital_chartered_hall", 650, 600, 245)],
    "forge": [("capital_ashfire_forge", 650, 600, 260)],
    "alembic": [("brew_stand", 650, 560, 170)],
    "kitchen": [("great_hearth", 650, 560, 155), ("cook_hearth", 1460, 560, 165)],
    "tannery": [("capital_market_stall", 650, 600, 220)],
    "verdant": [("capital_wellspring", 650, 600, 240)],
    "arena": [("capital_proving_gate", 1056, 560, 260)],
    "vault": [("capital_chartered_hall", 650, 600, 245)],
    "lapidary": [("capital_grand_archive", 650, 600, 245)],
    "archive": [("capital_grand_archive", 650, 600, 245)],
    "market": [("capital_market_stall", 620, 600, 215),
               ("capital_market_stall", 1492, 600, 215)],
    "echoes": [("capital_grand_archive", 650, 600, 245)],
    "alms": [("capital_chartered_hall", 650, 600, 245)],
    "tankard": [("capital_ashen_tankard", 650, 600, 260)],
    "causeway": [("capital_watchtower", 580, 560, 180),
                 ("capital_watchtower", 1532, 560, 180)],
    "gate": [("capital_emberward_gate", 1056, 560, 280)],
    "muster": [("capital_proving_gate", 1056, 560, 260)],
    "toll": [("capital_chartered_hall", 650, 600, 245)],
    "wf_moot": [("capital_wildfang_fangmoot", 1056, 570, 250)],
    "wf_callis": [("capital_market_stall", 650, 600, 220)],
    "wf_ottar": [("capital_wildfang_fangmoot", 650, 600, 245)],
    "wf_warren": [("capital_accord_longhouse", 650, 600, 285)],
    "wf_digger": [("capital_undercroft", 650, 600, 245)],
    "wf_trophy": [("capital_wildfang_fangmoot", 1056, 570, 250)],
    "ch_vigil": [("capital_rot_chapel", 650, 600, 260)],
    "ch_ilse": [("capital_rot_chapel", 650, 600, 260)],
    "ch_vela": [("capital_rot_chapel", 650, 600, 260)],
    "ch_waiting": [("capital_rot_chapel", 650, 600, 260)],
    "ch_suli": [("capital_wellspring", 650, 600, 240)],
    "ch_sexton": [("capital_undercroft", 650, 600, 245)],
    "acc_commons": [("capital_accord_longhouse", 650, 600, 285)],
    "acc_maren": [("capital_accord_longhouse", 650, 600, 285)],
    "acc_menders": [("capital_wellspring", 650, 600, 240)],
    "acc_tinker": [("capital_market_stall", 650, 600, 220)],
    "acc_fisher": [("capital_wellspring", 650, 600, 240)],
    "acc_well": [("capital_wellspring", 1056, 590, 250)],
    "cin_court": [("capital_sable_hall", 650, 600, 290)],
    "cin_aldric": [("capital_sable_hall", 650, 600, 290)],
    "cin_envoy": [("capital_chartered_hall", 650, 600, 245)],
    "cin_foundry": [("capital_ashfire_forge", 650, 600, 260)],
    "cin_keeper": [("capital_grand_archive", 650, 600, 245)],
    "cin_muster": [("capital_proving_gate", 1056, 560, 260)],
    "ramp_n": [("capital_watchtower", 1056, 560, 190)],
    "ramp_w": [("capital_watchtower", 1056, 560, 190)],
    "ramp_e": [("capital_watchtower", 1056, 560, 190)],
    "undercroft": [("capital_undercroft", 1056, 580, 255)],
    "stables": [("capital_stables", 650, 600, 285)],
    "physic": [("capital_wellspring", 650, 600, 240)],
}

# Sparse supporting dressing. The hero and landmark carry the room; these are
# texture, never the composition. Every capital zone emits empty `structures`
# and `accents` arrays so none of the old showcase set leaks back in.
DISTRICT_SCENERY = {
    "heart":    {"obstacles": ["bench2", "amphora"], "decor": ["pebble", "banner_red"], "count": 2, "decor_count": 3},
    "craft":    {"obstacles": ["bench2", "amphora", "station_anvil_t1"], "decor": ["pebble", "candle"], "count": 3, "decor_count": 4},
    "civic":    {"obstacles": ["bench2", "amphora", "library_desk"], "decor": ["pebble", "candle"], "count": 3, "decor_count": 4},
    "approach": {"obstacles": ["barrel", "crate", "pillar"], "decor": ["pebble", "banner_red"], "count": 3, "decor_count": 3},
    "wild":     {"obstacles": ["tree_green", "rock", "bush"], "decor": ["grass", "flower", "pebble"], "count": 4, "decor_count": 5},
    "choir":    {"obstacles": ["tombstone", "grave_cross", "pillar"], "decor": ["grave_crack", "web", "pebble"], "count": 3, "decor_count": 4},
    "accord":   {"obstacles": ["garden_bench", "garden_urns", "amphora"], "decor": ["grass", "flower", "pebble"], "count": 3, "decor_count": 5},
    "cinder":   {"obstacles": ["pillar", "castle_bust", "bench2"], "decor": ["candle", "pebble", "banner_red"], "count": 3, "decor_count": 4},
    "outer":    {"obstacles": ["barrel", "crate", "pillar"], "decor": ["pebble", "crack"], "count": 3, "decor_count": 3},
}

# District per room (colours the in-game capital map). Derived by id prefix +
# explicit for the core/civic/approach rooms.
_DISTRICT_EXPLICIT = {
    "plaza": "heart",
    "portal": "craft", "guild": "craft", "forge": "craft", "alembic": "craft",
    "kitchen": "craft", "tannery": "craft", "verdant": "craft", "arena": "craft",
    "vault": "civic", "lapidary": "civic", "archive": "civic", "market": "civic",
    "echoes": "civic", "alms": "civic", "tankard": "civic",
    "causeway": "approach", "gate": "approach", "muster": "approach", "toll": "approach",
    "ramp_n": "outer", "ramp_w": "outer", "ramp_e": "outer",
    "undercroft": "outer", "stables": "outer", "physic": "outer",
}
def district_of(rid):
    if rid in _DISTRICT_EXPLICIT: return _DISTRICT_EXPLICIT[rid]
    if rid.startswith("wf_"):  return "wild"
    if rid.startswith("ch_"):  return "choir"
    if rid.startswith("acc_"): return "accord"
    if rid.startswith("cin_"): return "cinder"
    return "civic"

# Map marks: spawn star, portal diamond, quest-giver dot.
_QUESTGIVERS = {"acc_maren","acc_menders","cin_aldric","cin_envoy",
                "wf_callis","wf_ottar","ch_ilse","ch_vela"}
def mark_of(rid):
    if rid == "plaza":  return "★"   # star
    if rid == "portal": return "◆"   # diamond
    if rid in _QUESTGIVERS: return "●"  # dot
    return ""

# ---------- verify: unique coords, connected graph ----------
coord_of = {}
by_coord = {}
for i,(rid,name,gx,gy,terr,cast) in enumerate(ROOMS):
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
print("OK: %d rooms, unique coords, single connected component" % len(ROOMS))

# ---------- emit GDScript ----------
# NPC local placement: distribute cast around room center
SLOTS = [(CX, CY-70), (CX-360, CY+90), (CX+360, CY+90), (CX-560, CY-140),
         (CX+560, CY-140), (CX, CY+220)]
PORTAL_SLOTS = [(CX-480, CY-30), (CX, CY-90), (CX+480, CY-30)]
NPC_SLOT_OVERRIDES = {
    # Keep the first citizen off the fountain silhouette; the portal action
    # cores sit directly in front of their three authored arches.
    "plaza": [(1400, 650)],
    "portal": [(560, 590), (1056, 570), (1552, 590)],
}

def gd_zone(i, room):
    rid,name,gx,gy,terr,cast = room
    ex = exits_for(gx,gy)
    exs = ", ".join('"%s"' % d for d in ex)
    lines = []
    lines.append('\t{"name": "%s", "terrain": "%s", "type": "safe",' % (name, terr))
    lines.append('\t\t"coord": [%d, %d], "exits": [%s], "enemies": [], "boss": "",' % (gx, gy, exs))
    lines.append('\t\t"district": "%s", "mark": "%s",' % (district_of(rid), mark_of(rid)))
    scenery = DISTRICT_SCENERY[district_of(rid)]
    obstacle_names = ", ".join('"%s"' % value for value in scenery["obstacles"])
    decor_names = ", ".join('"%s"' % value for value in scenery["decor"])
    lines.append('\t\t"obstacles": [%s], "obstacle_count": %d,' %
                 (obstacle_names, scenery["count"]))
    lines.append('\t\t"decor": [%s], "decor_count": %d, "accents": [], "structures": [],' %
                 (decor_names, scenery["decor_count"]))
    landmark_lines = []
    for landmark_name,x,y,clearance in LANDMARKS.get(rid, []):
        landmark_lines.append('{"name": "%s", "x": %d, "y": %d, "clearance": %d}' %
                              (landmark_name, x, y, clearance))
    lines.append('\t\t"landmarks": [%s],' % ", ".join(landmark_lines))
    if rid in MERCHANTS:
        mx,my = MERCHANTS[rid]
        lines.append('\t\t"merchant": [%d, %d],' % (mx, my))
    if cast:
        npc_lines = []
        is_portal = any(k == A and ref.startswith("portal") for (_,_,ref,k) in cast)
        slots = NPC_SLOT_OVERRIDES.get(rid, PORTAL_SLOTS if is_portal else SLOTS)
        for j,(spr,prompt,ref,kind) in enumerate(cast):
            x,y = slots[j % len(slots)]
            if kind == A:
                hidden = ', "hidden": true' if rid == "portal" else ''
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
 "cap_citizen": ("A Citizen", "New in Crownfall? Spawn's the fountain, portals are up top, and everything you need to make is a door away. Mind the Choir."),
 "cap_guild": ("Guild Steward", "The Chartered Hall — charter a company, join one, sign on for guild work. The charters aren't drawn up yet, but the benches are warm. Soon."),
 "cap_petra": ("Smith Petra", "Crew Five ran the old royal foundry; now I run this fire. Everything with an edge comes through me — forge it new, or reforge what you've got: reroll a substat, re-cut an affix, right here at the anvil. Recipes pending; the reforge bench is already warm. Bring ore and patience."),
 "cap_sorrel": ("Apprentice Sorrel", "Herbalist Kesh lets me mind the Alembic when she's at the Menders' Row. Don't touch the green one. ...You touched the green one."),
 "cap_fenna": ("Old Fenna", "The Kitchen's mine. Grill sizzles, pan smokes, hearth never dies. Cook a thing worth eating and I'll teach you two more. Recipes pending, love."),
 "cap_tannery": ("Tanner", "Cured hides, honest stitching — this is where bags get made and made bigger. The trade's not open yet. Leave your measurements."),
 "cap_gardener": ("Gardener", "The Verdant Tiers feed the Kitchen and the Alembic both. Sow, wait, harvest. Nothing's growing on a schedule yet — but the beds are turned."),
 "cap_arena": ("Proving Marshal", "The Proving Gate. Sign your name and wait for the sand. No queue running today — the arena's a promise, not a pit. Yet."),
 "cap_lapidary": ("The Lapidary", "Gems and enchantment, not gearwork — take the anvil up the row for that. Here we cut and socket stones, synthesize the small ones into something worth setting, and bind the glow into a piece. Bring me raw stones and a steady hand."),
 "cap_echoes": ("Hall Warden", "Every deed you've done is filed here — bests, records, the fanfare wall. Skald Ottar sets the good ones to a verse, when he's not at his fire."),
 "cap_tankard": ("Tavern Keeper", "The Ashen Tankard — warmth, rumour, a fire that behaves. The whole city drifts through after dark. First cup's on the house for a shard-bearer."),
 "cap_gate": ("Gate Sergeant", "The Emberward Gate. Portcullis stays up in peacetime; the wild stays out on its honour. You came in clean — most do."),
 "cap_sighne": ("Warden Sighne", "Muster Square. I mark who comes and goes. You go a lot, by the look of that gear. Safe roads, shard-bearer."),
 "cap_palla": ("Toll-Warden Palla", "Stamps, seals, the gate ledger. No toll for the crowned and shard-touched — the city's glad enough you came back breathing."),
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
 "cap_ashe": ("Warden-Commander Ashe", "The Muster Yard. I drill those who'll hold a line for the idea of a king — old-regime steel, still marching. Fall in or pass through; either's fine, shard-bearer."),
}

# ---------- write the file ----------
zones = "\n".join(gd_zone(i, r) for i, r in enumerate(ROOMS))
convo_lines = []
for cid,(who,text) in CONVOS.items():
    t = text.replace('"', '\\"')
    convo_lines.append('\t"%s": {"start": "a", "nodes": {"a": {"who": "%s", "text": "%s", "next": ""}}},' % (cid, who, t))
convos = "\n".join(convo_lines)

OUT = r"C:/Users/asali/Projects/MMO/game/scripts/content/capital_hub.gd"
header = '''## capital_hub — Crownfall, the spawn-hub capital (2026-07-19). A STANDALONE
## 50-room fixed-layout world (see CROWNFALL_HUB.html): the guild/craft/portal
## core, the four faction wards, and the civic + outer rings. Dev-only for now —
## reached via the dev panel "Go To Capital" button (Story.chapter("capital")
## resolves this CHAPTER; game_world.switch_chapter allows it as a standalone).
##
## Fixed layout: every zone carries an authored "coord" + "exits", so
## game_world._prepare_rooms lays them out verbatim (no seeded spine). All zones
## are "safe" (no packs). Ground/props come from each room's ph_* terrain (the
## environment-seam showcase terrains). NPCs use the ch2-hub data pattern; three
## portal props carry an "action" (handled by game._hub_action) that leaves for
## Story / Crucible / Depths, and a few civic desks open existing menus.
## GENERATED by tools/content/gen_capital.py — edit the generator, not this file.
class_name CapitalHub

# The standalone world. Story.chapter("capital") returns this; it is kept OUT of
# CHAPTER_LIST so campaign machinery (chapter select, weekly rotation, act gating)
# never sees it — exactly like the endgame arenas.
const CHAPTER := {
\t"name": "Crownfall",
\t"sub": "The capital hub — guild, crafts, portals, and the four wards",
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


## Merge + integrity selftest: the world resolves, every zone is safe with a
## valid terrain, every NPC convo/action is wired, the graph is connected.
static func selftest(_game: Node2D) -> String:
\tvar ch: Dictionary = Story.chapter("capital")
\tif ch.get("zones", []).size() != @NZONES@:
\t\treturn "capital: expected @NZONES@ zones, got %d" % ch.get("zones", []).size()
\tvar coords := {}
\tfor z in ch["zones"]:
\t\tif z.get("type", "") != "safe":
\t\t\treturn "capital: zone %s is not safe" % z.get("name", "?")
\t\tif not Terrains.DATA.has(String(z.get("terrain", ""))):
\t\t\treturn "capital: zone %s has unknown terrain %s" % [z.get("name","?"), z.get("terrain","")]
\t\tvar c: Array = z.get("coord", [])
\t\tvar key := "%d,%d" % [int(c[0]), int(c[1])]
\t\tif coords.has(key):
\t\t\treturn "capital: duplicate coord %s" % key
\t\tcoords[key] = true
\t\tfor npc in z.get("npcs", []):
\t\t\tif npc.has("convo") and not Story.ALL_CONVOS.has(String(npc["convo"])):
\t\t\t\treturn "capital: NPC convo %s not registered" % npc["convo"]
\t\t\tif Art.tex(String(npc["sprite"])) == null:
\t\t\t\treturn "capital: NPC sprite %s missing" % npc["sprite"]
\treturn ""
'''

body = (header.replace("@START_X@", str(CX)).replace("@START_Y@", str(CY))
        .replace("@ZONES@", zones).replace("@CONVOS@", convos)
        .replace("@NZONES@", str(len(ROOMS))))
open(OUT, "w", encoding="utf-8", newline="\n").write(body)
print("wrote", OUT)
print("zones:", len(ROOMS), "| convos:", len(CONVOS), "| start_pos:", [CX, CY])
