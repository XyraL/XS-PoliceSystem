Config = {}

Config.Locale = 'en'
Config.Debug = false

Config.Bridges = {
    framework = 'auto', -- 'auto', 'qbox' or 'qbcore'
    inventory = 'auto', -- 'auto', 'ox_inventory', 'qb-inventory', 'qs-inventory', 'ps-inventory', 'codem-inventory' or 'core_inventory'
    target = 'auto',    -- 'auto', 'ox_target', 'qb-target', 'sleepless_interact', 'interact', 'qtarget' or 'none' ([E] prompts)
    dispatch = 'auto',  -- where panic and escape alerts also go: 'auto', 'none', 'XS-Dispatch', 'ps-dispatch', 'qs-dispatch', 'cd_dispatch', 'core_dispatch', 'rcore_dispatch' or 'linden_outlawalert'
    keys = 'auto',      -- vehicle keys for police cars: 'auto' or a resource name
    banking = 'auto',   -- where fines and the boss account live: 'auto' or a resource name
    fuel = 'auto',      -- 'auto', 'ox_fuel', 'LegacyFuel', 'cdn-fuel', 'ps-fuel', 'lc_fuel' or 'none'
    clothing = 'auto',  -- outfit menu at lockers: 'auto', 'illenium-appearance', 'fivem-appearance', 'qb-clothing', 'XS-Appearance' or 'none'
    evidence = 'auto',  -- scene evidence: 'auto', 'XS-PoliceSystem' (built in), 'evidences', 'none', or the resource name of another evidence script. Another script turns ours off
}

Config.Admin = {
    command = 'policebuilder',         -- opens the station and jail builder
    acePermission = 'xs.police.admin', -- add_ace group.admin xs.police.admin allow
    groups = { 'admin', 'god' },       -- framework permission groups that can open it
    licenses = {},                     -- 'license:...' identifiers that can always open it
}

-- Most options below can also be changed in game, in /policebuilder under Settings. What you save there
-- is kept in the database and wins over this file. Reset a setting there to go back to the value here.
Config.Builder = {
    showExisting = true, -- show the points you already placed while placing a new one
    cameraSpeed = { normal = 6.0, fast = 18.0, slow = 1.5 }, -- the placement camera, in metres a second
}

-- Who counts as police. A player with any of these job names, or a job of one of these types, is an officer.
Config.Jobs = {
    names = { 'police', 'lspd', 'bcso', 'sasp', 'sast', 'ranger' },
    types = { 'leo' },
    requireDuty = true, -- off-duty officers are treated like anyone else
}

-- Lowest job grade that can do each thing. Bosses can always do everything.
Config.Grades = {
    helipad = 2,
    impound = 0,
    impoundRelease = 2, -- clear a hold or waive the fee at an impound lot
    evidence = 0,
    jail = 0,
    manage = 4, -- hire, fire and promote at the boss office
    licences = 2, -- give someone a driver or firearm licence. Any officer can take one away
    camRoom = 0, -- watch body cams and dash cams from a station's camera room
}

-- The boss office at a station: roster, notes and warnings, the station's armory and garage, money and the activity log.
-- Bosses can only add items and vehicles from these lists, so nobody hands out weapons the server never meant to give police.
-- Admins can add anything in /policebuilder; whatever is already in a station's armory or garage can always be kept.
Config.Boss = {
    notes = true,      -- notes, warnings and commendations on each officer
    maxPrice = 100000, -- the most a boss can charge for an armory item
    armoryPool = {
        'weapon_flashlight', 'weapon_nightstick', 'weapon_stungun', 'weapon_combatpistol', 'weapon_pistol', 'weapon_heavypistol',
        'weapon_pistol_mk2', 'weapon_smg', 'weapon_pumpshotgun', 'weapon_carbinerifle', 'weapon_fireextinguisher', 'weapon_flare',
        'pistol_ammo', 'smg_ammo', 'shotgun_ammo', 'rifle_ammo', 'ammo-9', 'ammo-45', 'ammo-shotgun', 'ammo-rifle',
        'armor', 'armour', 'heavyarmor', 'handcuffs', 'spikestrip', 'empty_evidence_bag', 'radio', 'bandage', 'firstaid', 'ifaks', 'binoculars',
    },
    vehiclePool = { 'police', 'police2', 'police3', 'police4', 'policeb', 'policet', 'policeold1', 'policeold2', 'sheriff', 'sheriff2', 'fbi', 'fbi2', 'pranger', 'riot', 'riot2' },
    helicopterPool = { 'polmav' },
}

