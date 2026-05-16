OKGangs = OKGangs or {}
OKGangs.Server = OKGangs.Server or {}

local function publicGang(gang)
    if not gang then return nil end
    return {
        id = gang.id,
        name = gang.name,
        label = gang.label,
        status = gang.status,
        level = gang.level,
        xp = gang.xp,
        money = gang.money,
        black_money = gang.black_money,
        member_slots = gang.member_slots,
        expires_at = gang.expires_at,
        ranks = gang.ranks,
        locations = gang.locations,
        memberCount = OKGangs.TableCount(gang.members)
    }
end

function OKGangs.Server.GetPublicGang(gang)
    return publicGang(gang)
end

function OKGangs.Server.GetAllPublicGangs()
    local gangs = {}
    for _, gang in pairs(OKGangs.Server.Gangs) do gangs[#gangs + 1] = publicGang(gang) end
    table.sort(gangs, function(a, b) return a.name < b.name end)
    return gangs
end

function OKGangs.Server.CreateGang(source, data)
    if not OKGangs.Server.RequireAdmin(source) then return false, OKGangs.Errors.no_permission end
    local name = OKGangs.Slug(data.name)
    local label = OKGangs.Trim(data.label)
    local days = math.max(Config.MinExpireDays, math.min(Config.MaxExpireDays, tonumber(data.days) or Config.DefaultExpireDays))
    if name == '' or label == '' then return false, 'invalid input' end
    if OKGangs.Server.GetGang(name) then return false, 'gang already exists' end

    local expireDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + (days * 86400))
    local gangId = MySQL.insert.await('INSERT INTO gangs (name, label, status, expires_at, member_slots) VALUES (?, ?, 1, ?, ?)', { name, label, expireDate, Config.DefaultMemberSlots })
    for rank = 1, Config.MaxRank do
        MySQL.insert.await('INSERT INTO gang_ranks (gang_id, rank, label, salary, permissions) VALUES (?, ?, ?, 0, ?)', { gangId, rank, OKGangs.DefaultRankLabels[rank], json.encode({}) })
    end
    if data.hq then
        MySQL.insert.await('INSERT INTO gang_locations (gang_id, type, coords) VALUES (?, ?, ?)', { gangId, 'boss', OKGangs.EncodeCoords(data.hq) })
        MySQL.insert.await('INSERT INTO gang_locations (gang_id, type, coords) VALUES (?, ?, ?)', { gangId, 'blip', OKGangs.EncodeCoords(data.hq) })
    end
    OKGangs.Server.LoadCache()
    OKGangs.Server.RegisterGangInventories(OKGangs.Server.Gangs[gangId])
    OKGangs.Server.Audit(gangId, source, 'Gang Create/Delete', { action = 'create', name = name, label = label, days = days })
    TriggerClientEvent('ok_gangs:client:syncGangs', -1, OKGangs.Server.GetAllPublicGangs())
    return true, publicGang(OKGangs.Server.Gangs[gangId])
end

function OKGangs.Server.SetGangStatus(source, gangId, status)
    if not OKGangs.Server.RequireAdmin(source) then return false end
    local gang = OKGangs.Server.Gangs[tonumber(gangId)]
    if not gang then return false, OKGangs.Errors.invalid_gang end
    status = status and 1 or 0
    MySQL.update.await('UPDATE gangs SET status = ?, deleted_at = IF(? = 0, NOW(), NULL) WHERE id = ?', { status, status, gang.id })
    gang.status = status
    OKGangs.Server.Audit(gang.id, source, 'Gang Create/Delete', { action = status == 1 and 'restore' or 'soft_delete' })
    TriggerClientEvent('ok_gangs:client:syncGangs', -1, OKGangs.Server.GetAllPublicGangs())
    return true
end

