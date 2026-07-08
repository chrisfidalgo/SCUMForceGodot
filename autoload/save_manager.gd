extends Node
## SaveManager — writes/reads the run to disk (STUB for Phase 0).
##
## Autoload. Serializes RunState to a JSON blob in user:// after every resolved
## node (combat won, shop closed, event resolved) — never mid-combat. On
## Continue it loads the blob back into RunState and routes to the era map.
##
## Phase 0 ships only the plumbing and the versioned file shape. The real blob
## serialization (02-ARCHITECTURE.md §6) is finalized in Phase 2 packet P2e —
## `save_run()` here writes a minimal versioned stub so the file path and
## version handshake exist from day one.

const SAVE_VERSION: int = 1
const RUN_SAVE_PATH: String = "user://save_run.json"
const META_SAVE_PATH: String = "user://meta.json"

## True if a run save exists to Continue from.
func has_run_save() -> bool:
	return FileAccess.file_exists(RUN_SAVE_PATH)

## Write the in-progress run. Stub: real field mapping lands in P2e.
func save_run() -> void:
	var blob: Dictionary = {
		"version": SAVE_VERSION,
		"seed": RunState.seed,
		"arc_index": RunState.arc_index,
		# roster/node_map/relics/cash serialized for real in P2e.
	}
	var file := FileAccess.open(RUN_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager.save_run: could not open %s" % RUN_SAVE_PATH)
		return
	file.store_string(JSON.stringify(blob, "\t"))

## Read the run save into memory. Returns the parsed blob, or {} if none/invalid.
## Stub: does not yet rebuild RunState (P2e).
func load_run() -> Dictionary:
	if not has_run_save():
		return {}
	var text := FileAccess.get_file_as_string(RUN_SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

func delete_run_save() -> void:
	if has_run_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_SAVE_PATH))
