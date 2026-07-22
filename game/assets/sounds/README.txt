Drop .wav or .ogg files here to override any synthesized sound effect.
Name them after the effect: stab.ogg, sword.ogg, bow.ogg, fireball.ogg,
blink.ogg, nova.ogg, slam.ogg, knife.ogg, hurt.ogg, ult_warrior.ogg...
Good free (CC0) sources: kenney.nl/assets (audio packs), freesound.org (filter by CC0).

Current sounds are from 'RPG Sound Pack' by artisticdude (OpenGameArt.org), CC0 public domain.
ult.wav / ult_mage.wav and meteor.wav from 'The Essential Retro Video Game Sound Effects
Collection' by Juhani Junkala (OpenGameArt.org), CC0 public domain.
roar_fangmaw.ogg: 'Wolf howls' from Wikimedia Commons, public domain.
Warrior/archer/assassin ultimates are synthesized in scripts/sfx.gd.
roar_morwen: SYNTHESIZED (sfx.gd _make_wail) — the RPG-pack clip was
replaced (user: bad); no witch-voice in any owned pack, so it's a
bespoke spectral wail, hag-sicklier than Vess's grief-keen.

GameSounds pack casts (purchased bundle, 2026-07-07 — commercial OK,
no raw-pack redistribution; user-approved casting):
  coin=Coin Pick up Sound · splash=Short Water P1 · gate=Door Sound ·
  bolt=Spell Cast V2 · nova=Water Magic Hit 2 · fireball=Fire Spell
  Cast V2 · ehit=Punch 1 (+4dB at call site) · potion=Drink Sound ·
  equip=Wearing Armor · parry=Sword Parry (aegis retaliation) ·
  ui_click=Button Click · gem=Collect P1 · campfire=Campfire Loop
  (positional, cottage hearths) · amb_birds/amb_crickets/amb_rain =
  Forest/Night/Rain Ambience Loops (override the synth beds) ·
  step_1..3 / step_armor_1..3 = Walking Hits / Armor Solo Hits
  (footstep system; plate classes clank).
Talk sounds from the pack were REJECTED (user: bad) — dialogue blip
stays synthesized. bow/arrow candidates rejected too.

Attack-audio review pass (2026-07-21): semantic override families use
<key>_v1, <key>_v2, ... filenames. Game.sfx("<key>") discovers the group,
randomizes it without immediate repeats, and retains the existing subtle pitch
jitter. Class changes from this pass are currently unwired for a separate,
original-by-original review. Bosses retain the approved earth, fire, frost,
storm-impact, and holy-impact candidates; individual boss moves select their
own cue so family material does not replace every attack indiscriminately. The
rejected shared void-cast family was removed: Vess now has two short synthesized
grief cues (initial fan + delayed memory), and Echo throws with the knife cue.
Storm casts, rot casts, and boss teleports use three synthesized non-repeating
variants apiece (electrical intake, damp root-strain, and heavy spatial rupture)
instead of the rejected generic/magical cues.
Whitepelt, Gardener, Cure-Twisted, and Saint Varo now use separately sourced
CC0 snarl/deep-roar/horror-screech/human-battle-roar recordings.
See CREDITS.txt for the shipped sources, licenses, and attribution.
