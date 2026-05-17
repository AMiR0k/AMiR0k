Animals = Animals or {}

Animals.Definitions = {
    deer = {
        model = `a_c_deer`,
        label = 'Deer',
        aggressive = false,
        health = 120,
        spawnChance = 35,
        spawnZones = {'paleto_sawmill'},
        time = {day = true, night = true},
        legendary = false,
        xp = 18,
        sellPrice = {meat = 28, skin = 85, carcass = 140},
        rewards = {
            meat = {item = 'deer_meat', min = 2, max = 4},
            skin = {item = 'deer_skin', amount = 1},
            carcass = 'deer_carcass'
        }
    },
    cow = {
        model = `a_c_cow`,
        label = 'Cow',
        aggressive = false,
        health = 180,
        spawnChance = 18,
        spawnZones = {'paleto_sawmill'},
        time = {day = true, night = false},
        legendary = false,
        xp = 14,
        sellPrice = {meat = 22, skin = 55, carcass = 120},
        rewards = {
            meat = {item = 'cow_meat', min = 5, max = 8},
            skin = {item = 'cow_hide', amount = 1},
            carcass = 'cow_carcass'
        }
    },
    pig = {
        model = `a_c_pig`,
        label = 'Pig',
        aggressive = false,
        health = 95,
        spawnChance = 22,
        spawnZones = {'paleto_sawmill'},
        time = {day = true, night = true},
        legendary = false,
        xp = 10,
        sellPrice = {meat = 18, skin = 35},
        rewards = {
            meat = {item = 'pig_meat', min = 1, max = 3},
            skin = {item = 'pig_skin', amount = 1}
        }
    },
    boar = {
        model = `a_c_boar`,
        label = 'Boar',
        aggressive = true,
        health = 150,
        spawnChance = 24,
        spawnZones = {'paleto_sawmill'},
        time = {day = true, night = true},
        legendary = false,
        xp = 22,
        sellPrice = {meat = 25, skin = 70, carcass = 150},
        rewards = {
            meat = {item = 'boar_meat', min = 3, max = 5},
            skin = {item = 'boar_skin', amount = 1},
            carcass = 'boar_carcass'
        }
    },
    rabbit = {
        model = `a_c_rabbit_01`,
        label = 'Rabbit',
        aggressive = false,
        health = 35,
        spawnChance = 28,
        spawnZones = {'paleto_sawmill'},
        time = {day = true, night = true},
        legendary = false,
        xp = 8,
        sellPrice = {meat = 12, skin = 30},
        rewards = {
            meat = {item = 'rabbit_meat', min = 1, max = 2},
            skin = {item = 'rabbit_fur', amount = 1}
        }
    },
    wolf = {
        model = `a_c_coyote`,
        label = 'Wolf',
        aggressive = true,
        health = 140,
        spawnChance = 12,
        spawnZones = {'paleto_sawmill'},
        time = {day = false, night = true},
        legendary = false,
        xp = 28,
        sellPrice = {skin = 180},
        rewards = {
            skin = {item = 'wolf_pelt', amount = 1}
        }
    },
    tiger = {
        model = `a_c_mtlion`,
        label = 'Tiger',
        aggressive = true,
        health = 240,
        spawnChance = 5,
        spawnZones = {'paleto_sawmill'},
        time = {day = false, night = true},
        legendary = false,
        xp = 45,
        sellPrice = {skin = 350},
        rewards = {
            skin = {item = 'tiger_skin', amount = 1}
        }
    },
    panther = {
        model = `a_c_mtlion`,
        label = 'Panther',
        aggressive = true,
        health = 220,
        spawnChance = 6,
        spawnZones = {'paleto_sawmill'},
        time = {day = false, night = true},
        legendary = false,
        xp = 42,
        sellPrice = {skin = 320},
        rewards = {
            skin = {item = 'panther_fur', amount = 1}
        }
    },
    golden_deer = {
        model = `a_c_deer`,
        label = 'Golden Deer',
        aggressive = false,
        health = 200,
        spawnChance = 1,
        spawnZones = {'paleto_sawmill'},
        time = {day = true, night = false},
        legendary = true,
        xp = 140,
        sellPrice = {meat = 120, skin = 1200, carcass = 1600},
        rewards = {
            meat = {item = 'deer_meat', min = 5, max = 8},
            skin = {item = 'deer_skin', amount = 2},
            carcass = 'deer_carcass'
        }
    },
    black_panther = {
        model = `a_c_mtlion`,
        label = 'Black Panther',
        aggressive = true,
        health = 330,
        spawnChance = 1,
        spawnZones = {'paleto_sawmill'},
        time = {day = false, night = true},
        legendary = true,
        xp = 180,
        sellPrice = {skin = 1800},
        rewards = {
            skin = {item = 'panther_fur', amount = 3}
        }
    },
    albino_boar = {
        model = `a_c_boar`,
        label = 'Albino Boar',
        aggressive = true,
        health = 280,
        spawnChance = 1,
        spawnZones = {'paleto_sawmill'},
        time = {day = true, night = true},
        legendary = true,
        xp = 155,
        sellPrice = {meat = 90, skin = 1250, carcass = 1500},
        rewards = {
            meat = {item = 'boar_meat', min = 6, max = 9},
            skin = {item = 'boar_skin', amount = 2},
            carcass = 'boar_carcass'
        }
    }
}
