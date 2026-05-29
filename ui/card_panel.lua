-- ui/card_panel.lua
-- Owns and lays out a vertical list of active Card banner rows. Lives inside
-- the left sidebar's "ACTIVE CARDS" region. Owned by states/game.lua.

local Object = require("lib.classic")
local Card   = require("ui.card")

local lg = love.graphics

local CardPanel = Object:extend()

local CARD_GAP = 8
local EMPTY_COL = { 0.38, 0.28, 0.14 }   -- muted, matches the sidebar label

function CardPanel:new(x, y, width)
  self.x      = x or 0
  self.y      = y or 0
  self.width  = width or 200
  self.cards  = {}
end

-- Create a Card instance from a plain data table and append it.
function CardPanel:addCard(cardData)
  cardData.width = self.width
  local card = Card(cardData)
  self.cards[#self.cards + 1] = card
  return card
end

-- Remove the first card whose name matches. Returns true if one was removed.
function CardPanel:removeCard(name)
  for i, card in ipairs(self.cards) do
    if card.name == name then
      table.remove(self.cards, i)
      return true
    end
  end
  return false
end

-- Reposition the panel without re-creating cards (called on resize / layout
-- rebuild by the owning state). Propagates width to existing cards.
function CardPanel:setRegion(x, y, width)
  self.x, self.y, self.width = x, y, width
  for _, card in ipairs(self.cards) do
    card.width = width
  end
end

function CardPanel:update(dt)
  -- Stub for future card animation (hover lift, deal-in slide, etc.).
end

function CardPanel:draw()
  if #self.cards == 0 then
    lg.setColor(EMPTY_COL[1], EMPTY_COL[2], EMPTY_COL[3], 0.38)
    lg.printf("NO CARDS YET", self.x, self.y + 24, self.width, "center")
    lg.setColor(1, 1, 1, 1)
    return
  end
  local cy = self.y
  for _, card in ipairs(self.cards) do
    card:draw(self.x, cy)
    cy = cy + card:getHeight() + CARD_GAP
  end
end

return CardPanel