function OKGangs.Server.UpdateGangField(source, gangId, field, value)
    if not OKGangs.Server.RequireAdmin(source) then return false end
    local allowed = { level = true, xp = true, money = true, black_money = true, member_slots = true }
    if not allowed[field] then return false, 'invalid field' end
    local gang = OKGangs.Server.Gangs[tonumber(gangId)]
    if not gang then return false, OKGangs.Errors.invalid_gang end
    value = math.max(0, tonumber(value) or 0)
    MySQL.update.await(('UPDATE gangs SET %s = ? WHERE id = ?'):format(field), { value, gang.id })
    gang[field] = value
    OKGangs.Server.Audit(gang.id, source, 'Gang Update', { field = field, value = value })
    return true
end

function OKGangs.Server.ExtendGang(source, gangId, days)
    if not OKGangs.Server.RequireAdmin(source) then return false end
    local gang = OKGangs.Server.Gangs[tonumber(gangId)]
    if not gang then return false, OKGangs.Errors.invalid_gang end
    days = math.max(Config.MinExpireDays, math.min(Config.MaxExpireDays, tonumber(days) or 1))
    MySQL.update.await('UPDATE gangs SET expires_at = DATE_ADD(GREATEST(expires_at, NOW()), INTERVAL ? DAY), status = 1, deleted_at = NULL WHERE id = ?', { days, gang.id })
    OKGangs.Server.LoadCache()
    OKGangs.Server.Audit(gang.id, source, 'Gang Create/Delete', { action = 'extend', days = days })
    TriggerClientEvent('ok_gangs:client:syncGangs', -1, OKGangs.Server.GetAllPublicGangs())
    return true
end

function OKGangs.Server.SetLocation(source, gangId, locationType, coords)
    if not OKGangs.Server.RequireAdmin(source) then return false end
    if not OKGangs.LocationTypes[locationType] then return false, 'invalid location' end
    local gang = OKGangs.Server.Gangs[tonumber(gangId)]
    if not gang then return false, OKGangs.Errors.invalid_gang end
    MySQL.update.await('INSERT INTO gang_locations (gang_id, type, coords, enabled) VALUES (?, ?, ?, 1) ON DUPLICATE KEY UPDATE coords = VALUES(coords), enabled = 1', { gang.id, locationType, OKGangs.EncodeCoords(coords) })
    OKGangs.Server.LoadCache()
    OKGangs.Server.Audit(gang.id, source, 'Gang Location', { type = locationType, coords = coords })
    TriggerClientEvent('ok_gangs:client:syncGangs', -1, OKGangs.Server.GetAllPublicGangs())
    return true
end

function OKGangs.Server.AddMember(source, target, gangId, rank)
    local gang = OKGangs.Server.Gangs[tonumber(gangId)]
    local xTarget = ESX.GetPlayerFromId(target)
    if not gang or not xTarget then return false, OKGangs.Errors.invalid_gang end
    if gang.status ~= 1 then return false, OKGangs.Errors.gang_inactive end
    if OKGangs.Server.GetMember(xTarget.identifier) then return false, OKGangs.Errors.already_in_gang end
    if OKGangs.TableCount(gang.members) >= gang.member_slots then return false, OKGangs.Errors.gang_full end
    rank = math.max(1, math.min(Config.BossRank, tonumber(rank) or 1))
    MySQL.insert.await('INSERT INTO gang_members (gang_id, identifier, name, rank) VALUES (?, ?, ?, ?)', { gang.id, xTarget.identifier, xTarget.getName(), rank })
    OKGangs.Server.LoadCache()
    OKGangs.Server.Audit(gang.id, source, 'Invite Player', { target = target, rank = rank })
    TriggerClientEvent('ok_gangs:client:playerGang', target, publicGang(gang), OKGangs.Server.GetMember(xTarget.identifier))
    return true
end


