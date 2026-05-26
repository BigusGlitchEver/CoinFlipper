# COIN FLIPPER — FLIP BOARD VISUAL SPEC

This document describes only how the board looks. Physics and input logic
live in `FLIP_PHYSICS_SPEC.md`. Gameplay rules live in the GDD.
Build exactly what is described here — no embellishment, no additions.

## THE BIG PICTURE

The board is a plain white rectangle sitting on a light grey background.
No texture, no wood grain, no felt, no shadow gradients, no decorative border.
The hand-drawn art imported later will carry all the personality. The board is a
clean, neutral stage. Keep it ruthlessly simple.

## SCREEN LAYOUT

Portrait orientation (taller than it is wide).

- HUD strip — thin strip at the very top. Points on the left, current
  multiplier on the right. Plain text, no panels, no boxes.
- The board — fills the rest of the screen below the HUD. Full screen width
  with a small margin on each side (roughly 16px on a 390px-wide screen, adjust
  proportionally). The white rectangle runs from just below the HUD to the bottom
  of the screen.

That's the whole layout. Two regions: HUD strip on top, board filling everything
below it.

## THE BOARD RECTANGLE

- Fill: pure white. `#FFFFFF`. No off-white, no cream, no tint.
- Border: a single thin line. Medium grey, `#AAAAAA`, 2px. Crisp, not soft.
- No rounded corners.
- Background behind the board: light grey, `#EEEEEE`. Subtle contrast — makes
  the board read as a physical surface.
- No drop shadow. No inner shadow. No glow.

## THE TARGET CIRCLE

A single circle sits centered on the board, positioned in the upper half.
This is the scoring zone and the only target. It is not decorative.

### Structure — three concentric rings, inside out

1. Bullseye — the innermost filled circle.
2. Middle ring — an annular band around the bullseye.
3. Outer ring — the outermost annular band.

### Sizing

- The circle should feel large and almost generous on Floor 1 — it gets smaller
  each floor, so this is the friendliest it will ever be.
- Clear white space between the circle's outer edge and the board edges on all
  sides — roughly 15–20% of the board's width as margin.
- Ring radii as proportions of the outer radius: `bullseye = 0.33`,
  `middle = 0.66`, `outer = 1.0`. To be tuned during playtest.

### Colors — flat fills, no gradients

| Zone                 | Color         | Hex     |
|----------------------|---------------|---------|
| Bullseye (innermost) | Warm red      | `#E8473F` |
| Middle ring          | Amber         | `#F5A623` |
| Outer ring           | Soft green    | `#5DB35D` |

Hard color edges between rings — no gradient, no glow, no stroke between them.

A single thin dark outline — `#333333`, 2px — runs around the outside of the
entire circle only. Do not outline each ring individually.

No numbers or labels inside the rings. The rings are clean at rest.

## THE COINS

Multiple coins sit scattered randomly across the board at the start of a flip
sequence. They rest on top of the white board surface.

- For the prototype, each coin is a simple filled circle, `#F0C040`
  (gold-ish yellow), with a thin dark outline `#333333`, 2px. Diameter roughly
  48px on a 390px-wide screen.
- Coins are scattered across the board at random positions, avoiding heavy
  overlap with each other. They can sit anywhere on the white rectangle —
  including near or partially overlapping the target circle area — because the
  board is the playing field, not just a backdrop.
- Only the coin being flipped is tappable. The others wait. One flip at a
  time.
- This placeholder coin gets replaced with the hand-drawn sprite later — match
  the size on swap.

## THE HAND

A hand reaches in from the nearest screen edge to the coin being flipped.
It sits just behind the coin, as if about to press it.

- For the prototype, draw the hand as a simple rounded rectangle in warm skin
  tone `#FDBCB4` — a stubby arm shape pointing toward the coin.
- The hand is static before the flip. It does not animate or move until
  launch. It is a visual indicator of "this is where input comes from."
- The hand sits behind the coin in z-order.
- Post-prototype this becomes the hand-drawn sprite with a brief launch animation.

## LANDING FEEDBACK (implement last — do not skip)

- Score popup: a number floats up from the landing point and fades out over
  ~0.6s. Large, bold. Color matches the ring landed in — red for bullseye, amber
  for middle, green for outer. A full miss off the board shows `MISS` in dark grey
  `#555555`, same fade treatment.
- Ring highlight: the landed ring briefly brightens (~0.2s on, fade back over
  ~0.3s). Other rings do not change.
- Multiplier counter: scales up with a quick bounce (~1.2×) when it increases.
  Grows visually hotter as the chain stacks — slightly larger at 3×, noticeably
  bigger at 5×+. Exact breakpoints tuned during playtest.
- Miss: brief low-amplitude screen shake (~3px, ~0.25s). Multiplier snaps back
  to 1× instantly — no animation, just a hard reset.
- Zone shrink between floors: the target circle scales down to its new size
  over ~0.4s with a slight ease-in. The player watches their target tighten.

## WHAT NOT TO ADD

Do not add any of the following without explicit instruction:

- Texture or pattern on the board
- Decorative border or frame
- Drop shadow on the board or circle
- Animated idle on the coins (no bobbing, pulsing, or spinning before a flip)
- Labels or numbers inside the scoring rings
- A trajectory preview or aim-assist line
- Any tap/click handler on the scoring zones
- Any visual change to zones on hover or touch
