Gamestate = {}

function Gamestate.switch(state)
    if Gamestate.current then
        if Gamestate.current.leave then
            Gamestate.current:leave()
        end
    end
    Gamestate.current = state
    if Gamestate.current.enter then
        Gamestate.current:enter()
    end
end

function Gamestate.update(dt)
    if Gamestate.current.update then
        Gamestate.current:update(dt)
    end
end

function Gamestate.draw()
    if Gamestate.current.draw then
        Gamestate.current:draw()
    end
end

function Gamestate.keypressed(key)
    if Gamestate.current.keypressed then
        Gamestate.current:keypressed(key)
    end
end

function Gamestate.mousepressed(x, y, button)
    if Gamestate.current.mousepressed then
        Gamestate.current:mousepressed(x, y, button)
    end
end

function Gamestate.mousereleased(x, y, button)
    if Gamestate.current.mousereleased then
        Gamestate.current:mousereleased(x, y, button)
    end
end

function Gamestate.mousemoved(x, y, dx, dy, istouch)
    if Gamestate.current and Gamestate.current.mousemoved then
        Gamestate.current:mousemoved(x, y, dx, dy, istouch)
    end
end

return Gamestate
