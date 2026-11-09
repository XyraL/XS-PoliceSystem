Stations = { vehicles = {}, armoryAt = {} }

local VEHICLE_TYPES = { automobile = true, bike = true, boat = true, heli = true, plane = true, submarine = true, trailer = true, train = true }

local function at(src, placeId, kind, pointId, range)
    local place = Places.Get(placeId)
    if not place or place.kind ~= 'station' then return nil end
    local p = Places.Point(place, kind, pointId)
    if not p or not Places.Near(src, p, range or 3.0) then return nil end
    return place, p
end

local function staff(src, place, ignoreDuty)
    local job = Framework.GetJob(src)
    if not Framework.IsCop(job, ignoreDuty) then return nil, Text('err_police_only') end
    if not Places.ServesJob(place, job) then return nil, Text('err_not_your_station') end
    return job
end

local function canDo(job, key)
    if job.isBoss then return true end
    return (job.grade or 0) >= ((Config.Grades or {})[key] or 0)
end

function Stations.Groups(place, minGrade)
    local groups = {}
    local names = (place.jobs and #place.jobs > 0) and place.jobs or (Config.Jobs or {}).names or { 'police' }
    for _, name in ipairs(names) do groups[name] = minGrade or 0 end
    return groups
end

function Stations.Society(job)
    return job and job.name or 'police'
end

lib.callback.register('XS-PoliceSystem:server:duty', function(src, placeId, pointId)
    local place = at(src, placeId, 'duty', pointId)
    if not place then return false, Text('err_too_far') end
    local job, err = staff(src, place, true)
    if not job then return false, err end
    local on = not job.onDuty
    Framework.SetDuty(src, on)
    Duty.Changed(src, on)
    return true, on
end)

lib.callback.register('XS-PoliceSystem:server:locker', function(src, placeId, pointId)
    local place, p = at(src, placeId, 'locker', pointId)
    if not place then return false, Text('err_too_far') end
    local job, err = staff(src, place, true)
    if not job then return false, err end
    local S = Config.Stashes.locker
    local mode, id = Inventory.OpenLocker(src, ('xspolice_locker_%s'):format(place.id), Text('locker_label', { station = place.name }), S.slots, S.weight, vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0), Stations.Groups(place, 0))
    return true, { mode = mode, id = id, label = Text('locker_label', { station = place.name }), slots = S.slots, weight = S.weight }
end)

local function evidenceAt(src, placeId, pointId)
    local place, p = at(src, placeId, 'evidence', pointId)
    if not place then return nil, Text('err_too_far') end
    local job, err = staff(src, place)
    if not job then return nil, err end
    if not canDo(job, 'evidence') then return nil, Text('err_grade') end
    return place, p
end

local function evidenceScope(place)
    return (Config.Evidence or {}).shared and 'all' or tostring(place.id)
end

lib.callback.register('XS-PoliceSystem:server:evidence', function(src, placeId, pointId)
    local place, err = evidenceAt(src, placeId, pointId)
    if not place then return false, err end
    local rows = MySQL.query.await('SELECT `number`, `label`, `opened_by`, `opened_at` FROM `xs_police_evidence` WHERE `scope` = ? ORDER BY `opened_at` DESC LIMIT 300', { evidenceScope(place) }) or {}
    local lockers = {}
    for _, row in ipairs(rows) do
        lockers[#lockers + 1] = { number = tonumber(row.number), label = row.label or '', by = row.opened_by or '', at = tonumber(row.opened_at) or 0 }
    end
    return true, { station = place.name, max = (Config.Evidence or {}).lockers or 9999, shared = (Config.Evidence or {}).shared == true, lockers = lockers }
end)

lib.callback.register('XS-PoliceSystem:server:evidenceOpen', function(src, placeId, pointId, number, label)
    local place, p = evidenceAt(src, placeId, pointId)
    if not place then return false, p end
    local E = Config.Evidence or {}
    local max = E.lockers or 9999
    number = math.floor(tonumber(number) or 0)
    if number < 1 or number > max then return false, Text('err_locker_number', { max = max }) end
    local scope = evidenceScope(place)
    MySQL.query.await('INSERT INTO `xs_police_evidence` (`scope`, `number`, `label`, `opened_by`, `opened_at`) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `opened_by` = VALUES(`opened_by`), `opened_at` = VALUES(`opened_at`)', {
        scope, number, Util.Text(label, 96), Util.Text(Framework.GetName(src) or '', 96), os.time(),
    })
    local id = E.shared and ('xspolice_evidence_%d'):format(number) or ('xspolice_evidence_%s_%d'):format(place.id, number)
    local title = Text(E.shared and 'evidence_locker_shared' or 'evidence_locker_label', { number = number, station = place.name })
    local slots, weight = E.slots or 50, E.weight or 250000
    local coords = not E.shared and vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0) or nil
    local mode = Inventory.OpenStash(src, id, title, slots, weight, Stations.Groups(place, (Config.Grades or {}).evidence or 0), coords)
    return true, { mode = mode, id = id, label = title, slots = slots, weight = weight }
end)

