## A branch off the village; appended so existing room/save indices stay stable.
const CHAPTER_ZONES := {"ch1": [{
	"name": "Stillwater Reach", "terrain": "village", "type": "safe",
	"coord": [-1, 1], "exits": ["E"],
	"after_waking": true,  # old weekly-run saves keep their breach indices
	"river": {"chance": 1.0, "color": Color(0.10, 0.28, 0.30, 0.84)},
	"enemies": [], "boss": "", "npcs": [], "buildings": [],
}]}