-- The quick action wheel. Hold or tap the key, scroll or press 1-9 to pick, left click to use,
-- right click to go back. It never takes the mouse, so you can keep walking and looking around.
Config.Wheel = {
    command = 'policewheel',
    key = 'F6',
    holdToOpen = false, -- true: the wheel shows while the key is held and the picked action runs on release
    range = 3.0,        -- how close a person or vehicle must be for an action
    favourites = 4,     -- how many actions an officer can pin to the front of their wheel with the pin key. 0 turns pinning off
    pinKey = 47,        -- the pin key while the wheel is open. 47 is G
    -- The layout itself (order, sub-menus, names, icons, who sees what and your own actions) is set in /policebuilder under Quick action wheel
    actions = {         -- set any to false to remove it from the wheel
        cuff = true,
        escort = true,
        search = true,
        seize = true,
        idcheck = true,
        gsr = true,
        fingerprint = true,
        breathalyzer = true,
        drugswab = true,
        licences = true,
        tracker = true,
        flagPlate = true,
        cameras = true,
        unitCams = true,
        service = true,
        solitary = true,
        searchVehicle = true,
        dustPrints = true,
        slowTraffic = true,
        stopTraffic = true,
        k9Call = true,
        k9Follow = true,
        k9Search = true,
        k9Attack = true,
        k9Car = true,
        putInVehicle = true,
        takeOutVehicle = true,
        impound = true,
        checkPlate = true,
        cone = true,
        barrier = true,
        spikes = true,
        removeProp = true,
        fine = true,
        jail = true,
        mdt = true,
        panic = true,
    },
}

-- The MDT button on the wheel. 'auto' opens the first one running: XS-MDT, ps-mdt, redutzu-mdt, kartik-mdt,
-- tk_mdt, drx_mdt, codem-mdtv2, origen_police, qs-dispatch, lb-tablet or qb-mdt.
-- Set a resource name to pick one, 'command' to run the command below, or 'none' to hide the button.
Config.MDT = {
    resource = 'auto',
    command = '', -- a command to run, like 'mdt', when resource is 'command' or nothing above is running
}

Config.Cuffs = {
    item = 'handcuffs',  -- needed to put cuffs on. Taking them off never needs it. Set to false for no item
    resist = true,       -- a player who is not surrendering gets one quick skill check to pull away
    resistDifficulty = { 'easy', 'medium' },
    needsHandsUp = false, -- only cuff players with their hands up, down, or already restrained
    civilians = true,     -- anyone carrying handcuffs can cuff, escort and seat people, like qb-policejob
}

Config.Search = {
    needsRestrained = true, -- the person must be cuffed, have their hands up or be down
}

Config.Seize = {
    cash = true,             -- take the cash they are carrying into evidence
    society = true,          -- seized cash goes into the department account instead of vanishing
}

Config.Gsr = {
    minutes = 20,        -- how long a test stays positive after firing
    waterClears = true,  -- swimming washes it off
    ignoredWeapons = {   -- these never leave residue
        `WEAPON_STUNGUN`, `WEAPON_PETROLCAN`, `WEAPON_FIREEXTINGUISHER`, `WEAPON_BALL`, `WEAPON_SNOWBALL`, `WEAPON_FLARE`,
    },
}

-- Evidence at a scene. Shooting leaves casings, getting hurt leaves blood, and robbery scripts that use
-- qb-policejob's evidence events leave fingerprints. On-duty officers bag it and file it in an evidence locker.
Config.Forensics = {
    enabled = true,
    flashlight = true,              -- evidence only shows in the beam of a flashlight, handheld or on a weapon. false: always shows up close
    range = 12.0,                   -- how far away evidence can be seen
    collectKey = 38,                -- the key to bag evidence. 38 is E
    minutes = 45,                   -- evidence left at a scene is gone after this long
    bag = 'empty_evidence_bag',     -- used up for each piece bagged. Set to false to bag without one
    filled = 'filled_evidence_bag', -- the bag the officer gets back
    casings = true,
    blood = true,
    bloodChance = 70,               -- percent chance a hit that does damage leaves blood
    bloodTrail = true,              -- badly hurt players leave a trail of blood as they move
    trailHealth = 150,              -- below this health (100 is dead, 200 is full) they leave a trail
    printSeconds = 4,               -- how long taking prints and a DNA swab takes
    needsRestrained = true,         -- the person must be cuffed, have their hands up or be down
    glovesBlock = true,             -- gloves stop the fingerprint scanner until they come off
    printOnCasing = 35,             -- percent chance a shooter without gloves leaves a print on the casings
    carPrintHours = 6,              -- prints left on a car by someone without gloves last this long
    dustSeconds = 6,                -- how long dusting a car for prints takes
    bleach = 'bleach',              -- the item that cleans up blood, casings and prints around you. false to turn it off
    bleachRadius = 5.0,
    bleachSeconds = 8,
    calibres = {                    -- what a casing from each kind of gun is labelled
        pistol = '9mm pistol round',
        smg = '9mm SMG round',
        rifle = '5.56mm rifle round',
        mg = '7.62mm machine gun round',
        shotgun = '12 gauge shotgun shell',
        sniper = '.308 sniper round',
    },
}

Config.Fines = {
    max = 50000,
    account = 'bank',  -- taken from this account; if it is short, the rest comes from cash
    society = true,    -- paid into the officer's department account
    allowDebt = false, -- false: a fine that cannot be paid is refused
}

