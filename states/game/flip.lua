-- states/game/flip.lua
-- Shot math + press resolution + the flip/chain launch path. Pure logic over
-- the shared L layout and the active game state `self`; no drawing.

local C     = require("states.game.config")
local L     = require("states.game.layout")
local Spawn = require("states.game.spawn")
local Items = require("data.flip_items")
local Tiers = require("data.coin_tiers")

local sqrt  = math.sqrt
local max   = math.max
local cos   = math.cos
local sin   = math.sin
local pi    = math.pi
local huge  = math.huge
local floor = math.floor

local TRI_UX             = C.TRI_UX
local TRI_UY             = C.TRI_UY
local POINTS             = C.POINTS
local CHAIN_BONUS        = C.CHAIN_BONUS
local CHAIN_SPAWN_MAX_DEPTH = C.CHAIN_SPAWN_MAX_DEPTH

local M = {}

-- Tiny helper: linear interpolation in [0, 1].
local function lerp(a, b, t) return a + (b - a) * t end

-- Two-zone power/arc model. A hard discontinuity at zone_threshold (typically
-- 0.65): inner zone is a short, high pop; outer zone is a long, flat launch.
local function resolveShot(item, offDist)
  local th = item.zone_threshold or 0.65
  if offDist < th then
    local t = offDist / th
    return lerp(item.inner_power_center or 80,  item.inner_power_edge or 130, t),
           lerp(item.inner_arc_center   or 220, item.inner_arc_edge   or 160, t)
  end
  local t = (offDist - th) / (1 - th)
  return lerp(item.outer_power_center or 180, item.outer_power_edge or 340, t),
         lerp(item.outer_arc_center   or 70,  item.outer_arc_edge   or 25,  t)
end
M.resolveShot = resolveShot

-- Per-dot STRICT-CONTAINMENT resolution. Returns count of (dot, coin) pairs.
local function findPressedCoin(coins, toolX, toolY, toolR, outConflict, isTriangle)
  local count = 0
  if isTriangle then
    -- Forgiveness margin: a tip grabs the nearest coin whose disc it touches
    -- OR comes within one base-coin radius of, so the triangle can engage any
    -- coin from any side without having to land a tip exactly inside it.
    local grab = L.coinR
    for d = 1, 3 do
      local tx = toolX + TRI_UX[d] * toolR
      local ty = toolY + TRI_UY[d] * toolR
      local bestCoin, bestD2 = nil, huge
      for i = 1, #coins do
        local coin = coins[i]
        if not coin.flipping and not coin.used then
          local dx = tx - coin.x
          local dy = ty - coin.y
          local d2 = dx*dx + dy*dy
          local reach = coin.radius + grab
          if d2 < reach*reach and d2 < bestD2 then
            bestCoin = coin
            bestD2   = d2
          end
        end
      end
      if bestCoin then
        count = count + 1
        local slot = outConflict[count]
        slot.contactX = tx
        slot.contactY = ty
        slot.coin     = bestCoin
        if count == 6 then break end
      end
    end
  else
    for i = 1, #coins do
      local coin = coins[i]
      if not coin.flipping and not coin.used then
        local dx   = coin.x - toolX
        local dy   = coin.y - toolY
        local dist = sqrt(dx*dx + dy*dy)
        -- Engage whenever the tool DISC overlaps the coin disc — rim graze
        -- (dist ~ toolR + cr) all the way through to the tool fully covering
        -- the coin (dist < toolR). No interior dead zone: the tool can touch
        -- any point of any coin from any side, including coins pinned to a wall.
        if dist > 1 and dist < toolR + coin.radius then
          count = count + 1
          local slot = outConflict[count]
          -- Rim offset = how far the coin centre is from the tool's rim. The
          -- contact sits on the coin's NEAR side (toward the tool), so the
          -- launch direction (contact -> centre) always pushes the coin AWAY
          -- from the tool. In the orbit zone (dist >= toolR) this point is
          -- identical to the old toolR-projection; inside the tool it mirrors
          -- to the near side instead of flipping the shot backwards.
          local off = dist - toolR
          if off < 0 then off = -off end
          local f = off / dist
          slot.contactX = coin.x - dx * f
          slot.contactY = coin.y - dy * f
          slot.coin     = coin
          if count == 6 then break end
        end
      end
    end
  end
  return count
end
M.findPressedCoin = findPressedCoin

