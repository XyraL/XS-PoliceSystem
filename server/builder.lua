local function admin(src)
    return Framework.IsAdmin(src)
end

local function at(x, y, z, w, extra)
    local out = { x = x, y = y, z = z, w = w }
    for k, v in pairs(extra or {}) do out[k] = v end
    return out
end

local BOLINGBROKE = {
    center = { x = 1693.33, y = 2569.51, z = 44.55 },
    radius = 200.0,
    points = {
        cell = {
            at(1661.05, 2524.68, 45.56, 260.5), at(1650.81, 2540.58, 45.56, 230.4), at(1654.96, 2545.54, 45.56, 230.4),
            at(1697.11, 2525.56, 45.56, 187.2), at(1673.08, 2519.82, 45.56, 229.5), at(1666.03, 2511.37, 45.56, 233.9),
            at(1691.23, 2509.64, 45.56, 52.4), at(1770.59, 2536.06, 45.56, 258.1), at(1792.45, 2584.37, 45.56, 276.2),
            at(1768.33, 2566.08, 45.56, 176.8), at(1696.09, 2469.40, 45.56, 1.4),
        },
        canteen = { at(1778.31, 2560.56, 45.62, 181.1) },
        workout = { at(1770.72, 2479.98, 45.74, 31.7, { exercise = 'pushups' }), at(1745.03, 2479.21, 45.74, 323.1, { exercise = 'weights' }) },
        release = { at(1848.13, 2586.05, 44.67, 269.5) },
    },
    work = {
        {
            label = 'Fix the wiring', activity = 'repair',
            spots = {
                at(1761.46, 2540.41, 45.56, 272.2), at(1718.54, 2527.80, 45.56, 272.2), at(1700.20, 2474.81, 45.56, 272.2),
                at(1664.83, 2501.58, 45.56, 272.2), at(1621.62, 2509.30, 45.56, 272.2), at(1627.94, 2538.39, 45.56, 272.2),
                at(1625.10, 2575.99, 45.56, 272.2),
            },
        },
    },
}

