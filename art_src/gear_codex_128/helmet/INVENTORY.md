# Helmet regeneration inventory

Source of truth: `../manifest.json` and `game/scripts/items.gd`. This slice has
30 families, 90 authored B/A/S variants, and 60 named uniques: 180 assets.

| Class | Family | Neutral | B | A | S | Named A | Named S |
|---|---|---|---|---|---|---|---|
| Archer | Beastpelt Hood | `h_beastpelt_hood` | `h_beastpelt_hood_B` | `h_beastpelt_hood_A` | `h_beastpelt_hood_S` | Oldhide Hood (`u_oldhide_hood`) | First Beast, Hood of the Last Gale (`u_first_beast_hood_of_the_last_gale`) |
| Paladin | Blessed Greathelm | `h_blessed_greathelm` | `h_blessed_greathelm_B` | `h_blessed_greathelm_A` | `h_blessed_greathelm_S` | Saintglass Greathelm (`u_saintglass_greathelm`) | Unshadowed, Greathelm of the Final Oath (`u_unshadowed_greathelm_of_the_final_oath`) |
| Warlock | Bloodpact Hood | `h_bloodpact_hood` | `h_bloodpact_hood_B` | `h_bloodpact_hood_A` | `h_bloodpact_hood_S` | Veinbound Hood (`u_veinbound_hood`) | Last Pulse, Hood Beneath All Names (`u_last_pulse_hood_beneath_all_names`) |
| Warlock | Bonemail Hood | `h_bonemail_hood` | `h_bonemail_hood_B` | `h_bonemail_hood_A` | `h_bonemail_hood_S` | Gravebone Hood (`u_gravebone_hood`) | Ossuary King, Hood Beneath All Names (`u_ossuary_king_hood_beneath_all_names`) |
| Mage | Earthen Circlet | `h_earthen_circlet` | `h_earthen_circlet_B` | `h_earthen_circlet_A` | `h_earthen_circlet_S` | Faultstone Circlet (`u_faultstone_circlet`) | Worldmantle, Circlet Beyond the Firmament (`u_worldmantle_circlet_beyond_the_firmament`) |
| Mage | Featherweave Circlet | `h_featherweave_circlet` | `h_featherweave_circlet_B` | `h_featherweave_circlet_A` | `h_featherweave_circlet_S` | Skyquill Circlet (`u_skyquill_circlet`) | Zero Weight, Circlet Beyond the Firmament (`u_zero_weight_circlet_beyond_the_firmament`) |
| Assassin | Gossamer Cowl | `h_gossamer_cowl` | `h_gossamer_cowl_B` | `h_gossamer_cowl_A` | `h_gossamer_cowl_S` | Mothsilk Cowl (`u_mothsilk_cowl`) | Pale Web, Cowl Between Heartbeats (`u_pale_web_cowl_between_heartbeats`) |
| Assassin | Grave Cowl | `h_grave_cowl` | `h_grave_cowl_B` | `h_grave_cowl_A` | `h_grave_cowl_S` | Pale Bone Cowl (`u_pale_bone_cowl`) | Returning Dead, Cowl Between Heartbeats (`u_returning_dead_cowl_between_heartbeats`) |
| Archer | Hunter's Hood | `h_hunters_hood` | `h_hunters_hood_B` | `h_hunters_hood_A` | `h_hunters_hood_S` | Red Quarry Hood (`u_red_quarry_hood`) | Last Hunt, Hood of the Last Gale (`u_last_hunt_hood_of_the_last_gale`) |
| Warrior | Ironwall Helm | `h_ironwall_helm` | `h_ironwall_helm_B` | `h_ironwall_helm_A` | `h_ironwall_helm_S` | Gatebrow Helm (`u_gatebrow_helm`) | Unbroken, Helm of the Crownless Host (`u_unbroken_helm_of_the_crownless_host`) |
| Assassin | Nightsilk Cowl | `h_nightsilk_cowl` | `h_nightsilk_cowl_B` | `h_nightsilk_cowl_A` | `h_nightsilk_cowl_S` | Red Fold Cowl (`u_red_fold_cowl`) | Last Shadow, Cowl Between Heartbeats (`u_last_shadow_cowl_between_heartbeats`) |
| Archer | Ranger's Hood | `h_rangers_hood` | `h_rangers_hood_B` | `h_rangers_hood_A` | `h_rangers_hood_S` | Windfeather Hood (`u_windfeather_hood`) | White Wind, Hood of the Last Gale (`u_white_wind_hood_of_the_last_gale`) |
| Warrior | Reaver Helm | `h_reaver_helm` | `h_reaver_helm_B` | `h_reaver_helm_A` | `h_reaver_helm_S` | Red Antler Helm (`u_red_antler_helm`) | Warhowl, Helm of the Crownless Host (`u_warhowl_helm_of_the_crownless_host`) |
| Warlock | Ruinweave Hood | `h_ruinweave_hood` | `h_ruinweave_hood_B` | `h_ruinweave_hood_A` | `h_ruinweave_hood_S` | Black Clause Hood (`u_black_clause_hood`) | Ruin's Testament, Hood Beneath All Names (`u_ruins_testament_hood_beneath_all_names`) |
| Mage | Runeplate Circlet | `h_runeplate_circlet` | `h_runeplate_circlet_B` | `h_runeplate_circlet_A` | `h_runeplate_circlet_S` | Hexplate Circlet (`u_hexplate_circlet`) | Axiom Guard, Circlet Beyond the Firmament (`u_axiom_guard_circlet_beyond_the_firmament`) |
| Paladin | Sanctified Greathelm | `h_sanctified_greathelm` | `h_sanctified_greathelm_B` | `h_sanctified_greathelm_A` | `h_sanctified_greathelm_S` | Dawnstone Greathelm (`u_dawnstone_greathelm`) | First Dawn, Greathelm of the Final Oath (`u_first_dawn_greathelm_of_the_final_oath`) |
| Warlock | Shadeweave Hood | `h_shadeweave_hood` | `h_shadeweave_hood_B` | `h_shadeweave_hood_A` | `h_shadeweave_hood_S` | Hushshade Hood (`u_hushshade_hood`) | Shadow Without Owner, Hood Beneath All Names (`u_shadow_without_owner_hood_beneath_all_names`) |
| Assassin | Shadowveil Cowl | `h_shadowveil_cowl` | `h_shadowveil_cowl_B` | `h_shadowveil_cowl_A` | `h_shadowveil_cowl_S` | Hushveil Cowl (`u_hushveil_cowl`) | Empty Witness, Cowl Between Heartbeats (`u_empty_witness_cowl_between_heartbeats`) |
| Mage | Silkward Circlet | `h_silkward_circlet` | `h_silkward_circlet_B` | `h_silkward_circlet_A` | `h_silkward_circlet_S` | Wardthread Circlet (`u_wardthread_circlet`) | White Theorem, Circlet Beyond the Firmament (`u_white_theorem_circlet_beyond_the_firmament`) |
| Warrior | Skirmisher's Helm | `h_skirmishers_helm` | `h_skirmishers_helm_B` | `h_skirmishers_helm_A` | `h_skirmishers_helm_S` | Windcut Helm (`u_windcut_helm`) | No Horizon, Helm of the Crownless Host (`u_no_horizon_helm_of_the_crownless_host`) |
| Mage | Starweave Circlet | `h_starweave_circlet` | `h_starweave_circlet_B` | `h_starweave_circlet_A` | `h_starweave_circlet_S` | Cometweave Circlet (`u_cometweave_circlet`) | Ninth Star, Circlet Beyond the Firmament (`u_ninth_star_circlet_beyond_the_firmament`) |
| Archer | Stormweave Hood | `h_stormweave_hood` | `h_stormweave_hood_B` | `h_stormweave_hood_A` | `h_stormweave_hood_S` | Stormneedle Hood (`u_stormneedle_hood`) | Tempest Crown, Hood of the Last Gale (`u_tempest_crown_hood_of_the_last_gale`) |
| Archer | Studded Hood | `h_studded_hood` | `h_studded_hood_B` | `h_studded_hood_A` | `h_studded_hood_S` | Rivetleaf Hood (`u_rivetleaf_hood`) | Ironwood Witness, Hood of the Last Gale (`u_ironwood_witness_hood_of_the_last_gale`) |
| Paladin | Templar Greathelm | `h_templar_greathelm` | `h_templar_greathelm_B` | `h_templar_greathelm_A` | `h_templar_greathelm_S` | Oathiron Greathelm (`u_oathiron_greathelm`) | Last Templar, Greathelm of the Final Oath (`u_last_templar_greathelm_of_the_final_oath`) |
| Warrior | Titan Helm | `h_titan_helm` | `h_titan_helm_B` | `h_titan_helm_A` | `h_titan_helm_S` | Mountainheart Helm (`u_mountainheart_helm`) | Stonefather, Helm of the Crownless Host (`u_stonefather_helm_of_the_crownless_host`) |
| Paladin | Vigil Greathelm | `h_vigil_greathelm` | `h_vigil_greathelm_B` | `h_vigil_greathelm_A` | `h_vigil_greathelm_S` | Swiftvow Greathelm (`u_swiftvow_greathelm`) | Vigil Without End, Greathelm of the Final Oath (`u_vigil_without_end_greathelm_of_the_final_oath`) |
| Warlock | Voidsilk Hood | `h_voidsilk_hood` | `h_voidsilk_hood_B` | `h_voidsilk_hood_A` | `h_voidsilk_hood_S` | Nullsilk Hood (`u_nullsilk_hood`) | Oblivion Veil, Hood Beneath All Names (`u_oblivion_veil_hood_beneath_all_names`) |
| Assassin | Warded Cowl | `h_warded_cowl` | `h_warded_cowl_B` | `h_warded_cowl_A` | `h_warded_cowl_S` | Sealhand Cowl (`u_sealhand_cowl`) | Closed Door, Cowl Between Heartbeats (`u_closed_door_cowl_between_heartbeats`) |
| Warrior | Wardsteel Helm | `h_wardsteel_helm` | `h_wardsteel_helm_B` | `h_wardsteel_helm_A` | `h_wardsteel_helm_S` | Spellscar Helm (`u_spellscar_helm`) | Nullward, Helm of the Crownless Host (`u_nullward_helm_of_the_crownless_host`) |
| Paladin | Zealot Greathelm | `h_zealot_greathelm` | `h_zealot_greathelm_B` | `h_zealot_greathelm_A` | `h_zealot_greathelm_S` | Censure Greathelm (`u_censure_greathelm`) | Final Censure, Greathelm of the Final Oath (`u_final_censure_greathelm_of_the_final_oath`) |

The Blessed Greathelm row is the approved benchmark. The remaining 174 assets
are intentionally not generated until the seven slot benchmarks align.
