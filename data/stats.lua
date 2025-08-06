local Stats = {}

-- Order in which stats should be displayed or iterated
Stats.order = {"luck", "speed", "coin_value", "critical_chance", "multi_flip"}

-- Stat definitions
Stats.definitions = {
    luck = {
        name = "Luck",
        description = "Increases chance of favorable coin flips",
        default = 0,
        display_format = "+%d Luck",
        type = "flat"
    },
    speed = {
        name = "Flipping Speed",
        description = "Reduces time between coin flips",
        default = 0,
        display_format = "+%d Speed",
        type = "flat"
    },
    coin_value = {
        name = "Coin Value",
        description = "Multiplier for points earned per flip",
        default = 0,
        display_format = "+%d%% Value",
        type = "percent"
    },
    critical_chance = {
        name = "Critical Chance",
        description = "Chance for bonus point multipliers",
        default = 0,
        display_format = "+%d%% Crit",
        type = "percent"
    },
    multi_flip = {
        name = "Multi-Flip",
        description = "Chance to flip multiple coins at once",
        default = 0,
        display_format = "+%d%% Multi",
        type = "percent"
    }
}

-- Format a stat bonus for display
function Stats.formatStatBonus(statName, value)
    local def = Stats.definitions[statName]
    if def and def.display_format then
        return string.format(def.display_format, value)
    end
    return string.format("+%d %s", value, statName)
end

-- Validate that a stat exists
function Stats.isValidStat(statName)
    return Stats.definitions[statName] ~= nil
end

-- Get the default value for a stat
function Stats.getDefault(statName)
    local def = Stats.definitions[statName]
    return def and def.default or 0
end

-- Iterate stats in the defined order
function Stats.orderedPairs(tbl)
    local i = 0
    local function iter()
        i = i + 1
        local statName = Stats.order[i]
        if statName then
            return statName, tbl[statName]
        end
    end
    return iter
end

return Stats 