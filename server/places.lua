Places = { places = {}, order = {} }

local KINDS = { station = true, jail = true, impound = true, blip = true, service = true }
local DEFAULT_NAMES = { station = 'station_default_name', jail = 'jail_default_name', impound = 'impound_default_name', blip = 'blip_default_name', service = 'service_default_name' }
local WHO = { all = true, police = true, duty = true }

local function str(value, max, fallback)
    local out = Util.Text(value, max)
    if out == '' then return fallback or '' end
    return out
end

local function int(value, low, high, fallback)
    local n = tonumber(value)
    if not n then return fallback end
    return Util.Clamp(math.floor(n), low, high)
end

local function slug(value, max)
    return (tostring(value or ''):lower():gsub('[^%w_%-]', '')):sub(1, max or 48)
end

local function vehicleList(raw, defaults)
    local out, seen = {}, {}
    local list = type(raw) == 'table' and raw or defaults or {}
    for _, v in ipairs(list) do
        if type(v) == 'string' then v = { model = v } end
        if type(v) == 'table' then
            local model = slug(v.model, 48)
            if model ~= '' and not seen[model] and #out < 40 then
                seen[model] = true
                local extras = {}
                for _, e in ipairs(type(v.extras) == 'table' and v.extras or {}) do
                    local n = tonumber(e)
                    if n and n >= 0 and n <= 20 and #extras < 20 then extras[#extras + 1] = math.floor(n) end
                end
                out[#out + 1] = {
                    model = model, label = str(v.label, 32, model), grade = int(v.grade, 0, 50, 0),
                    livery = int(v.livery, -1, 99, -1), extras = extras,
                }
            end
        end
    end
    return out
end

function Places.ArmoryDefaults()
    if Inventory.name == 'ox_inventory' and Config.Armory.oxDefaults then return Config.Armory.oxDefaults end
    return Config.Armory.defaults or {}
end

local function armoryList(raw)
    local out, seen = {}, {}
    local list = type(raw) == 'table' and raw or Places.ArmoryDefaults()
    for _, e in ipairs(list) do
        if type(e) == 'table' then
            local item = slug(e.item, 64)
            if item ~= '' and not seen[item] and #out < 80 then
                seen[item] = true
                out[#out + 1] = {
                    item = item, grade = int(e.grade, 0, 50, 0), price = int(e.price, 0, 1000000, 0), amount = int(e.amount, 1, 250, 1),
                }
            end
        end
    end
    return out
end

