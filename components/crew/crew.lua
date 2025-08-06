local crew = {}

crew.types = {
    friend = {
        name = "Friend",
        description = "Basic helpers who flip coins for you",
        cost = 100,
        costMultiplier = 1.15,
        interval = 3.0,
        coinsPerCycle = 1,
        winRate = 0.5,
        owned = 0,
        assignments = {}
    },
    gambler = {
        name = "Gambler",
        description = "Experienced flippers with better timing",
        cost = 500,
        costMultiplier = 1.15,
        interval = 2.0,
        coinsPerCycle = 2,
        winRate = 0.55,
        owned = 0,
        assignments = {}
    },
    highRoller = {
        name = "High Roller",
        description = "Elite flippers with high win rates",
        cost = 2500,
        costMultiplier = 1.15,
        interval = 1.5,
        coinsPerCycle = 3,
        winRate = 0.65,
        owned = 0,
        assignments = {}
    }
}

function crew.getCost(crewType)
    local c = crew.types[crewType]
    return math.floor(c.cost * (c.costMultiplier ^ c.owned))
end

function crew.canAfford(crewType, playerPoints)
    return playerPoints >= crew.getCost(crewType)
end

function crew.buy(crewType, playerPoints)
    if crew.canAfford(crewType, playerPoints) then
        local cost = crew.getCost(crewType)
        crew.types[crewType].owned = crew.types[crewType].owned + 1
        crew.types[crewType].assignments[crew.types[crewType].owned] = 'coin' -- default assignment
        return cost
    end
    return 0
end

return crew 