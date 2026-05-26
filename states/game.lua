-- states/game.lua
-- The flip board, rebuilt per docs/FLIP_BOARD_VISUAL_SPEC.md.
--
-- Portrait layout, light grey background, white board rectangle filling
-- everything below a top HUD strip. One target (3 concentric rings) in the
-- upper half of the board. Multiple coins scattered on the board at floor
-- start; tap an un-used coin to flip it (closed-form arc per the physics
-- spec). Only one coin flies at a time. A hand sprite renders behind the
-- most-recently-tapped coin, from the nearest screen edge.
--
-- Scoring is 4-tier: bullseye / middle ring / outer ring (graze) / off-board
-- (full miss + chain reset). On-board-but-outside-target is a no-op (no
-- score, no chain change) -- effectively a "wasted shot."
--
-- NO JUICE in this chunk: no score popups, no ring flash, no screen shake,
-- no multiplier bounce, no between-floor shrink. Those land in Chunk 4.

local StateMachine = require("statemachine")
local Coin         = require("entities.coin")
local Items        = require("data.flip_items")

local lg    = love.graphics
local sqrt  = math.sqrt
local min   = math.min
local max   = math.max

local Game = {}

-- ---------- Visual spec colors ----------

local COLOR_BG             = { 0xEE/255, 0xEE/255, 0xEE/255 }
local COLOR_BOARD          = { 1, 1, 1 }
local COLOR_BOARD_BORDER   = { 0xAA/255, 0xAA/255, 0xAA/255 }
local COLOR_BULL           = { 0xE8/255, 0x47/255, 0x3F/255 }
local COLOR_MIDDLE         = { 0xF5/255, 0xA6/255, 0x23/255 }
local COLOR_OUTER          = { 0x5D/255, 0xB3/255, 0x5D/255 }
local COLOR_TARGET_OUTLINE = { 0x33/255, 0x33/255, 0x33/255 }
local COLOR_TOOL           = { 0x9A/255, 0xA0/255, 0xA6/255 }
local COLOR_TOOL_OUTLINE   = { 0x33/255, 0x33/255, 0x33/255 }
local COLOR_TEXT           = { 0.10, 0.10, 0.10 }
local COLOR_TEXT_DIM       = { 0.40, 0.40, 0.40 }

-- ---------- Tunables ----------

local COINS_PER_FLOOR = 5
local COIN_RADIUS_AT_390W = 24                  -- spec: 48px DIAMETER at 390w
local FLOOR_THRESHOLDS = { [1] = 20, [2] = 60, [3] = 120 }

-- Tight per Balatro lesson; the big numbers come from the multiplier chain.
local POINTS = { bull = 5, middle = 3, outer = 1 }

local HUD_HEIGHT       = 64
local BOARD_MARGIN     = 16
-- Per FIX prompt: outer radius <= 18% of board's shortest dim. On 800x600
-- with this layout that's ~85px max; we pick 65px (in spec's 60-70 range)
-- so the target genuinely feels missable.
local TARGET_OUTER_R   = 65
local TARGET_CENTER_Y_FRAC = 0.40   -- target somewhat above middle, room for coin scatter below

-- ---------- Layout (rebuilt on enter / resize) ----------

local L = {}

local function rebuildLayout()
  L.W, L.H = lg.getWidth(), lg.getHeight()
  L.hudH = HUD_HEIGHT
  L.boardX = BOARD_MARGIN
  L.boardY = L.hudH + BOARD_MARGIN
  L.boardW = L.W - 2 * BOARD_MARGIN
  L.boardH = L.H - L.boardY - BOARD_MARGIN

  -- Target circle in the upper portion of the board.
  L.targetCX = L.boardX + L.boardW / 2
  L.targetCY = L.boardY + L.boardH * TARGET_CENTER_Y_FRAC
  L.outerR  = TARGET_OUTER_R
  L.middleR = L.outerR * 0.66
  L.bullR   = L.outerR * 0.33

  -- Coin size: use the spec value (48px diameter) directly. Coins are
  -- intentionally larger than the target -- tappable, not aim-able.
  L.coinR = COIN_RADIUS_AT_390W
end

