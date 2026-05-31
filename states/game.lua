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
local Services     = require("services")
local Map          = require("states.map")

local C          = require("states.game.config")
local F          = require("states.game.fonts")
local L          = require("states.game.layout")
local Flip       = require("states.game.flip")
local Spawn      = require("states.game.spawn")
local RenderHud  = require("states.game.render_hud")
local RenderBoard = require("states.game.render_board")
local MarbleEvent = require("states.game.marble_event")
local CardPanel  = require("ui.card_panel")

local lg    = love.graphics
local lm    = love.mouse
local floor = math.floor
local min   = math.min
local max   = math.max
local sin   = math.sin

local TOOL_CIRCLE      = C.TOOL_CIRCLE
local TOOL_TRIANGLE    = C.TOOL_TRIANGLE
local COLOR_BG         = C.COLOR_BG
local NUM_FLOORS       = C.NUM_FLOORS
local PREVIEW_BTN_H    = C.PREVIEW_BTN_H
local FLOOR_THRESHOLDS = C.FLOOR_THRESHOLDS
local FLIPS_PER_FLOOR  = C.FLIPS_PER_FLOOR
local HOUSE_FLOORS     = C.HOUSE_FLOORS
local NEXT_ARROW_X = C.NEXT_ARROW_X
local NEXT_ARROW_Y = C.NEXT_ARROW_Y
local NEXT_ARROW_W = C.NEXT_ARROW_W
local NEXT_ARROW_H = C.NEXT_ARROW_H

-- Overlay geometry (fixed 800 × 600 window).
local OVL_X, OVL_Y, OVL_W, OVL_H   = 180, 95,  440, 230
local PRI_X, PRI_Y, PRI_W, PRI_H    = 315, 263, 170, 42   -- primary action btn (between/win)
local SEC_X, SEC_Y, SEC_W, SEC_H    = 180, 340, 440, 120  -- "play again?" box (win only)
local YEA_X, YEA_Y, YEA_W, YEA_H   = 219, 408, 175, 38   -- "You Betcha!" btn
local NAH_X, NAH_Y, NAH_W, NAH_H   = 406, 408, 175, 38   -- "Nah" btn

-- DEBUG floor-jump arrows (bottom-right of the board). ◄ = previous floor
-- layout, ► = win the current stage (shows the clear/win screen).
local DBG_W, DBG_H = 30, 26
local DBG_PREV_X, DBG_PREV_Y = 705, 566
local DBG_NEXT_X, DBG_NEXT_Y = 742, 566

-- Shared palette for overlays.
local OVL_BG       = { 0.12, 0.10, 0.08, 0.93 }
local OVL_BORDER   = { 0.70, 0.55, 0.20, 1.00 }
local OVL_TITLE_WIN  = { 0.92, 0.80, 0.20 }
local OVL_TITLE_LOSE = { 0.85, 0.22, 0.18 }
local OVL_TITLE_NEXT = { 0.30, 0.80, 0.45 }
local OVL_TEXT     = { 0.90, 0.88, 0.84 }
local OVL_DIM      = { 0.60, 0.58, 0.54 }
local BTN_PRI_BG   = { 0.22, 0.58, 0.22 }
local BTN_PRI_HL   = { 0.30, 0.75, 0.30 }
local BTN_SEC_BG   = { 0.28, 0.28, 0.28 }
local BTN_NEG_BG   = { 0.50, 0.18, 0.14 }
local BTN_TEXT     = { 1.00, 1.00, 1.00 }

local function commaNum(n)
  local s = tostring(floor(n or 0))
  local result, i = "", #s
  while i > 0 do
    local from = max(1, i - 2)
    result = s:sub(from, i) .. result
    if from > 1 then result = "," .. result end
    i = from - 1
  end
  return result
end

local Game = {}

-- ---------- State lifecycle ----------

-- Sets the run state and fires any one-time side-effects. Showing an overlay
-- (any state other than "playing") brings the OS mouse cursor back so the
-- player can click the overlay buttons; returning to play hides it again.
local function setRunState(self, state)
  self.runState = state
  lm.setVisible(state ~= "playing")
  if state == "win" then
    if Services.bank then Services.bank:deposit(self.runMarbles or 0) end
    Map.markConquered(self.houseName)
  end
end

-- Advances past a cleared floor: clearing floor 3 ends the run (win screen),
-- any earlier floor shows the floor-clear screen.
local function advanceStage(self)
  if self.floor >= NUM_FLOORS then
    setRunState(self, "win")
  else
    setRunState(self, "between")
  end
