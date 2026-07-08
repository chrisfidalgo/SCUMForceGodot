extends Node
## EventBus — a few global signals (STUB for Phase 0).
##
## Autoload. A "signal" in Godot is a message a node emits that any other node
## can connect a function to, without the two holding references to each other.
## EventBus holds the handful of signals that are truly global, so distant
## systems (HUD, save, audio later) can react to run-wide events without hard
## wiring. Use it sparingly — prefer local signals between nearby nodes; only
## genuinely cross-cutting events belong here.
##
## Phase 0 declares the signals; the systems that emit/consume them arrive with
## their packets (character_downed in P1d, encounter_resolved in Phase 2).

## Fired when any character drops to 0 half-hearts and becomes a mini.
signal character_downed(character_id: String)

## Fired when a combat/shop/event node finishes resolving.
signal encounter_resolved(result: String)
