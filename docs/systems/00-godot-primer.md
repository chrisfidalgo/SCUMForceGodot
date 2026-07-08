# 00 — Godot Primer (for the project owner)

A one-page orientation to the Godot concepts this project is built on, written for a designer who reads scene trees and inspectors fluently but is new to Godot specifically. Every later systems doc assumes this vocabulary. Nothing here is SCUM-Force-specific — it's just "how Godot is put together."

## Nodes and scenes

A **node** is the atomic building block — one object that does one job. `Node2D` is a thing with a position; `Area2D` detects overlaps; `Camera2D` frames the view; `Label` draws text. Nodes are arranged in a **tree**: parents contain children, and children move with their parents.

A **scene** (`.tscn` file) is just a saved tree of nodes you can reuse — like a prefab. `gym.tscn` is a scene; so is `main.tscn`. A scene can be *instanced* (dropped) inside another scene as many times as you like. You build and edit scenes visually in the editor's main viewport and the **Scene** dock (top-left tree).

When you press **F5** Godot runs the whole game starting from the **main scene** (`main.tscn`). Pressing **F6** runs *the scene you're currently editing* on its own — that's how you'll test `gym.tscn` in isolation.

## The Inspector — where you tune

Click any node and its properties appear in the **Inspector** dock (right side). This is your control panel. Everywhere this project has a gameplay number a designer would want to touch — move speed, damage, cooldowns, cone angles — it is exposed as an **`@export` variable** (a script value deliberately surfaced to the Inspector) or lives in a **resource file** (below). You should almost never need to open a script to balance the game; if you find a number you want to change buried in code, that's a bug in how we set it up — flag it.

## Resources (`.tres` files) — data you can edit

A **resource** is a pure data asset, saved as a `.tres` text file, whose fields show up in the Inspector like a node's do — but it holds *no behavior*, just values. This project uses two custom resource types:

- **`AttackDef`** (`resources/attacks/*.tres`) — one attack's numbers: aim type, channel, damage, cooldown, range, projectile speed.
- **`CharacterDef`** (`resources/characters/*.tres`) — one character's numbers: name, move speed, health, and *which two `AttackDef`s they use*.

Double-click `resources/characters/johnny.tres` and you'll see Johnny's whole kit as editable rows. Because characters are data, making a new character means making a new `.tres` file — no new code. **This is where balance work happens.**

## Signals — how nodes talk without wiring

A **signal** is a message a node emits ("I was hit", "I reached the exit") that any other node can listen to by connecting a function to it. The emitter doesn't need to know who's listening. This keeps systems decoupled: a health bar can react to a "damaged" signal without the damage code ever knowing the health bar exists. The rule we follow: a child never reaches *up* the tree to poke its parent — it emits a signal and lets the parent connect.

## Autoloads — the always-there globals

An **autoload** (a.k.a. singleton) is a script Godot loads once at startup and makes reachable from anywhere by name. They live outside any single scene, so they survive screen changes. This project has four (in `autoload/`):

| Autoload | What it's for |
|---|---|
| **`GameFlow`** | The *only* thing that changes what's on screen — swaps full screens and opens/closes modal windows. |
| **`RunState`** | The current run held in memory: roster health, items, cash, where you are on the map. |
| **`SaveManager`** | Writes/reads that run to disk (so **Continue** works). |
| **`EventBus`** | A short list of truly game-wide signals other systems can react to. |

You configure autoloads in **Project → Project Settings → Globals → Autoload**. For Phase 0 only `GameFlow` does real work; the other three are labelled stubs that later packets fill in.

## The screen stack (this game's shape)

`main.tscn` is the permanent root and never gets freed. Under it sit three layers: **ScreenRoot** (holds exactly one full screen at a time — Splash, the era map, Combat…), **ModalLayer** (pop-up windows like Shop/Inventory that dim what's behind them), and **TooltipLayer** (always on top). `GameFlow` owns all three. Right now the game boots to a plain placeholder screen — proof the plumbing routes correctly before any real screens exist.

## The physics layers (this game's identity)

Godot's 2D physics has 32 numbered **collision layers**; we've *named* the first eight (**Project Settings → Layer Names → 2D Physics**) to encode the channel system — `hurt_low`, `hurt_high`, `block_low`, `block_high`, and so on. An attack only interacts with the layers its channel maps to, which is what makes "the right character for the situation" a real, physical rule rather than a script check. The dedicated channel doc (arriving with that packet) explains it in full; for now just know that **the layer *names* are the mechanic**, and they're frozen — don't rename them.

---

*Where to look:* scenes in `scenes/`, tunable data in `resources/`, global scripts in `autoload/`, and one of these explainers per system in `docs/systems/`.
