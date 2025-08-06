local equipment_template = require('components.ui.flipper_ui.equipment_menu.equipment_template')

-- Create gloves tab using the template
local template = equipment_template.create({
    slotName = 'gloves',
    showAllItems = false
})

local gloves_tab = {
    draw = template.draw,
    mousepressed = template.mousepressed,
    mousemoved = template.mousemoved
}

return gloves_tab 