-- Impound lots are built in the builder. Officers pick the lot, how long the car is held and the fee,
-- and the owner pays at the lot's release desk once the hold is over.
-- With no lot built, the car goes to your garage script's depot for the fee instead.
Config.Impound = {
    seconds = 6,       -- how long the impound takes
    fee = 500,         -- release fee a new lot starts with
    minFee = 0,
    maxFee = 25000,
    holds = { 0, 1, 6, 12, 24, 48, 72 }, -- hold times offered in the impound form, in hours. 0 can be collected right away
    defaultHold = 0,   -- the hold the impound form starts on, in hours
    maxHours = 168,    -- the longest hold an officer can type in
    society = true,    -- release fees go into the impounding officer's department account
    clerk = 's_m_y_cop_01', -- the clerk standing at a new lot's release desk. '' for nobody
    heldState = 'auto', -- player_vehicles state while a car sits in a lot. 'auto' picks one qb-garages and qbx_garages will not hand out
}

-- Props officers can place from the wheel.
Config.Props = {
    max = 12, -- per officer
    list = {
        cone = { model = 'prop_roadcone02a', label = 'Cone' },
        barrier = { model = 'prop_barrier_work05', label = 'Barrier' },
    },
}

Config.Spikes = {
    item = 'spikestrip', -- set to false to allow spike strips without an item
    model = 'p_ld_stinger_s',
    max = 2,
    seconds = 120, -- removed on their own after this long
}

-- On-duty officers see each other on the map with their callsign and what they are in.
Config.UnitBlips = {
    enabled = true,
    seconds = 2,              -- how often blips of officers far away move. Officers close by move smoothly
    jobs = { 'ambulance' },   -- other on-duty jobs shown on the police map. {} for none
    colours = { police = 38, lspd = 38, bcso = 47, sasp = 3, sast = 3, ranger = 2, ambulance = 1 }, -- blip colour per job, others use 38
}

-- Officers set their own callsign with /callsign 2-A-14. Bosses can also set them in the boss office.
Config.Callsign = {
    command = 'callsign', -- '' turns the command off so only the boss office sets them
    max = 10,
}

-- Sprint at someone and press the key to tackle them to the ground.
Config.Tackle = {
    enabled = true,
    command = 'policetackle',
    key = 'G',
    range = 2.5,      -- how close they must be, in front of you
    seconds = 4,      -- how long they stay down
    cooldown = 10,    -- seconds between tackles
    anyone = false,   -- true: civilians can tackle too
}

