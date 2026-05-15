OKGangs = OKGangs or {}
OKGangs.Client = OKGangs.Client or {}

function OKGangs.Client.RefreshBlips()
    for _, blip in pairs(OKGangs.Client.blips or {}) do RemoveBlip(blip) end
    OKGangs.Client.blips = {}
    for _, gang in ipairs(OKGangs.Client.gangs or {}) do
        local loc = gang.locations and gang.locations.blip
        if gang.status == 1 and loc and loc.enabled and loc.coords then
            local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
            SetBlipSprite(blip, Config.BlipDefaults.sprite)
            SetBlipColour(blip, Config.BlipDefaults.colour)
            SetBlipScale(blip, Config.BlipDefaults.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(gang.label)
            EndTextCommandSetBlipName(blip)
            OKGangs.Client.blips[#OKGangs.Client.blips + 1] = blip
        end
    end
end
