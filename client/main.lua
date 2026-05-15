OKGangs = OKGangs or {}
OKGangs.Client = OKGangs.Client or { gangs = {}, myGang = nil, myMember = nil, points = {}, blips = {} }

local function setPlayerGang(gang, member)
    OKGangs.Client.myGang = gang
    OKGangs.Client.myMember = member
end

RegisterNetEvent('ok_gangs:client:syncGangs', function(gangs)
    OKGangs.Client.gangs = gangs or {}
    OKGangs.Client.RefreshBlips()
    OKGangs.Client.RefreshPoints()
end)

RegisterNetEvent('ok_gangs:client:playerGang', function(gang, member)
    setPlayerGang(gang, member)
    OKGangs.Client.RefreshPoints()
end)

CreateThread(function()
    Wait(1500)
    local gang, member = lib.callback.await('ok_gangs:server:getMyGang', false)
    setPlayerGang(gang, member)
    OKGangs.Client.gangs = lib.callback.await('ok_gangs:server:getAllGangs', false) or OKGangs.Client.gangs
    OKGangs.Client.RefreshBlips()
    OKGangs.Client.RefreshPoints()
end)

RegisterCommand('ok_gang_menu', function()
    if OKGangs.Client.myGang then OKGangs.Client.OpenGangMenu() end
end, false)
RegisterKeyMapping('ok_gang_menu', 'Open gang menu', 'keyboard', Config.Keys.gangMenu)
