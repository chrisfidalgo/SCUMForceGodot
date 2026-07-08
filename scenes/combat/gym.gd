extends Node2D
## gym.gd — the combat-testing arena (empty shell for Phase 0).
##
## Phase 0 ships this scene deliberately near-empty: a Node2D root and a fixed
## Camera2D at the arena center (the combat camera never follows the player —
## 02-ARCHITECTURE.md §2). Packet P1b builds the actual layout inside gym.tscn
## (floor, arena walls, structure sampler, dummy row); P1a/P1c add the player
## and attacks. It must always open and run standalone (F5) — see 03-GYM-SPEC.md.
