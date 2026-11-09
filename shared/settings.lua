Settings = { fields = {}, byKey = {} }

local MDTS = { 'auto', 'XS-MDT', 'ps-mdt', 'redutzu-mdt', 'kartik-mdt', 'tk_mdt', 'drx_mdt', 'codem-mdtv2', 'origen_police', 'qs-dispatch', 'lb-tablet', 'qb-mdt', 'command', 'none' }

Settings.Sections = {
    { id = 'officers', icon = 'shield', fields = {
        { 'Jobs.requireDuty', 'bool' },
        { 'Jobs.names', 'list', max = 20, slug = true },
        { 'Jobs.types', 'list', max = 10, slug = true },
        { 'Callsign.max', 'int', min = 2, max = 16, unit = 'chars' },
    } },
    { id = 'ranks', icon = 'star', fields = {
        { 'Grades.helipad', 'grade' },
        { 'Grades.evidence', 'grade' },
        { 'Grades.jail', 'grade' },
        { 'Grades.impound', 'grade' },
        { 'Grades.impoundRelease', 'grade' },
        { 'Grades.licences', 'grade' },
        { 'Grades.manage', 'grade' },
        { 'K9.grade', 'grade' },
    } },
    { id = 'boss', icon = 'star', fields = {
        { 'Boss.notes', 'bool' },
        { 'Boss.maxPrice', 'int', min = 0, max = 10000000, step = 100, unit = '$' },
        { 'Boss.armoryPool', 'list', max = 80, slug = true, items = true },
        { 'Boss.vehiclePool', 'list', max = 60, slug = true },
        { 'Boss.helicopterPool', 'list', max = 20, slug = true },
    } },
    { id = 'wheel', icon = 'wheel', fields = {
        { 'Wheel.holdToOpen', 'bool' },
        { 'Wheel.range', 'num', min = 1, max = 10, step = 0.5, unit = 'm' },
        { 'Wheel.favourites', 'int', min = 0, max = 8 },
        { 'MDT.resource', 'select', options = MDTS },
        { 'MDT.command', 'text', max = 32, slug = true, empty = true },
    } },
    { id = 'arrests', icon = 'cuffs', fields = {
        { 'Cuffs.item', 'item', off = true },
        { 'Cuffs.civilians', 'bool' },
        { 'Cuffs.needsHandsUp', 'bool' },
        { 'Cuffs.resist', 'bool' },
        { 'Cuffs.resistDifficulty', 'seq', options = { 'easy', 'medium', 'hard' }, max = 5, needs = 'Cuffs.resist' },
        { 'Search.needsRestrained', 'bool' },
        { 'Seize.cash', 'bool' },
        { 'Seize.society', 'bool', needs = 'Seize.cash' },
        { 'Tackle.enabled', 'bool' },
        { 'Tackle.anyone', 'bool', needs = 'Tackle.enabled' },
        { 'Tackle.range', 'num', min = 1, max = 6, step = 0.5, unit = 'm', needs = 'Tackle.enabled' },
        { 'Tackle.seconds', 'int', min = 1, max = 15, unit = 's', needs = 'Tackle.enabled' },
        { 'Tackle.cooldown', 'int', min = 0, max = 120, unit = 's', needs = 'Tackle.enabled' },
    } },
    { id = 'forensics', icon = 'fingerprint', fields = {
        { 'Forensics.enabled', 'bool' },
        { 'Forensics.flashlight', 'bool', needs = 'Forensics.enabled' },
        { 'Forensics.range', 'num', min = 3, max = 30, step = 1, unit = 'm', needs = 'Forensics.enabled' },
        { 'Forensics.minutes', 'int', min = 5, max = 240, unit = 'min', needs = 'Forensics.enabled' },
        { 'Forensics.bag', 'item', off = true, needs = 'Forensics.enabled' },
        { 'Forensics.casings', 'bool', needs = 'Forensics.enabled' },
        { 'Forensics.printOnCasing', 'pct', needs = 'Forensics.casings' },
        { 'Forensics.blood', 'bool', needs = 'Forensics.enabled' },
        { 'Forensics.bloodChance', 'pct', needs = 'Forensics.blood' },
        { 'Forensics.bloodTrail', 'bool', needs = 'Forensics.blood' },
        { 'Forensics.trailHealth', 'int', min = 101, max = 199, needs = 'Forensics.bloodTrail' },
        { 'Forensics.needsRestrained', 'bool', needs = 'Forensics.enabled' },
        { 'Forensics.printSeconds', 'int', min = 1, max = 30, unit = 's', needs = 'Forensics.enabled' },
        { 'Forensics.glovesBlock', 'bool', needs = 'Forensics.enabled' },
        { 'Forensics.carPrintHours', 'int', min = 0, max = 48, unit = 'h', needs = 'Forensics.enabled' },
        { 'Forensics.dustSeconds', 'int', min = 1, max = 30, unit = 's', needs = 'Forensics.enabled' },
        { 'Forensics.bleach', 'item', off = true },
        { 'Forensics.bleachRadius', 'num', min = 1, max = 15, step = 0.5, unit = 'm', needs = 'Forensics.bleach' },
        { 'Forensics.bleachSeconds', 'int', min = 1, max = 30, unit = 's', needs = 'Forensics.bleach' },
        { 'Gsr.minutes', 'int', min = 1, max = 120, unit = 'min' },
        { 'Gsr.waterClears', 'bool' },
        { 'Lab.seconds', 'int', min = 1, max = 60, unit = 's' },
    } },
    { id = 'storage', icon = 'locker', fields = {
        { 'Evidence.lockers', 'int', min = 1, max = 9999 },
        { 'Evidence.shared', 'bool' },
        { 'Evidence.slots', 'int', min = 1, max = 200 },
        { 'Evidence.weight', 'int', min = 1000, max = 5000000, step = 1000, unit = 'g' },
        { 'Stashes.locker.slots', 'int', min = 1, max = 200 },
        { 'Stashes.locker.weight', 'int', min = 1000, max = 5000000, step = 1000, unit = 'g' },
        { 'SearchVehicle.trunk.slots', 'int', min = 1, max = 200 },
        { 'SearchVehicle.trunk.weight', 'int', min = 1000, max = 5000000, step = 1000, unit = 'g' },
        { 'SearchVehicle.glovebox.slots', 'int', min = 1, max = 50 },
        { 'SearchVehicle.glovebox.weight', 'int', min = 1000, max = 1000000, step = 1000, unit = 'g' },
    } },
    { id = 'money', icon = 'fine', fields = {
        { 'Fines.max', 'int', min = 100, max = 10000000, step = 100, unit = '$' },
        { 'Fines.account', 'select', options = { 'bank', 'cash' } },
        { 'Fines.allowDebt', 'bool' },
        { 'Fines.society', 'bool' },
        { 'Armory.payFromSociety', 'bool' },
        { 'Pay.tow', 'int', min = 0, max = 1000000, step = 50, unit = '$' },
        { 'Pay.lawyer', 'int', min = 0, max = 1000000, step = 50, unit = '$' },
        { 'Pay.fromSociety', 'bool' },
    } },
    { id = 'impound', icon = 'tow', fields = {
        { 'Impound.seconds', 'int', min = 1, max = 30, unit = 's' },
        { 'Impound.holds', 'nums', min = 0, max = 720, count = 10, unit = 'h' },
        { 'Impound.defaultHold', 'int', min = 0, max = 720, unit = 'h' },
        { 'Impound.maxHours', 'int', min = 1, max = 720, unit = 'h' },
        { 'Impound.minFee', 'int', min = 0, max = 1000000, step = 50, unit = '$' },
        { 'Impound.maxFee', 'int', min = 0, max = 1000000, step = 50, unit = '$' },
        { 'Impound.fee', 'int', min = 0, max = 1000000, step = 50, unit = '$' },
        { 'Impound.society', 'bool' },
        { 'Impound.clerk', 'text', max = 48, slug = true, empty = true },
    } },
    { id = 'vehicles', icon = 'car', fields = {
        { 'Garage.platePrefix', 'text', max = 4, upper = true },
        { 'Garage.fuel', 'int', min = 0, max = 100, unit = '%' },
        { 'Radar.enabled', 'bool' },
        { 'Radar.mph', 'bool', needs = 'Radar.enabled' },
        { 'Radar.range', 'int', min = 10, max = 200, unit = 'm', needs = 'Radar.enabled' },
        { 'Heli.enabled', 'bool' },
        { 'Plates.maxHours', 'int', min = 1, max = 8760, unit = 'h' },
        { 'SpeedCameras.enabled', 'bool' },
        { 'SpeedCameras.mph', 'bool', needs = 'SpeedCameras.enabled' },
        { 'SpeedCameras.society', 'bool', needs = 'SpeedCameras.enabled' },
        { 'SpeedCameras.account', 'text', max = 32, slug = true, needs = 'SpeedCameras.society' },
    } },
    { id = 'scene', icon = 'cone', fields = {
        { 'Props.max', 'int', min = 1, max = 50 },
        { 'Spikes.item', 'item', off = true },
        { 'Spikes.max', 'int', min = 1, max = 10 },
        { 'Spikes.seconds', 'int', min = 10, max = 1800, step = 10, unit = 's' },
        { 'Traffic.radius', 'int', min = 10, max = 150, unit = 'm' },
        { 'Traffic.slowSpeed', 'num', min = 1, max = 20, step = 0.5, unit = 'm/s' },
        { 'Traffic.minutes', 'int', min = 1, max = 120, unit = 'min' },
        { 'Traffic.perOfficer', 'int', min = 1, max = 10 },
        { 'Cameras.enabled', 'bool' },
        { 'OfficerDown.enabled', 'bool' },
        { 'Panic.cooldownSeconds', 'int', min = 0, max = 600, unit = 's' },
        { 'Panic.blipSeconds', 'int', min = 10, max = 600, unit = 's' },
    } },
    { id = 'unitcams', icon = 'camera', fields = {
        { 'UnitCams.enabled', 'bool' },
        { 'UnitCams.body', 'bool', needs = 'UnitCams.enabled' },
        { 'UnitCams.dash', 'bool', needs = 'UnitCams.enabled' },
        { 'UnitCams.cabin', 'bool', needs = 'UnitCams.dash' },
        { 'UnitCams.anyEmergencyVehicle', 'bool', needs = 'UnitCams.dash' },
        { 'Grades.camRoom', 'grade', needs = 'UnitCams.enabled' },
        { 'UnitCams.remote', 'bool', needs = 'UnitCams.enabled' },
        { 'UnitCams.remoteGrade', 'grade', needs = 'UnitCams.remote' },
        { 'UnitCams.audio', 'bool', needs = 'UnitCams.enabled' },
        { 'UnitCams.minimap', 'bool', needs = 'UnitCams.enabled' },
        { 'UnitCams.radar', 'bool', needs = 'UnitCams.dash' },
        { 'UnitCams.signalLoss', 'int', min = 3, max = 60, unit = 's', needs = 'UnitCams.enabled' },
        { 'UnitCams.fov.body', 'num', min = 50, max = 120, step = 1, unit = '°', needs = 'UnitCams.body' },
        { 'UnitCams.fov.dash', 'num', min = 40, max = 110, step = 1, unit = '°', needs = 'UnitCams.dash' },
        { 'UnitCams.fov.cabin', 'num', min = 40, max = 120, step = 1, unit = '°', needs = 'UnitCams.cabin' },
    } },
    { id = 'k9', icon = 'k9', fields = {
        { 'K9.enabled', 'bool' },
        { 'K9.jobs', 'list', max = 10, slug = true, needs = 'K9.enabled' },
        { 'K9.model', 'text', max = 48, slug = true, needs = 'K9.enabled' },
        { 'K9.invincible', 'bool', needs = 'K9.enabled' },
        { 'K9.attackSeconds', 'int', min = 1, max = 30, unit = 's', needs = 'K9.enabled' },
        { 'K9.attackRange', 'int', min = 5, max = 60, unit = 'm', needs = 'K9.enabled' },
        { 'K9.trackRadius', 'int', min = 10, max = 300, unit = 'm', needs = 'K9.enabled' },
        { 'K9.guardDistance', 'int', min = 1, max = 30, unit = 'm', needs = 'K9.enabled' },
        { 'K9.guardMinutes', 'int', min = 1, max = 30, unit = 'min', needs = 'K9.enabled' },
        { 'K9.find', 'list', max = 40, slug = true, needs = 'K9.enabled' },
    } },
    { id = 'map', icon = 'map', fields = {
        { 'UnitBlips.enabled', 'bool' },
        { 'UnitBlips.seconds', 'int', min = 1, max = 10, unit = 's', needs = 'UnitBlips.enabled' },
        { 'UnitBlips.jobs', 'list', max = 10, slug = true, needs = 'UnitBlips.enabled' },
        { 'Tracker.enabled', 'bool' },
        { 'Tracker.sprite', 'int', min = 0, max = 999, needs = 'Tracker.enabled' },
        { 'Tracker.colour', 'int', min = 0, max = 85, needs = 'Tracker.enabled' },
        { 'Markers', 'bool' },
    } },
    { id = 'checks', icon = 'gsr', fields = {
        { 'Tests.bacLimit', 'num', min = 0, max = 0.5, step = 0.01 },
        { 'Licences.kinds', 'list', max = 10, slug = true },
        { 'Mugshot.title', 'text', max = 40 },
    } },
    { id = 'prison', icon = 'jail', fields = {
        { 'Jail.enabled', 'bool' },
        { 'Jail.minutesPerMonth', 'num', min = 0.1, max = 60, step = 0.1, unit = 'min', needs = 'Jail.enabled' },
        { 'Jail.maxMonths', 'int', min = 1, max = 10000, needs = 'Jail.enabled' },
        { 'Jail.confiscate', 'bool', needs = 'Jail.enabled' },
        { 'Jail.keepItems', 'list', max = 20, slug = true, items = true, needs = 'Jail.confiscate' },
        { 'Jail.releaseClear', 'bool', needs = 'Jail.enabled' },
        { 'Jail.outfit', 'bool', needs = 'Jail.enabled' },
        { 'Jail.escapeAlert', 'bool', needs = 'Jail.enabled' },
        { 'Jail.alarm', 'bool', needs = 'Jail.enabled' },
        { 'Jail.alarmMinutes', 'int', min = 1, max = 30, unit = 'min', needs = 'Jail.alarm' },
        { 'Jail.escapeRadius', 'int', min = 20, max = 1500, unit = 'm', needs = 'Jail.enabled' },
        { 'Jail.solitaryMinutes', 'int', min = 1, max = 60, unit = 'min', needs = 'Jail.enabled' },
        { 'Jail.spotCooldown', 'int', min = 0, max = 600, unit = 's', needs = 'Jail.enabled' },
        { 'Jail.jobSeconds', 'int', min = 3, max = 120, unit = 's', needs = 'Jail.enabled' },
        { 'Jail.jobCredit', 'int', min = 0, max = 3600, unit = 's', needs = 'Jail.enabled' },
        { 'Jail.workout.seconds', 'int', min = 3, max = 120, unit = 's', needs = 'Jail.enabled' },
        { 'Jail.workout.stress', 'int', min = 0, max = 100, needs = 'Jail.enabled' },
        { 'Jail.workout.credit', 'int', min = 0, max = 600, unit = 's', needs = 'Jail.enabled' },
        { 'Jail.canteenMinutes', 'int', min = 0, max = 120, unit = 'min', needs = 'Jail.enabled' },
        { 'Jail.bedStash.enabled', 'bool', needs = 'Jail.enabled' },
        { 'Jail.bedStash.slots', 'int', min = 1, max = 100, needs = 'Jail.bedStash.enabled' },
        { 'Jail.bedStash.weight', 'int', min = 1000, max = 1000000, step = 1000, unit = 'g', needs = 'Jail.bedStash.enabled' },
        { 'Jail.hiddenStash.slots', 'int', min = 1, max = 100, needs = 'Jail.enabled' },
        { 'Jail.hiddenStash.weight', 'int', min = 1000, max = 1000000, step = 1000, unit = 'g', needs = 'Jail.enabled' },
    } },
    { id = 'service', icon = 'broom', fields = {
        { 'Service.maxTasks', 'int', min = 1, max = 500 },
        { 'Service.seconds', 'int', min = 2, max = 60, unit = 's' },
        { 'Service.radius', 'int', min = 10, max = 500, unit = 'm' },
        { 'Service.penalty', 'int', min = 0, max = 20 },
    } },
    { id = 'builder', icon = 'gear', fields = {
        { 'Builder.showExisting', 'bool' },
        { 'Builder.cameraSpeed.normal', 'num', min = 1, max = 30, step = 0.5, unit = 'm/s' },
        { 'Builder.cameraSpeed.fast', 'num', min = 1, max = 60, step = 0.5, unit = 'm/s' },
        { 'Builder.cameraSpeed.slow', 'num', min = 0.2, max = 10, step = 0.1, unit = 'm/s' },
        { 'Commands', 'bool', restart = true },
    } },
}