function OKGangs.Server.AdminSetPlayerGang(source, target, gangName, rank)
    if not OKGangs.Server.RequireAdmin(source) then return false, OKGangs.Errors.no_permission end

    target = tonumber(target)
    if not target then return false, 'invalid player id' end

    local xTarget = ESX.GetPlayerFromId(target)
    if not xTarget then return false, 'player not online' end

    local gang = OKGangs.Server.GetGang(OKGangs.Slug(gangName or ''))
    if not gang then return false, OKGangs.Errors.invalid_gang end
    if gang.status ~= 1 then return false, OKGangs.Errors.gang_inactive end

    rank = math.max(1, math.min(Config.BossRank, tonumber(rank) or 1))
    if not gang.ranks[rank] then return false, 'invalid rank' end

    local oldMember = OKGangs.Server.GetMember(xTarget.identifier)
    local movingFromAnotherGang = oldMember and tonumber(oldMember.gang_id) ~= tonumber(gang.id)
    if (not oldMember or movingFromAnotherGang) and OKGangs.TableCount(gang.members) >= gang.member_slots then
        return false, OKGangs.Errors.gang_full
    end

    if oldMember then
        MySQL.update.await('UPDATE gang_members SET gang_id = ?, name = ?, rank = ? WHERE identifier = ?', { gang.id, xTarget.getName(), rank, xTarget.identifier })
        OKGangs.Server.Audit(oldMember.gang_id, source, 'Admin Set Gang', { target = target, identifier = xTarget.identifier, old_gang_id = oldMember.gang_id, new_gang_id = gang.id, rank = rank })
    else
        MySQL.insert.await('INSERT INTO gang_members (gang_id, identifier, name, rank) VALUES (?, ?, ?, ?)', { gang.id, xTarget.identifier, xTarget.getName(), rank })
    end

    OKGangs.Server.LoadCache()
    local refreshedGang = OKGangs.Server.GetGang(gang.name)
    local refreshedMember = OKGangs.Server.GetMember(xTarget.identifier)
    OKGangs.Server.Audit(refreshedGang.id, source, 'Admin Set Gang', { target = target, identifier = xTarget.identifier, gang = refreshedGang.name, rank = rank })
    TriggerClientEvent('ok_gangs:client:playerGang', target, publicGang(refreshedGang), refreshedMember)
    TriggerClientEvent('ok_gangs:client:syncGangs', -1, OKGangs.Server.GetAllPublicGangs())

    return true, { gang = publicGang(refreshedGang), member = refreshedMember, rank = rank }
end

function OKGangs.Server.RemoveMember(source, identifier)
    local member = OKGangs.Server.Members[identifier]
    if not member then return false end
    MySQL.update.await('DELETE FROM gang_members WHERE identifier = ?', { identifier })
    OKGangs.Server.LoadCache()
    OKGangs.Server.Audit(member.gang_id, source, 'Fire Player', { identifier = identifier })
    return true
end

function OKGangs.Server.SetMemberRank(source, identifier, rank)
    local member = OKGangs.Server.Members[identifier]
    if not member then return false end
    rank = math.max(1, math.min(Config.BossRank, tonumber(rank) or 1))
    MySQL.update.await('UPDATE gang_members SET rank = ? WHERE identifier = ?', { rank, identifier })
    member.rank = rank
    OKGangs.Server.Audit(member.gang_id, source, 'Rank Change', { identifier = identifier, rank = rank })
    return true
end

function OKGangs.Server.SetRankData(source, gangId, rank, label, salary, permissions)
    local gang = OKGangs.Server.Gangs[tonumber(gangId)]
    if not gang then return false end
    rank = math.max(1, math.min(Config.BossRank, tonumber(rank) or 1))
    salary = math.max(0, math.min(1000, tonumber(salary) or 0))
    MySQL.update.await('UPDATE gang_ranks SET label = ?, salary = ?, permissions = ? WHERE gang_id = ? AND rank = ?', { label, salary, json.encode(permissions or {}), gang.id, rank })
    OKGangs.Server.LoadCache()
    OKGangs.Server.Audit(gang.id, source, 'Rank Change', { rank = rank, label = label, salary = salary })
    return true
end

function OKGangs.Server.ExpireOldGangs()
    local changed = MySQL.update.await('UPDATE gangs SET status = 0, deleted_at = NOW() WHERE status = 1 AND expires_at < NOW()', {})
    if changed and changed > 0 then
        OKGangs.Server.LoadCache()
        TriggerClientEvent('ok_gangs:client:syncGangs', -1, OKGangs.Server.GetAllPublicGangs())
    end
end
