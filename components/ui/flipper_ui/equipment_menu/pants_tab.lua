local equipment_template = require('components.ui.flipper_ui.equipment_menu.equipment_template')

-- Create pants tab using the template
local template = equipment_template.create({
    slotName = 'pants',
    showAllItems = false
})

local pants_tab = {
    draw = template.draw,
    mousepressed = template.mousepressed,
    mousemoved = template.mousemoved
}

return pants_tab 