for _, section in ipairs(Settings.Sections) do
    local list = {}
    for _, raw in ipairs(section.fields) do
        local def = { key = raw[1], type = raw[2], section = section.id }
        for k, v in pairs(raw) do
            if type(k) == 'string' then def[k] = v end
        end
        list[#list + 1] = def
        Settings.fields[#Settings.fields + 1] = def
        Settings.byKey[def.key] = def
    end
    section.fields = list
end

local function path(key)
    local parts = {}
    for part in key:gmatch('[^%.]+') do parts[#parts + 1] = part end
    return parts
end

function Settings.Read(key)
    local node = Config
    for _, part in ipairs(path(key)) do
        if type(node) ~= 'table' then return nil end
        node = node[part]
    end
    return node
end

function Settings.Write(key, value)
    local parts = path(key)
    local node = Config
    for i = 1, #parts - 1 do
        if type(node[parts[i]]) ~= 'table' then node[parts[i]] = {} end
        node = node[parts[i]]
    end
    node[parts[#parts]] = value
end

function Settings.Same(a, b)
    if type(a) ~= type(b) then
        if type(a) == 'number' and type(b) == 'number' then return a == b end
        return false
    end
    if type(a) ~= 'table' then return a == b end
    if #a ~= #b then return false end
    for k, v in pairs(a) do
        if not Settings.Same(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local function slug(value, max)
    return (tostring(value or ''):lower():gsub('[^%w_%-]', '')):sub(1, max or 48)
end

local function within(def, n)
    if def.min and n < def.min then n = def.min end
    if def.max and n > def.max then n = def.max end
    return n
end

function Settings.Clean(def, value)
    local kind = def.type
    if kind == 'bool' then
        if type(value) == 'boolean' then return value end
        if value == 1 or value == '1' or value == 'true' then return true end
        if value == 0 or value == '0' or value == 'false' then return false end
        return nil
    elseif kind == 'int' or kind == 'grade' or kind == 'pct' then
        local n = tonumber(value)
        if not n or n ~= n then return nil end
        n = math.floor(n + 0.5)
        if kind == 'grade' then return math.max(0, math.min(50, n)) end
        if kind == 'pct' then return math.max(0, math.min(100, n)) end
        return within(def, n)
    elseif kind == 'num' then
        local n = tonumber(value)
        if not n or n ~= n then return nil end
        local step = def.step or 0.1
        n = math.floor(n / step + 0.5) * step
        n = math.floor(n * 1000 + 0.5) / 1000
        return within(def, n)
    elseif kind == 'text' then
        if value == nil or type(value) == 'table' then return nil end
        local s = Util.Text(value, 96)
        if def.upper then s = (s:upper():gsub('[^%u%d]', '')) end
        if def.slug then s = slug(s, 96) end
        s = s:sub(1, def.max or 64)
        if s == '' and not def.empty then return nil end
        return s
    elseif kind == 'select' then
        for _, option in ipairs(def.options or {}) do
            if option == value then return value end
        end
        return nil
    elseif kind == 'item' then
        local s = (value == false or value == nil) and '' or slug(value, 64)
        if s ~= '' then return s end
        if def.off then return false end
        return nil
    elseif kind == 'list' then
        if type(value) ~= 'table' then return nil end
        local out, seen = {}, {}
        for _, v in ipairs(value) do
            local s = def.slug and slug(v, 48) or Util.Text(v, 48)
            if s ~= '' and not seen[s] and #out < (def.max or 20) then
                seen[s] = true
                out[#out + 1] = s
            end
        end
        return out
    elseif kind == 'nums' then
        if type(value) ~= 'table' then return nil end
        local out, seen = {}, {}
        for _, v in ipairs(value) do
            local n = tonumber(v)
            if n then
                n = within(def, math.floor(n + 0.5))
                if not seen[n] and #out < (def.count or 10) then
                    seen[n] = true
                    out[#out + 1] = n
                end
            end
        end
        table.sort(out)
        if #out == 0 then return nil end
        return out
    elseif kind == 'seq' then
        if type(value) ~= 'table' then return nil end
        local allowed = {}
        for _, option in ipairs(def.options or {}) do allowed[option] = true end
        local out = {}
        for _, v in ipairs(value) do
            if allowed[v] and #out < (def.max or 5) then out[#out + 1] = v end
        end
        if #out == 0 then return nil end
        return out
    end
    return nil
end

function Settings.Apply(values)
    if type(values) ~= 'table' then return end
    for key, value in pairs(values) do
        local def = Settings.byKey[key]
        if def then
            local clean = Settings.Clean(def, value)
            if clean ~= nil then Settings.Write(key, clean) end
        end
    end
end

function Settings.Public()
    local sections = {}
    for _, section in ipairs(Settings.Sections) do
        local fields = {}
        for _, def in ipairs(section.fields) do
            local out = {}
            for k, v in pairs(def) do out[k] = v end
            fields[#fields + 1] = out
        end
        sections[#sections + 1] = { id = section.id, icon = section.icon, fields = fields }
    end
    return sections
end
