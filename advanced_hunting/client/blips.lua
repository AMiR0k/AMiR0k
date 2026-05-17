AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.Blips = AdvancedHunting.Blips or {}

local Blips = AdvancedHunting.Blips
Blips.created = {}

local function createBlip(coords, data)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, data.sprite)
    SetBlipColour(blip, data.color)
    SetBlipScale(blip, data.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(data.label)
    EndTextCommandSetBlipName(blip)
    return blip
end

function Blips.CreateZoneBlips()
    for zoneId, zone in pairs(HuntingZones) do
        local data = zone.blip or Config.StartStop.blip
        if data and data.enabled then
            Blips.created[#Blips.created + 1] = createBlip(zone.center, data)
            local radius = AddBlipForRadius(zone.center.x, zone.center.y, zone.center.z, zone.radius)
            SetBlipColour(radius, data.radiusColor or data.color)
            SetBlipAlpha(radius, data.radiusAlpha or 70)
            Blips.created[#Blips.created + 1] = radius
        end
    end
end

function Blips.CreateTraderBlips()
    for _, trader in pairs(HuntingTraders) do
        if trader.blip and trader.blip.enabled then
            Blips.created[#Blips.created + 1] = createBlip(vector3(trader.coords.x, trader.coords.y, trader.coords.z), trader.blip)
        end
    end
end

function Blips.Cleanup()
    for _, blip in ipairs(Blips.created) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    Blips.created = {}
end
