-- Paste these into ox_inventory/data/items.lua, replacing any entries with the same name.
-- Images: copy inventory_images/*.png into ox_inventory/web/images.

['handcuffs'] = {
    label = 'Handcuffs',
    weight = 300,
    description = 'Cuffs the person in front of you.',
    client = { export = 'XS-PoliceSystem.useItem' },
},

['spikestrip'] = {
    label = 'Spike Strip',
    weight = 2500,
    description = 'Lays a strip that bursts the tyres of anything driving over it. Police only.',
    client = { export = 'XS-PoliceSystem.useItem' },
},

['empty_evidence_bag'] = {
    label = 'Evidence Bag',
    weight = 20,
    stack = true,
    description = 'An empty bag for evidence at a scene.',
},

['filled_evidence_bag'] = {
    label = 'Evidence Bag',
    weight = 60,
    stack = false,
    description = 'Sealed evidence. File it in an evidence locker.',
},

['bleach'] = {
    label = 'Bleach',
    weight = 1000,
    description = 'Cleans blood, casings and prints off a scene.',
    client = { export = 'XS-PoliceSystem.useItem' },
},

['prison_scrap'] = {
    label = 'Scrap Metal',
    weight = 150,
    stack = true,
    description = 'A bent strip of metal pocketed on a prison job. Guards take it if they find it.',
},

['prison_spoon'] = {
    label = 'Spoon',
    weight = 40,
    stack = true,
    description = 'A canteen spoon. Slow work, but it digs.',
},

['prison_cutters'] = {
    label = 'Wire Cutters',
    weight = 450,
    stack = true,
    description = 'Home made cutters. Good for one fence, maybe two.',
},

['prison_cigarettes'] = {
    label = 'Cigarettes',
    weight = 30,
    stack = true,
    description = 'A pack of cigarettes. Money inside.',
},
