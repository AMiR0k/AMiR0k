AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.Animations = AdvancedHunting.Animations or {}

function AdvancedHunting.Animations.PlaySkinning(duration)
    return lib.progressBar({
        duration = duration,
        label = _L('skin_animal'),
        useWhileDead = false,
        canCancel = true,
        disable = {move = true, car = true, combat = true},
        anim = {dict = 'amb@medic@standing@kneel@base', clip = 'base'}
    })
end

function AdvancedHunting.Animations.PlayButcher(duration)
    return lib.progressBar({
        duration = duration,
        label = _L('butcher_animal'),
        useWhileDead = false,
        canCancel = true,
        disable = {move = true, car = true, combat = true},
        anim = {dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer'}
    })
end

function AdvancedHunting.Animations.PlayCarry()
    lib.requestAnimDict('missfinale_c2mcs_1')
    TaskPlayAnim(PlayerPedId(), 'missfinale_c2mcs_1', 'fin_c2_mcs_1_camman', 8.0, -8.0, -1, 49, 0, false, false, false)
end

function AdvancedHunting.Animations.PlayStartStop()
    lib.requestAnimDict('amb@world_human_clipboard@male@idle_a')
    TaskPlayAnim(PlayerPedId(), 'amb@world_human_clipboard@male@idle_a', 'idle_c', 4.0, -4.0, 1800, 49, 0, false, false, false)
    Wait(1800)
    ClearPedTasks(PlayerPedId())
end
