# Enemy behaviours

**Scripts:** `scenes/enemies/enemy.gd` (+ `enemy.tscn`), `resources/enemy_def.gd`,
`scenes/enemies/patrol_route.gd`. **Presets:** `resources/enemies/*.tres`.
**Test arena:** `scenes/enemies/enemy_sandbox.tscn` (open it, press F6).
Spec: `docs/plan/06-ENEMY-BEHAVIOURS-AND-ENCOUNTERS.md` §2.

## The idea

An enemy is **three independent choices**, plus numbers, all saved in one file
(an *EnemyDef*, a `.tres` just like a character or an attack):

1. **When does it wake up?** (Activation)
2. **How does it move?** (Movement — once while asleep, once while awake)
3. **How does it attack?** (Attack style, and how it aims)

A new enemy type is a new file, never new code. "A guard who walks a beat, then
chases and swipes once he spots you" is just PROXIMITY activation + PATROL while
asleep + SEEK while awake + MELEE attack.

Things that differ per **placement** rather than per type live on the enemy in the
scene instead (see "Placing one"), so ten Turrets can share one file.

## Making a new enemy type

1. In the FileSystem dock, open `resources/enemies/`. Right-click an existing
   preset that is close to what you want, **Duplicate**, and name it
   (e.g. `heavy_brawler.tres`).
2. Click the new file. The Inspector shows every setting, grouped. Change what you
   like (see the dropdown guide below). Set **Display Name** — that is what the
   debug tray and the tuning panel show.
3. Done. It shows up in the gym's F2/F3 type cycle automatically (the tray reads
   the folder when the game starts).

Editing a `.tres` changes **every** enemy using it. The `` ` `` tuning panel does
the same live while you play; use "Log values to console" and copy numbers back
into the file by hand.

## Dropdown guide

**Activation**
- `ALWAYS` — awake from the moment it appears. Ignores the Idle Movement setting.
- `PROXIMITY` — asleep until the player comes within *Activation Range Px*. Also
  wakes if you shoot it (turn off *Wake On Damage* to prevent that). Distance only:
  walls do not block its "sight".
  - *Leash Enabled* — once awake, if you get further than *Leash Range Px* it goes
    back to sleep and returns to its idle behaviour. Keep Leash Range bigger than
    Activation Range. *Leash Grace Sec* stops it nodding straight back off when
    something far away wakes it by damage.

**Movement** (*Idle Movement* is used while asleep, *Active Movement* while awake)
- `STATIONARY` — never moves.
- `WANDER` — walks in a random direction, switching every *Wander Change Sec*,
  and turns around when it hits a wall.
- `PATROL` — walks its placement's patrol route, pausing *Patrol Wait Sec* at each
  point. *Patrol Mode*: `LOOP` goes 1-2-3-1-2-3, `PING_PONG` goes 1-2-3-2-1.
  With no route it stands still and prints a warning.
- `SEEK` — walks toward the player until it is at *Preferred Range Px*. If you get
  closer than Preferred Range x *Retreat Ratio* it backs away (0 = never backs away).

**Attack Style**
- `NONE` — never attacks. Touching it still hurts (*Contact Damage*).
- `MELEE` — swings when the player is within *Attack Range Px* (its reach). Use a
  short-range attack such as `enemy_swipe.tres`. It is a very short shot, so a low
  wall blocks it.
- `RANGED` — fires when the player is within *Attack Range Px* (0 = any distance).

**Aim**
- `AT_PLAYER` — aims where the player is when the attack *begins*.
- `FIXED_FACING` — fires along the placed enemy's *Facing Degrees*
  (0 = right, 90 = down). Turrets use this.

**Other attack settings**
- *Attack* — drag in any attack `.tres`. Enemy attacks are tuned exactly like
  player ones, and obey the same channel rules (a low wall stops a LOW shot; a
  lob goes over it).
- *Fire Cooldown Sec* — gap between attacks.
- *Windup Sec* — the enemy stops, shows a warning, then attacks. The direction is
  **locked when the wind-up starts**, so you can side-step. 0 = instant.
- *Fire While Moving* — off means it only attacks while standing still (a Seeker
  closes the distance, then stops to shoot).
- *Muzzle Offset Px* — how far from its centre the attack appears.

## Reading an enemy at a glance

- **Dimmed body and a blue "z"** — dormant. It will not move (unless Idle
  Movement says so) or attack.
- **Yellow "!"** for a moment — it just woke up.
- **Pulsing yellow ring and a line** — a wind-up in progress. The line shows
  exactly where the attack will go.
- **Light-blue tint** — slowed by cheese. **White flash** — just got hit.
- Body colour comes from the def's *Placeholder Color*.

Those looks are tweakable in the Inspector under the enemy's **Presentation**
group.

## Placing one

1. Drag `scenes/enemies/enemy.tscn` into your level.
2. In the Inspector set **Def** to one of the `.tres` files.
3. **Elevation** — `GROUND` (only LOW attacks hit it), `ELEVATED` (only HIGH),
   `TALL` (both). Same as the target dummies.
4. **Facing Degrees** — only matters for FIXED_FACING enemies.
5. **Patrol Route** — only matters for PATROL enemies (below).

## Drawing a patrol route

1. Add a plain `Node2D` to the level and name it (e.g. `Route A`). Optionally
   attach `scenes/enemies/patrol_route.gd` to it to see the route drawn in the
   editor.
2. Add `Marker2D` nodes as its children. **Their order in the Scene dock is the
   walking order.** Move each marker where you want a stop.
3. Select the enemy, and in the Inspector drag the route node into **Patrol Route**.

One route can be shared by several enemies. In the gym, the debug tray spawns
patrollers onto the node called `PatrolRoute` (if the level has one).

## Tuning

Each enemy in the `` ` `` panel shows its type name and elevation, its attack's
numbers, and only the def numbers that matter for what it does (a Turret has no
speed slider; a Sentry has an activation range slider). Moving one slider retunes
every enemy of that type, because they all share the def.

## Debug tray (gym)

- **F1** — spawn the selected enemy type.
- **F2 / F3** — next / previous type. The current type is shown at the top of the tray.
- F4–F6 unchanged.
