# COIN FLIPPER — THE FLIP BOARD: FEEL & MENTAL MODEL

> **Read this before touching any flip board code.** This document corrects a
> common misreading of the mechanic and defines how the board should *feel*.
> The companion file `FLIP_PHYSICS_SPEC.md` gives the concrete, tunable numbers.

---

## THE ONE THING TO GET RIGHT

**The player taps the COIN, not the zone.**

The player does **not** click a scoring zone to send the coin there. The player
taps directly on the flip *item* — the coin, toast, pancake — and that flick is
what launches it. The zones are the *target*, never the input. The coin is the
only thing the finger ever touches.

Think tiddlywinks: you press the disc to make it leap. You do not point at where
you want it to go and have it teleport.

If you ever find yourself writing a click handler on a zone that launches the
coin, stop — that is the wrong model.

---

## THE CORE INPUT

Tapping a different spot **on the item** produces a different launch:

- **Tap dead center** → a straight, predictable, low-arc trajectory. This is the
  "pool shot" — clean, readable, goes where you aimed.
- **Tap toward an edge** → a sharper, angled, riskier launch. The further from
  center, the more extreme the angle.

**There is no random variance.** The outcome is 100% determined by where the
finger lands on the item. Same tap point = same flight, every single time. This
is what makes the early game skill-based rather than luck-based. Repetition
teaches the player each item's "tap map."

---

## FLIGHT & LANDING

The item visibly travels through the air before it lands — arc, tumble, settle.
The flight is not instant; reading it is part of the skill. Each item type flies
differently, and learning those differences is the mastery curve:

- **Coin** — pops fast, short hang time, lands quickly. High precision, tiny
  margin for error. The honest, learnable starter.
- **Toast** — middle of the road. A bit more hang, a bit more drift than the coin.
- **Pancakes** — lift slow and hang in the air. Lots of time to read the flight,
  but the floaty motion makes them genuinely hard to place. Big payoff, big
  difficulty.

The tumble/spin is cosmetic juice — it sells the tiddlywink feel — but the
landing point is decided by the launch, not by the tumble. (See the spec for why
this matters for determinism.)

---

## ITEM COLOR = VALUE = DIFFICULTY

Items are color-coded by value tier, and **value is inversely tied to control**:

- **Low-value item** → forgiving, stable arc. The tap-to-landing relationship is
  consistent and easy to learn. Small tap errors produce small landing errors.
- **High-value item** → finicky, sensitive trajectory. Small differences in tap
  position produce *big* differences in landing. Hard to control, high reward.

The player chooses their own risk by choosing which item to flip. The better the
potential payout, the twitchier the item. This is the core risk/reward dial of
the base mechanic — before any cards enter the picture.

---

## BAD FLIPS MUST HURT

A sloppy tap should not quietly succeed. Punish it on a gradient:

- **Slightly off** → catch the outer ring. Low Marbles. Survivable.
- **Badly off** → the item sails clean off the board. **Zero score. Multiplier
  chain resets.**

The board **shrinks every floor**. The exact same tap that landed a high-value
zone on Floor 1 might catch the outer ring on Floor 2 and miss the board entirely
on Floor 3. The player's muscle memory has to *re-tighten* each floor. That
shrinking board is the primary difficulty lever (per the GDD) — honor it.

---

## THE SKILL CURVE

Instantly understandable: tap the thing, watch it land. Hard to master: every
item has its own tap map, and the board keeps shrinking under you.

The base mechanic stays **constant and clean**. Cards and modifiers layer on top
— some stabilize trajectories, some add new risk/reward, some grant a reflip on a
miss. The foundation never changes; the cards are what make each run feel
different. Do not bake card-like special-casing into the base flip — keep it pure
and let modifiers compose on top.

---

## LOOK & PRESENTATION (board feel)

- **Flat 2D surface, concentric scoring rings.** Hand-drawn, schoolyard-notebook
  energy. The art carries the personality; UI chrome stays minimal so the
  drawings breathe.
- **The player's hand reaches in from the screen edge** (Slay the Spire style)
  and that hand is what taps the item. Reinforce visually that the hand touches
  the coin.
- **One flip item on the board at a time.**
- **Readable flight.** The arc should be legible enough that a skilled player can
  predict the landing mid-air. Floaty items telegraph more; fast items demand
  faster reads.
- **Juice on landing** (do last, do not skip): impact shake or flash on landing,
  a score popup, the landed zone highlights. The multiplier counter grows
  bigger/hotter as the chain stacks. A miss-off-board should feel as bad as a
  bullseye feels good.
- **Zone-shrink transition between floors** should be a visible, slightly
  ominous beat — the player watches their target get smaller.

---

## QUICK ANTI-PATTERNS CHECKLIST

- ❌ Clicking a zone to launch the coin → ✅ tapping the coin itself
- ❌ Random scatter on the base coin → ✅ deterministic tap-position → trajectory
- ❌ Every item flies the same → ✅ per-item flight personalities
- ❌ A bad tap still scores fine → ✅ graded punishment up to off-board zero
- ❌ Box2D / love.physics for the launch → ✅ custom deterministic arc (see spec)
