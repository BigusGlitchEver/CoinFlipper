-- Hats items with KISS unlock conditions
-- Each item has its own getItemState function with unlock logic baked in
local Player = require('components.player.player')
local Inventory = require('components.player.inventory')
local StatsTracker = require('components.player.stats_tracker')
local crew = require('components.crew.crew')
local BuildingManager = require('components.buildings.manager')

local hats = {
    {
        id = "classic_hat",
        name = "Classic Hat",
        slot = "hat",
        image = "assets/upgrades/hats/classichat.png",
        price = 1000,
        stats = { coin_value = 10 },
        description = "A timeless classic.",
        getItemState = function()
            if Player.equipped and Player.equipped.hat and Player.equipped.hat.id == "classic_hat" then return 'equipped' end
            if Inventory.hasItem("classic_hat") then return 'owned' end
            if Player.getPoints() >= 1000 then return 'available' end
            return 'locked'
        end
    },
    {
        id = "mock_hat_1",
        name = "Mock Hat 1",
        slot = "hat",
        image = "assets/upgrades/hats/classichat.png",
        price = 1000001,
        stats = { coin_value = 0 },
        description = "A mysterious locked hat.",
        getItemState = function()
            if StatsTracker.getCoinFlipWins() < 1 then
                return 'locked'
            end
            -- Permanently unlocked after first coin win
            if Player.equipped and Player.equipped.hat and Player.equipped.hat.id == "mock_hat_1" then return 'equipped' end
            if Inventory.hasItem("mock_hat_1") then return 'owned' end
            if Player.getPoints() >= 1000001 then return 'available' end
            return 'unavailable'
        end
    },
    {
        id = "mock_hat_2",
        name = "Mock Hat 2",
        slot = "hat",
        image = "assets/upgrades/hats/classichat.png",
        price = 1000002,
        stats = { coin_value = 0 },
        description = "A mysterious locked hat.",
        getItemState = function()
            if StatsTracker.getTotalCoinsEarned() < 1000005 then
                return 'locked'
            end
            -- Permanently unlocked after earning enough
            if Player.equipped and Player.equipped.hat and Player.equipped.hat.id == "mock_hat_2" then return 'equipped' end
            if Inventory.hasItem("mock_hat_2") then return 'owned' end
            if Player.getPoints() >= 1000002 then return 'available' end
            return 'unavailable'
        end
    },
    {
        id = "mock_hat_3",
        name = "Mock Hat 3",
        slot = "hat",
        image = "assets/upgrades/hats/classichat.png",
        price = 1000003,
        stats = { coin_value = 0 },
        description = "A mysterious locked hat.",
        getItemState = function()
            if crew.types.friend.owned < 1 then
                return 'locked'
            end
            -- Permanently unlocked after buying friend
            if Player.equipped and Player.equipped.hat and Player.equipped.hat.id == "mock_hat_3" then return 'equipped' end
            if Inventory.hasItem("mock_hat_3") then return 'owned' end
            if Player.getPoints() >= 1000003 then return 'available' end
            return 'unavailable'
        end
    },
    {
        id = "mock_hat_4",
        name = "Mock Hat 4",
        slot = "hat",
        image = "assets/upgrades/hats/classichat.png",
        price = 1000004,
        stats = { coin_value = 0 },
        description = "A mysterious locked hat.",
        getItemState = function()
            if crew.types.gambler.owned < 1 then
                return 'locked'
            end
            -- Permanently unlocked after buying gambler
            if Player.equipped and Player.equipped.hat and Player.equipped.hat.id == "mock_hat_4" then return 'equipped' end
            if Inventory.hasItem("mock_hat_4") then return 'owned' end
            if Player.getPoints() >= 1000004 then return 'available' end
            return 'unavailable'
        end
    },
    {
        id = "mock_hat_5",
        name = "Mock Hat 5",
        slot = "hat",
        image = "assets/upgrades/hats/classichat.png",
        price = 1000005,
        stats = { coin_value = 0 },
        description = "A mysterious locked hat.",
        getItemState = function()
            local buildings = BuildingManager.getBuildings()
            local hasAnyBuilding = false
            for _, building in ipairs(buildings) do
                if building.owned > 0 then
                    hasAnyBuilding = true
                    break
                end
            end
            if not hasAnyBuilding then
                return 'locked'
            end
            -- Permanently unlocked after buying any building
            if Player.equipped and Player.equipped.hat and Player.equipped.hat.id == "mock_hat_5" then return 'equipped' end
            if Inventory.hasItem("mock_hat_5") then return 'owned' end
            if Player.getPoints() >= 1000005 then return 'available' end
            return 'unavailable'
        end
    }
}

return hats 