AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.AntiAbuse = AdvancedHunting.AntiAbuse or {}

local AntiAbuse = AdvancedHunting.AntiAbuse
AntiAbuse.cooldowns = AntiAbuse.cooldowns or {}

function AntiAbuse.IsOnCooldown(key, cooldown)
    local now = GetGameTimer()
    local expires = AntiAbuse.cooldowns[key]
    if expires and expires > now then
        return true
    end
    AntiAbuse.cooldowns[key] = now + (cooldown or Config.Security.actionCooldown)
    return false
end

function AntiAbuse.Clear(key)
    AntiAbuse.cooldowns[key] = nil
end
