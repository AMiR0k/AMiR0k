HuntingTraders = {
    legal = {
        label = 'Licensed Butcher',
        type = 'legal',
        coords = vector4(-679.07, 5834.11, 17.33, 132.0),
        model = `s_m_m_linecook`,
        items = {'deer_meat', 'cow_meat', 'boar_meat', 'pig_meat', 'rabbit_meat', 'deer_carcass', 'cow_carcass', 'boar_carcass'},
        account = 'money',
        blip = {enabled = true, sprite = 605, color = 2, scale = 0.7, label = 'Hunting Butcher'}
    },
    illegal = {
        label = 'Rare Pelt Fence',
        type = 'illegal',
        coords = vector4(-1112.42, 4922.38, 218.38, 248.0),
        model = `g_m_m_chigoon_02`,
        items = {'deer_skin', 'cow_hide', 'boar_skin', 'pig_skin', 'rabbit_fur', 'wolf_pelt', 'tiger_skin', 'panther_fur'},
        account = 'black_money',
        blip = {enabled = false, sprite = 442, color = 1, scale = 0.65, label = 'Rare Pelt Fence'}
    }
}