-- Store and bank security cameras. Robbery scripts send a camera number with their alert, so the numbers match qb-policejob's list.
-- Officers watch them from the wheel (Paperwork > Cameras) or with /cam 22. canRotate lets the viewer turn the camera.
Config.Cameras = {
    enabled = true,
    list = {
        [1] = { label = 'Pacific Bank CAM#1', coords = vector3(257.45, 210.07, 109.08), r = { x = -25.0, y = 0.0, z = 28.05 }, canRotate = false },
        [2] = { label = 'Pacific Bank CAM#2', coords = vector3(232.86, 221.46, 107.83), r = { x = -25.0, y = 0.0, z = -140.91 }, canRotate = false },
        [3] = { label = 'Pacific Bank CAM#3', coords = vector3(252.27, 225.52, 103.99), r = { x = -35.0, y = 0.0, z = -74.87 }, canRotate = false },
        [4] = { label = 'Limited Ltd Grove St. CAM#1', coords = vector3(-53.1433, -1746.714, 31.546), r = { x = -35.0, y = 0.0, z = -168.9182 }, canRotate = false },
        [5] = { label = "Rob's Liqour Prosperity St. CAM#1", coords = vector3(-1482.9, -380.463, 42.363), r = { x = -35.0, y = 0.0, z = 79.53281 }, canRotate = false },
        [6] = { label = "Rob's Liqour San Andreas Ave. CAM#1", coords = vector3(-1224.874, -911.094, 14.401), r = { x = -35.0, y = 0.0, z = -6.778894 }, canRotate = false },
        [7] = { label = 'Limited Ltd Ginger St. CAM#1', coords = vector3(-718.153, -909.211, 21.49), r = { x = -35.0, y = 0.0, z = -137.1431 }, canRotate = false },
        [8] = { label = '24/7 Supermarkt Innocence Blvd. CAM#1', coords = vector3(23.885, -1342.441, 31.672), r = { x = -35.0, y = 0.0, z = -142.9191 }, canRotate = false },
        [9] = { label = "Rob's Liqour El Rancho Blvd. CAM#1", coords = vector3(1133.024, -978.712, 48.515), r = { x = -35.0, y = 0.0, z = -137.302 }, canRotate = false },
        [10] = { label = 'Limited Ltd West Mirror Drive CAM#1', coords = vector3(1151.93, -320.389, 71.33), r = { x = -35.0, y = 0.0, z = -119.4468 }, canRotate = false },
        [11] = { label = '24/7 Supermarkt Clinton Ave CAM#1', coords = vector3(383.402, 328.915, 105.541), r = { x = -35.0, y = 0.0, z = 118.585 }, canRotate = false },
        [12] = { label = 'Limited Ltd Banham Canyon Dr CAM#1', coords = vector3(-1832.057, 789.389, 140.436), r = { x = -35.0, y = 0.0, z = -91.481 }, canRotate = false },
        [13] = { label = "Rob's Liqour Great Ocean Hwy CAM#1", coords = vector3(-2966.15, 387.067, 17.393), r = { x = -35.0, y = 0.0, z = 32.92229 }, canRotate = false },
        [14] = { label = '24/7 Supermarkt Ineseno Road CAM#1', coords = vector3(-3046.749, 592.491, 9.808), r = { x = -35.0, y = 0.0, z = -116.673 }, canRotate = false },
        [15] = { label = '24/7 Supermarkt Barbareno Rd. CAM#1', coords = vector3(-3246.489, 1010.408, 14.705), r = { x = -35.0, y = 0.0, z = -135.2151 }, canRotate = false },
        [16] = { label = '24/7 Supermarkt Route 68 CAM#1', coords = vector3(539.773, 2664.904, 44.056), r = { x = -35.0, y = 0.0, z = -42.947 }, canRotate = false },
        [17] = { label = "Rob's Liqour Route 68 CAM#1", coords = vector3(1169.855, 2711.493, 40.432), r = { x = -35.0, y = 0.0, z = 127.17 }, canRotate = false },
        [18] = { label = '24/7 Supermarkt Senora Fwy CAM#1', coords = vector3(2673.579, 3281.265, 57.541), r = { x = -35.0, y = 0.0, z = -80.242 }, canRotate = false },
        [19] = { label = '24/7 Supermarkt Alhambra Dr. CAM#1', coords = vector3(1966.24, 3749.545, 34.143), r = { x = -35.0, y = 0.0, z = 163.065 }, canRotate = false },
        [20] = { label = '24/7 Supermarkt Senora Fwy CAM#2', coords = vector3(1729.522, 6419.87, 37.262), r = { x = -35.0, y = 0.0, z = -160.089 }, canRotate = false },
        [21] = { label = 'Fleeca Bank Hawick Ave CAM#1', coords = vector3(309.341, -281.439, 55.88), r = { x = -35.0, y = 0.0, z = -146.1595 }, canRotate = false },
        [22] = { label = 'Fleeca Bank Legion Square CAM#1', coords = vector3(144.871, -1043.044, 31.017), r = { x = -35.0, y = 0.0, z = -143.9796 }, canRotate = false },
        [23] = { label = 'Fleeca Bank Hawick Ave CAM#2', coords = vector3(-355.7643, -52.506, 50.746), r = { x = -35.0, y = 0.0, z = -143.8711 }, canRotate = false },
        [24] = { label = 'Fleeca Bank Del Perro Blvd CAM#1', coords = vector3(-1214.226, -335.86, 39.515), r = { x = -35.0, y = 0.0, z = -97.862 }, canRotate = false },
        [25] = { label = 'Fleeca Bank Great Ocean Hwy CAM#1', coords = vector3(-2958.885, 478.983, 17.406), r = { x = -35.0, y = 0.0, z = -34.69595 }, canRotate = false },
        [26] = { label = 'Paleto Bank CAM#1', coords = vector3(-102.939, 6467.668, 33.424), r = { x = -35.0, y = 0.0, z = 24.66 }, canRotate = false },
        [27] = { label = 'Del Vecchio Liquor Paleto Bay', coords = vector3(-163.75, 6323.45, 33.424), r = { x = -35.0, y = 0.0, z = 260.00 }, canRotate = false },
        [28] = { label = "Don's Country Store Paleto Bay CAM#1", coords = vector3(166.42, 6634.4, 33.69), r = { x = -35.0, y = 0.0, z = 32.00 }, canRotate = false },
        [29] = { label = "Don's Country Store Paleto Bay CAM#2", coords = vector3(163.74, 6644.34, 33.69), r = { x = -35.0, y = 0.0, z = 168.00 }, canRotate = false },
        [30] = { label = "Don's Country Store Paleto Bay CAM#3", coords = vector3(169.54, 6640.89, 33.69), r = { x = -35.0, y = 0.0, z = 5.78 }, canRotate = false },
        [31] = { label = 'Vangelico Jewelery CAM#1', coords = vector3(-627.54, -239.74, 40.33), r = { x = -35.0, y = 0.0, z = 5.78 }, canRotate = true },
        [32] = { label = 'Vangelico Jewelery CAM#2', coords = vector3(-627.51, -229.51, 40.24), r = { x = -35.0, y = 0.0, z = -95.78 }, canRotate = true },
        [33] = { label = 'Vangelico Jewelery CAM#3', coords = vector3(-620.3, -224.31, 40.23), r = { x = -35.0, y = 0.0, z = 165.78 }, canRotate = true },
        [34] = { label = 'Vangelico Jewelery CAM#4', coords = vector3(-622.57, -236.3, 40.31), r = { x = -35.0, y = 0.0, z = 5.78 }, canRotate = true },
    },
}

