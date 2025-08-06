-- Global Inventory System
-- Provides access to player's item inventory without circular dependencies

local Inventory = {}

-- Initialize inventory if not already done
Inventory.items = Inventory.items or {}

-- Check if player owns an item
function Inventory.hasItem(itemId)
    return Inventory.items[itemId] == true
end

-- Add item to inventory
function Inventory.addItem(itemId)
    Inventory.items[itemId] = true
end

-- Remove item from inventory
function Inventory.removeItem(itemId)
    Inventory.items[itemId] = nil
end

-- Get all owned item IDs
function Inventory.getOwnedItems()
    local owned = {}
    for itemId, _ in pairs(Inventory.items) do
        table.insert(owned, itemId)
    end
    return owned
end

-- Clear inventory (for testing)
function Inventory.clear()
    Inventory.items = {}
end

return Inventory 