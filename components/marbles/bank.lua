-- components/marbles/bank.lua
-- The global Marble bank. One currency to rule them all (per GDD).
-- Grows from completed runs and from passive building generation.

local Bank = {}
Bank.__index = Bank

function Bank.new(starting)
    return setmetatable({ amount = starting or 0 }, Bank)
end

function Bank:balance()
    return self.amount
end

function Bank:deposit(n)
    if n and n > 0 then
        self.amount = self.amount + n
    end
end

function Bank:spend(n)
    if n and n > 0 and self.amount >= n then
        self.amount = self.amount - n
        return true
    end
    return false
end

-- Apply passive income from buildings each tick.
-- income = Marbles per second; dt = seconds elapsed.
function Bank:accrue(income, dt)
    if income and income > 0 and dt and dt > 0 then
        self.amount = self.amount + income * dt
    end
end

function Bank:getSaveData()
    return { amount = self.amount }
end

function Bank:loadSaveData(data)
    if data and data.amount then
        self.amount = data.amount
    end
end

return Bank
