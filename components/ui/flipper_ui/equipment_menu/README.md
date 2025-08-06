# Universal Equipment Template System

## Overview

The equipment template system allows any equipment tab (hats, pants, socks, etc.) to be created with just 2-3 lines of code by plugging into the template.

## Basic Usage

### Simple Equipment Tab
```lua
local equipment_template = require('components.ui.flipper_ui.equipment_menu.equipment_template')

-- Create hats tab using the template
local template = equipment_template.create({
    slotName = 'hat',
    showAllItems = false
})

local hats_tab = {
    draw = template.draw,
    mousepressed = template.mousepressed,
    mousemoved = template.mousemoved
}

return hats_tab
```

### Advanced Equipment Tab with Custom Features
```lua
local equipment_template = require('components.ui.flipper_ui.equipment_menu.equipment_template')
local EquipmentManager = require('components.ui.flipper_ui.equipment_menu.equipment_manager')

-- Create hats tab using the template with advanced features
local template = equipment_template.create({
    slotName = 'hat',
    showAllItems = false,
    -- Custom filter: only show hats under 5000 points
    customFilters = function(item)
        return item.price < 5000
    end,
    -- Custom actions: add special effects or logging
    customActions = {
        buy = function(item)
            local success, message = EquipmentManager.buyItem(item)
            if success then
                print("Bought " .. item.name .. " for " .. item.price .. " points!")
            end
            return success, message
        end,
        equip = function(item)
            local success = EquipmentManager.equipItem(item.slot, item)
            if success then
                print("Equipped " .. item.name .. "!")
            end
            return success
        end
    }
})

local hats_tab = {
    draw = template.draw,
    mousepressed = template.mousepressed,
    mousemoved = template.mousemoved
}

return hats_tab
```

## Configuration Options

### Basic Configuration
- `slotName`: The equipment slot ('hat', 'pants', 'socks', etc.)
- `showAllItems`: Whether to show locked items (default: false)

### Advanced Configuration
- `customFilters`: Optional function to filter items
- `customActions`: Optional custom buy/equip/unequip behavior
- `customStyling`: Optional custom colors/themes
- `gridLayout`: Optional custom grid configuration

## Template Features

### Core Features
- **Grid System**: 4-column grid with 88x88 cells, 18px padding
- **Item Management**: Automatic filtering by slot, state management
- **Preview Panel**: Large image, name, description, stats, action button
- **Interaction**: Hover detection, selection, clicking
- **State Handling**: Locked, available, owned, equipped states
- **Visual Feedback**: Border colors, hover effects, selection highlighting

### Template Functions
- `draw(x, y, w, h)`: Renders the entire equipment interface
- `mousepressed(mx, my, x, y, w, h)`: Handles all mouse clicks
- `mousemoved(mx, my, x, y, w, h)`: Handles hover detection
- `update(dt)`: Optional update function for animations/effects

### Data Integration
- Automatically uses EquipmentManager for item states
- Automatically uses Player for points and equipment
- Automatically filters items from data/items.lua by slot
- Handles image loading and caching automatically

### Extensibility Points
- **Custom Item Filters**: Override default filtering logic
- **Custom Button Actions**: Override buy/equip/unequip behavior
- **Custom Visual Styles**: Override colors, borders, effects
- **Custom Layout**: Override grid size, positioning, etc.

## Item States

The template automatically handles these item states:
- **Equipped**: Green background, "EQUIPPED" text
- **Owned**: Yellow background, "OWNED" text
- **Available**: Blue background, price display
- **Locked**: Gray background, "LOCKED" text

## Item Unlock System (KISS Approach)

The equipment template uses a simple, direct approach for item unlocking following KISS principles:

### Simple Unlock Logic
Instead of a complex unlock system, unlock conditions are baked directly into the `getItemState()` function:

```lua
local function getItemState(item)
    -- Simple unlock checks for specific items
    if item.name == "Mock Hat 1" then
        local coinWins = StatsTracker.getCoinFlipWins()
        if coinWins < 1 then return 'locked' end
    elseif item.name == "Mock Hat 2" then
        local coinWins = StatsTracker.getCoinFlipWins()
        if coinWins < 5 then return 'locked' end
    elseif item.name == "Cool Glasses" then
        if Player.getPoints() < 500 then return 'locked' end
    end
    
    -- Then check equipment manager state
    return EquipmentManager.getItemState(item)
end
```

### Benefits of KISS Approach
- **Simple**: No complex unlock system, just direct if/else statements
- **Direct**: Each item's unlock logic is right there in the code
- **Easy to modify**: Change unlock requirements by editing one line
- **No dependencies**: No circular dependencies or complex systems
- **Easy to understand**: You can see exactly what unlocks each item

### Adding New Unlock Conditions
When creating new items, simply add another `elseif` line:

```lua
elseif item.name == "New Item" then
    if Player.getPoints() < 1000 then return 'locked' end
```

This approach eliminates the need for:
- ❌ Complex unlock system files
- ❌ Multiple condition types
- ❌ Circular dependencies
- ❌ Separate configuration files

✅ **Result**: Simple, maintainable, and easy to understand unlock logic

## Performance Features

- **Image Caching**: Images are cached to avoid reloading
- **Efficient Grid Rendering**: Minimal recalculation of item states
- **Smart Update Cycles**: Item list updates are cached per frame
- **Shared State**: Image cache is shared across all template instances

## Error Handling

- Graceful handling of missing images
- Fallback for missing item data
- Safe state checking
- Debug information when needed

## Example Equipment Tabs

All equipment tabs have been updated to use the template:

- `hats_tab.lua` - Basic usage with custom filters and actions
- `pants_tab.lua` - Basic usage
- `socks_tab.lua` - Basic usage
- `gloves_tab.lua` - Basic usage
- `glasses_tab.lua` - Basic usage
- `rings_tab.lua` - Basic usage
- `accessory_tab.lua` - Basic usage

## Success Criteria Met

✅ Creating a new equipment tab requires ≤3 lines of code  
✅ Template handles all common equipment tab functionality  
✅ Template is easily extensible for custom needs  
✅ Template maintains consistent behavior across all equipment types  
✅ All functions use identical item lists (no separate filtering)  
✅ All coordinate calculations call shared utility functions  
✅ Item states are cached once per update cycle  
✅ Grid positioning is calculated consistently across draw/mouse functions  
✅ Hover detection matches visual item positions  

## Bug Prevention Features

- **Shared Item Lists**: All functions use the same cached item list
- **Consistent Coordinates**: Grid positioning uses shared utility functions
- **State Caching**: Item states are calculated once per update cycle
- **Coordinate Validation**: All mouse interactions use the same coordinate system
- **Error Handling**: Graceful fallbacks for missing data or images 