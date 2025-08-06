local coins = require('components.flippers.coins')
local misc = require('components.flippers.miscellaneous')

local flippers = {}
for k, v in pairs(coins) do flippers[k] = v end
for k, v in pairs(misc) do flippers[k] = v end

local nameToKey = {}
for k, v in pairs(flippers) do nameToKey[v.name] = k end

return {
    flippers = flippers,
    nameToKey = nameToKey
} 