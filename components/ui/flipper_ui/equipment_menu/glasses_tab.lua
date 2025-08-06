local equipment_template = require('components.ui.flipper_ui.equipment_menu.equipment_template')

-- Create glasses tab using the template
local template = equipment_template.create({
    slotName = 'glasses',
    showAllItems = false
})

local glasses_tab = {
    draw = template.draw,
    mousepressed = template.mousepressed,
    mousemoved = template.mousemoved
}

return glasses_tab 