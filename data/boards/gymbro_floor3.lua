-- data/boards/gymbro_floor3.lua
-- Gym Bro's House, floor 3. Archetype: be_exact (hardest board in the build).
-- A single tiny red zone, no yellow and no blue, in the upper third slightly
-- right of center — off-center enough that a straight flip misses. The rest of
-- the board is dead white. No partial credit: touch the red or score nothing.
-- Chains (knocking a nearby coin onto it) are the consistent way to score.
-- All coordinates are fractions of the FULL board interior (wall to wall).

return {
  name      = "One Rep Max",
  archetype = "be_exact",
  zones = {
    { points = 3, color = "#D92E24", xPct = 0.42, yPct = 0.08, wPct = 0.18, hPct = 0.14 },
  },
}
