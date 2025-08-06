local equipment_template = require('components.ui.flipper_ui.equipment_menu.equipment_template')

-- Create hats tab using the template
local template = equipment_template.create({
    slotName = 'hat',
    showAllItems = true
})

local hats_tab = {
    draw = template.draw,
    mousepressed = template.mousepressed,
    mousemoved = template.mousemoved
}

return hats_tab