local function jobList(raw)
    local out, seen = {}, {}
    for _, name in ipairs(type(raw) == 'table' and raw or {}) do
        local job = slug(name, 32)
        if job ~= '' and not seen[job] and #out < 10 then
            seen[job] = true
            out[#out + 1] = job
        end
    end
    return out
end

local function blipOf(raw, kind)
    local B = (Config.Blips or {})[kind] or (Config.Blips or {}).custom or {}
    local b = type(raw) == 'table' and raw or { show = raw ~= false }
    return {
        show = b.show ~= false,
        sprite = int(b.sprite, 0, 999, B.sprite or 1),
        colour = int(b.colour, 0, 85, B.colour or 0),
        scale = Util.Clamp(Util.Round(tonumber(b.scale) or B.scale or 0.8, 2), 0.3, 2.0),
        label = str(b.label, 48, ''),
        short = b.short ~= false,
        who = WHO[b.who] and b.who or 'all',
    }
end

local function firstKey(map, preferred)
    if type(map) ~= 'table' then return preferred end
    if preferred and map[preferred] then return preferred end
    local keys = {}
    for key in pairs(map) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys[1] or preferred
end

local function sanitizePoint(placeKind, kind, raw)
    local def = Points.Allowed(placeKind, kind)
    if not def then return nil end
    local p = Util.Point(raw)
    if not p then return nil end
    p.id = str(raw.id, 24, Util.Id('p'))
    if def.spawn then p.spawn = Util.Point(raw.spawn) or Util.Point(raw) end
    if def.exit then p.exit = Util.Point(raw.exit) end
    if def.named then p.label = str(raw.label, 32, Text('point_' .. kind)) end
    if def.exercise then
        local list = Config.Jail.exercises or {}
        p.exercise = list[raw.exercise] and raw.exercise or firstKey(list, 'pushups')
    end
    return p
end

local function workList(raw, legacyPoints)
    local J = Config.Jail or {}
    local activities = J.activities or {}
    local list = type(raw) == 'table' and raw or nil
    if not list then
        list = {}
        local byLabel = {}
        local legacy = type(legacyPoints) == 'table' and type(legacyPoints.job) == 'table' and legacyPoints.job or {}
        for _, p in ipairs(legacy) do
            local label = str(type(p) == 'table' and p.label, 32, Text('point_job'))
            if not byLabel[label] then
                byLabel[label] = { label = label, activity = 'repair', spots = {} }
                list[#list + 1] = byLabel[label]
            end
            table.insert(byLabel[label].spots, p)
        end
        if #list == 0 then
            for _, d in ipairs(J.defaultJobs or {}) do list[#list + 1] = { label = d.label, activity = d.activity, spots = d.spots } end
        end
    end
    local out, seen = {}, {}
    for _, w in ipairs(list) do
        if type(w) == 'table' and #out < 12 then
            local id = str(w.id, 24, '')
            if id == '' or seen[id] then id = Util.Id('w') end
            seen[id] = true
            local spots = {}
            for _, s in ipairs(type(w.spots) == 'table' and w.spots or {}) do
                local p = type(s) == 'table' and Util.Point(s) or nil
                if p and #spots < 40 then
                    p.id = str(s.id, 24, '')
                    if p.id == '' or seen[p.id] then p.id = Util.Id('s') end
                    seen[p.id] = true
                    spots[#spots + 1] = p
                end
            end
            out[#out + 1] = {
                id = id, label = str(w.label, 32, Text('point_job')),
                activity = activities[w.activity] and w.activity or firstKey(activities, 'repair'),
                seconds = int(w.seconds, 3, 120, J.jobSeconds or 12),
                credit = int(w.credit, 0, 3600, J.jobCredit or 30),
                pay = int(w.pay, 0, 1000, J.jobPay or 5),
                spots = spots,
            }
        end
    end
    return out
end

local function mealList(raw)
    local list = type(raw) == 'table' and raw or { { label = Text('canteen_default_meal'), items = (Config.Jail or {}).canteen or {} } }
    local out, seen = {}, {}
    for _, m in ipairs(list) do
        if type(m) == 'table' and #out < 12 then
            local items = {}
            for _, e in ipairs(type(m.items) == 'table' and m.items or {}) do
                if type(e) == 'string' then e = { item = e, amount = 1 } end
                if type(e) == 'table' then
                    local item = slug(e.item, 64)
                    if item ~= '' and #items < 6 then items[#items + 1] = { item = item, amount = int(e.amount, 1, 20, 1) } end
                end
            end
            if #items > 0 then
                local id = str(m.id, 24, '')
                if id == '' or seen[id] then id = Util.Id('m') end
                seen[id] = true
                out[#out + 1] = { id = id, label = str(m.label, 32, Text('canteen_default_meal')), items = items }
            end
        end
    end
    return out
end

function Places.Sanitize(raw)
    if type(raw) ~= 'table' then return nil end
    local kind = KINDS[raw.kind] and raw.kind or 'station'
    local place = {
        id = tonumber(raw.id), kind = kind,
        name = str(raw.name, 48, Text(DEFAULT_NAMES[kind])),
        blip = blipOf(raw.blip, kind), points = {},
        enabled = raw.enabled ~= false and raw.enabled ~= 0,
    }
    if type(raw.blipAt) == 'table' then place.blipAt = Util.Point(raw.blipAt) end
    if kind ~= 'blip' then
        if raw.markers == nil then place.markers = Config.Markers == true else place.markers = Util.Truthy(raw.markers) end
    end
    if kind == 'station' then
        place.jobs = jobList(raw.jobs)
        place.plate = (tostring(raw.plate or Config.Garage.platePrefix or 'LSPD'):upper():gsub('[^%u%d]', '')):sub(1, 4)
        if place.plate == '' then place.plate = 'LSPD' end
        place.armory = armoryList(raw.armory)
        place.vehicles = vehicleList(raw.vehicles, Config.Garage.defaults)
        place.helicopters = vehicleList(raw.helicopters, Config.Garage.helicopters)
    elseif kind == 'jail' then
        place.radius = Util.Clamp(tonumber(raw.radius) or Config.Jail.escapeRadius or 150.0, 20.0, 1500.0)
        place.center = Util.Point(raw.center)
        place.work = workList(raw.work, raw.points)
        place.meals = mealList(raw.meals)
        place.mealMinutes = int(raw.mealMinutes, 0, 120, Config.Jail.canteenMinutes or 5)
    elseif kind == 'impound' then
        local I = Config.Impound or {}
        place.jobs = jobList(raw.jobs)
        place.fee = int(raw.fee, I.minFee or 0, I.maxFee or 25000, I.fee or 500)
        if raw.clerk == nil then place.clerk = I.clerk or '' else place.clerk = slug(raw.clerk, 48) end
    end
    local seen = {}
    for _, def in ipairs(Points.Kinds[kind]) do
        local list = {}
        local rawList = type(raw.points) == 'table' and type(raw.points[def.key]) == 'table' and raw.points[def.key] or {}
        for _, rawPoint in ipairs(rawList) do
            local p = sanitizePoint(kind, def.key, rawPoint)
            if p and #list < (def.single and 1 or 80) then
                if seen[p.id] then p.id = Util.Id('p') end
                seen[p.id] = true
                list[#list + 1] = p
            end
        end
        place.points[def.key] = list
    end
    return place
end

function Places.Load()
    Places.places, Places.order = {}, {}
    local rows = MySQL.query.await('SELECT `id`, `kind`, `name`, `data` FROM `xs_police_places` ORDER BY `id`') or {}
    for _, row in ipairs(rows) do
        local data = Db.Decode(row.data, {})
        data.id, data.kind, data.name = row.id, row.kind, row.name
        local place = Places.Sanitize(data)
        if place then
            Places.places[place.id] = place
            Places.order[#Places.order + 1] = place.id
        end
    end
    Places.Publish()
end

function Places.List(kind)
    local out = {}
    for _, id in ipairs(Places.order) do
        local place = Places.places[id]
        if place.enabled ~= false and (not kind or place.kind == kind) then out[#out + 1] = place end
    end
    return out
end

function Places.All()
    local out = {}
    for _, id in ipairs(Places.order) do out[#out + 1] = Places.places[id] end
    return out
end

function Places.Publish(target)
    TriggerClientEvent('XS-PoliceSystem:client:places', target or -1, Places.List())
end

function Places.Save(place)
    local data = {}
    for key, value in pairs(place) do
        if key ~= 'id' and key ~= 'kind' and key ~= 'name' then data[key] = value end
    end
    local json = Db.Json(data)
    if place.id and Places.places[place.id] then
        MySQL.update.await('UPDATE `xs_police_places` SET `kind` = ?, `name` = ?, `data` = ? WHERE `id` = ?', { place.kind, place.name, json, place.id })
    else
        place.id = MySQL.insert.await('INSERT INTO `xs_police_places` (`kind`, `name`, `data`) VALUES (?, ?, ?)', { place.kind, place.name, json })
        if not place.id then return nil end
        Places.order[#Places.order + 1] = place.id
    end
    Places.places[place.id] = place
    Places.Publish()
    return place
end

function Places.Delete(id)
    id = tonumber(id)
    if not id or not Places.places[id] then return false end
    MySQL.query.await('DELETE FROM `xs_police_places` WHERE `id` = ?', { id })
    Places.places[id] = nil
    for i, value in ipairs(Places.order) do
        if value == id then table.remove(Places.order, i) break end
    end
    Places.Publish()
    return true
end

function Places.Get(id)
    return Places.places[tonumber(id) or -1]
end

function Places.Point(place, kind, id)
    if not place then return nil end
    for _, p in ipairs(place.points[kind] or {}) do
        if p.id == id then return p end
    end
    return nil
end

function Places.Coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function Places.Near(src, p, max)
    local c = Places.Coords(src)
    if not c or not p then return false end
    return #(c - vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0)) <= (max or 3.0)
end

function Places.ServesJob(place, job)
    if not place or (place.kind ~= 'station' and place.kind ~= 'impound') or not job then return false end
    if #(place.jobs or {}) == 0 then return true end
    for _, name in ipairs(place.jobs) do
        if name == job.name then return true end
    end
    return false
end

function Places.FirstJail()
    for _, id in ipairs(Places.order) do
        local place = Places.places[id]
        if place.kind == 'jail' and place.enabled ~= false and #(place.points.cell or {}) > 0 then return place end
    end
    return nil
end
