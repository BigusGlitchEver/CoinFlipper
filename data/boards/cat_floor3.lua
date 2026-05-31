-- data/boards/cat_floor3.lua
-- The Cat's House, floor 3. Archetype: be_exact. A single small target dead
-- center, surrounded entirely by white. No blue outer ring — straight to
-- yellow then red. Every flip is a clean centered hit or a complete miss;
-- chains (bouncing several coins together in the small area) score big.
-- All coordinates are fractions of the FULL board interior (wall to wall).

return {
  name      = "Hairball",
  archetype = "be_exact",
  zones = {
    { points = 2, color = "#F5CC1A", xPct = 0.32, yPct = 0.28, wPct = 0.36, hPct = 0.28 },
    { points = 3, color = "#D92E24", xPct = 0.40, yPct = 0.35, wPct = 0.20, hPct = 0.16 },
  },
}
