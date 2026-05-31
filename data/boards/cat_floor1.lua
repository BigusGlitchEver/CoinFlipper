-- data/boards/cat_floor1.lua
-- The Cat's House, floor 1. Archetype: reuse_coins. Three small scoring
-- clusters in a loose triangle (top-left, top-right, bottom-center) with dead
-- white gaps between them. Bottom-center is the safe-but-cheap entry; the top
-- clusters pay more and are harder to reach. Chains between clusters score big.
-- Zone order: all blues, then yellows, then reds (highest renders/wins on top).
-- All coordinates are fractions of the FULL board interior (wall to wall).

return {
  name      = "The Cat's Table",
  archetype = "reuse_coins",
  zones = {
    -- Blues (1pt): TL, TR, BC
    { points = 1, color = "#3380D9", xPct = 0.04, yPct = 0.05, wPct = 0.28, hPct = 0.30 },
    { points = 1, color = "#3380D9", xPct = 0.68, yPct = 0.05, wPct = 0.28, hPct = 0.30 },
    { points = 1, color = "#3380D9", xPct = 0.32, yPct = 0.58, wPct = 0.36, hPct = 0.28 },
    -- Yellows (2pt): TL, TR, BC
    { points = 2, color = "#F5CC1A", xPct = 0.08, yPct = 0.09, wPct = 0.20, hPct = 0.22 },
    { points = 2, color = "#F5CC1A", xPct = 0.72, yPct = 0.09, wPct = 0.20, hPct = 0.22 },
    { points = 2, color = "#F5CC1A", xPct = 0.37, yPct = 0.63, wPct = 0.26, hPct = 0.18 },
    -- Reds (3pt): TL, TR, BC
    { points = 3, color = "#D92E24", xPct = 0.12, yPct = 0.14, wPct = 0.12, hPct = 0.12 },
    { points = 3, color = "#D92E24", xPct = 0.76, yPct = 0.14, wPct = 0.12, hPct = 0.12 },
    { points = 3, color = "#D92E24", xPct = 0.42, yPct = 0.68, wPct = 0.16, hPct = 0.08 },
  },
}
