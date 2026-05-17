AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.Tracking = AdvancedHunting.Tracking or {}
AdvancedHunting.Tracking.blood = {}

function AdvancedHunting.Tracking.AddBlood(coords)
    local marker = {coords = coords, expires = GetGameTimer() + 60000}
    AdvancedHunting.Tracking.blood[#AdvancedHunting.Tracking.blood + 1] = marker
end

CreateThread(function()
    while true do
        local sleep = 1500
        if AdvancedHunting.State and AdvancedHunting.State.active then
            local playerCoords = GetEntityCoords(PlayerPedId())
            for index = #AdvancedHunting.Tracking.blood, 1, -1 do
                local blood = AdvancedHunting.Tracking.blood[index]
                if blood.expires < GetGameTimer() then
                    table.remove(AdvancedHunting.Tracking.blood, index)
                elseif #(playerCoords - blood.coords) < 35.0 then
                    sleep = 0
                    DrawMarker(28, blood.coords.x, blood.coords.y, blood.coords.z + 0.02, 0, 0, 0, 0, 0, 0, 0.18, 0.18, 0.02, 160, 0, 0, 150, false, false, 2, false, nil, nil, false)
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        if AdvancedHunting.State and AdvancedHunting.State.active then
            for _, data in pairs(AdvancedHunting.Spawn.spawned) do
                if DoesEntityExist(data.entity) and not IsEntityDead(data.entity) and GetEntityHealth(data.entity) < 80 then
                    AdvancedHunting.Tracking.AddBlood(GetEntityCoords(data.entity))
                    TaskSmartFleePed(data.entity, PlayerPedId(), 120.0, 20000, false, false)
                end
            end
        end
        Wait(5000)
    end
end)