end

-- DEBUG: draw the two floor-jump arrow buttons in the board's bottom-right.
local function drawDebugArrows()
  lg.setFont(F.SMALL)
  lg.setColor(1, 1, 1, 0.45)
  lg.printf("DEBUG FLOOR", DBG_PREV_X - 60, DBG_PREV_Y - 14, DBG_W + 127, "right")
  -- ◄ previous
  lg.setColor(0, 0, 0, 0.40)
  lg.rectangle("fill", DBG_PREV_X, DBG_PREV_Y, DBG_W, DBG_H, 4, 4)
  lg.setColor(1, 1, 1, 0.85)
  local pcx, pcy = DBG_PREV_X + DBG_W * 0.5, DBG_PREV_Y + DBG_H * 0.5
  lg.polygon("fill", pcx + 6, pcy - 7, pcx + 6, pcy + 7, pcx - 7, pcy)
  -- ► next (= win current stage)
  lg.setColor(0, 0, 0, 0.40)
  lg.rectangle("fill", DBG_NEXT_X, DBG_NEXT_Y, DBG_W, DBG_H, 4, 4)
  lg.setColor(1, 1, 1, 0.85)
  local ncx, ncy = DBG_NEXT_X + DBG_W * 0.5, DBG_NEXT_Y + DBG_H * 0.5
  lg.polygon("fill", ncx - 6, ncy - 7, ncx - 6, ncy + 7, ncx + 7, ncy)
end

