-- data/boards/long_shot.lua
-- Floor 2 board. Archetype: shoot_long. A single tall narrow column of zones
-- pressed against the FAR END (top) of the board. The bottom 58% is open
-- white. Scoring demands a confident long-distance flip: too weak lands in
-- the white, too strong sails off the board. Chain reactions are valuable —
-- a coin reaching the column can knock another sitting near the top.
-- All coordinates are fractions of the FULL board interior (wall to wall).

return {
  name      = "Long Shot",
  archetype = "shoot_long",
  -- Keep all 8 starting coins corralled in a big circle at the bottom of the
  -- board, well clear of the zone column at the top. Forces a long flip.
  spawn = { cxPct = 0.50, cyPct = 0.71, rPct = 0.30 },
  zones = {
    -- Blue outer band of the column (1pt)
    { points = 1, color = "#3380D9", xPct = 0.30, yPct = 0.02, wPct = 0.40, hPct = 0.40 },
    -- Yellow inner band (2pt)
    { points = 2, color = "#F5CC1A", xPct = 0.36, yPct = 0.02, wPct = 0.28, hPct = 0.28 },
    -- Red tip at the very top (3pt)
    { points = 3, color = "#D92E24", xPct = 0.40, yPct = 0.02, wPct = 0.20, hPct = 0.14 },
  },
}
