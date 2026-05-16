OKGangs = OKGangs or {}
OKGangs.Client = OKGangs.Client or {}

local function clearPoints()
    for _, point in pairs(OKGangs.Client.points or {}) do point:remove() end
    OKGangs.Client.points = {}
end

local function canUseGang(gang)
    return OKGangs.Client.myGang and gang and OKGangs.Client.myGang.id == gang.id and gang.status == 1
end

local handlers = {
    stash = function(gang) TriggerServerEvent('ok_gangs:server:openStash', gang.name) end,
    armory = function(gang) TriggerServerEvent('ok_gangs:server:openArmory', gang.name) end,
    boss = function(gang) OKGangs.Client.OpenBossMenu(gang) end,
    crafting = function(gang) OKGangs.Client.OpenCrafting(gang) end,
    garage = function(gang) OKGangs.Client.OpenVehicleMenu(gang, 'car') end,
    heli_garage = function(gang) OKGangs.Client.OpenVehicleMenu(gang, 'helicopter') end,
    vehicle_store = function(gang) OKGangs.Client.StoreCurrentVehicle(gang, 'car') end,
    heli_store = function(gang) OKGangs.Client.StoreCurrentVehicle(gang, 'helicopter') end
}

function OKGangs.Client.RefreshPoints()
    clearPoints()
    for _, gang in ipairs(OKGangs.Client.gangs or {}) do
        if canUseGang(gang) then
            for locationType, location in pairs(gang.locations or {}) do
                if handlers[locationType] and location.enabled and location.coords then
                    local point = lib.points.new({ coords = vec3(location.coords.x, location.coords.y, location.coords.z), distance = Config.MarkerDistance, gang = gang, locationType = locationType })
                    function point:nearby()
                        DrawMarker(2, self.coords.x, self.coords.y, self.coords.z + 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35, 255, 120, 0, 160, false, true, 2, nil, nil, false)
                        if self.currentDistance <= Config.InteractDistance then
                            lib.showTextUI(('[E] %s'):format(self.locationType))
                            if IsControlJustReleased(0, Config.Keys.interact) then handlers[self.locationType](self.gang) end
                        else
                            lib.hideTextUI()
                        end
                    end
                    function point:onExit() lib.hideTextUI() end
                    OKGangs.Client.points[#OKGangs.Client.points + 1] = point
                end
            end
        end
    end
end
