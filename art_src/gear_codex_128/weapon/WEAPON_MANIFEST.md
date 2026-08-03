# Weapon high-resolution regeneration manifest

Source of truth: `art_src/gear_codex_128/manifest.json`, cross-checked against
`Items.CLASS_WEAPONS`, weapon rows in `Items.UNIQUES`, and
`Art.GEAR_SHAPES["weapon"]` on 2026-08-03.

- 6 classes
- 30 weapon families
- 30 neutral family masters
- 90 authored B/A/S grade masters
- 60 named A/S unique masters
- 180 exact runtime keys total

The table below inventories every weapon deliverable. The shared JSON manifest
is authoritative for automation; this file is the human review index.

| Class | Family | Neutral | B | A | S | Named A | Named S |
|---|---|---|---|---|---|---|---|
| Archer | Hunting Bow | `w_hunting_bow` | `w_hunting_bow_B` | `w_hunting_bow_A` | `w_hunting_bow_S` | Foxfire String (`u_foxfire_string`) | The White Hart's Last Breath (`u_the_white_harts_last_breath`) |
| Archer | Longbow | `w_longbow` | `w_longbow_B` | `w_longbow_A` | `w_longbow_S` | Far-Witness (`u_far_witness`) | Skyline, the Arrow Before Dawn (`u_skyline_the_arrow_before_dawn`) |
| Archer | Recurve | `w_recurve` | `w_recurve_B` | `w_recurve_A` | `w_recurve_S` | Hornsong (`u_hornsong`) | Moonturn, Bow of Returning Night (`u_moonturn_bow_of_returning_night`) |
| Archer | Thornbow | `w_thornbow` | `w_thornbow_B` | `w_thornbow_A` | `w_thornbow_S` | Briar Covenant (`u_briar_covenant`) | Green Ruin, Root of the First Wild (`u_green_ruin_root_of_the_first_wild`) |
| Archer | Warbow | `w_warbow` | `w_warbow_B` | `w_warbow_A` | `w_warbow_S` | Siegebough (`u_siegebough`) | Tempest Yew, Bow of the Last Gale (`u_tempest_yew_bow_of_the_last_gale`) |
| Assassin | Cleaver | `w_cleaver` | `w_cleaver_B` | `w_cleaver_A` | `w_cleaver_S` | Red Arithmetic (`u_red_arithmetic`) | Headsman's Mercy (`u_headsmans_mercy`) |
| Assassin | Glasswing | `w_glasswing` | `w_glasswing_B` | `w_glasswing_A` | `w_glasswing_S` | Mothknife (`u_mothknife`) | Pale Flight, Blade Between Heartbeats (`u_pale_flight_blade_between_heartbeats`) |
| Assassin | Shuriken | `w_shuriken` | `w_shuriken_B` | `w_shuriken_A` | `w_shuriken_S` | Widow's Compass (`u_widows_compass`) | End of Night (`u_end_of_night`) |
| Assassin | Stiletto | `w_stiletto` | `w_stiletto_B` | `w_stiletto_A` | `w_stiletto_S` | Silkneedle (`u_silkneedle`) | Quietus, the King's Final Thought (`u_quietus_the_kings_final_thought`) |
| Assassin | Warded Fang | `w_warded_fang` | `w_warded_fang_B` | `w_warded_fang_A` | `w_warded_fang_S` | Parryshade (`u_parryshade`) | The Hand That Refused Death (`u_the_hand_that_refused_death`) |
| Mage | Bloomstaff | `w_bloomstaff` | `w_bloomstaff_B` | `w_bloomstaff_A` | `w_bloomstaff_S` | Springwake (`u_springwake`) | Verdancy, Staff of the Worldroot (`u_verdancy_staff_of_the_worldroot`) |
| Mage | Greatstaff | `w_greatstaff` | `w_greatstaff_B` | `w_greatstaff_A` | `w_greatstaff_S` | Atlas Branch (`u_atlas_branch`) | Firmament, the Heaven-Bearing Staff (`u_firmament_the_heaven_bearing_staff`) |
| Mage | Scepter | `w_scepter` | `w_scepter_B` | `w_scepter_A` | `w_scepter_S` | Wardpiercer (`u_wardpiercer`) | Axiom, Scepter of the Broken Law (`u_axiom_scepter_of_the_broken_law`) |
| Mage | Starfocus | `w_starfocus` | `w_starfocus_B` | `w_starfocus_A` | `w_starfocus_S` | Comet's Eye (`u_comets_eye`) | The Ninth Star, Unblinking (`u_the_ninth_star_unblinking`) |
| Mage | Zephyr Rod | `w_zephyr_rod` | `w_zephyr_rod_B` | `w_zephyr_rod_A` | `w_zephyr_rod_S` | Quickweather (`u_quickweather`) | Breathless, Rod of the Empty Sky (`u_breathless_rod_of_the_empty_sky`) |
| Paladin | Aegis Mace | `w_aegis_mace` | `w_aegis_mace_B` | `w_aegis_mace_A` | `w_aegis_mace_S` | Chapel Knell (`u_chapel_knell`) | The Bastion's Answer (`u_the_bastions_answer`) |
| Paladin | Duelist's Blade | `w_duelists_blade` | `w_duelists_blade_B` | `w_duelists_blade_A` | `w_duelists_blade_S` | Mercy in Measure (`u_mercy_in_measure`) | First Light, Edge of the Vigil (`u_first_light_edge_of_the_vigil`) |
| Paladin | Lance | `w_lance` | `w_lance_B` | `w_lance_A` | `w_lance_S` | Vowspike (`u_vowspike`) | Noonday, Lance of the Unshadowed (`u_noonday_lance_of_the_unshadowed`) |
| Paladin | Oathflail | `w_oathflail` | `w_oathflail_B` | `w_oathflail_A` | `w_oathflail_S` | Bell of Censure (`u_bell_of_censure`) | Absolution, the Last Toll (`u_absolution_the_last_toll`) |
| Paladin | Warmaul | `w_warmaul` | `w_warmaul_B` | `w_warmaul_A` | `w_warmaul_S` | Pilgrim's Burden (`u_pilgrims_burden`) | Dawnfall, Hammer of the Final Oath (`u_dawnfall_hammer_of_the_final_oath`) |
| Warlock | Grimheart Staff | `w_grimheart_staff` | `w_grimheart_staff_B` | `w_grimheart_staff_A` | `w_grimheart_staff_S` | Veinroot (`u_veinroot`) | Red Reliquary, Staff of the Last Pulse (`u_red_reliquary_staff_of_the_last_pulse`) |
| Warlock | Grimoire | `w_grimoire` | `w_grimoire_B` | `w_grimoire_A` | `w_grimoire_S` | Ink of Teeth (`u_ink_of_teeth`) | The Book That Remembers You (`u_the_book_that_remembers_you`) |
| Warlock | Hexblade | `w_hexblade` | `w_hexblade_B` | `w_hexblade_A` | `w_hexblade_S` | Debtcollector (`u_debtcollector`) | Black Clause, Edge of the Final Bargain (`u_black_clause_edge_of_the_final_bargain`) |
| Warlock | Pactshield Codex | `w_pactshield_codex` | `w_pactshield_codex_B` | `w_pactshield_codex_A` | `w_pactshield_codex_S` | Bound Witness (`u_bound_witness`) | The Cover Between Worlds (`u_the_cover_between_worlds`) |
| Warlock | Whisper Rod | `w_whisper_rod` | `w_whisper_rod_B` | `w_whisper_rod_A` | `w_whisper_rod_S` | Hushbone (`u_hushbone`) | The Name Beneath All Names (`u_the_name_beneath_all_names`) |
| Warrior | Bulwark Blade | `w_bulwark_blade` | `w_bulwark_blade_B` | `w_bulwark_blade_A` | `w_bulwark_blade_S` | Bastion's Tooth (`u_bastions_tooth`) | The Gate That Walks (`u_the_gate_that_walks`) |
| Warrior | Claymore | `w_claymore` | `w_claymore_B` | `w_claymore_A` | `w_claymore_S` | Gravesong (`u_gravesong`) | Crownfall, the Kingdom's End (`u_crownfall_the_kingdoms_end`) |
| Warrior | Pike | `w_pike` | `w_pike_B` | `w_pike_A` | `w_pike_S` | The Red Pennon (`u_the_red_pennon`) | Crownspike, the Last Decree (`u_crownspike_the_last_decree`) |
| Warrior | Saber | `w_saber` | `w_saber_B` | `w_saber_A` | `w_saber_S` | Ashrider (`u_ashrider`) | Red Horizon (`u_red_horizon`) |
| Warrior | Warblade | `w_warblade` | `w_warblade_B` | `w_warblade_A` | `w_warblade_S` | Marchbreaker (`u_marchbreaker`) | Throneless, Edge of the Last Host (`u_throneless_edge_of_the_last_host`) |

## Approved benchmark

The Pike row is the accepted production benchmark. Its six untouched chroma
sources live in `generated/`, transparent masters in `alpha/`, and exact prompts
in `prompts/`. Rejected thin-silhouette family attempts are retained under
`generated/rejected_pass1/` and `prompts/rejected_pass1/`.

The builder produced candidate-only outputs under
`tmp/gear_codex_128/weapon/`; runtime assets were not installed.
