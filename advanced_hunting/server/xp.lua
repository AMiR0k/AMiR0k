AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.XP = AdvancedHunting.XP or {}

local XP = AdvancedHunting.XP
local cache = {}

local function identifier(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer and xPlayer.identifier
end

function XP.Required(level)
    return math.floor(Config.XP.baseLevelXP * (level ^ Config.XP.levelMultiplier))
end

function XP.Get(source)
    local id = identifier(source)
    if not id then return {level = 1, xp = 0} end
    if cache[id] then return cache[id] end
    local row = MySQL.single.await(('SELECT level, xp FROM %s WHERE identifier = ?'):format(Config.XP.tableName), {id})
    cache[id] = row or {level = 1, xp = 0}
    return cache[id]
end

function XP.Add(source, amount)
    if not Config.XP.enabled then return 1 end
    local id = identifier(source)
    if not id then return 1 end
    local data = XP.Get(source)
    data.xp = data.xp + amount
    while data.xp >= XP.Required(data.level) do
        data.xp = data.xp - XP.Required(data.level)
        data.level = data.level + 1
        TriggerClientEvent('ox_lib:notify', source, {description = _L('level_up', data.level), type = 'success'})
    end
    MySQL.prepare(('INSERT INTO %s (identifier, level, xp) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE level = VALUES(level), xp = VALUES(xp)'):format(Config.XP.tableName), {id, data.level, data.xp})
    return data.level
end
