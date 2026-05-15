OKGangs = OKGangs or {}
OKGangs.Server = OKGangs.Server or {}
OKGangs.Server.Gangs = {}
OKGangs.Server.Members = {}
OKGangs.Server.ByName = {}

local function safeJsonDecode(value)
    if not value or value == '' then return nil end
    local ok, decoded = pcall(json.decode, value)
    return ok and decoded or nil
end

local function decode(value)
    return OKGangs.DecodeCoords(value) or safeJsonDecode(value)
end

local function normalizeGangRow(row)
    row.id = tonumber(row.id or row.gang_id)
    row.name = OKGangs.Slug(row.name or row.gang_name or row.gang or row.job_name or '')
    row.label = OKGangs.Trim(row.label or row.gang_label or row.name)

    if not row.id or row.name == '' then
        print(('[OK_GANGS] Skipping invalid gangs row while loading cache: id=%s name=%s. Import gang.sql or migrate existing gangs table to the OK_GANGS schema.'):format(tostring(row.id), tostring(row.name)))
        return nil
    end

    if row.label == '' then row.label = row.name end
    return row
end

local function indexGang(row)
    row = normalizeGangRow(row)
    if not row then return false end
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
    return true
end

function OKGangs.Server.LoadCache()
    OKGangs.Server.Gangs, OKGangs.Server.Members, OKGangs.Server.ByName = {}, {}, {}

    for _, gang in ipairs(MySQL.query.await('SELECT * FROM gangs') or {}) do
        indexGang(gang)
    end

    for _, rank in ipairs(MySQL.query.await('SELECT * FROM gang_ranks ORDER BY gang_id, rank') or {}) do
        local gang = OKGangs.Server.Gangs[tonumber(rank.gang_id)]
        if gang then
            rank.permissions = safeJsonDecode(rank.permissions) or {}
            gang.ranks[tonumber(rank.rank)] = rank
        end
    end

    for _, member in ipairs(MySQL.query.await('SELECT * FROM gang_members') or {}) do
        local gang = OKGangs.Server.Gangs[tonumber(member.gang_id)]
        if gang then
            member.rank = tonumber(member.rank) or 1
            gang.members[member.identifier] = member
            OKGangs.Server.Members[member.identifier] = member
        end
    end

    for _, location in ipairs(MySQL.query.await('SELECT * FROM gang_locations') or {}) do
        local gang = OKGangs.Server.Gangs[tonumber(location.gang_id)]
        if gang then
            location.coords = decode(location.coords)
            location.enabled = tonumber(location.enabled) == 1
            gang.locations[location.type] = location
        end
    end

    for _, vehicle in ipairs(MySQL.query.await('SELECT * FROM gang_vehicles') or {}) do
        local gang = OKGangs.Server.Gangs[tonumber(vehicle.gang_id)]
        if gang then
            vehicle.props = safeJsonDecode(vehicle.props)
            vehicle.min_rank = tonumber(vehicle.min_rank) or 1
            vehicle.stored = tonumber(vehicle.stored) == 1
            gang.vehicles[vehicle.plate] = vehicle
        end
    end

    for _, item in ipairs(MySQL.query.await('SELECT * FROM gang_armory_items') or {}) do
        local gang = OKGangs.Server.Gangs[tonumber(item.gang_id)]
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
    return OKGangs.Server.Gangs[tonumber(member.gang_id)], member
end

function OKGangs.Server.SaveLog(gangId, source, action, data)
    local identifier
    if source and source > 0 then
        local xPlayer = ESX.GetPlayerFromId(source)
        identifier = xPlayer and xPlayer.identifier or nil
    end
    MySQL.insert('INSERT INTO gang_logs (gang_id, identifier, action, data) VALUES (?, ?, ?, ?)', { gangId, identifier, action, json.encode(data or {}) })
end
