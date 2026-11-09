Impound = { releasing = {} }

local VEHICLE_TYPES = { automobile = true, bike = true, boat = true, heli = true, plane = true, submarine = true, trailer = true, train = true }

local function trim(plate)
    return (tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function grade(key)
    return (Config.Grades or {})[key] or 0
end

local function canDo(job, key)
    return job and (job.isBoss or (job.grade or 0) >= grade(key))
end

local function lotOf(id)
    local place = Places.Get(id)
    if place and place.kind == 'impound' then return place end
    return nil
end

local function ownerName(cid)
    local player = Framework.GetPlayerByCitizenId(cid)
    if player then return Framework.FullName(player.PlayerData.charinfo) end
    local row = MySQL.single.await('SELECT `charinfo` FROM `players` WHERE `citizenid` = ?', { cid })
    return row and Framework.FullName(Db.Decode(row.charinfo, {})) or ''
end

local function running(name)
    local state = GetResourceState(name)
    return state == 'started' or state == 'starting'
end

function Impound.HeldState()
    local forced = tonumber((Config.Impound or {}).heldState)
    if forced then return math.floor(forced) end
    return running('qbx_garages') and 3 or 2
end

function Impound.MarkHeld(plate)
    pcall(MySQL.update.await, ('UPDATE `player_vehicles` SET `state` = %d, `depotprice` = 0 WHERE `plate` = ?'):format(Impound.HeldState()), { plate })
end

function Impound.MarkDepot(plate, fee)
    local state = running('qbx_garages') and 2 or 0
    pcall(MySQL.update.await, ('UPDATE `player_vehicles` SET `state` = %d, `depotprice` = ? WHERE `plate` = ?'):format(state), { fee, plate })
end

function Impound.MarkOut(plate, vehicle)
    pcall(MySQL.update.await, 'UPDATE `player_vehicles` SET `state` = 0, `depotprice` = 0 WHERE `plate` = ?', { plate })
    if vehicle and running('qb-garages') then
        pcall(TriggerEvent, 'qb-garages:server:UpdateOutsideVehicle', plate, NetworkGetNetworkIdFromEntity(vehicle))
    end
end

local labels

local function modelLabel(model)
    if not labels then
        labels = {}
        for _, v in ipairs(Framework.Vehicles()) do labels[tostring(v.model):lower()] = v.label end
    end
    return labels[tostring(model or ''):lower()] or model or ''
end

local function record(row, now)
    local left = math.max(0, (tonumber(row.hold_until) or 0) - now)
    return {
        id = tonumber(row.id), plate = row.plate, model = row.model, label = modelLabel(row.model), owner = row.owner_name, lot = tonumber(row.lot_id),
        lotName = (lotOf(row.lot_id) or {}).name or '', fee = tonumber(row.fee) or 0, reason = row.reason or '',
        officer = row.officer_name or '', at = tonumber(row.created_at) or 0, left = left,
        policeHold = Util.Truthy(row.police_hold), ready = left <= 0 and not Util.Truthy(row.police_hold),
    }
end

local function vehicleState(vehicle, reported)
    local fuel = tonumber(Entity(vehicle).state.fuel) or tonumber(reported and reported.fuel)
    return {
        fuel = fuel and Util.Clamp(Util.Round(fuel, 1), 0, 100) or nil,
        engine = Util.Round(GetVehicleEngineHealth(vehicle), 1),
        body = Util.Round(GetVehicleBodyHealth(vehicle), 1),
    }
end

lib.callback.register('XS-PoliceSystem:server:impound', function(src, netId, opts)
    local job = Framework.GetJob(src)
    if not Framework.IsCop(job) then return false, Text('err_police_only') end
    if not canDo(job, 'impound') then return false, Text('err_grade') end
    if not WheelLayout.Allowed(src, 'impound', job) then return false, Text('err_not_allowed') end
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false, Text('err_no_vehicle') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(vehicle)) > 8.0 then return false, Text('err_too_far') end
    if GetPedInVehicleSeat(vehicle, -1) ~= 0 then return false, Text('err_vehicle_occupied') end
    if Entity(vehicle).state.xspVehicle then return false, Text('err_police_vehicle') end

    opts = type(opts) == 'table' and opts or {}
    local I = Config.Impound or {}
    local raw = Util.Text(GetVehicleNumberPlateText(vehicle), 16)
    local plate = trim(raw)
    local officer = { citizenid = Framework.GetCitizenId(src), name = Framework.GetName(src) or '', job = job.name }
    local owned = MySQL.single.await('SELECT `citizenid`, `vehicle`, `plate` FROM `player_vehicles` WHERE `plate` = ? OR `plate` = ? LIMIT 1', { plate, raw })
    local lot = lotOf(opts.lot)
    if lot and lot.enabled == false then lot = nil end

    if not lot and #Places.List('impound') > 0 then return false, Text('err_pick_lot') end

    if not lot then
        local fee = math.floor(tonumber(I.fee) or 0)
        if owned then
            Impound.MarkDepot(owned.plate, fee)
            Db.Log('impound', { citizenid = owned.citizenid, name = '' }, fee, plate, officer)
        end
        DeleteEntity(vehicle)
        return true, Text('impounded', { plate = plate })
    end

    local hours = Util.Clamp(math.floor(tonumber(opts.hours) or 0), 0, I.maxHours or 168)
    local fee = Util.Clamp(math.floor(tonumber(opts.fee) or lot.fee or I.fee or 0), I.minFee or 0, I.maxFee or 25000)
    local reason = Util.Text(opts.reason, 160)
    if reason == '' then return false, Text('err_need_reason') end

    if owned then
        local now = os.time()
        local condition = vehicleState(vehicle, opts.condition)
        MySQL.update.await('UPDATE `xs_police_impound` SET `released` = 1 WHERE `plate` = ? AND `released` = 0', { owned.plate })
        local id = MySQL.insert.await('INSERT INTO `xs_police_impound` (`plate`, `citizenid`, `owner_name`, `model`, `lot_id`, `fee`, `reason`, `officer_name`, `job`, `hold_until`, `police_hold`, `condition`, `released`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)', {
            owned.plate, owned.citizenid, Util.Text(ownerName(owned.citizenid), 96), Util.Text(owned.vehicle, 64), lot.id, fee, reason,
            Util.Text(officer.name, 96), job.name, now + hours * 3600, opts.policeHold == true and 1 or 0, Db.Json(condition), now,
        })
        if not id then return false, Text('err_db') end
        Impound.MarkHeld(owned.plate)
        Db.Log('impound', { citizenid = owned.citizenid, name = '' }, fee, ('%s · %s · %dh'):format(plate, lot.name, hours), officer)
    end
    DeleteEntity(vehicle)
    return true, Text(owned and 'impounded_to' or 'impounded_local', { plate = plate, lot = lot.name })
end)

