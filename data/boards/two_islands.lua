-- data/boards/two_islands.lua
-- Floor 3 board. Archetype: reuse_coins. Two separate scoring islands (left
-- and right), each a set of concentric rectangles. The center strip between
-- them and the bottom half of the board are open white miss territory. A coin
-- resting near the center can be knocked toward either island, so board-state
-- management and cross-island chain reactions are the whole game.
--
-- Zone order: all 1pt zones first (both blues), then all 2pt (both yellows),
-- then all 3pt (both reds), so higher-value zones always render on top and win
-- on overlap during the reverse-order scoring scan.
-- All coordinates are fractions of the FULL board interior (wall to wall).

return {
  name      = "Two Islands",
  archetype = "reuse_coins",
  zones = {
    -- Blues (1pt) — left then right
    { points = 1, color = "#3380D9", xPct = 0.02, yPct = 0.06, wPct = 0.36, hPct = 0.52 },
    { points = 1, color = "#3380D9", xPct = 0.62, yPct = 0.06, wPct = 0.36, hPct = 0.52 },
    -- Yellows (2pt) — left then right
    { points = 2, color = "#F5CC1A", xPct = 0.06, yPct = 0.12, wPct = 0.26, hPct = 0.38 },
    { points = 2, color = "#F5CC1A", xPct = 0.68, yPct = 0.12, wPct = 0.26, hPct = 0.38 },
    -- Reds (3pt) — left then right
    { points = 3, color = "#D92E24", xPct = 0.11, yPct = 0.19, wPct = 0.14, hPct = 0.24 },
    { points = 3, color = "#D92E24", xPct = 0.75, yPct = 0.19, wPct = 0.14, hPct = 0.24 },
  },
}