local function labelled(map)
    local out = {}
    for key, def in pairs(map or {}) do out[#out + 1] = { key = key, label = def.label or key } end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

local TEMPLATES = {
    missionrow = {
        kind = 'station', name = 'Mission Row PD',
        points = {
            duty = { at(440.09, -974.92, 30.69, 0.0) },
            locker = { at(453.08, -980.12, 30.89, 0.0) },
            armory = { at(462.23, -981.12, 30.68, 90.0) },
            garage = { at(448.16, -1017.41, 28.56, 90.65, { spawn = at(448.16, -1017.41, 28.56, 90.65) }) },
            helipad = { at(449.17, -981.33, 43.69, 87.23, { spawn = at(449.17, -981.33, 43.69, 87.23) }) },
            evidence = { at(442.17, -996.07, 30.69, 0.0) },
            booking = { at(460.97, -989.18, 24.92, 0.0) },
            boss = { at(461.45, -986.2, 30.73, 0.0) },
        },
    },
    paleto = {
        kind = 'station', name = 'Paleto Bay Sheriff',
        points = {
            duty = { at(-449.81, 6012.91, 31.82, 0.0) },
            garage = { at(-455.39, 6002.02, 31.34, 87.93, { spawn = at(-455.39, 6002.02, 31.34, 87.93) }) },
            helipad = { at(-475.43, 5988.35, 31.72, 31.34, { spawn = at(-475.43, 5988.35, 31.72, 31.34) }) },
        },
    },
}

local function gradesOf(def)
    local out = {}
    for key, g in pairs(type(def) == 'table' and type(def.grades) == 'table' and def.grades or {}) do
        local n = tonumber(key)
        if n then
            local label = type(g) == 'table' and (g.name or g.label) or nil
            out[#out + 1] = { grade = math.floor(n), label = label and tostring(label) or tostring(n), boss = type(g) == 'table' and (g.isboss == true or g.isBoss == true) }
        end
    end
    table.sort(out, function(a, b) return a.grade < b.grade end)
    return out
end

local function jobOptions()
    local out, seen = {}, {}
    local list
    local function add(name, def)
        if name and not seen[name] then
            seen[name] = true
            out[#out + 1] = { name = name, label = type(def) == 'table' and def.label or name, grades = gradesOf(def) }
        end
    end
    if Framework.name == 'qbox' then
        list = exports.qbx_core:GetJobs()
    elseif Framework.core then
        list = Framework.core.Shared.Jobs
    end
    for name, def in pairs(list or {}) do
        if Util.IsCopJob({ name = name, type = def.type }) then add(name, def) end
    end
    for _, name in ipairs((Config.Jobs or {}).names or {}) do
        if list and list[name] then add(name, list[name]) end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

local function heldByLot()
    local out = {}
    local ok, rows = pcall(MySQL.query.await, 'SELECT `lot_id`, COUNT(*) AS `n` FROM `xs_police_impound` WHERE `released` = 0 GROUP BY `lot_id`')
    for _, row in ipairs(ok and type(rows) == 'table' and rows or {}) do
        out[tonumber(row.lot_id) or 0] = tonumber(row.n) or 0
    end
    return out
end

local function serving(placeId)
    local n = 0
    for _, entry in pairs(Service.list or {}) do
        if entry.placeId == placeId then n = n + 1 end
    end
    local ok, row = pcall(MySQL.scalar.await, 'SELECT COUNT(*) FROM `xs_police_service` WHERE `place_id` = ? AND `tasks` > 0', { placeId })
    return math.max(n, ok and tonumber(row) or 0)
end

local function liveStats()
    local held = heldByLot()
    local out = {}
    for _, place in ipairs(Places.All()) do
        local s = {}
        if place.kind == 'jail' then s.inmates = Jail.Count(place.id) end
        if place.kind == 'impound' then s.held = held[place.id] or 0 end
        if place.kind == 'service' then s.serving = serving(place.id) end
        out[tostring(place.id)] = s
    end
    return out
end

local function inUse(place)
    if place.kind == 'jail' then
        local n = Jail.Count(place.id)
        if n > 0 then return Text('err_jail_in_use_n', { count = n }) end
    elseif place.kind == 'impound' then
        local n = heldByLot()[place.id] or 0
        if n > 0 then return Text('err_lot_in_use', { count = n }) end
    elseif place.kind == 'service' then
        local n = serving(place.id)
        if n > 0 then return Text('err_service_in_use', { count = n }) end
    end
    return nil
end

lib.callback.register('XS-PoliceSystem:server:builderJailTest', function(src, placeId)
    if not admin(src) then return false, Text('err_not_admin') end
    if not Places.Get(tonumber(placeId) or placeId) then return false, Text('err_no_jail') end
    return Jail.Test(src, nil, tonumber(placeId) or placeId)
end)

lib.callback.register('XS-PoliceSystem:server:builderJailTestSkip', function(src)
    if not admin(src) then return false, Text('err_not_admin') end
    local ok, msg = Jail.SkipTest(src)
    if not ok then return false, msg end
    return true, Jail.TestState(src)
end)

lib.callback.register('XS-PoliceSystem:server:builderJailTestEnd', function(src)
    if not admin(src) then return false, Text('err_not_admin') end
    return Jail.EndTest(src)
end)

lib.callback.register('XS-PoliceSystem:server:builderOpen', function(src)
    if not admin(src) then return false, Text('err_not_admin') end
    return true, {
        places = Places.All(), jailTest = Jail.TestState(src), vehicles = Framework.Vehicles(), items = Inventory.Items(), jobs = jobOptions(),
        defaults = {
            armory = Places.ArmoryDefaults(), vehicles = Config.Garage.defaults, helicopters = Config.Garage.helicopters,
            plate = Config.Garage.platePrefix, radius = Config.Jail.escapeRadius,
            fee = (Config.Impound or {}).fee or 500, clerk = (Config.Impound or {}).clerk or '',
            minFee = (Config.Impound or {}).minFee or 0, maxFee = (Config.Impound or {}).maxFee or 25000,
            markers = Config.Markers == true, blips = Config.Blips or {},
            jobs = Config.Jail.defaultJobs or {}, jobSeconds = Config.Jail.jobSeconds or 12, jobCredit = Config.Jail.jobCredit or 30, jobPay = Config.Jail.jobPay or 5,
            meals = { { label = Text('canteen_default_meal'), items = (function()
                local out = {}
                for _, item in ipairs(Config.Jail.canteen or {}) do out[#out + 1] = { item = item, amount = 1 } end
                return out
            end)() } },
            mealMinutes = Config.Jail.canteenMinutes or 5,
            activities = labelled(Config.Jail.activities), exercises = labelled(Config.Jail.exercises),
            bolingbroke = BOLINGBROKE, templates = TEMPLATES,
        },
        kinds = Points.Kinds,
        wheel = WheelLayout.Get(),
        wheelDefs = {
            actions = WheelDefs.Actions, order = WheelDefs.Order, pages = WheelDefs.Pages, icons = WheelDefs.Icons,
            favourites = Config.Wheel.favourites or 4, off = Config.Wheel.actions or {},
        },
        settings = Settings.Builder(),
        live = liveStats(),
        system = {
            framework = Framework.name, inventory = Inventory.name, banking = Banking.name, dispatch = Dispatch.name,
            keys = Keys.name, evidence = Evidence.Name(), onDuty = Duty.Count(), admin = GetPlayerName(src) or '',
        },
    }
end)

lib.callback.register('XS-PoliceSystem:server:builderLive', function(src)
    if not admin(src) then return false, Text('err_not_admin') end
    return true, { live = liveStats(), onDuty = Duty.Count() }
end)

lib.callback.register('XS-PoliceSystem:server:builderSave', function(src, raw)
    if not admin(src) then return false, Text('err_not_admin') end
    local place = Places.Sanitize(raw)
    if not place then return false, Text('err_failed') end
    local old = raw.id and Places.Get(raw.id)
    if raw.id and not old then place.id = nil end
    if old and old.enabled ~= false and place.enabled == false then
        local busy = inUse(old)
        if busy then return false, busy end
    end
    local saved = Places.Save(place)
    if not saved then return false, Text('err_db') end
    print(('^2[XS-PoliceSystem]^0 %s saved %s "%s" (#%s).'):format(GetPlayerName(src) or src, saved.kind, saved.name, saved.id))
    return true, saved
end)

lib.callback.register('XS-PoliceSystem:server:builderDelete', function(src, id)
    if not admin(src) then return false, Text('err_not_admin') end
    local place = Places.Get(id)
    if place and place.kind == 'jail' and Jail.Count(place.id) > 0 then return false, Text('err_jail_in_use') end
    if place and place.kind == 'impound' then
        local held = MySQL.scalar.await('SELECT COUNT(*) FROM `xs_police_impound` WHERE `lot_id` = ? AND `released` = 0', { place.id })
        if (tonumber(held) or 0) > 0 then return false, Text('err_lot_in_use', { count = held }) end
    end
    if place and place.kind == 'service' then
        local n = serving(place.id)
        if n > 0 then return false, Text('err_service_in_use', { count = n }) end
    end
    local ok = Places.Delete(id)
    if ok then print(('^3[XS-PoliceSystem]^0 %s deleted place #%s.'):format(GetPlayerName(src) or src, tostring(id))) end
    return ok
end)