local function deskAt(src, placeId, pointId)
    local lot = lotOf(placeId)
    if not lot then return nil, Text('err_failed') end
    local p = Places.Point(lot, 'desk', pointId)
    if not p or not Places.Near(src, p, 4.0) then return nil, Text('err_too_far') end
    return lot, p
end

local function staffOf(src, lot)
    local job = Framework.GetJob(src)
    if not Framework.IsCop(job) or not Places.ServesJob(lot, job) then return nil end
    return job
end

lib.callback.register('XS-PoliceSystem:server:impoundDesk', function(src, placeId, pointId)
    local lot, err = deskAt(src, placeId, pointId)
    if not lot then return false, err end
    local cid = Framework.GetCitizenId(src)
    local now = os.time()
    local mine = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM `xs_police_impound` WHERE `citizenid` = ? AND `released` = 0 ORDER BY `created_at` DESC', { cid }) or {}) do
        mine[#mine + 1] = record(row, now)
    end
    local job = staffOf(src, lot)
    local all
    if job then
        all = {}
        for _, row in ipairs(MySQL.query.await('SELECT * FROM `xs_police_impound` WHERE `lot_id` = ? AND `released` = 0 ORDER BY `created_at` DESC LIMIT 200', { lot.id }) or {}) do
            all[#all + 1] = record(row, now)
        end
    end
    return true, { lot = lot.id, name = lot.name, mine = mine, all = all, canManage = job and canDo(job, 'impoundRelease') or false }
end)

local function freeBay(lot)
    local vehicles = GetAllVehicles()
    for _, p in ipairs(lot.points.lot or {}) do
        local spot = vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0)
        local free = true
        for _, v in ipairs(vehicles) do
            if DoesEntityExist(v) and #(GetEntityCoords(v) - spot) < 3.0 then free = false break end
        end
        if free then return p end
    end
    return nil
end

lib.callback.register('XS-PoliceSystem:server:impoundRelease', function(src, placeId, pointId, id, vehicleType)
    local lot, err = deskAt(src, placeId, pointId)
    if not lot then return false, err end
    id = tonumber(id)
    local cid = Framework.GetCitizenId(src)
    if not id or not cid then return false, Text('err_failed') end
    if Impound.releasing[id] then return false, Text('err_slow_down') end
    Impound.releasing[id] = true
    local ok, a, b = pcall(function()
        local row = MySQL.single.await('SELECT * FROM `xs_police_impound` WHERE `id` = ? AND `released` = 0', { id })
        if not row or row.citizenid ~= cid then return false, Text('err_not_your_vehicle') end
        if tonumber(row.lot_id) ~= lot.id then return false, Text('err_other_lot', { lot = (lotOf(row.lot_id) or {}).name or '?' }) end
        if Util.Truthy(row.police_hold) then return false, Text('err_police_hold') end
        local left = (tonumber(row.hold_until) or 0) - os.time()
        if left > 0 then return false, Text('err_hold_left', { time = Util.Span(left) }) end
        local owned = MySQL.single.await('SELECT `vehicle`, `hash`, `mods`, `fuel`, `engine`, `body` FROM `player_vehicles` WHERE `plate` = ? AND `citizenid` = ?', { row.plate, cid })
        if not owned then return false, Text('err_not_your_vehicle') end
        local bay = freeBay(lot)
        if not bay then return false, Text('err_lot_full') end
        local fee = tonumber(row.fee) or 0
        if fee > 0 then
            if not Framework.Charge(src, fee, 'bank', 'Impound release') then return false, Text('err_no_money') end
            if (Config.Impound or {}).society ~= false then Banking.Deposit(row.job ~= '' and row.job or 'police', fee, 'Impound release ' .. row.plate) end
        end
        local hash = tonumber(owned.hash) or joaat(owned.vehicle or row.model or '')
        vehicleType = VEHICLE_TYPES[vehicleType] and vehicleType or 'automobile'
        local vehicle = 0
        pcall(function() vehicle = CreateVehicleServerSetter(hash, vehicleType, bay.x + 0.0, bay.y + 0.0, bay.z + 0.5, (bay.w or 0.0) + 0.0) end)
        local waited = 0
        while (not vehicle or vehicle == 0 or not DoesEntityExist(vehicle)) and waited < 3000 do
            Wait(50)
            waited = waited + 50
        end
        if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
            if fee > 0 then Framework.AddMoney(src, 'bank', fee, 'Impound refund') end
            return false, Text('err_spawn_failed')
        end
        SetVehicleNumberPlateText(vehicle, row.plate)
        MySQL.update.await('UPDATE `xs_police_impound` SET `released` = 1 WHERE `id` = ?', { id })
        Impound.MarkOut(row.plate, vehicle)
        local condition = Db.Decode(row.condition, {})
        local fuel = tonumber(condition.fuel) or tonumber(owned.fuel) or 100.0
        Entity(vehicle).state:set('fuel', fuel, true)
        SetTimeout(600, function()
            if DoesEntityExist(vehicle) then Keys.Give(src, vehicle, row.plate) end
        end)
        Db.Log('impound_release', { citizenid = cid, name = Framework.GetName(src) or '' }, fee, row.plate, { citizenid = cid, name = Framework.GetName(src) or '', job = row.job or '' })
        return true, {
            netId = NetworkGetNetworkIdFromEntity(vehicle), plate = row.plate, mods = Db.Decode(owned.mods, {}),
            fuel = fuel, engine = tonumber(condition.engine) or tonumber(owned.engine), body = tonumber(condition.body) or tonumber(owned.body),
        }
    end)
    Impound.releasing[id] = nil
    if not ok then
        print(('^1[XS-PoliceSystem]^0 impound release failed: %s'):format(tostring(a)))
        return false, Text('err_failed')
    end
    return a, b
end)

lib.callback.register('XS-PoliceSystem:server:impoundManage', function(src, placeId, pointId, id, action)
    local lot, err = deskAt(src, placeId, pointId)
    if not lot then return false, err end
    local job = staffOf(src, lot)
    if not job then return false, Text('err_police_only') end
    if not canDo(job, 'impoundRelease') then return false, Text('err_grade') end
    id = tonumber(id)
    local row = id and MySQL.single.await('SELECT `id`, `plate`, `citizenid`, `lot_id` FROM `xs_police_impound` WHERE `id` = ? AND `released` = 0', { id })
    if not row or tonumber(row.lot_id) ~= lot.id then return false, Text('err_failed') end
    local officer = { citizenid = Framework.GetCitizenId(src), name = Framework.GetName(src) or '', job = job.name }
    if action == 'clear' then
        MySQL.update.await('UPDATE `xs_police_impound` SET `hold_until` = ?, `police_hold` = 0 WHERE `id` = ?', { os.time(), id })
        Db.Log('impound_clear', { citizenid = row.citizenid, name = '' }, 0, row.plate, officer)
        return true, Text('impound_cleared', { plate = row.plate })
    elseif action == 'waive' then
        MySQL.update.await('UPDATE `xs_police_impound` SET `fee` = 0 WHERE `id` = ?', { id })
        pcall(MySQL.update.await, 'UPDATE `player_vehicles` SET `depotprice` = 0 WHERE `plate` = ?', { row.plate })
        Db.Log('impound_waive', { citizenid = row.citizenid, name = '' }, 0, row.plate, officer)
        return true, Text('impound_waived', { plate = row.plate })
    end
    return false, Text('err_failed')
end)

exports('ImpoundedVehicles', function(cid)
    local now = os.time()
    local out = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM `xs_police_impound` WHERE `citizenid` = ? AND `released` = 0', { cid }) or {}) do
        out[#out + 1] = record(row, now)
    end
    return out
end)
