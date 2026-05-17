AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.Logging = AdvancedHunting.Logging or {}

function AdvancedHunting.Logging.Write(kind, source, message, data)
    local payload = json.encode(data or {})
    print(('[advanced_hunting][%s][%s] %s %s'):format(kind, source or 'server', message, payload))

    if Config.Security.logWebhook and Config.Security.logWebhook ~= '' then
        PerformHttpRequest(Config.Security.logWebhook, function() end, 'POST', json.encode({
            username = 'Advanced Hunting',
            embeds = {{title = kind, description = message, color = kind == 'exploit' and 16711680 or 65280, fields = {{name = 'Source', value = tostring(source)}, {name = 'Data', value = payload}}}}
        }), {['Content-Type'] = 'application/json'})
    end
end
