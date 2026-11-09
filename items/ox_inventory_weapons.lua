-- Paste this into the Weapons table in ox_inventory/data/weapons.lua (next to WEAPON_KNIFE).
-- The shiv fights like a knife but keeps its own name and photo in the inventory.
-- If you pasted an older prison_shiv entry into data/items.lua, delete that one.

['prison_shiv'] = {
    label = 'Shiv',
    weight = 120,
    durability = 0.1,
    model = 'WEAPON_KNIFE',
    description = 'Sharpened scrap with a taped grip. Worth a lot to the right inmate.',
},
