Doors = {
    ["F1"] = {{loc = vector3(312.93, -284.45, 54.16), h = 160.91, txtloc = vector3(312.93, -284.45, 54.16), obj = nil, locked = true}, {loc = vector3(310.93, -284.44, 54.16), txtloc = vector3(310.93, -284.44, 54.16), state = nil, locked = true}},
    ["F2"] = {{loc = vector3(148.76, -1045.89, 29.37), h = 158.54, txtloc = vector3(148.76, -1045.89, 29.37), obj = nil, locked = true}, {loc = vector3(146.61, -1046.02, 29.37), txtloc = vector3(146.61, -1046.02, 29.37), state = nil, locked = true}},
    ["F3"] = {{loc = vector3(-1209.66, -335.15, 37.78), h = 213.67, txtloc = vector3(-1209.66, -335.15, 37.78), obj = nil, locked = true}, {loc = vector3(-1211.07, -336.68, 37.78), txtloc = vector3(-1211.07, -336.68, 37.78), state = nil, locked = true}},
    ["F4"] = {{loc = vector3(-2957.26, 483.53, 15.70), h = 267.73, txtloc = vector3(-2957.26, 483.53, 15.70), obj = nil, locked = true}, {loc = vector3(-2956.68, 481.34, 15.70), txtloc = vector3(-2956.68, 481.34, 15.7), state = nil, locked = true}},
    ["F5"] = {{loc = vector3(-351.97, -55.18, 49.04), h = 159.79, txtloc = vector3(-351.97, -55.18, 49.04), obj = nil, locked = true}, {loc = vector3(-354.15, -55.11, 49.04), txtloc = vector3(-354.15, -55.11, 49.04), state = nil, locked = true}},
    ["F6"] = {{loc = vector3(1174.24, 2712.47, 38.09), h = 160.91, txtloc = vector3(1174.24, 2712.47, 38.09), obj = nil, locked = true}, {loc = vector3(1176.40, 2712.75, 38.09), txtloc = vector3(1176.40, 2712.75, 38.09), state = nil, locked = true}},
}

UTK.lastGlobalRobbed = 0

RegisterServerEvent("utk_fh:startcheck")
AddEventHandler("utk_fh:startcheck", function(bank)
    local _source = source
    local copcount = 0
    local players = ESX.GetPlayers()

    for i = 1, #players, 1 do
        local xTarget = ESX.GetPlayerFromId(players[i])
        if xTarget.job.name == "police" then
            copcount = copcount + 1
        end
    end

    local xPlayer = ESX.GetPlayerFromId(_source)
    local item = xPlayer.getInventoryItem("id_card_f")["count"]

    if copcount < UTK.mincops then
        TriggerClientEvent("utk_fh:outcome", _source, false, "There is not enough police in the city.")
        return
    end

    if item < 1 then
        TriggerClientEvent("utk_fh:outcome", _source, false, "You don't have a malicious access card.")
        return
    end

    if UTK.Banks[bank].onaction then
        TriggerClientEvent("utk_fh:outcome", _source, false, "This bank is currently being robbed.")
        return
    end

    local now = os.time()
    if (now - UTK.lastGlobalRobbed) < UTK.globalCooldown then
        local remain = UTK.globalCooldown - (now - UTK.lastGlobalRobbed)
        TriggerClientEvent("utk_fh:outcome", _source, false, "Global cooldown is active. You need to wait " .. math.floor(remain / 60) .. ":" .. string.format("%02d", remain % 60))
        return
    end

    if (now - UTK.Banks[bank].lastrobbed) < UTK.cooldown then
        local remainBank = UTK.cooldown - (now - UTK.Banks[bank].lastrobbed)
        TriggerClientEvent("utk_fh:outcome", _source, false, "This bank recently robbed. You need to wait " .. math.floor(remainBank / 60) .. ":" .. string.format("%02d", remainBank % 60))
        return
    end

    UTK.Banks[bank].onaction = true
    xPlayer.removeInventoryItem("id_card_f", 1)
    TriggerClientEvent("utk_fh:outcome", _source, true, bank)
    TriggerClientEvent("utk_fh:policenotify", -1, bank)
end)

RegisterServerEvent("utk_fh:setCooldown")
AddEventHandler("utk_fh:setCooldown", function(name)
    local now = os.time()
    UTK.Banks[name].lastrobbed = now
    UTK.Banks[name].onaction = false
    UTK.lastGlobalRobbed = now
    TriggerClientEvent("utk_fh:resetDoorState", -1, name)
end)