local function armoryFor(place, job)
    local out = {}
    for _, e in ipairs(place.armory or {}) do
        if job.isBoss or (job.grade or 0) >= e.grade then
            out[#out + 1] = { item = e.item, label = Inventory.Label(e.item), image = Inventory.Image(e.item), price = e.price, amount = e.amount, grade = e.grade }
        end
    end
    return out
end

lib.callback.register('XS-PoliceSystem:server:armory', function(src, placeId, pointId)
    local place = at(src, placeId, 'armory', pointId)
    if not place then return false, Text('err_too_far') end
    local job, err = staff(src, place)
    if not job then return false, err end
    return true, { station = place.name, items = armoryFor(place, job), society = Config.Armory.payFromSociety }
end)

lib.callback.register('XS-PoliceSystem:server:armoryTake', function(src, placeId, pointId, item, qty)
    local place = at(src, placeId, 'armory', pointId)
    if not place then return false, Text('err_too_far') end
    local job, err = staff(src, place)
    if not job then return false, err end
    local entry
    for _, e in ipairs(armoryFor(place, job)) do
        if e.item == item then entry = e break end
    end
    if not entry then return false, Text('err_not_in_armory') end
    qty = Util.Clamp(math.floor(tonumber(qty) or 1), 1, 10)
    local now = GetGameTimer()
    if Stations.armoryAt[src] and now - Stations.armoryAt[src] < 1500 then return false, Text('err_slow_down') end
    Stations.armoryAt[src] = now
    local count = entry.amount * qty
    if not Inventory.CanCarry(src, entry.item, count) then return false, Text('err_cannot_carry') end
    local cost = entry.price * qty
    if cost > 0 then
        local paid = false
        if Config.Armory.payFromSociety then
            paid = Banking.Withdraw(Stations.Society(job), cost, 'Armory: ' .. entry.label)
        end
        if not paid and not Framework.Charge(src, cost, 'bank', 'Police armory') then return false, Text('err_no_money') end
    end
    if not Inventory.Add(src, entry.item, count) then return false, Text('err_cannot_carry') end
    Db.Log('armory', { citizenid = Framework.GetCitizenId(src), name = Framework.GetName(src) or '' }, count, entry.item, { citizenid = Framework.GetCitizenId(src), name = Framework.GetName(src) or '', job = job.name })
    return true, Text('armory_taken', { count = count, item = entry.label })
end)

local function fleet(place, kind, job)
    local out = {}
    for _, v in ipairs(kind == 'helipad' and place.helicopters or place.vehicles or {}) do
        if job.isBoss or (job.grade or 0) >= v.grade then out[#out + 1] = v end
    end
    return out
end

lib.callback.register('XS-PoliceSystem:server:garage', function(src, placeId, pointId, kind)
    kind = kind == 'helipad' and 'helipad' or 'garage'
    local place = at(src, placeId, kind, pointId)
    if not place then return false, Text('err_too_far') end
    local job, err = staff(src, place)
    if not job then return false, err end
    if kind == 'helipad' and not canDo(job, 'helipad') then return false, Text('err_grade') end
    return true, { station = place.name, vehicles = fleet(place, kind, job) }
end)

local function plateFor(place)
    local prefix = place.plate or 'LSPD'
    for _ = 1, 20 do
        local text = ('%s%s'):format(prefix, math.random(1000, 9999)):sub(1, 8)
        local taken = false
        for _, entry in pairs(Stations.vehicles) do
            if entry.plate == text then taken = true break end
        end
        if not taken then return text end
    end
    return ('%s%s'):format(prefix, math.random(1000, 9999)):sub(1, 8)
end

local function clearVehiclesOf(src)
    for netId, entry in pairs(Stations.vehicles) do
        if entry.owner == src then
            local old = NetworkGetEntityFromNetworkId(netId)
            if old ~= 0 and DoesEntityExist(old) then DeleteEntity(old) end
            Stations.vehicles[netId] = nil
        end
    end
end

lib.callback.register('XS-PoliceSystem:server:spawnVehicle', function(src, placeId, pointId, kind, model, vehicleType)
    kind = kind == 'helipad' and 'helipad' or 'garage'
    local place, p = at(src, placeId, kind, pointId, 4.0)
    if not place then return false, Text('err_too_far') end
    local job, err = staff(src, place)
    if not job then return false, err end
    if kind == 'helipad' and not canDo(job, 'helipad') then return false, Text('err_grade') end
    local entry
    for _, v in ipairs(fleet(place, kind, job)) do
        if v.model == model then entry = v break end
    end
    if not entry then return false, Text('err_vehicle_not_here') end
    vehicleType = VEHICLE_TYPES[vehicleType] and vehicleType or (kind == 'helipad' and 'heli' or 'automobile')

    clearVehiclesOf(src)

    local spawn = p.spawn or p
    local hash = joaat(entry.model)
    local vehicle = 0
    local z = spawn.z + 1.0
    pcall(function() vehicle = CreateVehicleServerSetter(hash, vehicleType, spawn.x + 0.0, spawn.y + 0.0, z + 0.0, (spawn.w or 0.0) + 0.0) end)
    if not vehicle or vehicle == 0 then
        pcall(function() vehicle = CreateVehicle(hash, spawn.x + 0.0, spawn.y + 0.0, z + 0.0, (spawn.w or 0.0) + 0.0, true, true) end)
    end
    local waited = 0
    while (not vehicle or vehicle == 0 or not DoesEntityExist(vehicle)) and waited < 3000 do
        Wait(50)
        waited = waited + 50
    end
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false, Text('err_spawn_failed') end

    local text = plateFor(place)
    SetVehicleNumberPlateText(vehicle, text)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    Stations.vehicles[netId] = { owner = src, place = place.id, model = entry.model, plate = text }
    Entity(vehicle).state:set('xspVehicle', true, true)
    Entity(vehicle).state:set('fuel', Config.Garage.fuel or 100.0, true)
    SetTimeout(600, function()
        if DoesEntityExist(vehicle) then Keys.Give(src, vehicle, text) end
    end)
    return true, { netId = netId, livery = entry.livery, extras = entry.extras, plate = text }
end)

lib.callback.register('XS-PoliceSystem:server:storeVehicle', function(src, netId)
    local entry = Stations.vehicles[tonumber(netId) or -1]
    if not entry then return false, Text('err_not_station_vehicle') end
    local job = Framework.GetJob(src)
    if entry.owner ~= src and not Framework.IsCop(job) then return false, Text('err_police_only') end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local ped = GetPlayerPed(src)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        if #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > 15.0 then return false, Text('err_too_far') end
        DeleteEntity(vehicle)
    end
    Stations.vehicles[netId] = nil
    return true
end)

Framework.OnUnloaded(function(src)
    clearVehiclesOf(src)
    Stations.armoryAt[src] = nil
end)
