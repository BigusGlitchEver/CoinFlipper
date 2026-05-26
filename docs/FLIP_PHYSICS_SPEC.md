# COIN FLIPPER — FLIP PHYSICS SPEC

Companion to `FLIP_BOARD_FEEL.md`. That file says how it should feel; this
file says how to build it. This is a deterministic, hand-tuned trajectory
model — NOT a real physics simulation and NOT Box2D / love.physics.

## WHY NOT REAL TIDDLYWINKS PHYSICS

Real tiddlywinks is a rigid disc pivoting off a squidger with backspin — genuinely
chaotic and impossible to aim precisely. That is the opposite of what this game
needs. The GDD requires the early flips to be skill-based and non-random, and
the user-facing rule is "same tap = same result, every time." A real simulation
would inject exactly the chaos we are trying to forbid.

Per the project's own physics skill: do not reach for `love.physics`/Box2D for
a launcher like this — it produces floaty, non-deterministic controls. Instead we
author a closed-form parametric arc: given the tap, we compute the entire
flight up front. The tumble/spin is cosmetic only and never feeds back into the
landing. This guarantees determinism, runs trivially at 60 FPS, and gives us clean
tuning knobs.

So: we do not "calculate tiddlywinks." We fake a tiddlywink-feeling arc with a
formula we fully control. That formula is below.

## THE MODEL (closed-form, deterministic)

### Step 1 — Read the tap as an offset from the item's center

When the player taps the item, record the tap position relative to the item's
center, normalized to the item's radius:

```
offset_x   = (tap_x - item_center_x) / item_radius   -- range roughly [-1, 1]
offset_y   = (tap_y - item_center_y) / item_radius   -- range roughly [-1, 1]
offset_dist = sqrt(offset_x^2 + offset_y^2)          -- 0 = dead center, 1 = edge
```

`offset_dist` is the single most important number: 0 = center = straight shot,
toward 1 = edge = sharp/risky launch.

### Step 2 — Convert offset into launch parameters

The launch is fully described by a 2D direction, a power, and an arc height. All
three are pure functions of the tap offset and the item's tuning constants:

```
-- Direction: dead-center launches "up the board"; edge taps swing the angle.
-- base_dir is straight toward the board center (the safe line).
launch_angle = base_angle + offset_x * item.angle_sensitivity
              -- offset_x left/right rotates the shot

-- Power: how far up the board it travels. Center is the calibrated sweet spot;
-- the vertical tap component pushes it long or short.
launch_power = item.base_power + offset_y * item.power_sensitivity

-- Arc height: how high it lifts. This is the visible "hang" and the item's
-- personality. Heavier/floatier items have a bigger base_arc.
arc_height   = item.base_arc + offset_dist * item.arc_variance
```

### Step 3 — The landing point is computed immediately

From `launch_angle` + `launch_power` we get the landing position at launch
time, **before** the animation plays:

```
landing_x = origin_x + cos(launch_angle) * launch_power
landing_y = origin_y + sin(launch_angle) * launch_power
```

Then we play a parametric arc animation from origin to that landing point over
`flight_time`, lofting by `arc_height` at the midpoint. The visual is just
interpolation; the result was already decided. (This is what makes it
deterministic and replay-stable.)

### Step 4 — The sweet-spot / sensitivity mapping (the difficulty soul)

Each item has a sweet spot (almost always dead center) and a sensitivity
curve that decides how fast control degrades as the tap moves off center.

A forgiving item uses a gentle curve: a tap 30% off center still lands close
to where a centered tap would. Low `angle_sensitivity` / `power_sensitivity`.

A finicky item uses a steep curve: the same 30%-off tap throws the landing
wildly. High sensitivities. This is how "high value = hard to control" is
expressed numerically.

A power-curve exponent (`sensitivity_falloff`) shapes how punishing the edges are:

```
effective_offset = offset_dist ^ item.sensitivity_falloff
-- falloff < 1  -> forgiving near center, scary only at the very edge
-- falloff = 1  -> linear
-- falloff > 1  -> tight sweet spot, punishing quickly  (high-value items)
```

## PER-ITEM TUNING TABLE (starting values — tune in playtest)

These are first-pass numbers to get it on screen, not sacred. Power is in
"board units" where ~1.0 reaches the board center from the launch edge. Color tier
follows the GDD's "color = value = difficulty" rule.

