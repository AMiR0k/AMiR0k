AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.Zones = AdvancedHunting.Zones or {}
AdvancedHunting.State = AdvancedHunting.State or {active = false, currentZone = nil, previousSkin = nil}

local Zones = AdvancedHunting.Zones

function Zones.IsInsideAny(coords)
    return AdvancedHunting.Utils.GetZoneAtCoords(coords)
end

function Zones.Monitor()
    CreateThread(function()
        while true do
            local sleep = AdvancedHunting.State.active and 1000 or 2500
            local coords = GetEntityCoords(PlayerPedId())
            local zoneId, zone = Zones.IsInsideAny(coords)

            if zoneId ~= AdvancedHunting.State.currentZone then
                if AdvancedHunting.State.currentZone then
                    AdvancedHunting.Spawn.CleanupZone(AdvancedHunting.State.currentZone)
                    AdvancedHunting.Utils.Notify(_L('leave_zone', HuntingZones[AdvancedHunting.State.currentZone].name), 'inform')
                end
                AdvancedHunting.State.currentZone = zoneId
                if zoneId then AdvancedHunting.Utils.Notify(_L('enter_zone', zone.name), 'inform') end
            end

            if AdvancedHunting.State.active and zoneId then
                AdvancedHunting.Spawn.TrySpawn(zoneId, zone)
            end

            if AdvancedHunting.State.active and zoneId == nil then
                AdvancedHunting.Spawn.CleanupZone()
            end
            Wait(sleep)
        end
    end)
end
