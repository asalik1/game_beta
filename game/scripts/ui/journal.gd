class_name UIJournal
## The Quest Log / journal. Static builder taking the Menus instance, like
## ui/mailbox.gd and ui/codex.gd. The game's live quest is a single active
## line (game.quest_key -> Story.ALL_QUESTS); this screen frames it with
## chapter boss progress, exploration, factions and Resonance so the
## player has one place to see "where am I and what's next".
## Reached from the HUD ⚑ (left of the quest tracker) and the pause menu.

const FACTION_NAME := {
	"accord": "The Accord", "cinderborn": "The Cinderborn",
	"wildfang": "The Wildfang", "choir": "The Hollow Choir",
}


static func open(m: Menus) -> void:
	var g := m.game
	var vbox := m._open("Quest Log — %s" % String(Story.chapter(g.chapter_id)["name"]), 860, 620)
	m.current = "journal"

	# --- current objective ---
	m._lbl(vbox, "— CURRENT OBJECTIVE —", 16, Color(0.95, 0.85, 0.5))
	var obj := Story.quest_text(g.quest_key)
	var ol := m._lbl(vbox, "◆  " + (obj if obj != "" else "Explore."), 16, Color(1, 1, 1))
	ol.custom_minimum_size = Vector2(800, 0)
	ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var zi: int = clampi(g.cur_room, 0, g.zone_count - 1)
	var left: int = g.zone_alive.get(zi, 0)
	if left > 0:
		m._lbl(vbox, "   This room: %d monster%s left to clear." % [left, "" if left == 1 else "s"],
			13, Color(0.8, 0.7, 0.5))

	# --- chapter boss checklist ---
	m._lbl(vbox, "— CHAPTER BOSSES —", 16, Color(1, 0.6, 0.6))
	var bosses := VBoxContainer.new()
	bosses.add_theme_constant_override("separation", 2)
	vbox.add_child(bosses)
	var seen := {}
	var any_boss := false
	for i in g.zone_count:
		var kind := String(g.zones[i].get("boss", ""))
		if kind == "" or seen.has(kind):
			continue
		seen[kind] = true
		any_boss = true
		var done: bool = g.boss_done.get(kind, false)
		var nm := String(Story.ALL_ENEMIES.get(kind, {}).get("name", kind))
		m._lbl(bosses, "%s  %s" % ["✓" if done else "○", nm],
			14, Color(0.6, 1.0, 0.6) if done else Color(0.85, 0.85, 0.9))
	if not any_boss:
		m._lbl(bosses, "None charted yet.", 13, Color(0.6, 0.62, 0.68))

	# --- exploration + resonance ---
	m._lbl(vbox, "— PROGRESS —", 16, Color(0.6, 0.9, 1.0))
	var visited := 0
	for i in g.zone_count:
		if g.visited.get(i, false):
			visited += 1
	m._lbl(vbox, "Rooms charted:  %d / %d" % [visited, g.zone_count], 14, Color(0.85, 0.88, 0.94))
	var res := int(g.player.resonance)
	var band := "Virtuous" if res > 20 else ("Tempted" if res < -20 else "Balanced")
	m._lbl(vbox, "Resonance:  %+d  (%s)" % [res, band], 14,
		Color(1.0, 0.85, 0.4) if res > 20 else (Color(0.7, 0.5, 0.95) if res < -20 else Color(0.85, 0.85, 0.9)))

	# --- factions ---
	m._lbl(vbox, "— STANDING —", 16, Color(0.8, 0.9, 0.7))
	for fid in g.player.faction_standing:
		var v: int = int(g.player.faction_standing[fid])
		if v == 0:
			continue
		var name: String = FACTION_NAME.get(fid, String(fid).capitalize())
		m._lbl(vbox, "%s:  %+d" % [name, v], 14,
			Color(0.7, 1.0, 0.7) if v > 0 else Color(1.0, 0.7, 0.6))
	var neutral := true
	for fid in g.player.faction_standing:
		if int(g.player.faction_standing[fid]) != 0:
			neutral = false
	if neutral:
		m._lbl(vbox, "No faction has taken your measure yet.", 13, Color(0.6, 0.62, 0.68))

	m._hint(vbox, "ESC to close")
