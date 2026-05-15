OKGangs = OKGangs or {}
OKGangs.Server = OKGangs.Server or {}

local webhook = GetConvar('ok_gangs_webhook', Config and Config.DefaultWebhook or '')

function OKGangs.Server.DiscordLog(action, title, description, fields)
    if not webhook or webhook == '' then return end
    local embed = {
        title = title or action,
        description = description or '',
        color = 16753920,
        fields = fields or {},
        footer = { text = 'OK_GANGS' },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }
    PerformHttpRequest(webhook, function() end, 'POST', json.encode({ username = 'OK_GANGS Logs', embeds = { embed } }), { ['Content-Type'] = 'application/json' })
end

function OKGangs.Server.Audit(gangId, source, action, data)
    OKGangs.Server.SaveLog(gangId, source, action, data)
    OKGangs.Server.DiscordLog(action, action, json.encode(data or {}), {
        { name = 'Gang ID', value = tostring(gangId or 'none'), inline = true },
        { name = 'Source', value = tostring(source or 0), inline = true }
    })
end