-- Grandma's House 4-zone landing resolution. Concentric rectangles tested
-- innermost-first so the highest zone always wins.
--
-- Zone checks use the coin's EDGE, not its centre: a zone registers the moment
-- any part of the coin's disc overlaps the zone's inner boundary. Each inset
-- (z1/z2/z3) is shrunk by coin.radius so the threshold shifts outward to the
-- coin edge. Inner zones (z3 > z2 > z1) also keep their relative order because
-- the same offset is subtracted from all of them.
local function resolveFlip(self, coin, landingX, landingY, depth)
  local bx, by    = L.boardX, L.boardY
  local bw, bh    = L.boardW, L.boardH
  local tx, ty    = L.targetX, L.targetY
  local tw, th    = L.targetW, L.targetH
  local tierMult  = Tiers[(coin.tier or 0) + 1].mult
  local chainMult = CHAIN_BONUS[depth or 0] or 1
  local scoreMult = coin.scoreMult or 1  -- golden bonus coins are worth 5x
  local cr        = coin.radius  -- edge-based offset

  -- Off-board: full miss, chain resets.
  if landingX < bx or landingX > bx + bw or
     landingY < by or landingY > by + bh then
    if coin.tier < 3 then coin.tier = coin.tier + 1 end
    self.multiplier = 1
    return "off_board_miss", 0
  end

  -- Edge-adjusted zone insets: the zone triggers when the coin's rim reaches
  -- the painted line, i.e. inset shrinks by the coin radius (clamped to >= 0).
  local z1 = max(0, L.zone1 - cr)
  local z2 = max(0, L.zone2 - cr)
  local z3 = max(0, L.zone3 - cr)

  -- Red centre (innermost).
  if landingX >= tx + z3 and landingX <= tx + tw - z3 and
     landingY >= ty + z3 and landingY <= ty + th - z3 then
    local gain = max(1, floor(POINTS.red * tierMult * self.multiplier * chainMult * scoreMult))
    self.marbles      = self.marbles + gain
    self.floorMarbles = (self.floorMarbles or 0) + gain
    self.runMarbles   = (self.runMarbles   or 0) + gain
    self.multiplier   = self.multiplier + 1
    return "red", gain
  end

  -- Yellow band.
  if landingX >= tx + z2 and landingX <= tx + tw - z2 and
     landingY >= ty + z2 and landingY <= ty + th - z2 then
    local gain = max(1, floor(POINTS.yellow * tierMult * self.multiplier * chainMult * scoreMult))
    self.marbles      = self.marbles + gain
    self.floorMarbles = (self.floorMarbles or 0) + gain
    self.runMarbles   = (self.runMarbles   or 0) + gain
    self.multiplier   = self.multiplier + 1
    return "yellow", gain
  end

  -- Blue band.
  if landingX >= tx + z1 and landingX <= tx + tw - z1 and
     landingY >= ty + z1 and landingY <= ty + th - z1 then
    local gain = max(1, floor(POINTS.blue * tierMult * self.multiplier * chainMult * scoreMult))
    self.marbles      = self.marbles + gain
    self.floorMarbles = (self.floorMarbles or 0) + gain
    self.runMarbles   = (self.runMarbles   or 0) + gain
    self.multiplier   = self.multiplier + 1
    return "blue", gain
  end

  -- White outer strip: on-board but no score. Coin stays live.
  if coin.tier < 3 then coin.tier = coin.tier + 1 end
  return "white_miss", 0
end
M.resolveFlip = resolveFlip

-- Forward-declared because tryChainFlip calls fireFlip and fireFlip's launch
-- callback calls tryChainFlip.
local fireFlip, tryChainFlip

