local InputHandler = {}

-- Get required components
local ModalMenu = require('components.modal_menu')
local FlipperUI = require('components.ui.flipper_ui')
local Dropdown = require('components.ui.dropdown')
local DropdownHandler = require('components.ui.dropdown_handler')
local upgrades_menu = require('components.ui.flipper_ui.upgrades_menu')

-- Main mouse input handler - processes clicks in priority order
function InputHandler.handleMousePress(x, y, button)
    if button ~= 1 then return end -- Only handle left clicks
    
    -- Priority 1: Handle dropdowns first (they consume clicks when open)
    if DropdownHandler.handleDropdownClicks(x, y, button) then
        return -- Dropdown handled the click - stop processing
    end
    
    -- Priority 1.25: Handle equipment sub-tabs if upgrades menu is open and Equipment tab is selected
    if ModalMenu.isOpen and upgrades_menu.selectedTab == 1 and upgrades_menu.tabs then
        if upgrades_menu.tabs[1].module.mousepressed_absolute(x, y, button) then
            return -- Equipment sub-tab handled the click
        end
    end
    
    -- Priority 1.5: Handle upgrades modal tabs (absolute coordinates)
    if ModalMenu.isOpen and upgrades_menu.absoluteTabPositions and #upgrades_menu.absoluteTabPositions > 0 then
        if upgrades_menu.mousepressed_absolute(x, y, button) then
            return -- Tab handled it, don't process modal close
        end
    end
    
    -- Priority 2: Handle modal input if modal is open
    if ModalMenu.isOpen then
        ModalMenu.mousepressed(x, y, button)
        return -- Modal handled the click - stop processing
    end
    
    -- Priority 3: Handle main UI input
    Dropdown.mousepressed(x, y, button)
    FlipperUI.mousepressed(x, y, button)
end

-- Delegate other input events
function InputHandler.handleMouseMoved(x, y)
    Dropdown.mousemoved(x, y)
    FlipperUI.mousemoved(x, y)
    -- Add hover support for equipment tabs when upgrades menu is open and Equipment tab is selected
    if ModalMenu.isOpen and upgrades_menu.selectedTab == 1 and upgrades_menu.tabs then
        local equipment_tab = upgrades_menu.tabs[1].module or require('components.ui/flipper_ui/upgrades_menu/equipment_tab')
        if equipment_tab.mousemoved_absolute then
            equipment_tab.mousemoved_absolute(x, y)
        end
    end
end

function InputHandler.handleKeyPressed(key)
    Dropdown.keypressed(key)
    FlipperUI.keypressed(key)
end

return InputHandler 