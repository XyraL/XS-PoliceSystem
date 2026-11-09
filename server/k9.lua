K9 = { sniffAt = {}, trackAt = {}, dogs = {} }

local function handler(src)
    local c = Config.K9 or {}
    if not c.enabled then return nil, Text('err_failed') end
    local job = Framework.GetJob(src)
    if not Framework.IsCop(job) then return nil, Text('err_police_only') end
    if #(c.jobs or {}) > 0 then
        local listed = false
        for _, name in ipairs(c.jobs) do if name == job.name then listed = true end end
        if not listed then return nil, Text('err_not_allowed') end
    end
    if not job.isBoss and (job.grade or 0) < (c.grade or 0) then return nil, Text('err_grade') end
    return job
end

local function finds(names)
    local hits = {}
    for _, name in ipairs(names) do
        local lower = tostring(name):lower()
        for _, word in ipairs((Config.K9 or {}).find or {}) do
            if lower:find(word, 1, true) then hits[#hits + 1] = name break end
        end
    end
    return hits
end

lib.callback.register('XS-PoliceSystem:server:k9', function(src, netId)
    local job, err = handler(src)
    if not job then return false, err end
    K9.dogs[src] = tonumber(netId)
    return true
end)

lib.callback.register('XS-PoliceSystem:server:k9Sniff', function(src, kind, target)
    local job, err = handler(src)
    if not job then return false, err end
    if not WheelLayout.Allowed(src, 'k9Search') then return false, Text('err_not_allowed') end
    local now = GetGameTimer()
    if K9.sniffAt[src] and now - K9.sniffAt[src] < 4000 then return false, Text('err_slow_down') end
    K9.sniffAt[src] = now
    local me = Places.Coords(src)
    local names = {}
    if kind == 'vehicle' then
        local vehicle = NetworkGetEntityFromNetworkId(tonumber(target) or 0)
        if vehicle == 0 or not DoesEntityExist(vehicle) then return false, Text('err_no_vehicle') end
        if not me or #(me - GetEntityCoords(vehicle)) > 15.0 then return false, Text('err_too_far') end
        names = Inventory.VehicleItems(GetVehicleNumberPlateText(vehicle))
        for seat = -1, 6 do
            local ped = GetPedInVehicleSeat(vehicle, seat)
            if ped and ped ~= 0 then
                for _, other in ipairs(Framework.Players()) do
                    if GetPlayerPed(other) == ped then
                        for _, item in ipairs(Inventory.Snapshot(other)) do names[#names + 1] = item.name end
                    end
                end
            end
        end
    else
        target = tonumber(target)
        if not target or not GetPlayerName(target) or target == src then return false, Text('err_no_player') end
        local them = Places.Coords(target)
        if not me or not them or #(me - them) > 15.0 then return false, Text('err_too_far') end
        for _, item in ipairs(Inventory.Snapshot(target)) do names[#names + 1] = item.name end
    end
    local hits = finds(names)
    Db.Log('k9', nil, #hits, (kind == 'vehicle' and 'Vehicle' or 'Person') .. (#hits > 0 and ' alerted' or ' clear'),
        { citizenid = Framework.GetCitizenId(src), name = Framework.GetName(src) or '', job = job.name })
    return true, #hits > 0
end)

lib.callback.register('XS-PoliceSystem:server:k9Track', function(src)
    local job, err = handler(src)
    if not job then return false, err end
    if not WheelLayout.Allowed(src, 'k9Track') then return false, Text('err_not_allowed') end
    local now = GetGameTimer()
    if K9.trackAt[src] and now - K9.trackAt[src] < 10000 then return false, Text('err_slow_down') end
    K9.trackAt[src] = now
    local me = Places.Coords(src)
    if not me then return false, Text('err_failed') end
    local radius = tonumber((Config.K9 or {}).trackRadius) or 60.0
    local best, bestAt, bestDist
    for _, other in ipairs(Framework.Players()) do
        if other ~= src and not Framework.IsCop(Framework.GetJob(other), true) then
            local them = Places.Coords(other)
            local d = them and #(me - them)
            if d and d <= radius and (not bestDist or d < bestDist) then best, bestAt, bestDist = other, them, d end
        end
    end
    Db.Log('k9', nil, best and 1 or 0, best and 'Tracked someone' or 'No trail',
        { citizenid = Framework.GetCitizenId(src), name = Framework.GetName(src) or '', job = job.name })
    if not best then return true, false end
    return true, { target = best, x = bestAt.x, y = bestAt.y, z = bestAt.z }
end)

AddEventHandler('playerDropped', function()
    local src = source
    K9.sniffAt[src], K9.trackAt[src] = nil, nil
    local netId = K9.dogs[src]
    K9.dogs[src] = nil
    local dog = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if dog ~= 0 and DoesEntityExist(dog) then DeleteEntity(dog) end
end)
