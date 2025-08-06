local equipment_template = require('components.ui.flipper_ui.equipment_menu.equipment_template')

-- Create socks tab using the template
local template = equipment_template.create({
    slotName = 'socks',
    showAllItems = false
})

local socks_tab = {
    draw = template.draw,
    mousepressed = template.mousepressed,
    mousemoved = template.mousemoved
}

return socks_tab 