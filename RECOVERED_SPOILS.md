# Recovered Spoils

Unopened combat chests and ordinary loose coins now survive saves. Chests cache
their exact existing gear/supply roll; saving neither opens them nor pays them.
On resume, their contents arrive in a Recovered Spoils letter and saved coin
value goes directly to the purse. Leaving a world recovers its live spoils too.
Victory itself preserves the painted chest opening moment.

Authored exploration caches and buried chests retain their discovery/flag path.
Charged Gold Rush coins are temporary effects and are excluded. Personal rewards
ride the character save, including guest/endgame home saves, without carrying
foreign room coordinates. Applying a character retires old live reward sources,
so restoring in place cannot leave both the chest and its recovered contents.
Claims and recovery reserve their source before paying; gold applies the owner's
bonus once, with the same per-coin rounding as collection.

The mailbox now displays the actual material and potion art, names and stack
counts. Attachments scroll independently of claim/delete/back controls. Pack
capacity and “Claim what fits” explain partial collection. A full material stack
refuses an incoming payload without consuming excess units; the whole payload
stays in its letter or on the ground until it fits. The Codex also corrects its
obsolete claim that extra bags sell themselves automatically.

Implementation: scripts/loot_recovery.gd, chest.gd, save.gd, world teardown,
material receipt and ui/mailbox.gd. No new currency or reward-table changes.
NET_VERSION remains 0.3.10: this is owner-local persistence, with no new RPC.

Live QA also found that room-transition autosaves could write halfway through
loading a saved world. Resume/application now suppress those writes until the
restore finishes, and autosave honors the existing no_saves test/QA flag.

Validated: desktop 181-script compile, 108
quick and 188 full checks; mobile editor import,
181-script compile and 108 quick checks.
All 15 scoped sources match; three new script UID pairs independently generated.
Ten polished live captures prove disk recovery, exact contents, full/partial/
complete claims, no duplicate reload, real painted opening, departure recovery,
character-only home saves and large/touch letters. The first live load also
enables production autosaves and proves the file is not rewritten mid-restore.

Source preflight: zero failures, 11 existing structural/moved-number warnings;
no new art. Explicit paths staged, no commits. Logs and screenshots are under
build/qa/recovery-*. Reproduce with shot.bat loot_recovery --timeout=220.
