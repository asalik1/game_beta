extends RefCounted
const Context := preload("res://scripts/encounter_context.gd")

class Fixture extends Game:
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass

class Event extends Node2D:
	var game: Game
	var zone := 0
	var running := true
	func active() -> bool: return running


static func run(t: Node) -> String:
	var g := Fixture.new()
	var other := Fixture.new()
	t.add_child(g)
	t.add_child(other)
	g.world = Node2D.new()
	g.add_child(g.world)
	var event := Event.new()
	event.game = g
	event.set_meta("encounter_title", "A shared watch")
	g.world.add_child(event)
	event.add_to_group("optional_encounters")
	var error := _checks(g, other, event)
	g.free()
	other.free()
	if error == "":
		print("ok: optional encounters reserve only their own room/world, permit existing orders and ignore inactive, retired or other-session actors")
	return error


static func _checks(g: Game, other: Game, event: Event) -> String:
	if Context.blocking_name(g, 0) != "A shared watch":
		return "an active optional fight did not reserve its room"
	if Context.blocking_name(g, 1) != "" or Context.blocking_name(other, 0) != "" \
		or Context.blocking_name(g, 0, event) != "":
		return "an encounter blocked another room/world or its own existing orders"
	event.running = false
	if Context.blocking_name(g, 0) != "":
		return "a completed encounter kept the room reserved"
	event.running = true
	var old := g.world
	g.world = Node2D.new()
	g.add_child(g.world)
	if Context.blocking_name(g, 0) != "":
		return "an old world retained its encounter reservation"
	old.remove_child(event)
	g.world.add_child(event)
	old.free()
	event.queue_free()
	if Context.blocking_name(g, 0) != "":
		return "a retiring encounter blocked a new invitation"
	return ""
