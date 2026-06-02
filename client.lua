Freeze = {F1 = 0, F2 = 0, F3 = 0, F4 = 0, F5 = 0, F6 = 0}
PlayerData = nil
Check = {F1 = false, F2 = false, F3 = false, F4 = false, F5 = false, F6 = false}
LootCheck = {
    F1 = {Stop = false, Loot1 = false, Loot2 = false, Loot3 = false},
    F2 = {Stop = false, Loot1 = false, Loot2 = false, Loot3 = false},
    F3 = {Stop = false, Loot1 = false, Loot2 = false, Loot3 = false},
    F4 = {Stop = false, Loot1 = false, Loot2 = false, Loot3 = false},
    F5 = {Stop = false, Loot1 = false, Loot2 = false, Loot3 = false},
    F6 = {Stop = false, Loot1 = false, Loot2 = false, Loot3 = false}
}
local disableinput = false

function Process(ms, text)
    exports['progressBars']:startUI(ms, text)
    Citizen.Wait(ms)
end

RegisterNetEvent("utk_fh:outcome")
AddEventHandler("utk_fh:outcome", function(oc, arg)
    if oc then
        TriggerEvent("utk_fh:startheist", UTK.Banks[arg], arg)
    else
        exports['okokNotify']:Alert("خطا", tostring(arg), 5000, 'error')
    end
end)

AddEventHandler("utk_fh:startheist", function(data, name)
    disableinput = true

    RequestModel("p_ld_id_card_01")
    while not HasModelLoaded("p_ld_id_card_01") do
        Citizen.Wait(1)
    end

    local ped = PlayerPedId()
    SetEntityCoords(ped, data.doors.startloc.animcoords.x, data.doors.startloc.animcoords.y, data.doors.startloc.animcoords.z)
    SetEntityHeading(ped, data.doors.startloc.animcoords.h)
    TaskStartScenarioInPlace(ped, "PROP_HUMAN_ATM", 0, true)
    exports['progressBars']:startUI(2000, "Using Malicious Card")
    Citizen.Wait(1500)
    ClearPedTasksImmediately(ped)

    disableinput = false
    Citizen.Wait(500)

    -- اولین مرحله هک با utk_hackdependency
    local ok = exports['utk_hackdependency']:StartHack(UTK.hacktime)
    if not ok then
        TriggerServerEvent("utk_fh:stopHeist", name)
        exports['okokNotify']:Alert("خطا", "هک ناموفق بود", 5000, 'error')
        return
    end

    exports['okokNotify']:Alert("موفق", "هک کامل شد!", 5000, 'success')
    TriggerServerEvent("utk_fh:toggleVault", name, false)
end)
