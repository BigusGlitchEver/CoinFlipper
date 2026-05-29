-- states/game.lua
-- The flip board, rebuilt per docs/FLIP_BOARD_VISUAL_SPEC.md.
--
-- This file is the STATE ORCHESTRATOR only: lifecycle (enter/exit), the
-- per-frame update, input routing, and the draw call order. All the heavy
-- lifting lives in focused submodules under states/game/:
--   config       — tunables, palette, precomputed geometry
--   fonts        — lazily-created HUD fonts
--   layout       — the shared L rectangle table (rebuilt on enter/resize)
--   flip         — shot math, press resolution, flip + chain launch path
--   spawn        — coin scatter + per-frame replenish
--   render_hud   — the left notebook sidebar
--   render_board — playing surface, tool, trajectory preview, debug overlays

local StateMachine = require("statemachine")
local Items        = require("data.flip_items")

local C          = require("states.game.config")
local F          = require("states.game.fonts")
local L          = require("states.game.layout")
local Flip       = require("states.game.flip")
local Spawn      = require("states.game.spawn")
local RenderHud  = require("states.game.render_hud")
local RenderBoard = require("states.game.render_board")

local lg = love.graphics
local lm = love.mouse

local TOOL_CIRCLE   = C.TOOL_CIRCLE
local TOOL_TRIANGLE = C.TOOL_TRIANGLE
local COLOR_BG      = C.COLOR_BG
local NUM_FLOORS    = C.NUM_FLOORS
local PREVIEW_BTN_H = C.PREVIEW_BTN_H

local Game = {}

-- ---------- State lifecycle ----------

function Game:enter(prev, houseName)
  self.houseName  = houseName or "?"
  self.floor      = 1
  self.marbles    = 0
  self.multiplier = 1

  L.rebuild()

  self.activeCoinItem = Items.byId("coin")  -- fallback for legacy paths
  self.coins          = Spawn.scatterBoard()
  self.activeCoin     = nil
  self.hoveredCoin    = nil
  self.conflictDots   = self.conflictDots or {}
  for i = 1, 6 do
    self.conflictDots[i] = self.conflictDots[i] or { contactX = 0, contactY = 0, coin = nil }
    self.conflictDots[i].contactX = 0
    self.conflictDots[i].contactY = 0
    self.conflictDots[i].coin     = nil
  end
  self.conflictCount  = 0
  self.conflictIdx    = 1
  self.armedDotIdx    = nil
  self.armedDotX      = nil
  self.armedDotY      = nil
  self.toolX, self.toolY = lm.getPosition()
  self.toolType     = self.toolType or TOOL_CIRCLE  -- preserved across [R] restart
  self.debugRegions = self.debugRegions or false
  F.ensure()
  self.multBounce   = 0
  self.scoreFlash   = 0
  self._prevMult    = 1
  self._prevMarbles = 0
  self.hotStreak  = 0
  self.bonusReady = false
  self.bonusFlash = 0
  if self.trajectoryPreview == nil then self.trajectoryPreview = true end
  lm.setVisible(false)
end

function Game:exit()
  lm.setVisible(true)
end

-- Computes hoveredCoin + armedDotX/Y from the currently selected pair.
function Game:_updateArmed()
  if self.conflictCount == 0 then
    self.hoveredCoin = nil
    self.armedDotX   = nil
    self.armedDotY   = nil
    return
  end
  local i        = (self.conflictCount == 1) and 1 or self.conflictIdx
  local pair     = self.conflictDots[i]
  self.hoveredCoin = pair.coin
  self.armedDotX   = pair.contactX
  self.armedDotY   = pair.contactY
end

-- Recompute hover/conflict state from the current tool position.
function Game:_refreshHover()
  local prevCoin
  if self.conflictCount > 0 then
    local prev = self.conflictDots[self.conflictIdx]
    if prev then prevCoin = prev.coin end
  end

  local count = Flip.findPressedCoin(
    self.coins, self.toolX, self.toolY, L.toolR, self.conflictDots,
    self.toolType == TOOL_TRIANGLE)
  self.conflictCount = count

  if count <= 1 then
    self.conflictIdx = 1
  else
    local newIdx = 1
    if prevCoin then
      for i = 1, count do
        local p = self.conflictDots[i]
        if p.coin == prevCoin then newIdx = i; break end
      end
    end
    self.conflictIdx = newIdx
  end

  self:_updateArmed()
end

function Game:update(dt)
  self.toolX, self.toolY = lm.getPosition()
  self:_refreshHover()
  for i = 1, #self.coins do self.coins[i]:update(dt) end
  if self.activeCoin and not self.activeCoin.flipping then
    self.activeCoin = nil
  end
  if self.multiplier ~= self._prevMult then
    if self.multiplier > (self._prevMult or 1) then
      self.multBounce = 0.28
    end
    self._prevMult = self.multiplier
  end
  if self.marbles ~= self._prevMarbles then
    if self.marbles > (self._prevMarbles or 0) then
      self.scoreFlash = 0.20
    end
    self._prevMarbles = self.marbles
  end
  if self.multBounce  > 0 then self.multBounce  = self.multBounce  - dt end
  if self.scoreFlash  > 0 then self.scoreFlash  = self.scoreFlash  - dt end
  if self.bonusFlash  > 0 then self.bonusFlash  = self.bonusFlash  - dt end
  Spawn.replenishCoins(self)
end

function Game:draw()
  -- Background.
  lg.setColor(COLOR_BG)
  lg.rectangle("fill", 0, 0, L.W, L.H)
  -- Left notebook HUD, then the playing surface.
  RenderHud.draw(self)
  RenderBoard.draw(self)
  lg.setColor(1, 1, 1, 1)
end

-- ---------- Input ----------

function Game:mousepressed(x, y, button)
  if button ~= 1 then return end
  if x < L.panelW then
    local btnY = L.H - PREVIEW_BTN_H - 10   -- 10 = HUD pm constant
    if y >= btnY and y <= btnY + PREVIEW_BTN_H then
      self.trajectoryPreview = not self.trajectoryPreview
    end
    return
  end
  if self.activeCoin then return end                 -- one flip at a time
  self.toolX, self.toolY = x, y
  self:_refreshHover()
  if not self.armedDotX then return end              -- no coin in contact
  Flip._fireFlip(self, self.hoveredCoin, self.armedDotX, self.armedDotY, 0)
end

function Game:keypressed(k)
  if not self.activeCoin and self.conflictCount > 1 then
    if k == "a" or k == "left" then
      self.conflictIdx = self.conflictIdx - 1
      if self.conflictIdx < 1 then self.conflictIdx = self.conflictCount end
      self:_updateArmed()
      return
    elseif k == "d" or k == "right" then
      self.conflictIdx = self.conflictIdx + 1
      if self.conflictIdx > self.conflictCount then self.conflictIdx = 1 end
      self:_updateArmed()
      return
    end
  end
  if k == "m" then
    StateMachine.switch("map")
  elseif k == "r" then
    Game:enter(nil, self.houseName)
  elseif k == "g" then
    self.debugRegions = not self.debugRegions
  elseif k == "t" then
    self.toolType = (self.toolType == TOOL_TRIANGLE) and TOOL_CIRCLE or TOOL_TRIANGLE
    self:_refreshHover()
  end
end

-- ---------- Test hooks ----------

Game._resolveFlip     = Flip.resolveFlip
Game._findPressedCoin = Flip.findPressedCoin
Game._resolveShot     = Flip.resolveShot
Game._fireFlip        = Flip._fireFlip
Game._tryChainFlip    = Flip.tryChainFlip
Game._L               = L  -- layout table (read after enter())

return Game
