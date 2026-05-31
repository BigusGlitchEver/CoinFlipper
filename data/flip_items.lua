-- data/flip_items.lua
-- MAIN COIN REGISTRY. This is the one file to look at to see every coin in the
-- game. Each coin type is its own modular file under data/coins/ — edit a coin
-- there, or add a new one and list it below. This file only aggregates the
-- coin definitions and provides id lookup; it holds no per-coin tuning itself.
--
-- Shared geometry (the collision/direction grids) lives in data/coins/regions.lua.
-- Per-coin schema is documented in data/coins/coin.lua.

local Data = {}

Data.items = {
  require("data.coins.coin"),
  require("data.coins.easy_coin"),
  require("data.coins.mini_coin"),
  require("data.coins.hard_coin"),
  require("data.coins.lucky_coin"),
  require("data.coins.toast"),
  require("data.coins.egg"),
  require("data.coins.skull"),
  require("data.coins.pancakes"),
  require("data.coins.gold_coin"),
}

function Data.byId(id)
  for i = 1, #Data.items do
    if Data.items[i].id == id then return Data.items[i] end
  end
  return nil
end

return Data
