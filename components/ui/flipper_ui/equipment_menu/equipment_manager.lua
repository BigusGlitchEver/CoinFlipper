local Player = require('components.player.player')
local Items = require('data.items')
local Stats = require('data.stats')
local StatsTracker = require('components.player.stats_tracker')
local Inventory = require('components.player.inventory')

local EquipmentManager = {}

-- Use the global inventory system

-- Buy an item (deduct points, add to inventory)
function EquipmentManager.buyItem(item)
    if Inventory.hasItem(item.id) then return false, 'Already owned' end
    if Player.getPoints() < item.price then return false, 'Not enough points' end
    Player.subtractPoints(item.price)
    Inventory.addItem(item.id)
    StatsTracker.onItemPurchased()
    return true
end

-- Equip an item to a slot
function EquipmentManager.equipItem(slot, item)
    if not EquipmentManager.inventory[item.id] then return false, 'Not owned' end
    Player.equipItem(slot, item)
    return true
end

-- Unequip an item from a slot
function EquipmentManager.unequipItem(slot)
    Player.equipItem(slot, nil)
    return true
end

-- Get the state of an item: 'equipped', 'owned', 'available', 'locked'
function EquipmentManager.getItemState(item)
    -- Add safety check
    local equipped = Player.equipped and Player.equipped[item.slot]
    if equipped and equipped.id == item.id then
        return 'equipped'
    elseif Inventory.hasItem(item.id) then
        return 'owned'
    elseif Player.getPoints() >= item.price then
        return 'available'
    else
        return 'locked'
    end
end

-- Get all items for a slot, optionally sorted by state
function EquipmentManager.getItemsForSlot(slot, showAll)
    local list = {}
    for _, item in ipairs(Items) do
        if item.slot == slot then
            -- Use the item's own getItemState function if it exists (KISS approach)
            local state
            if item.getItemState then
                state = item.getItemState()
            else
                state = EquipmentManager.getItemState(item)
            end
            -- Fixed: showAll shows everything, otherwise hide locked
            if showAll or state ~= 'locked' then
                table.insert(list, item)
            end
        end
    end
    -- Don't sort - keep items in their original order
    -- This prevents items from jumping around when they unlock
    return list
end

-- Recalculate player stats (delegates to Player)
function EquipmentManager.recalculateStats()
    Player.recalculateStats()
end

return EquipmentManager 