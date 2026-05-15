OKGangs = OKGangs or {}
OKGangs.Server = OKGangs.Server or {}

function OKGangs.Server.AddXP(gangId, amount, reason)
    local gang = OKGangs.Server.Gangs[tonumber(gangId)]
    if not gang then return false end
    amount = math.max(0, tonumber(amount) or 0)
    if amount == 0 then return true end
    gang.xp = gang.xp + amount
    local nextLevel = gang.level * 1000
    while gang.xp >= nextLevel do
        gang.xp = gang.xp - nextLevel
        gang.level = gang.level + 1
        nextLevel = gang.level * 1000
    end
    MySQL.update.await('UPDATE gangs SET xp = ?, level = ? WHERE id = ?', { gang.xp, gang.level, gang.id })
    OKGangs.Server.Audit(gang.id, 0, 'XP Gain', { amount = amount, reason = reason, level = gang.level, xp = gang.xp })
    return true
end

CreateThread(function()
    while true do
        Wait(Config.SalaryInterval)
        for _, playerId in ipairs(ESX.GetPlayers()) do
            local gang, member = OKGangs.Server.GetPlayerGang(playerId)
            if gang and member and gang.status == 1 then
                local rank = gang.ranks[member.rank]
                local salary = rank and tonumber(rank.salary) or 0
                if salary and salary > 0 then
                    local xPlayer = ESX.GetPlayerFromId(playerId)
                    if xPlayer then xPlayer.addAccountMoney('bank', salary) end
                end
            end
        end
    end
end)
