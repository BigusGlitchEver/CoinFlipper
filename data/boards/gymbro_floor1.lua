-- data/boards/gymbro_floor1.lua
-- Gym Bro's House, floor 1. Archetype: shoot_long (hardest). One long, shallow
-- horizontal bar at the very top — a barbell rack on the wall. Nearly full
-- width but very short in height, so getting onto it needs a strong long flip.
-- Red is a small block at dead center of the bar; the wide blue strips on the
-- left/right ends are the only forgiveness. Everything below is white miss.
-- All coordinates are fractions of the FULL board interior (wall to wall).

return {
  name      = "The Bench",
  archetype = "shoot_long",
  zones = {
    { points = 1, color = "#3380D9", xPct = 0.04, yPct = 0.02, wPct = 0.92, hPct = 0.16 },
    { points = 2, color = "#F5CC1A", xPct = 0.18, yPct = 0.02, wPct = 0.64, hPct = 0.12 },
    { points = 3, color = "#D92E24", xPct = 0.38, yPct = 0.02, wPct = 0.24, hPct = 0.08 },
  },
}