| Item        | Tier / Color    | base_power | power_sens | angle_sens | base_arc | arc_var | flight_time | falloff | Feel |
|-------------|-----------------|------------|------------|------------|----------|---------|-------------|---------|------|
| Coin        | Low (green)     | 1.00       | 0.15       | 0.20 rad   | 0.30     | 0.10    | 0.45 s      | 0.8     | Fast pop, short hang, very learnable. The honest starter. |
| Lucky Coin  | Low+ (blue)     | 1.00       | 0.15       | 0.20 rad   | 0.30     | 0.10    | 0.45 s      | 0.8     | Same flight as Coin; its edge is a bonus effect, not harder physics. |
| Toast       | Mid (yellow)    | 1.05       | 0.25       | 0.30 rad   | 0.45     | 0.20    | 0.65 s      | 1.0     | Medium hang, more drift than Coin. The in-between teacher. |
| Pancakes    | High (red)      | 1.10       | 0.40       | 0.45 rad   | 0.70     | 0.35    | 0.95 s      | 1.4     | Slow lift, long floaty hang, tight sweet spot. High reward, hard to place. |

Reading the table: bigger `power_sens` / `angle_sens` / `falloff` = twitchier =
higher value. Bigger `base_arc` + longer `flight_time` = floatier = more hang time
to read but harder to control. Pancakes are deliberately the most extreme on every
axis.

Scoring-ratio guardrail (from the Balatro reference): keep the base zone
values fairly tight — the best zone should be roughly ×2 the worst, not ×10. The
wild numbers should come from the multiplier chain and from cards, not from the
raw zone payouts. Don't let a high-value item's bullseye out-base a low item's by
an order of magnitude; the risk is already priced into how hard it is to land.

## THE FLOOR-SHRINK LEVER

Difficulty between floors comes almost entirely from shrinking the zones, not
from changing the items. The flight model stays identical floor to floor; the
target just gets smaller.

```
zone_scale = { [1] = 1.00, [2] = 0.70, [3] = 0.45 }   -- starting values, tune
```

A given tap lands at the same board coordinate on every floor — but on Floor 3
that coordinate is far more likely to be outer-ring or off-board because the
high-value rings have shrunk. This is the whole curve: the player must flick
more accurately as floors progress, with no new mechanic to learn. Keep this as
the primary lever and leave the per-item constants alone between floors.

## LANDING RESOLUTION

Separate detection from response (per the physics skill):

**Detect:** compute `landing_x, landing_y`, find which concentric ring (after
`zone_scale`) contains it. Distance-from-center vs. ring radii — cheap, exact.

**Resolve:**

- Inside a scoring ring → award that ring's Marbles × current multiplier;
  advance the multiplier chain; highlight the ring; pop the score.
- Outer ring only → low Marbles; multiplier survives (graze, not miss).
- Outside the board entirely → zero; multiplier chain resets. Sell the miss
  hard with juice.

The "slightly off vs. badly off" gradient in the feel doc maps directly to
"outer-ring vs. off-board" here.

## IMPLEMENTATION NOTES (LuaJIT / LÖVE2D)

Following the project's optimization skill:

- Localize math up top in the flip module: `local cos, sin, sqrt, pi =
  math.cos, math.sin, math.sqrt, math.pi`. The arc runs every frame during flight;
  no global lookups in the loop.
- One flip item on screen at a time (GDD). Don't allocate a new item table per
  flip — keep a single reusable `flip_item` table and reset its fields on each
  launch. No table creation inside update/draw.
- Pre-compute the landing at launch. `update` only advances a `t` from 0→1 and
  interpolates position + arc height + cosmetic spin. The landing is already known,
  so the simulation cannot drift and is trivially cheap.
- Spin/tumble is cosmetic. Drive it off `t` for the visual; never let it feed
  back into the landing calculation. This is what preserves "same tap = same
  result."
- Keep the base flip pure. Cards/modifiers should wrap or post-process the
  result (adjust sensitivities, grow zones, grant a reflip) — don't special-case
  card logic inside the core launch function.

## OPEN TUNING ITEMS (resolve in playtest)

- Exact `base_power` so a centered tap reliably hits a mid-value ring on Floor 1.
- The `sensitivity_falloff` per item — how punishing should Pancake edges really
  feel? Start at 1.4 and adjust by feel.
- `zone_scale` per floor — 1.0 / 0.7 / 0.45 is a starting guess.
- Whether Lucky Coin stays physically identical to Coin (recommended) or gets a
  slightly wider sweet spot as part of its "lucky" identity.
- Off-board threshold: how far past the outer ring before it counts as a full miss
  vs. a generous outer-ring catch.
