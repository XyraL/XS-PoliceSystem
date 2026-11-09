Service = { list = {}, begin = {} }

local function cfg()
    return Config.Service or {}
end

local function spots(place)
    return place and place.points.task or {}
end

local function centroid(place)
    local list = spots(place)
    if #list == 0 then return nil end
    local x, y, z = 0.0, 0.0, 0.0
    for _, p in ipairs(list) do x, y, z = x + p.x, y + p.y, z + p.z end
    return vector3(x / #list, y / #list, z / #list)
end

local function outside(place, at)
    local list = spots(place)
    if #list == 0 then return false end
    local radius = cfg().radius or 60.0
    for _, p in ipairs(list) do
        if #(at - vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0)) <= radius then return false end
    end
    return true
end

local function pick(near)
    local best, bestDist
    for _, place in ipairs(Places.List('service')) do
        local c = centroid(place)
        if c then
            local d = near and #(near - c) or 0
            if not best or d < bestDist then best, bestDist = place, d end
        end
    end
    return best
end

local function persist(entry)
    MySQL.query('INSERT INTO `xs_police_service` (`citizenid`, `place_id`, `tasks`, `reason`, `officer`) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `place_id` = VALUES(`place_id`), `tasks` = VALUES(`tasks`), `reason` = VALUES(`reason`), `officer` = VALUES(`officer`)',
        { entry.cid, entry.placeId, entry.left, entry.reason or '', entry.officer or '' })
end

local function state(entry, place)
    local out = {}
    for _, p in ipairs(spots(place)) do out[#out + 1] = { id = p.id, x = p.x, y = p.y, z = p.z } end
    return { left = entry.left, reason = entry.reason or '', place = place.name, spots = out, seconds = cfg().seconds or 8 }
end

local function sendTo(src, entry, place)
    local list = spots(place)
    local spot = list[math.random(1, #list)]
    local ped = GetPlayerPed(src)
    if spot and ped ~= 0 then SetEntityCoords(ped, spot.x + 0.0, spot.y + 0.0, spot.z + 0.0, false, false, false, false) end
    TriggerClientEvent('XS-PoliceSystem:client:service', src, state(entry, place))
end

function Service.Is(src)
    return Service.list[tonumber(src) or -1] ~= nil
end

function Service.Send(target, tasks, reason, officer)
    if Jail.IsInmate(target) then return false, Text('err_in_jail_already') end
    local c = cfg()
    tasks = math.floor(tonumber(tasks) or 0)
    if tasks < 1 or tasks > (c.maxTasks or 50) then return false, Text('err_tasks', { max = c.maxTasks or 50 }) end
    local place = pick(Places.Coords(target))
    if not place then return false, Text('err_no_service') end
    local cid = Framework.GetCitizenId(target)
    if not cid then return false, Text('err_no_player') end
    local existing = Service.list[target]
    local entry = {
        cid = cid, placeId = place.id, left = (existing and existing.left or 0) + tasks,
        reason = Util.Text(reason, 120), officer = officer and officer.name or '',
    }
    Service.list[target] = entry
    persist(entry)
    if Field.IsCuffed(target) then Field.SetCuffed(target, false) end
    if Field.escorts[target] then Field.StopEscort(target) end
    sendTo(target, entry, place)
    Framework.Notify(target, Text('service_you', { tasks = entry.left }), 'error')
    Db.Log('service', { citizenid = cid, name = Framework.GetName(target) or '' }, tasks, entry.reason, officer)
    TriggerEvent('XS-PoliceSystem:server:service', target, tasks, entry.reason, officer and officer.src)
    return true, Text('service_sent', { tasks = tasks })
end

function Service.Finish(src)
    local entry = Service.list[src]
    if not entry then return end
    Service.list[src], Service.begin[src] = nil, nil
    MySQL.query('DELETE FROM `xs_police_service` WHERE `citizenid` = ?', { entry.cid })
    TriggerClientEvent('XS-PoliceSystem:client:serviceDone', src)
    Framework.Notify(src, Text('service_done'), 'success')
end

function Service.Load(src)
    local cid = Framework.GetCitizenId(src)
    if not cid then return end
    local row = MySQL.single.await('SELECT `place_id`, `tasks`, `reason`, `officer` FROM `xs_police_service` WHERE `citizenid` = ?', { cid })
    if not row or (tonumber(row.tasks) or 0) <= 0 then return end
    local place = Places.Get(tonumber(row.place_id)) or pick(Places.Coords(src))
    if not place then return end
    local entry = { cid = cid, placeId = place.id, left = tonumber(row.tasks), reason = row.reason or '', officer = row.officer or '' }
    Service.list[src] = entry
    sendTo(src, entry, place)
end

local function spotOf(src, spotId)
    local entry = Service.list[src]
    if not entry then return nil end
    local place = Places.Get(entry.placeId)
    local spot = place and Places.Point(place, 'task', spotId)
    if not spot or not Places.Near(src, spot, 2.5) then return nil end
    return entry, place, spot
end

lib.callback.register('XS-PoliceSystem:server:serviceBegin', function(src, spotId)
    local entry, _, spot = spotOf(src, spotId)
    if not entry then return false, Text('err_too_far') end
    if entry.lastSpot == spot.id and #spots(Places.Get(entry.placeId)) > 1 then return false, Text('service_other_spot') end
    Service.begin[src] = { spot = spot.id, at = os.time() }
    return true, cfg().seconds or 8
end)

lib.callback.register('XS-PoliceSystem:server:serviceTask', function(src, spotId)
    local entry, place, spot = spotOf(src, spotId)
    if not entry then return false, Text('err_too_far') end
    local b = Service.begin[src]
    if not b or b.spot ~= spot.id or os.time() - b.at < (cfg().seconds or 8) - 1 then return false, Text('err_slow_down') end
    Service.begin[src] = nil
    entry.left = entry.left - 1
    entry.lastSpot = spot.id
    if entry.left <= 0 then
        Service.Finish(src)
        return true, { done = true }
    end
    persist(entry)
    return true, { left = entry.left, state = state(entry, place) }
end)

CreateThread(function()
    while true do
        Wait(5000)
        for src, entry in pairs(Service.list) do
            if not GetPlayerName(src) then
                Service.list[src] = nil
            else
                local place = Places.Get(entry.placeId)
                local at = Places.Coords(src)
                if place and at and outside(place, at) then
                    entry.left = entry.left + (cfg().penalty or 2)
                    persist(entry)
                    sendTo(src, entry, place)
                    Framework.Notify(src, Text('service_left_area', { tasks = cfg().penalty or 2 }), 'error')
                end
            end
        end
    end
end)

Framework.OnLoaded(function(src)
    SetTimeout(3000, function() Service.Load(src) end)
end)

Framework.OnUnloaded(function(src)
    Service.list[src], Service.begin[src] = nil, nil
end)

AddEventHandler('playerDropped', function()
    Service.list[source], Service.begin[source] = nil, nil
end)

exports('SendToService', function(src, tasks, reason) return Service.Send(tonumber(src), tasks, reason, nil) end)
exports('InService', function(src) return Service.Is(src) end)