-- Live body cams and dash cams. Every officer on duty has their body cam running, and nobody is told when it is watched.
-- Watch them from a Camera room point at a station (place one in /policebuilder).
-- Dash cams are on the cars officers take out of a station garage, so they keep running after the officer gets out.
Config.UnitCams = {
    enabled = true,
    body = true,
    dash = true,
    cabin = true,                -- a camera on the back seat of station cars, facing the prisoner
    anyEmergencyVehicle = false, -- true also gives a dash cam to any emergency vehicle an officer is driving
    remote = true,               -- supervisors can also watch from the wheel (Paperwork > Unit cams) and the MDT
    remoteGrade = 3,             -- the lowest rank that can watch away from a station. Bosses always can
    audio = true,                -- hear what the officer hears, through pma-voice
    minimap = true,              -- the minimap follows the unit being watched
    radar = true,                -- the dash cam reads the speed of the car in front
    signalLoss = 8,              -- seconds a unit can be out of range before the feed drops
    fov = { body = 100.0, dash = 72.0, cabin = 90.0 },
    filter = { body = 'CAMERA_secuirity', dash = 'scanline_cam_cheap', cabin = 'scanline_cam_cheap', strength = 0.45 },
}

-- Police helicopters: E opens the camera, right click switches night and thermal vision, space locks onto a vehicle,
-- the mouse wheel zooms, H turns the spotlight on and X rappels from a back seat.
Config.Heli = {
    enabled = true,
    models = { 'polmav' },
}

-- The radar in police cars: target speeds ahead and behind and a plate reader that warns about flagged plates.
Config.Radar = {
    enabled = true,
    command = 'policeradar',
    key = 'F5',         -- shows or hides the radar
    lockKey = 'NUMPAD5', -- freezes the readings
    mph = true,
    range = 60.0,       -- how far ahead and behind it reads, in metres
    classes = { 18 },   -- vehicle classes it works in. 18 is emergency vehicles
}

-- Flagged plates. Set from the wheel or with /flagplate. The radar, the helicopter camera and speed cameras warn officers.
Config.Plates = {
    maxHours = 720, -- the longest a flag can last. 0 hours in the form means until someone removes it
}

-- Fixed speed cameras from qbx_police. Speeders are fined from the bank and flagged plates are reported to officers.
Config.SpeedCameras = {
    enabled = false,
    mph = true,
    society = true,      -- fines go to this department account
    account = 'police',
    fines = {            -- the fine for going up to "over" above the limit
        { over = 10, fine = 25 },
        { over = 30, fine = 50 },
        { over = 80, fine = 250 },
        { over = 9999, fine = 500 },
    },
    list = {
        { coords = vector3(-623.44, -823.08, 25.26), limit = 35 },
        { coords = vector3(-652.44, -854.08, 24.56), limit = 50 },
        { coords = vector3(1623.01, 1068.99, 80.90), limit = 65 },
        { coords = vector3(-2604.90, 2996.34, 27.53), limit = 65 },
        { coords = vector3(2136.65, -591.81, 94.27), limit = 65 },
        { coords = vector3(2117.58, -558.51, 95.68), limit = 65 },
        { coords = vector3(406.90, -969.06, 29.44), limit = 35 },
        { coords = vector3(657.32, -218.82, 44.06), limit = 65 },
        { coords = vector3(2118.29, 6040.03, 50.93), limit = 65 },
        { coords = vector3(-106.30, -1127.55, 30.78), limit = 35 },
        { coords = vector3(-823.37, -1146.98, 8.00), limit = 35 },
    },
}

-- Breathalyzer and drug swab. Drinks and drugs from other scripts report through qb-policejob's evidence:client:SetStatus,
-- and these say which of those statuses each drug test line picks up.
Config.Tests = {
    bacLimit = 0.08,
    drugs = {
        thc = { 'weedsmell', 'redeyes' },
        coc = { 'widepupils', 'agitated' },
        met = { 'chemicals', 'sweat' },
        opi = { 'confused', 'heavybreath' },
    },
}

-- Ankle monitors, put on and taken off from the wheel. On-duty officers see whoever wears one on the map.
Config.Tracker = {
    enabled = true,
    sprite = 458,
    colour = 1,
}

Config.Licences = {
    kinds = { 'driver', 'weapon' }, -- licences officers can see, give and take on the wheel
}

-- qb-policejob's chat commands: /cuff, /escort, /cam, /flagplate, /unflagplate, /plateinfo, /anklet, /ankletlocation,
-- /grantlicense, /revokelicense, /takedrivinglicense, /takedna, /clearcasings, /clearblood, /fine, /pobject, /spikestrip,
-- /seizecash, /paytow, /paylawyer and /911p. Set to false if another script already uses these names.
Config.Commands = true

