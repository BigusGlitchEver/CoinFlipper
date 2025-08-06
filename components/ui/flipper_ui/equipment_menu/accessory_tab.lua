local equipment_template = require('components.ui.flipper_ui.equipment_menu.equipment_template')

-- Create accessory tab using the template
local template = equipment_template.create({
    slotName = 'accessory',
    showAllItems = false
})

local accessory_tab = {
    draw = template.draw,
    mousepressed = template.mousepressed,
    mousemoved = template.mousemoved
}

return accessory_tab 