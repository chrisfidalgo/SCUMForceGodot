extends Node
## RunState — the current run held in memory (STUB for Phase 0).
##
## Autoload. Combat and the era map read from and write back to this single
## object so nothing has to pass run data around by hand. SaveManager
## serializes it to disk after every resolved node.
##
## Phase 0 defines only the SHAPE (matching 02-ARCHITECTURE.md §6). The fields
## are placeholders until Phase 2 (the fixed harness) fills them with real
## values — no run actually populates this yet.

## One roster member's live state. `status` is "active", "downed", or "lost".
class RosterMember:
	var id: String = ""
	var half_hearts: int = 0
	var max_half_hearts: int = 0
	var status: String = "active"

var seed: int = 0                    ## RNG seed for the whole run (deterministic maps later).
var arc_index: int = 0               ## Which era arc we're on.
var node_map: Dictionary = {}        ## nodes / edges / current / cleared — shape TBD in Phase 3.
var roster: Array[RosterMember] = [] ## Live per-character HP/status.
var relics: Array = []               ## Items/relics collected this run (placeholder).
var cash: int = 0                    ## Placeholder currency.

## Wipe everything back to a fresh run. Called when a new run starts.
func reset() -> void:
	seed = 0
	arc_index = 0
	node_map = {}
	roster = []
	relics = []
	cash = 0