-- The forensic lab, a point placed at a station in the builder. Officers analyse their evidence bags there:
-- DNA and prints are matched to a name, and a casing's serial number to whoever carries that gun.
-- Community service: a lighter sentence than jail. Build a service area in the builder and place its task spots.
-- The person sweeps up at the spots until the tasks are done. Leaving the area adds tasks, and logging out keeps them.
Config.Service = {
    maxTasks = 50,
    seconds = 8,   -- how long one task takes
    radius = 60.0, -- how far from the task spots they can go
    penalty = 2,   -- tasks added for leaving the area
}

-- Mugshots, taken at a station's booking point. They show on the ID card check and through exports.GetMugshot.
-- The photo needs screenshot-basic running.
Config.Mugshot = {
    title = 'LOS SANTOS POLICE DEPT',
}

Config.Lab = {
    seconds = 8, -- how long an analysis takes
}

-- Searching a car's trunk, or its glovebox when you search from inside. These sizes are only used when the inventory makes a new one.
Config.SearchVehicle = {
    trunk = { slots = 30, weight = 100000 },
    glovebox = { slots = 5, weight = 10000 },
}

-- Slow or stop the traffic around you from the wheel (Scene). Pressing it again where you stand clears it.
Config.Traffic = {
    radius = 40.0,
    slowSpeed = 5.0, -- metres per second, about 11 mph
    minutes = 20,    -- cleared on its own after this long
    perOfficer = 3,
}

-- Every on-duty officer is alerted, with a blip, when an on-duty officer goes down.
Config.OfficerDown = {
    enabled = true,
}

-- Police dogs, from the wheel (Scene > K9). The dog follows, stays, sniffs people and cars, bites on command and rides in the car.
Config.K9 = {
    enabled = true,
    model = 'a_c_shepherd',
    grade = 0,       -- lowest rank that can have a dog
    jobs = {},       -- departments with dogs. {} for every police job
    invincible = true,
    attackSeconds = 8,
    attackRange = 25.0,   -- how far away the person you send the dog at can be
    sniffRange = 8.0,     -- how far away the person or car you point the dog at can be
    trackRadius = 60.0,   -- Track: how far the dog searches for someone who is not police
    guardDistance = 5.0,  -- Guard: how far the suspect can move before the dog takes them down. Sprinting always counts
    guardMinutes = 5,     -- Guard: how long the dog holds a suspect before coming back
    find = { 'weed', 'joint', 'coke', 'cocaine', 'crack', 'meth', 'heroin', 'oxy', 'xtc', 'ecstasy', 'lsd', 'drug' }, -- items it alerts on, matched anywhere in the item name
}

Config.Pay = {
    tow = 500,          -- /paytow pays a tow driver this much
    lawyer = 500,       -- /paylawyer pays a lawyer this much
    fromSociety = true, -- paid out of the department account
}

Config.Panic = {
    cooldownSeconds = 30,
    blipSeconds = 90,
}

-- Station garages. Vehicles, liveries and extras for each station are set in the builder;
-- this is only the default list a new garage starts with.
Config.Garage = {
    platePrefix = 'LSPD', -- plate shows as LSPD 4271
    fuel = 100.0,
    defaults = {
        { model = 'police', label = 'Cruiser', grade = 0 },
        { model = 'police2', label = 'Buffalo', grade = 0 },
        { model = 'police3', label = 'Interceptor', grade = 1 },
        { model = 'policeb', label = 'Bike', grade = 1 },
        { model = 'fbi', label = 'Unmarked', grade = 3 },
    },
    helicopters = {
        { model = 'polmav', label = 'Maverick', grade = 2 },
    },
}

-- Station armories. Items for each station are set in the builder; this is the list a new armory starts with.
-- price 0 is free. Prices are paid from the department account when payFromSociety is on.
Config.Armory = {
    payFromSociety = true,
    images = 'auto', -- where item photos come from. 'auto' reads your inventory's image folder, or give your own like 'nui://my_inventory/html/images/%s.png'
    defaults = {
        { item = 'weapon_flashlight', grade = 0, price = 0 },
        { item = 'weapon_nightstick', grade = 0, price = 0 },
        { item = 'weapon_stungun', grade = 0, price = 0 },
        { item = 'weapon_combatpistol', grade = 0, price = 0 },
        { item = 'weapon_pumpshotgun', grade = 2, price = 0 },
        { item = 'weapon_carbinerifle', grade = 3, price = 0 },
        { item = 'pistol_ammo', grade = 0, price = 0, amount = 5 },
        { item = 'shotgun_ammo', grade = 2, price = 0, amount = 5 },
        { item = 'rifle_ammo', grade = 3, price = 0, amount = 5 },
        { item = 'armor', grade = 0, price = 0 },
        { item = 'handcuffs', grade = 0, price = 0 },
        { item = 'spikestrip', grade = 0, price = 0 },
        { item = 'empty_evidence_bag', grade = 0, price = 0, amount = 10 },
        { item = 'radio', grade = 0, price = 0 },
    },
    -- The same list with ox_inventory's item names, used when ox_inventory is running.
    oxDefaults = {
        { item = 'weapon_flashlight', grade = 0, price = 0 },
        { item = 'weapon_nightstick', grade = 0, price = 0 },
        { item = 'weapon_stungun', grade = 0, price = 0 },
        { item = 'weapon_combatpistol', grade = 0, price = 0 },
        { item = 'weapon_pumpshotgun', grade = 2, price = 0 },
        { item = 'weapon_carbinerifle', grade = 3, price = 0 },
        { item = 'ammo-9', grade = 0, price = 0, amount = 24 },
        { item = 'ammo-shotgun', grade = 2, price = 0, amount = 12 },
        { item = 'ammo-rifle', grade = 3, price = 0, amount = 30 },
        { item = 'armour', grade = 0, price = 0 },
        { item = 'handcuffs', grade = 0, price = 0 },
        { item = 'spikestrip', grade = 0, price = 0 },
        { item = 'empty_evidence_bag', grade = 0, price = 0, amount = 10 },
        { item = 'radio', grade = 0, price = 0 },
    },
}

