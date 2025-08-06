-- FlipperUI.keypressed function

local state = require('components.ui.flipper_ui.flipper_state')
local Button = require('components.ui.button')

local function keypressed(key)
    if key == '+' or key == '=' then
        if Button.buttons['bet_up'] and Button.buttons['bet_up'].callback then Button.buttons['bet_up'].callback() end
    elseif key == '-' then
        if Button.buttons['bet_down'] and Button.buttons['bet_down'].callback then Button.buttons['bet_down'].callback() end
    end
end

return keypressed 