-- Load items from separate category files
local hats = require('data.items.hats')
local glasses = require('data.items.glasses')
local gloves = require('data.items.gloves')
local socks = require('data.items.socks')
local accessories = require('data.items.accessories')

-- Combine all items
local items = {}

-- Add hats
for _, item in ipairs(hats) do
    table.insert(items, item)
end

-- Add glasses
for _, item in ipairs(glasses) do
    table.insert(items, item)
end

-- Add gloves
for _, item in ipairs(gloves) do
    table.insert(items, item)
end

-- Add socks
for _, item in ipairs(socks) do
    table.insert(items, item)
end

-- Add accessories
for _, item in ipairs(accessories) do
    table.insert(items, item)
end

return items