Config.Stashes = {
    locker = { slots = 40, weight = 120000 }, -- each officer's own locker
}

-- Evidence rooms hold numbered lockers. An officer types a number at the evidence point and that locker opens.
Config.Evidence = {
    lockers = 9999,  -- lockers are numbered 1 to this
    shared = false,  -- true: locker 12 is the same locker at every station
    slots = 50,
    weight = 250000,
}

Config.Jail = {
    enabled = true,       -- false if you run another prison script
    minutesPerMonth = 1,  -- a sentence of 30 months is 30 minutes, counted only while the prisoner is online
    maxMonths = 300,
    confiscate = true,    -- take their items when they go in and give them back when they leave
    keepItems = {},       -- item names a prisoner keeps, for example { 'phone' }
    releaseClear = true,  -- at release, take everything they picked up inside before handing their own items back
    escapeAlert = true,   -- tell on-duty officers when someone leaves the prison
    alarm = true,         -- the prison siren sounds around the prison when someone escapes
    alarmMinutes = 3,
    testMode = true,      -- staff can jail themselves from a prison's editor in the builder (Test on me). No record, no police alerts
    testMinutes = 5,      -- how long a test sentence lasts
    solitaryMinutes = 5,  -- how long an officer can put an inmate in a solitary cell. Place solitary cells in the builder
    escapeRadius = 150.0, -- used when a prison has no boundary drawn
    -- Prison jobs are made per prison on the builder's Jobs tab. These are the starting values.
    jobSeconds = 12,      -- how long one task takes
    jobCredit = 30,       -- seconds taken off the sentence for each task
    spotCooldown = 90,    -- seconds before a prisoner can do the same spot again, so a job moves them around
    defaultJobs = {       -- the jobs a new prison starts with. Place their spots in the builder
        { label = 'Fix the wiring', activity = 'repair' },
        { label = 'Sweep the yard', activity = 'sweep' },
        { label = 'Clean the cells', activity = 'clean' },
        { label = 'Kitchen duty', activity = 'cook' },
        { label = 'Tend the garden', activity = 'garden' },
    },
    -- What each kind of job looks like. Add your own with a scenario, or with anim = { dict = '...', clip = '...' }
    activities = {
        repair = { label = 'Electrical repairs', scenario = 'WORLD_HUMAN_WELDING' },
        sweep = { label = 'Sweeping', scenario = 'WORLD_HUMAN_JANITOR' },
        clean = { label = 'Cleaning', scenario = 'WORLD_HUMAN_MAID_CLEAN' },
        cook = { label = 'Kitchen duty', scenario = 'PROP_HUMAN_BBQ' },
        garden = { label = 'Gardening', scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
        leaves = { label = 'Leaf blowing', scenario = 'WORLD_HUMAN_GARDENER_LEAF_BLOWER' },
        build = { label = 'Building work', scenario = 'WORLD_HUMAN_HAMMERING' },
        rubbish = { label = 'Sorting rubbish', scenario = 'PROP_HUMAN_BUM_BIN' },
        paperwork = { label = 'Paperwork', scenario = 'WORLD_HUMAN_CLIPBOARD' },
    },
    -- Workout stations are placed in the builder. One set lowers stress and can take time off.
    workout = {
        seconds = 20, -- how long one set takes
        stress = 10,  -- stress taken off per set
        credit = 0,   -- seconds taken off the sentence per set
    },
    exercises = {
        pushups = { label = 'Push-ups', scenario = 'WORLD_HUMAN_PUSH_UPS' },
        situps = { label = 'Sit-ups', scenario = 'WORLD_HUMAN_SIT_UPS' },
        chinups = { label = 'Chin-ups', scenario = 'PROP_HUMAN_MUSCLE_CHIN_UPS' },
        weights = { label = 'Free weights', scenario = 'WORLD_HUMAN_MUSCLE_FREE_WEIGHTS' },
        yoga = { label = 'Yoga', scenario = 'WORLD_HUMAN_YOGA' },
        jog = { label = 'Jogging on the spot', scenario = 'WORLD_HUMAN_JOG_STANDING' },
    },
    -- The canteen's meals are set per prison on the builder's Canteen tab. A new prison starts with this one.
    canteen = { 'sandwich', 'water_bottle' },
    canteenMinutes = 5, -- how long a prisoner waits between meals
    -- Commissary credit. Prison jobs pay credit, spent at a commissary clerk placed in the builder.
    jobPay = 5,          -- credit a new prison job pays per task. Each job has its own on the Prison jobs tab
    creditPayout = 0,    -- credit left at release is paid out as cash at this rate. 0 keeps it in the prison
    commissary = {
        { item = 'sandwich', price = 8 },
        { item = 'water_bottle', price = 4 },
        { item = 'prison_cigarettes', price = 15 },
        { call = true, price = 20 }, -- a phone call: the inmate sends a message to someone in the city
    },
    -- The inmate trader, placed in the builder, deals in cigarettes.
    currency = 'prison_cigarettes',
    trader = {
        sells = { { item = 'prison_scrap', price = 2 }, { item = 'prison_spoon', price = 6 }, { item = 'lockpick', price = 12 } },
        buys = { { item = 'prison_shiv', price = 6 }, { item = 'sandwich', price = 1 } },
    },
    -- Contraband. Prison jobs turn up scrap, a hidden workbench (placed in the builder) turns it into tools,
    -- and guards search inmates who hang around their posts.
    contraband = {
        finds = { { item = 'prison_scrap', chance = 25 }, { item = 'prison_spoon', chance = 4 } }, -- percent chance per finished job task
        items = { 'prison_shiv', 'prison_cutters', 'prison_spoon', 'prison_scrap', 'lockpick', 'weapon_knife' }, -- what guards take off them
        searchMinutes = 4,  -- how often guards search an inmate near a guard post. 0 turns searches off
        searchRange = 12.0,
        searchChance = 50,  -- percent chance a search turns up what they carry
        penaltyMonths = 5,  -- added to the sentence when guards find contraband
    },
    -- Stashes. Every cell has a stash under the mattress that is the inmate's own and is still there the next time
    -- they are locked up. Hidden stash spots, placed in the builder, are shared by every inmate who finds them.
    bedStash = { enabled = true, slots = 8, weight = 8000 },
    hiddenStash = { slots = 15, weight = 20000 },
    recipes = {
        { item = 'prison_shiv', needs = { prison_scrap = 2 }, seconds = 15 },
        { item = 'lockpick', needs = { prison_scrap = 1 }, seconds = 10 },
        { item = 'prison_cutters', needs = { prison_scrap = 4, prison_shiv = 1 }, seconds = 25 },
    },
    -- Breakouts. Tunnels are dug with a spoon over several sessions, fences are cut with wire cutters.
    -- Place tunnel and fence spots, and where each one comes out, in the builder.
    breakout = {
        tunnelItem = 'prison_spoon',
        tunnelSessions = 8,
        tunnelSeconds = 30,
        spoonBreak = 15,     -- percent chance the spoon snaps each session
        fenceItem = 'prison_cutters',
        fenceSeconds = 20,
        cuttersBreak = 50,
        caughtChance = 25,   -- percent chance a guard post nearby catches them at it
        guardRange = 15.0,
        alarm = true,        -- going through sets off the prison alarm and alerts police
    },
    -- Prison staff and inmates standing at the guard, clerk and trader spots placed in the builder.
    npcs = {
        guard = { model = 's_m_m_prisguard_01', scenario = 'WORLD_HUMAN_GUARD_STAND', patrol = true },
        clerk = { model = 's_m_m_prisguard_01', scenario = 'WORLD_HUMAN_CLIPBOARD' },
        trader = { model = 's_m_y_prisoner_01', scenario = 'WORLD_HUMAN_SMOKING' },
    },
    outfit = true,        -- prisoners wear the jail outfit while inside
    outfits = {
        male = { [3] = { 19, 0 }, [4] = { 3, 7 }, [6] = { 1, 0 }, [8] = { 15, 0 }, [11] = { 345, 0 } },
        female = { [3] = { 0, 0 }, [4] = { 0, 12 }, [6] = { 1, 0 }, [8] = { 14, 0 }, [11] = { 370, 0 } },
    },
}

-- What a new place's map blip starts as. Each one can be changed in the builder.
Config.Blips = {
    station = { sprite = 60, colour = 29, scale = 0.8 },
    jail = { sprite = 285, colour = 1, scale = 0.8 },
    impound = { sprite = 68, colour = 47, scale = 0.8 },
    custom = { sprite = 162, colour = 3, scale = 0.8 },
    service = { sprite = 365, colour = 17, scale = 0.8 },
    panic = { sprite = 161, colour = 1, scale = 1.2 },
    alert = { sprite = 161, colour = 3, scale = 1.0 },
    escape = { sprite = 285, colour = 1, scale = 1.1 },
}

Config.Markers = false -- floor rings at station, prison and impound points. This is the default for new places; each has its own switch in the builder
