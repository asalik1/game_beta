extends Node
## Mobile touch-input state — autoload singleton `MobileInput`.
##
## MULTIPLAYER.md §6/§10: the simulation reads ONLY the player's `intent_*`
## fields; the keyboard poller (player_core.gd::_poll_local_intents) is just one
## filler. On mobile the touch HUD (scripts/ui/touch_hud.gd) writes held state
## here every frame, and _poll_local_intents OR-s it into the SAME intents — so
## the sim (and the netcode) can't tell a tapped ability button from a pressed
## key. This is pure presentation glue: zero gameplay code forks per platform.
##
## Held state only. The one-shot target-LOCK edge is NOT routed through here —
## the lock button writes `game.local_player.intent_lock` directly (exactly like
## hud.gd's Tab/Space), because polling a one-shot edge each frame would eat it.

# Analog movement from the left joystick (magnitude 0..1). ZERO = thumb lifted;
# _poll_local_intents leaves the keyboard vector alone when this is ZERO.
var move := Vector2.ZERO

# Held ability / action intents — a touch button sets its own flag while pressed.
var a1 := false
var a2 := false
var a3 := false
var ult := false
var potion := false
var potion_next := false
var interact := false

## True while any touch widget is engaged (a live joystick or a held button).
## Lets other code know the on-screen controls are driving input this frame.
var active := false


## Zero every held field — called when a touch ends or the app loses focus so a
## lifted (or interrupted) thumb never sticks a movement or ability on.
func clear_held() -> void:
	move = Vector2.ZERO
	a1 = false
	a2 = false
	a3 = false
	ult = false
	potion = false
	potion_next = false
	interact = false
	active = false
