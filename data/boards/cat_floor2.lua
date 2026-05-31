-- data/boards/cat_floor2.lua
-- The Cat's House, floor 2. Archetype: shoot_long (directional). The cat swiped
-- everything into the top-right corner: all zones are crammed there, the rest
-- of the board is dead white. Scoring needs both distance AND a rightward
-- angle; a centered straight flip goes nowhere near the corner.
-- All coordinates are fractions of the FULL board interior (wall to wall).

return {
  name      = "Paw Swipe",
  archetype = "shoot_long",
  zones = {
    { points = 1, color = "#3380D9", xPct = 0.54, yPct = 0.03, wPct = 0.43, hPct = 0.38 },
    { points = 2, color = "#F5CC1A", xPct = 0.62, yPct = 0.06, wPct = 0.32, hPct = 0.28 },
    { points = 3, color = "#D92E24", xPct = 0.72, yPct = 0.10, wPct = 0.22, hPct = 0.18 },
  },
}
