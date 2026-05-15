OKGangs = OKGangs or {}
OKGangs.Server = OKGangs.Server or {}
OKGangs.Server.Gangs = {}
OKGangs.Server.Members = {}
OKGangs.Server.ByName = {}

local function decode(value)
    return OKGangs.DecodeCoords(value) or (value and json.decode(value) or nil)
end

local function indexGang(row)
    row.status = tonumber(row.status) or 0
    row.level = tonumber(row.level) or 1
    row.xp = tonumber(row.xp) or 0
    row.money = tonumber(row.money) or 0
    row.black_money = tonumber(row.black_money) or 0
    row.member_slots = tonumber(row.member_slots) or Config.DefaultMemberSlots
    row.ranks = {}
    row.locations = {}
    row.members = {}
    row.vehicles = {}
    row.armory = {}
    OKGangs.Server.Gangs[row.id] = row
    OKGangs.Server.ByName[row.name] = row.id
end

function OKGangs.Server.LoadCache()
    OKGangs.Server.Gangs, OKGangs.Server.Members, OKGangs.Server.ByName = {}, {}, {}

    for _, gang in ipairs(MySQL.query.await('SELECT * FROM gangs') or {}) do
        indexGang(gang)
    end

    for _, rank in ipairs(MySQL.query.await('SELECT * FROM gang_ranks ORDER BY gang_id, rank') or {}) do
        local gang = OKGangs.Server.Gangs[rank.gang_id]
        if gang then
            rank.permissions = rank.permissions and json.decode(rank.permissions) or {}
            gang.ranks[tonumber(rank.rank)] = rank
        end
    end

    for _, member in ipairs(MySQL.query.await('SELECT * FROM gang_members') or {}) do
        local gang = OKGangs.Server.Gangs[member.gang_id]
        if gang then
            member.rank = tonumber(member.rank) or 1
            gang.members[member.identifier] = member
            OKGangs.Server.Members[member.identifier] = member
        end
    end

    for _, location in ipairs(MySQL.query.await('SELECT * FROM gang_locations') or {}) do
        local gang = OKGangs.Server.Gangs[location.gang_id]
        if gang then
            location.coords = decode(location.coords)
            location.enabled = tonumber(location.enabled) == 1
            gang.locations[location.type] = location
        end
    end

    for _, vehicle in ipairs(MySQL.query.await('SELECT * FROM gang_vehicles') or {}) do
        local gang = OKGangs.Server.Gangs[vehicle.gang_id]
        if gang then
            vehicle.props = vehicle.props and json.decode(vehicle.props) or nil
            vehicle.min_rank = tonumber(vehicle.min_rank) or 1
            vehicle.stored = tonumber(vehicle.stored) == 1
            gang.vehicles[vehicle.plate] = vehicle
        end
    end

    for _, item in ipairs(MySQL.query.await('SELECT * FROM gang_armory_items') or {}) do
        local gang = OKGangs.Server.Gangs[item.gang_id]
        if gang then
            item.min_rank = tonumber(item.min_rank) or 1
            item.enabled = tonumber(item.enabled) == 1
            gang.armory[item.item] = item
        end
    end

    print(('[OK_GANGS] Loaded %s gangs and %s members into cache'):format(OKGangs.TableCount(OKGangs.Server.Gangs), OKGangs.TableCount(OKGangs.Server.Members)))
end

function OKGangs.Server.GetGang(gangIdOrName)
    if type(gangIdOrName) == 'string' then
        return OKGangs.Server.Gangs[OKGangs.Server.ByName[gangIdOrName]]
    end
    return OKGangs.Server.Gangs[gangIdOrName]
end

function OKGangs.Server.GetMember(identifier)
    return identifier and OKGangs.Server.Members[identifier] or nil
end

function OKGangs.Server.GetPlayerGang(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil, nil end
    local member = OKGangs.Server.GetMember(xPlayer.identifier)
    if not member then return nil, nil end
    return OKGangs.Server.Gangs[member.gang_id], member
end

function OKGangs.Server.SaveLog(gangId, source, action, data)
    local identifier
    if source and source > 0 then
        local xPlayer = ESX.GetPlayerFromId(source)
        identifier = xPlayer and xPlayer.identifier or nil
    end
    MySQL.insert('INSERT INTO gang_logs (gang_id, identifier, action, data) VALUES (?, ?, ?, ?)', { gangId, identifier, action, json.encode(data or {}) })
end
