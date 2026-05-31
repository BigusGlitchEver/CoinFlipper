-- data/boards/gymbro_floor2.lua
-- Gym Bro's House, floor 2. Archetype: reuse_coins. Two small "dumbbell"
-- pockets — one far left, one far right — separated by a long empty gap (the
-- center 54%, xPct 0.24..0.76, is fully dead). Each pocket has only a tiny red
-- center and a small yellow ring. Cross-pocket chains are the realistic way to
-- score. Zone order: all blues, then yellows, then reds.
-- All coordinates are fractions of the FULL board interior (wall to wall).

return {
  name      = "Dumbbells",
  archetype = "reuse_coins",
  zones = {
    -- Blues (1pt): left, right
    { points = 1, color = "#3380D9", xPct = 0.02, yPct = 0.28, wPct = 0.22, hPct = 0.28 },
    { points = 1, color = "#3380D9", xPct = 0.76, yPct = 0.28, wPct = 0.22, hPct = 0.28 },
    -- Yellows (2pt): left, right
    { points = 2, color = "#F5CC1A", xPct = 0.05, yPct = 0.32, wPct = 0.16, hPct = 0.20 },
    { points = 2, color = "#F5CC1A", xPct = 0.79, yPct = 0.32, wPct = 0.16, hPct = 0.20 },
    -- Reds (3pt): left, right
    { points = 3, color = "#D92E24", xPct = 0.09, yPct = 0.37, wPct = 0.08, hPct = 0.10 },
    { points = 3, color = "#D92E24", xPct = 0.83, yPct = 0.37, wPct = 0.08, hPct = 0.10 },
  },
}
