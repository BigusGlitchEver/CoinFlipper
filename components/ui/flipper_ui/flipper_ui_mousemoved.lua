-- FlipperUI.mousemoved function

local state = require('components.ui.flipper_ui.flipper_state')

local function mousemoved(x, y)
    state.mouseX, state.mouseY = x, y
end

return mousemoved 