-- ---------- Coin scatter ----------

local function scatterCoins(n, item)
  local coins = {}
  local minSpacing = L.coinR * 2 + 12
  local maxAttempts = 60
  for i = 1, n do
    local placed = false
    for attempt = 1, maxAttempts do
      local x = love.math.random(L.boardX + L.coinR, L.boardX + L.boardW - L.coinR)
      local y = love.math.random(L.boardY + L.coinR, L.boardY + L.boardH - L.coinR)
      local ok = true
      for j = 1, #coins do
        local c = coins[j]
        local dx = x - c.x
        local dy = y - c.y
        if (dx * dx + dy * dy) < (minSpacing * minSpacing) then ok = false; break end
      end
      if ok then
        local coin = Coin(x, y, L.coinR)
        coin.boardCenterX = L.targetCX
        coin.boardCenterY = L.targetCY
        coins[#coins + 1] = coin
        placed = true
        break
      end
    end
    if not placed then break end  -- give up if we can't fit more
  end
  return coins
end

-- ---------- Flip tool (round, behind the about-to-flip coin) ----------

-- Draws a round metal-grey disc behind the given coin, nudged slightly toward
-- the nearest screen edge from that coin. Replaces the old skin-toned "hand."
local function drawToolFor(coin)
  if not coin then return end
  local W, H = L.W, L.H
  local cx, cy = coin.x, coin.y
  -- z'd up coins still get the tool drawn at their ground position
  local dTop, dBot, dLeft, dRight = cy, H - cy, cx, W - cx
  local mind = min(dTop, dBot, dLeft, dRight)

  local toolR  = L.coinR * 1.3
  local offset = L.coinR * 0.5
  local tx, ty = cx, cy
  if mind == dTop then
    ty = cy - offset
  elseif mind == dBot then
    ty = cy + offset
  elseif mind == dLeft then
    tx = cx - offset
  else
    tx = cx + offset
  end

  lg.setColor(COLOR_TOOL)
  lg.circle("fill", tx, ty, toolR)
  lg.setColor(COLOR_TOOL_OUTLINE)
  lg.setLineWidth(2)
  lg.circle("line", tx, ty, toolR)
  lg.setColor(1, 1, 1, 1)
end

-- ---------- Flip resolution ----------

-- 4-tier landing resolution. Pure logic; exposed as Game._resolveFlip for tests.
local function resolveFlip(self, landingX, landingY)
  local dx = landingX - L.targetCX
  local dy = landingY - L.targetCY
  local d2 = dx * dx + dy * dy

  if d2 <= L.bullR * L.bullR then
    local gain = POINTS.bull * self.multiplier
    self.marbles    = self.marbles + gain
    self.multiplier = self.multiplier + 1
    return "bull", gain
  elseif d2 <= L.middleR * L.middleR then
    local gain = POINTS.middle * self.multiplier
    self.marbles    = self.marbles + gain
    self.multiplier = self.multiplier + 1
    return "middle", gain
  elseif d2 <= L.outerR * L.outerR then
    local gain = POINTS.outer * self.multiplier
    self.marbles    = self.marbles + gain
    self.multiplier = self.multiplier + 1
    return "outer", gain
  end

  -- Outside the target. Is it still on the board?
  local onBoard =
    landingX >= L.boardX and landingX <= L.boardX + L.boardW and
    landingY >= L.boardY and landingY <= L.boardY + L.boardH

  if onBoard then
    -- Wasted shot: no points, no chain change. Survivable.
    return "on_board_miss", 0
  else
    -- Full miss: chain resets, no points.
    self.multiplier = 1
    return "off_board_miss", 0
  end
end

-- ---------- State lifecycle ----------

function Game:enter(prev, houseName)
  self.houseName  = houseName or "?"
  self.floor      = 1
  self.marbles    = 0
  self.multiplier = 1

  rebuildLayout()

  -- Prototype: every coin in the scatter is the same item (Coin). Future:
  -- per-floor item assignment, varied per scatter spot.
  self.activeCoinItem = Items.byId("coin")
  self.coins          = scatterCoins(COINS_PER_FLOOR, self.activeCoinItem)
  self.activeCoin     = nil  -- the one currently in flight, or nil
  self.lastTappedCoin = self.coins[1]   -- where the hand points before any tap
end

function Game:exit() end

function Game:update(dt)
  for i = 1, #self.coins do self.coins[i]:update(dt) end
  if self.activeCoin and not self.activeCoin.flipping then
    self.activeCoin = nil
  end
end

function Game:draw()
  -- Background.
  lg.setColor(COLOR_BG)
  lg.rectangle("fill", 0, 0, L.W, L.H)

  -- HUD strip.
  lg.setColor(COLOR_TEXT)
  lg.print("MARBLES  " .. self.marbles, 20, 22)
  local multStr = "MULT  x" .. self.multiplier
  local font = lg.getFont()
  lg.print(multStr, L.W - font:getWidth(multStr) - 20, 22)
  -- Floor threshold (secondary).
  lg.setColor(COLOR_TEXT_DIM)
  local threshStr = "FLOOR " .. self.floor .. "   NEED " .. (FLOOR_THRESHOLDS[self.floor] or "?")
  lg.printf(threshStr, 0, 52, L.W, "center")

  -- Board rectangle.
  lg.setColor(COLOR_BOARD)
  lg.rectangle("fill", L.boardX, L.boardY, L.boardW, L.boardH)
  lg.setColor(COLOR_BOARD_BORDER)
  lg.setLineWidth(2)
  lg.rectangle("line", L.boardX, L.boardY, L.boardW, L.boardH)

  -- Target rings (outer first so inner sit on top -- flat fills, no
  -- per-ring outline -- a single outer outline goes on last).
  lg.setColor(COLOR_OUTER)
  lg.circle("fill", L.targetCX, L.targetCY, L.outerR)
  lg.setColor(COLOR_MIDDLE)
  lg.circle("fill", L.targetCX, L.targetCY, L.middleR)
  lg.setColor(COLOR_BULL)
  lg.circle("fill", L.targetCX, L.targetCY, L.bullR)
  lg.setColor(COLOR_TARGET_OUTLINE)
  lg.setLineWidth(2)
  lg.circle("line", L.targetCX, L.targetCY, L.outerR)

  -- Flip tool: behind the most-recently-tapped (or about-to-be-tapped) coin.
  local toolCoin = self.activeCoin or self.lastTappedCoin
  if toolCoin and not toolCoin.used then
    drawToolFor(toolCoin)
  elseif toolCoin and toolCoin.used then
    -- Find next unused coin to point at.
    for i = 1, #self.coins do
      if not self.coins[i].used then drawToolFor(self.coins[i]); break end
    end
  end

  -- Coins.
  for i = 1, #self.coins do self.coins[i]:draw() end

  -- Bottom hint (temporary; replaced when the run/shop flow lands).
  lg.setColor(COLOR_TEXT_DIM)
  lg.printf("HOUSE: " .. self.houseName .. "   [M] map   [R] reset   [Esc] quit",
    0, L.H - 24, L.W, "center")
  lg.setColor(1, 1, 1, 1)
end

-- ---------- Input ----------

function Game:mousepressed(x, y, button)
  if button ~= 1 then return end
  if self.activeCoin then return end                 -- one flip at a time
  for i = 1, #self.coins do
    local coin = self.coins[i]
    if coin:contains(x, y) then
      local offX = (x - coin.x) / coin.radius
      local offY = (y - coin.y) / coin.radius
      local game = self
      coin:launch(offX, offY, self.activeCoinItem, function(lx, ly)
        local zone, _ = resolveFlip(game, lx, ly)
        if zone == "bull" or zone == "middle" or zone == "outer" then
          coin.used = true   -- scored: retire this coin
        end
        -- on_board_miss / off_board_miss: coin stays live, player can flip again
      end)
      self.activeCoin     = coin
      self.lastTappedCoin = coin
      return
    end
  end
end

function Game:keypressed(k)
  if k == "m" then
    StateMachine.switch("map")
  elseif k == "r" then
    Game:enter(nil, self.houseName)
  end
end

-- ---------- Test hooks ----------

Game._resolveFlip = resolveFlip
Game._L           = L  -- layout table (read after enter())

return Game
