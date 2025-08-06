local Dropdown = {}

local dropdowns = {}
local activeDropdown = nil

function Dropdown.create(id, x, y, w, h, options, selectedIndex, onSelect)
    dropdowns[id] = {
        x = x, y = y, w = w, h = h,
        options = options or {},
        selectedIndex = selectedIndex or 1,
        isOpen = false,
        anim = 0,
        onSelect = onSelect,
        hoverIndex = nil,
    }
end

function Dropdown.update(dt)
    for id, dd in pairs(dropdowns) do
        if dd.isOpen then
            dd.anim = math.min(1, dd.anim + dt * 10)
        else
            dd.anim = math.max(0, dd.anim - dt * 10)
        end
    end
end

function Dropdown.draw()
    for id, dd in pairs(dropdowns) do
        local x, y, w, h = dd.x, dd.y, dd.w, dd.h
        -- Main button
        love.graphics.setColor(0.85, 0.1, 0)
        love.graphics.rectangle('fill', x, y, w, h, 8)
        love.graphics.setColor(1, 215/255, 0)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle('line', x, y, w, h, 8)
        love.graphics.setColor(1, 1, 1)
        local label = dd.options[dd.selectedIndex] or 'Select...'
        love.graphics.print(label, x + 10, y + 6)
        love.graphics.print(dd.isOpen and '▲' or '▼', x + w - 24, y + 6)
        -- Dropdown list
        if dd.anim > 0 then
            local optH = h
            local n = #dd.options
            local listH = n * optH * dd.anim
            love.graphics.setColor(0.7, 0, 0, dd.anim)
            love.graphics.rectangle('fill', x, y + h, w, listH, 8)
            love.graphics.setColor(1, 215/255, 0, dd.anim)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle('line', x, y + h, w, listH, 8)
            for i = 1, n do
                local oy = y + h + (i-1)*optH
                if dd.isOpen and (dd.hoverIndex == i or dd.selectedIndex == i) then
                    love.graphics.setColor(1, 0.85, 0, 0.25*dd.anim+0.25)
                    love.graphics.rectangle('fill', x+2, oy+2, w-4, optH-4, 6)
                end
                love.graphics.setColor(1, 1, 1, dd.anim)
                love.graphics.print(dd.options[i], x + 10, oy + 6)
            end
        end
    end
end

function Dropdown.mousepressed(x, y, button)
    if button ~= 1 then return false end
    for id, dd in pairs(dropdowns) do
        local bx, by, bw, bh = dd.x, dd.y, dd.w, dd.h
        -- Main button
        if x >= bx and x <= bx + bw and y >= by and y <= by + bh then
            -- Toggle open/close
            dd.isOpen = not dd.isOpen
            if dd.isOpen then
                activeDropdown = id
            else
                activeDropdown = nil
            end
            return true
        end
        -- Dropdown list
        if dd.isOpen and dd.anim > 0.5 then
            local optH = bh
            for i = 1, #dd.options do
                local oy = by + bh + (i-1)*optH
                if x >= bx and x <= bx + bw and y >= oy and y <= oy + optH then
                    dd.selectedIndex = i
                    dd.isOpen = false
                    activeDropdown = nil
                    if dd.onSelect then dd.onSelect(i, dd.options[i]) end
                    return true
                end
            end
        end
    end
    -- Click outside closes all
    if activeDropdown then
        dropdowns[activeDropdown].isOpen = false
        activeDropdown = nil
        return true
    end
    return false
end

function Dropdown.mousemoved(x, y)
    for id, dd in pairs(dropdowns) do
        if dd.isOpen then
            local bx, by, bw, bh = dd.x, dd.y, dd.w, dd.h
            local optH = bh
            dd.hoverIndex = nil
            for i = 1, #dd.options do
                local oy = by + bh + (i-1)*optH
                if x >= bx and x <= bx + bw and y >= oy and y <= oy + optH then
                    dd.hoverIndex = i
                end
            end
        end
    end
end

function Dropdown.keypressed(key)
    if not activeDropdown then return end
    local dd = dropdowns[activeDropdown]
    if not dd or not dd.isOpen then return end
    if key == 'up' then
        dd.hoverIndex = (dd.hoverIndex or dd.selectedIndex or 1) - 1
        if dd.hoverIndex < 1 then dd.hoverIndex = #dd.options end
    elseif key == 'down' then
        dd.hoverIndex = (dd.hoverIndex or dd.selectedIndex or 1) + 1
        if dd.hoverIndex > #dd.options then dd.hoverIndex = 1 end
    elseif key == 'return' or key == 'kpenter' or key == 'space' then
        if dd.hoverIndex then
            dd.selectedIndex = dd.hoverIndex
            dd.isOpen = false
            activeDropdown = nil
            if dd.onSelect then dd.onSelect(dd.selectedIndex, dd.options[dd.selectedIndex]) end
        end
    elseif key == 'escape' then
        dd.isOpen = false
        activeDropdown = nil
    end
end

function Dropdown.getSelected(id)
    local dd = dropdowns[id]
    if dd then
        return dd.selectedIndex, dd.options[dd.selectedIndex]
    end
    return nil, nil
end

function Dropdown.setSelected(id, index)
    local dd = dropdowns[id]
    if dd and index >= 1 and index <= #dd.options then
        dd.selectedIndex = index
    end
end

function Dropdown.clear()
    dropdowns = {}
    activeDropdown = nil
end

return Dropdown 