-- DEBUG: reset the board for a fresh floor (used by the prev-floor arrow).
-- Loads the board assigned to the current house + floor. This is the single
-- point of board assignment — swapping a board means editing HOUSE_FLOORS.
local function loadFloorBoard(self)
  local houses = HOUSE_FLOORS[(self.houseName or ""):lower()] or HOUSE_FLOORS.grandma
  local path   = houses[self.floor] or houses[#houses]
  L.loadBoard(require(path))
end

local function resetFloor(self)
  self.floorMarbles   = 0
  self.marbles        = 0
  self.multiplier     = 1
  self.hotStreak      = 0
  self.bonusReady     = false
  self.flipsLeft      = FLIPS_PER_FLOOR
  self.floorTargetMet = false
  loadFloorBoard(self)       -- load this floor's board BEFORE scattering coins
  self.coins          = Spawn.scatterBoard()
  self.runState       = "playing"
  MarbleEvent.onFloorStart()
  lm.setVisible(false)
end

-- Draws a rounded-rect button and returns whether the mouse is over it.
local function drawBtn(x, y, w, h, bgColor, label, font, mx, my)
  local hovered = mx >= x and mx <= x + w and my >= y and my <= y + h
  local c = hovered and BTN_PRI_HL or bgColor
  lg.setColor(c[1], c[2], c[3])
  lg.rectangle("fill", x, y, w, h, 7, 7)
  lg.setColor(OVL_BORDER[1], OVL_BORDER[2], OVL_BORDER[3], 0.60)
  lg.setLineWidth(1.5)
  lg.rectangle("line", x, y, w, h, 7, 7)
  lg.setFont(font)
  local tw = font:getWidth(label)
  local th = font:getHeight()
  lg.setColor(BTN_TEXT[1], BTN_TEXT[2], BTN_TEXT[3])
  lg.print(label, x + floor((w - tw) * 0.5), y + floor((h - th) * 0.5))
  return hovered
end

function Game:enter(prev, houseName)
  self.houseName    = houseName or "?"
  self.floor        = 1
  self.marbles      = 0
  self.floorMarbles = 0
  self.runMarbles   = 0
  self.multiplier   = 1
  self.runState      = "playing"
  self.flipsLeft     = FLIPS_PER_FLOOR
  self.floorTargetMet = false

  L.rebuild()
  loadFloorBoard(self)

  self.activeCoinItem = Items.byId("coin")  -- fallback for legacy paths
  self.coins          = Spawn.scatterBoard()
  MarbleEvent.onFloorStart()
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

  -- Active-cards sidebar panel. render_hud positions it inside the "ACTIVE
  -- CARDS" region each frame; the initial region here is a sane default.
  self.cardPanel = CardPanel(0, 0, L.panelW - 20)
  self.cardPanel:addCard({
    cardType = "bicycle", rank = 7, suit = "heart",
    name = "Marble Insurance",
    description = "First dead-zone miss each floor is ignored",
  })
  self.cardPanel:addCard({
    cardType = "bicycle", rank = 3, suit = "diamond",
    name = "Compound Interest",
    description = "+10% score per successful flip, stacks this floor",
  })
  self.cardPanel:addCard({
    cardType = "monster",
    name = "Magnet Slime",
    description = "Coins drift toward higher-value zones each flip",
  })

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

  -- Freeze gameplay when an overlay is showing.
  if self.runState ~= "playing" then return end

  self:_refreshHover()
  for i = 1, #self.coins do self.coins[i]:update(dt) end
  MarbleEvent.update(self, dt)
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
  if self.cardPanel then self.cardPanel:update(dt) end

  -- Floor target: once reached, just flag it. This surfaces the green
  -- "progress to next floor" arrow on the progress bar but keeps play going —
  -- the clear/win screen only appears when the player clicks that arrow or
  -- runs out of moves.
  local thresh = FLOOR_THRESHOLDS[self.floor] or 0
  if (self.floorMarbles or 0) >= thresh then
    self.floorTargetMet = true
  end

  -- No-moves check: every coin has settled (nothing flipping) and there are
  -- no clickable coins left (all in their Done/used state) OR the flip budget
  -- is spent. We wait for settle so a final chain still gets its chance. If
  -- the target was met by then it's a clear/win; otherwise it's a loss.
  local anyFlipping, anyClickable = false, false
  for i = 1, #self.coins do
    local c = self.coins[i]
    if c.flipping then
      anyFlipping = true
    elseif not c.used then
      anyClickable = true
    end
  end
  if not anyFlipping and (not anyClickable or (self.flipsLeft or 0) <= 0) then
    if self.floorTargetMet then
      advanceStage(self)
    else
      setRunState(self, "lose")
    end
  end
end

function Game:drawOverlay()
  local mx, my = lm.getPosition()
  local rs = self.runState
  F.ensure()

  -- Dim the whole screen.
  lg.setColor(0, 0, 0, 0.55)
  lg.rectangle("fill", 0, 0, L.W, L.H)

  -- ── Main info box ────────────────────────────────────────────────────
  lg.setColor(OVL_BG[1], OVL_BG[2], OVL_BG[3], OVL_BG[4])
  lg.rectangle("fill", OVL_X, OVL_Y, OVL_W, OVL_H, 10, 10)
  lg.setColor(OVL_BORDER[1], OVL_BORDER[2], OVL_BORDER[3])
  lg.setLineWidth(2.5)
  lg.rectangle("line", OVL_X, OVL_Y, OVL_W, OVL_H, 10, 10)

  local titleColor, titleText, bodyLine1, bodyLine2
  if rs == "win" then
    titleColor = OVL_TITLE_WIN
    titleText  = "YOU WIN THE HOUSE!"
    bodyLine1  = "All " .. NUM_FLOORS .. " floors cleared!"
    bodyLine2  = commaNum(self.runMarbles) .. " marbles banked."
  elseif rs == "lose" then
    titleColor = OVL_TITLE_LOSE
    titleText  = "YOU LOSE"
    bodyLine1  = "Out of coins before the target!"
    bodyLine2  = "You earned " .. commaNum(self.runMarbles) .. " marbles."
  else -- between
    titleColor = OVL_TITLE_NEXT
    titleText  = "FLOOR " .. self.floor .. " CLEAR!"
    bodyLine1  = "Floor " .. self.floor .. " target reached."
    bodyLine2  = "Total so far: " .. commaNum(self.runMarbles) .. " marbles."
  end

  lg.setFont(F.LARGE)
  lg.setColor(titleColor[1], titleColor[2], titleColor[3])
  local tw = F.LARGE:getWidth(titleText)
  lg.print(titleText, OVL_X + floor((OVL_W - tw) * 0.5), OVL_Y + 22)

  lg.setFont(F.MEDIUM)
  lg.setColor(OVL_TEXT[1], OVL_TEXT[2], OVL_TEXT[3])
  lg.printf(bodyLine1, OVL_X + 20, OVL_Y + 90,  OVL_W - 40, "center")
  lg.printf(bodyLine2, OVL_X + 20, OVL_Y + 118, OVL_W - 40, "center")

  if rs == "between" then
    -- Floor 1 or 2 cleared: just continue, no play-again prompt.
    drawBtn(PRI_X, PRI_Y, PRI_W, PRI_H, BTN_PRI_BG, "NEXT FLOOR", F.MEDIUM, mx, my)

  else  -- "win" (floor 3 cleared) OR "lose": offer to play the house again.
    -- ── "Play again?" box ────────────────────────────────────────────
    lg.setColor(OVL_BG[1], OVL_BG[2], OVL_BG[3], OVL_BG[4])
    lg.rectangle("fill", SEC_X, SEC_Y, SEC_W, SEC_H, 10, 10)
    lg.setColor(OVL_BORDER[1], OVL_BORDER[2], OVL_BORDER[3], 0.60)
    lg.setLineWidth(1.5)
    lg.rectangle("line", SEC_X, SEC_Y, SEC_W, SEC_H, 10, 10)

    lg.setFont(F.MEDIUM)
    lg.setColor(OVL_DIM[1], OVL_DIM[2], OVL_DIM[3])
    lg.printf("Play this house again?", SEC_X, SEC_Y + 18, SEC_W, "center")

    drawBtn(YEA_X, YEA_Y, YEA_W, YEA_H, BTN_PRI_BG, "You Betcha!", F.MEDIUM, mx, my)
    drawBtn(NAH_X, NAH_Y, NAH_W, NAH_H, BTN_NEG_BG, "Nah",         F.MEDIUM, mx, my)
  end

  lg.setColor(1, 1, 1, 1)
end

function Game:draw()
  -- Background.
  lg.setColor(COLOR_BG)
  lg.rectangle("fill", 0, 0, L.W, L.H)
  -- Left notebook HUD, then the playing surface.
  RenderHud.draw(self)
  RenderBoard.draw(self)
  MarbleEvent.draw(self)
  if self.runState == "playing" then
    drawDebugArrows()
  else
    self:drawOverlay()
  end
  lg.setColor(1, 1, 1, 1)
end

-- ---------- Input ----------

function Game:mousepressed(x, y, button)
  if button ~= 1 then return end

  -- ── Overlay click handling ────────────────────────────────────────────
  local rs = self.runState
  if rs and rs ~= "playing" then
    if rs == "between" then
      -- NEXT FLOOR button.
      if x >= PRI_X and x <= PRI_X + PRI_W and y >= PRI_Y and y <= PRI_Y + PRI_H then
        self.floor = self.floor + 1
        resetFloor(self)
        return
      end

    else  -- "win" or "lose": play-again choice
      -- "You Betcha!" — restart this house from floor 1.
      if x >= YEA_X and x <= YEA_X + YEA_W and y >= YEA_Y and y <= YEA_Y + YEA_H then
        Game:enter(nil, self.houseName)
        return
      end
      -- "Nah" — go back to the map.
      if x >= NAH_X and x <= NAH_X + NAH_W and y >= NAH_Y and y <= NAH_Y + NAH_H then
        StateMachine.switch("map")
        return
      end
    end
    return  -- eat all other clicks while overlay is up
  end

  -- ── Special Marble Event: click the rolling marble to burst it ────────
  if MarbleEvent.click(self, x, y) then return end

  -- ── DEBUG floor-jump arrows ───────────────────────────────────────────
  -- ► wins the current stage; ◄ jumps back to the previous floor's layout.
  if x >= DBG_NEXT_X and x <= DBG_NEXT_X + DBG_W
     and y >= DBG_NEXT_Y and y <= DBG_NEXT_Y + DBG_H then
    if self.floor >= NUM_FLOORS then
      setRunState(self, "win")
    else
      setRunState(self, "between")
    end
    return
  end
  if x >= DBG_PREV_X and x <= DBG_PREV_X + DBG_W
     and y >= DBG_PREV_Y and y <= DBG_PREV_Y + DBG_H then
    if self.floor > 1 then self.floor = self.floor - 1 end
    resetFloor(self)
    return
  end

  -- ── Normal gameplay clicks ────────────────────────────────────────────
  if x < L.panelW then
    -- Green "progress to next floor" arrow — only active once the target's met.
    if self.floorTargetMet
       and x >= NEXT_ARROW_X and x <= NEXT_ARROW_X + NEXT_ARROW_W
       and y >= NEXT_ARROW_Y and y <= NEXT_ARROW_Y + NEXT_ARROW_H then
      advanceStage(self)
      return
    end
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
  if (self.flipsLeft or 0) <= 0 then return end       -- out of shots
  self.flipsLeft = self.flipsLeft - 1
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
  -- DEBUG ONLY: remove before release
  if k == "m" then
    MarbleEvent.trigger(self)
    return
  end
  if k == "escape" then
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
