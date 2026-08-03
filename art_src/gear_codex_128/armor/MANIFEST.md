# Armor high-resolution regeneration manifest

This slice owns the 180 `armor` entries in
[`../manifest.json`](../manifest.json): 30 neutral families, 90 authored B/A/S
grades, and 60 named A/S uniques. The JSON manifest is the machine-readable
source of truth; this table records the class grouping and family-level audit.

Approved transparent masters belong in `alpha/<key>.png`. Untouched built-in
ImageGen chroma sources belong in `generated/<key>.png`, and the exact prompts
belong in `prompts/<key>.txt`. Runtime assets are intentionally out of scope
until benchmark approval.

| Class | Family noun | Neutral key | B key | A key | S key | Named A unique | Named S unique | Status |
|---|---|---|---|---|---|---|---|---|
| Warrior | Wardsteel Plate | `a_wardsteel_plate` | `a_wardsteel_plate_B` | `a_wardsteel_plate_A` | `a_wardsteel_plate_S` | Spellscar Cuirass (`u_spellscar_cuirass`) | Null Crown, Plate of the Silent Siege (`u_null_crown_plate_of_the_silent_siege`) | benchmark built |
| Warrior | Ironwall Plate | `a_ironwall_plate` | `a_ironwall_plate_B` | `a_ironwall_plate_A` | `a_ironwall_plate_S` | Stone's Refusal (`u_stones_refusal`) | Last Rampart, Armor That Would Not Fall (`u_last_rampart_armor_that_would_not_fall`) | pending |
| Warrior | Skirmisher's Halfplate | `a_skirmishers_halfplate` | `a_skirmishers_halfplate_B` | `a_skirmishers_halfplate_A` | `a_skirmishers_halfplate_S` | Fleet Iron (`u_fleet_iron`) | Windcut, Halfplate of the Uncaught (`u_windcut_halfplate_of_the_uncaught`) | pending |
| Warrior | Bloodforged Harness | `a_bloodforged_harness` | `a_bloodforged_harness_B` | `a_bloodforged_harness_A` | `a_bloodforged_harness_S` | Red Maw Harness (`u_red_maw_harness`) | The Armor That Bites Back (`u_the_armor_that_bites_back`) | pending |
| Warrior | Titanplate | `a_titanplate` | `a_titanplate_B` | `a_titanplate_A` | `a_titanplate_S` | Mountain's Burden (`u_mountains_burden`) | Worldweight, Plate of the First Giant (`u_worldweight_plate_of_the_first_giant`) | pending |
| Archer | Stormweave Jerkin | `a_stormweave_jerkin` | `a_stormweave_jerkin_B` | `a_stormweave_jerkin_A` | `a_stormweave_jerkin_S` | Gale-Sewn Jack (`u_gale_sewn_jack`) | Eye of the Tempest, Jerkin of Still Air (`u_eye_of_the_tempest_jerkin_of_still_air`) | pending |
| Archer | Studded Brigandine | `a_studded_brigandine` | `a_studded_brigandine_B` | `a_studded_brigandine_A` | `a_studded_brigandine_S` | Thousand-Nail Vest (`u_thousand_nail_vest`) | Rainwall, Brigandine of the Last Volley (`u_rainwall_brigandine_of_the_last_volley`) | pending |
| Archer | Ranger's Leathers | `a_rangers_leathers` | `a_rangers_leathers_B` | `a_rangers_leathers_A` | `a_rangers_leathers_S` | Hartshadow Leathers (`u_hartshadow_leathers`) | Greenwood Ghost, Hide of the Unseen Trail (`u_greenwood_ghost_hide_of_the_unseen_trail`) | pending |
| Archer | Hunter's Harness | `a_hunters_harness` | `a_hunters_harness_B` | `a_hunters_harness_A` | `a_hunters_harness_S` | Whitefang Rig (`u_whitefang_rig`) | Apex Covenant, Harness of the First Hunt (`u_apex_covenant_harness_of_the_first_hunt`) | pending |
| Archer | Beastpelt | `a_beastpelt` | `a_beastpelt_B` | `a_beastpelt_A` | `a_beastpelt_S` | Moonclaw Pelt (`u_moonclaw_pelt`) | Winterking's Mantle (`u_winterking_mantle`) | pending |
| Assassin | Shadowveil Cloak | `a_shadowveil_cloak` | `a_shadowveil_cloak_B` | `a_shadowveil_cloak_A` | `a_shadowveil_cloak_S` | Knife-Shadow Cloak (`u_knife_shadow_cloak`) | Eclipse's Hem, Cloak of No Witness (`u_eclipses_hem_cloak_of_no_witness`) | pending |
| Assassin | Warded Mantle | `a_warded_mantle` | `a_warded_mantle_B` | `a_warded_mantle_A` | `a_warded_mantle_S` | Nine-Seal Mantle (`u_nine_seal_mantle`) | Unanswerable, Mantle of the Closed Door (`u_unanswerable_mantle_of_the_closed_door`) | pending |
| Assassin | Gossamer Cloak | `a_gossamer_cloak` | `a_gossamer_cloak_B` | `a_gossamer_cloak_A` | `a_gossamer_cloak_S` | Widowglass Veil (`u_widowglass_veil`) | Pale Web, Cloak Between Heartbeats (`u_pale_web_cloak_between_heartbeats`) | pending |
| Assassin | Nightsilk Wrap | `a_nightsilk_wrap` | `a_nightsilk_wrap_B` | `a_nightsilk_wrap_A` | `a_nightsilk_wrap_S` | Red Fold (`u_red_fold`) | Last Shadow, Wrap of the Absent Hand (`u_last_shadow_wrap_of_the_absent_hand`) | pending |
| Assassin | Verdant Shroud | `a_verdant_shroud` | `a_verdant_shroud_B` | `a_verdant_shroud_A` | `a_verdant_shroud_S` | Thornshade Shroud (`u_thornshade_shroud`) | Green Silence, Shroud of the Hollow Grove (`u_green_silence_shroud_of_the_hollow_grove`) | pending |
| Mage | Silk Vestments | `a_silk_vestments` | `a_silk_vestments_B` | `a_silk_vestments_A` | `a_silk_vestments_S` | Equation Robe (`u_equation_robe`) | White Theorem, Vestments of Proof (`u_white_theorem_vestments_of_proof`) | pending |
| Mage | Runeplate Robe | `a_runeplate_robe` | `a_runeplate_robe_B` | `a_runeplate_robe_A` | `a_runeplate_robe_S` | Hexwall Cassock (`u_hexwall_cassock`) | Axiom Guard, Robe of Nine Locks (`u_axiom_guard_robe_of_nine_locks`) | pending |
| Mage | Featherweave Robe | `a_featherweave_robe` | `a_featherweave_robe_B` | `a_featherweave_robe_A` | `a_featherweave_robe_S` | Skyquill Robe (`u_skyquill_robe`) | Zero Weight, Raiment Above Gravity (`u_zero_weight_raiment_above_gravity`) | pending |
| Mage | Starweave Robe | `a_starweave_robe` | `a_starweave_robe_B` | `a_starweave_robe_A` | `a_starweave_robe_S` | Comet Sash (`u_comet_sash`) | Eventide, Robe of the Last Constellation (`u_eventide_robe_of_the_last_constellation`) | pending |
| Mage | Earthen Robe | `a_earthen_robe` | `a_earthen_robe_B` | `a_earthen_robe_A` | `a_earthen_robe_S` | Faultscribe Robe (`u_faultscribe_robe`) | Worldmantle, Vestment of the First Stone (`u_worldmantle_vestment_of_the_first_stone`) | pending |
| Paladin | Templar Plate | `a_templar_plate` | `a_templar_plate_B` | `a_templar_plate_A` | `a_templar_plate_S` | Blue Oath Cuirass (`u_blue_oath_cuirass`) | Covenant Crownplate (`u_covenant_crownplate`) | pending |
| Paladin | Blessed Plate | `a_blessed_plate` | `a_blessed_plate_B` | `a_blessed_plate_A` | `a_blessed_plate_S` | Rose Chapel Plate (`u_rose_chapel_plate`) | Noonheart, Armor of First Light (`u_noonheart_armor_of_first_light`) | pending |
| Paladin | Vigil Halfplate | `a_vigil_halfplate` | `a_vigil_halfplate_B` | `a_vigil_halfplate_A` | `a_vigil_halfplate_S` | Watcher's Halfplate (`u_watchers_halfplate`) | Unblinking, Plate of the Last Vigil (`u_unblinking_plate_of_the_last_vigil`) | pending |
| Paladin | Zealot Harness | `a_zealot_harness` | `a_zealot_harness_B` | `a_zealot_harness_A` | `a_zealot_harness_S` | Red Doctrine (`u_red_doctrine`) | Martyrfire Harness (`u_martyrfire_harness`) | pending |
| Paladin | Sanctified Bulwark | `a_sanctified_bulwark` | `a_sanctified_bulwark_B` | `a_sanctified_bulwark_A` | `a_sanctified_bulwark_S` | Gate-Shrine Armor (`u_gate_shrine_armor`) | Holy City, Bulwark of the Walking Cathedral (`u_holy_city_bulwark_of_the_walking_cathedral`) | pending |
| Warlock | Voidsilk Robe | `a_voidsilk_robe` | `a_voidsilk_robe_B` | `a_voidsilk_robe_A` | `a_voidsilk_robe_S` | Black Equation Robe (`u_black_equation_robe`) | Event Horizon, Vestment of No Return (`u_event_horizon_vestment_of_no_return`) | pending |
| Warlock | Bonemail | `a_bonemail` | `a_bonemail_B` | `a_bonemail_A` | `a_bonemail_S` | Pale Covenant (`u_pale_covenant`) | Ossuary King, Mail of the First Grave (`u_ossuary_king_mail_of_the_first_grave`) | pending |
| Warlock | Shadeweave Robe | `a_shadeweave_robe` | `a_shadeweave_robe_B` | `a_shadeweave_robe_A` | `a_shadeweave_robe_S` | Mothshade Robe (`u_mothshade_robe`) | The Shadow That Remained (`u_the_shadow_that_remained`) | pending |
| Warlock | Ruinweave | `a_ruinweave` | `a_ruinweave_B` | `a_ruinweave_A` | `a_ruinweave_S` | Broken Law Vestment (`u_broken_law_vestment`) | Catastrophe Script (`u_catastrophe_script`) | pending |
| Warlock | Bloodpact Vestment | `a_bloodpact_vestment` | `a_bloodpact_vestment_B` | `a_bloodpact_vestment_A` | `a_bloodpact_vestment_S` | Red Contract (`u_red_contract`) | Last Pulse, Vestment of the Final Debt (`u_last_pulse_vestment_of_the_final_debt`) | pending |

## Benchmark acceptance notes

- Built-in ImageGen only; PixelLab was not used.
- Wardsteel neutral/B/A/S preserve one recognizable high-gorget, layered-shoulder,
  torso-plate family identity while escalating construction and contained magic.
- Spellscar Cuirass and Null Crown are independent silhouettes and constructions,
  but both remain immediately readable as torso plate armor.
- The first Null Crown draft was rejected because faux null script resembled
  readable lettering. The accepted regeneration uses non-textual bars, diamonds,
  and chevrons only.
- Chroma removal uses border auto-key, soft matte, and despill. Candidate building
  uses the shared gamma/extent pipeline; runtime icons remain untouched.
