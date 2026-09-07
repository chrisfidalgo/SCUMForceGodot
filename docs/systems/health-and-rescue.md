# Health, going down, and the rescue/escort loop

**Scripts:** `scenes/combat/health.gd`, `scenes/combat/faction.gd`,
`scenes/characters/mini.gd` (+ `mini.tscn`), and the coordination in
`scenes/combat/gym.gd`.

## Half-hearts

Health is counted in **half-hearts**, not hearts. A standard hit costs 1
half-heart; a heavy one costs 2 or more. Johnny is `max_half_hearts = 4` (two
hearts), Curly is `8` (four). The number lives on each `CharacterDef` `.tres`, so
changing how tanky someone is never means touching code.

`Health` is a plain Node parented under whatever owns it — the player and every
enemy carry an identical one. That is why the HUD, the debug tray and the rescue
flow can all speak to one contract without caring who they're looking at:

```gdscript
health.take_damage(2)   # returns false if blocked by invulnerability
health.heal(1)
health.reset_full()     # also clears death
health.current()
health.is_dead()
```

with signals `changed(current, max)`, `damaged(amount)` and `died`.

**There is no mid-combat regeneration**, by design — encounters run 30–90
seconds, so recovery is structural (rest and shop nodes between encounters), not
something you scavenge mid-fight. `heal()` exists for the debug tray and for
Phase 2's between-encounter flow.

### Invulnerability frames

After a hit the player is immune for `invuln_after_hit_sec` (0.6s placeholder)
and blinks red. Without this, walking into a projectile stream drains a
4-half-heart character almost instantly and no individual hit reads as an event.
It is an `@export` on the player — tune it by feel.

## Whose side is it on

The eight physics layers encode **height, not side**: `hurt_low` means "a low
attack can reach this", never "this belongs to the enemy". That's deliberate —
the channel system is the game's identity and everyone shares it — but it means
collision alone can't tell a projectile whether it hit a target or a teammate.

The layers are frozen after Phase 0 and none are spare, so side is resolved in
script. Anything that shoots or gets shot has a `faction` property; a projectile
records its shooter's faction and **passes straight through** a same-side
hurtbox instead of exploding on it. Anything without the property reads as
`NEUTRAL` and is hittable by everyone, which is why the target dummies still work
untouched.

Walls stay faction-blind on purpose: a wall stops everyone.

## Going down is not dying

At 0 half-hearts a character does **not** disappear. They emit `went_down`, and
the arena turns them into a **Mini** — a small `Area2D` on the `pickup` layer
lying exactly where they fell.

A mini wears its character's `placeholder_color` — dimmed while lying down, full
strength once following — so you can tell *who* is down without reading the
label.

A mini is deliberately **not** on any hurt layer. A downed teammate cannot be
shot again, so a rescue can never be made impossible by bad luck. The canon is
explicit that minis are re-rescuable and never lost.

Walk the active character into a mini and it stands up and trails behind:

- **Escorting 1 mini is free.** No penalty at all.
- **Escorting 2 or more costs 25% move speed** (`escort_penalty_multiplier` on
  the gym, placeholder). This is the risk/reward dial — the original arcade's
  hard one-mini cap was judged padding rather than depth, so here you *may* drag
  three, you just get slower doing it.
- **If the escort goes down, the whole chain lies back down where it stands.**
  Nothing is lost; go back for them with the next character.
- **Reaching the exit banks everyone you're dragging** and logs the character as
  survived.

Following is a simple trailing chain — each mini walks toward whatever is ahead
of it in the line and stops at `follow_gap_px`. No pathfinding; they will bump
into walls, which is fine at this scale.

## Who owns what

The player does not know what a mini is, and a mini does not know what the exit
means. Each part announces what happened (`went_down`, `rescued`,
`character_exited`) and **`gym.gd` decides what those announcements mean**. That
is why Phase 2 can give the same signals different consequences — a real
encounter timer, roster removal, a run loss — without editing any of these
scenes.

## Testing it by hand

Open `scenes/combat/gym.tscn`, press **F6**, then:

1. **F4** — force the active character down. A grey "(down)" mini appears.
2. **F5** — swap to Curly. Note the hearts jump from 4 pips to 8.
3. Walk over the mini. It turns blue and follows; the HUD reads
   `escorting: 1 (no penalty)`.
4. **F4**, **F5**, rescue both minis. The HUD reads `escorting: 2 (SLOWED)` and
   you can feel the drag. That difference is the thing to judge.
5. Walk into the green exit zone at the top. The console logs the survivor and
   how many minis were banked.
6. **F4** while escorting — the chain drops in place rather than vanishing.
