local equipment_template = require('components.ui.flipper_ui.equipment_menu.equipment_template')

-- Create rings tab using the template
local template = equipment_template.create({
    slotName = 'rings',
    showAllItems = false
})

local rings_tab = {
    draw = template.draw,
    mousepressed = template.mousepressed,
    mousemoved = template.mousemoved
}

return rings_tab 