fireFlip = function(self, coin, contactX, contactY, depth)
  local item = (coin.itemType and Items.byId(coin.itemType)) or self.activeCoinItem
  local offX, offY, offDist = coin:pressedBy(contactX, contactY)
  if not offX then return end
  -- Direction MUST match the trajectory preview: a true straight line from the
  -- contact point through the coin center. We deliberately do NOT snap to the
  -- coin's preset region.angle (that "coin math" sent the coin sideways).
  local angle = math.atan2(coin.y - contactY, coin.x - contactX)
  -- Power also matches the preview (resolveShot from the off-center distance).
  -- arc is flight HEIGHT only; it never changes where the coin lands, so we
  -- still take it from the region if one is present.
  local region = coin:regionAt(offX, offY, item)
  local power, arc = resolveShot(item, offDist)
  if region and region.arc then arc = region.arc end
  if depth == 0 then self.activeCoin = coin end
  coin:launch(angle, power, arc, item, function(lx, ly)
    local zone, gain = resolveFlip(self, coin, lx, ly, depth)
    if zone == "red" or zone == "yellow" or zone == "blue" then
      coin.used = true
    elseif zone == "white_miss" then
      coin.used = false
    end

    if depth == 0 then
      local scored = zone == "red" or zone == "yellow" or zone == "blue"
      if scored and self.bonusReady then
        self.marbles    = self.marbles + gain * 29
        self.bonusReady = false
        self.hotStreak  = 0
        self.bonusFlash = 1.0
        self.scoreFlash = 0.20
      elseif scored then
        self.hotStreak = self.hotStreak + 1
        if self.hotStreak >= 3 then
          self.bonusReady = true
        end
      else
        self.hotStreak  = 0
        self.bonusReady = false
      end
    end

    -- Spawn extra coins only when:
    --   • this is a chain hit within the spawn window (0 < depth <= cap)
    --   • the activated coin is an egg (only eggs split)
    --   • the coin itself wasn't already spawned (spawned coins don't multiply)
    if depth > 0 and depth <= CHAIN_SPAWN_MAX_DEPTH
       and coin.itemType == "egg" and not coin.isSpawned then
      local spawned = Spawn.spawnCoinsAt(self, lx, ly, depth, coin.tier or 0)
      -- Each spawned coin immediately flies out in the same direction and
      -- distance the egg just travelled — same angle, power, arc, and item.
      for si = 1, #spawned do
        local sc = spawned[si]
        sc:launch(angle, power, arc, item, function(slx, sly)
          local szone = resolveFlip(self, sc, slx, sly, depth)
          if szone == "red" or szone == "yellow" or szone == "blue" then
            sc.used = true
          elseif szone == "white_miss" then
            sc.used = false
          end
          -- Spawned coins CAN knock other coins when they land; isSpawned=true
          -- already prevents those knocked coins from re-multiplying.
          -- No depth guard here — the spawn gate above uses the upper bound.
          tryChainFlip(self, sc, slx, sly, depth + 1)
        end, L.boardX + sc.radius, L.boardY + sc.radius,
             L.boardW - sc.radius * 2, L.boardH - sc.radius * 2)
      end
    end

    -- Chain reaction: always propagate — the flipping flag on each coin
    -- prevents cycles. The spawn-multiplication gate above (depth <= cap,
    -- egg only, not isSpawned) is the only thing that limits splitting;
    -- the knock-on chain itself is unlimited so all coins behave the same.
    tryChainFlip(self, coin, lx, ly, depth + 1)
    if depth == 0 then self.activeCoin = nil end
  end, L.boardX + coin.radius, L.boardY + coin.radius,
       L.boardW - coin.radius * 2, L.boardH - coin.radius * 2)
end
M.fireFlip = function(self, coin, x, y, depth) return fireFlip(self, coin, x, y, depth) end

tryChainFlip = function(self, landingCoin, lx, ly, depth)
  local lr = landingCoin.radius
  for i = 1, #self.coins do
    local target = self.coins[i]
    if target ~= landingCoin
       and not target.flipping then
      local dx   = target.x - lx
      local dy   = target.y - ly
      local d2   = dx * dx + dy * dy
      local sumR = lr + target.radius
      if d2 < (sumR * sumR) then
        -- Contact point: computed from the TARGET'S side, not the landing
        -- coin's. Using the landing coin's rim (lx + dx/d * lr) overshoots
        -- when the coins land close together (d < lr), placing the contact
        -- outside the target's disc and causing pressedBy to return nil.
        -- A point 80% inside the target toward the landing coin is always
        -- strictly inside the disc at any distance, including d ≈ 0, and
        -- still resolves to the same centre-to-centre direction.
        local d    = sqrt(d2)
        local invD = d > 0 and (1 / d) or 0
        local tr   = target.radius
        local contactX = target.x - dx * invD * tr * 0.8
        local contactY = target.y - dy * invD * tr * 0.8
        fireFlip(self, target, contactX, contactY, depth)
      end
    end
  end
end
M.tryChainFlip = function(self, landing, lx, ly, depth) return tryChainFlip(self, landing, lx, ly, depth) end

-- Internal direct refs (used by game.lua input path without wrapper overhead).
M._fireFlip = function(self, coin, x, y, depth) return fireFlip(self, coin, x, y, depth) end

return M
