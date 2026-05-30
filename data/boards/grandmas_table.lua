-- data/boards/grandmas_table.lua
-- Floor 1 board. Forgiving, centered, teaches zone reading and basic aiming.
-- Three centered concentric rectangles occupying roughly the top 60% of the
-- board; the bottom 40% is open white where coins scatter and rest safely.
-- All coordinates are fractions of the FULL board interior (wall to wall).

return {
  name      = "Grandma's Table",
  archetype = "intro",
  zones = {
    -- Blue outer (1pt)
    { points = 1, color = "#3380D9", xPct = 0.03, yPct = 0.04, wPct = 0.94, hPct = 0.56 },
    -- Yellow middle (2pt)
    { points = 2, color = "#F5CC1A", xPct = 0.13, yPct = 0.10, wPct = 0.74, hPct = 0.44 },
    -- Red centre (3pt)
    { points = 3, color = "#D92E24", xPct = 0.28, yPct = 0.17, wPct = 0.44, hPct = 0.30 },
  },
}
