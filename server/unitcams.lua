UnitCams = { sessions = {} }

local MODES = { body = true, dash = true, cabin = true }

local function cfg()
    return Config.UnitCams or {}
end

local function coordsOf(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetEntityCoords(ped) or nil
end

local function officerOf(src, job)
    return { citizenid = Framework.GetCitizenId(src) or '', name = Framework.GetName(src) or '', job = job and job.name or '' }
end

local function atRoom(src, placeId, pointId)
    local place = Places.Get(placeId)
    if not place or place.kind ~= 'station' then return nil end
    local p = Places.Point(place, 'camroom', pointId)
    if not p or not Places.Near(src, p, 3.0) then return nil end
    return place
end

function UnitCams.Access(src, ctx)
    local C = cfg()
    if not C.enabled then return nil, Text('err_unitcams_off') end
    local job = Framework.GetJob(src)
    if not Framework.IsCop(job) then return nil, Text('err_police_only') end
    ctx = type(ctx) == 'table' and ctx or {}
    if ctx.place then
        local place = atRoom(src, ctx.place, ctx.point)
        if not place then return nil, Text('err_too_far') end
        if not Places.ServesJob(place, job) then return nil, Text('err_police_only') end
        if not job.isBoss and (job.grade or 0) < ((Config.Grades or {}).camRoom or 0) then return nil, Text('err_grade') end
        return job
    end
    if not C.remote then return nil, Text('err_unitcams_station') end
    if not job.isBoss and (job.grade or 0) < (C.remoteGrade or 3) then return nil, Text('err_grade') end
    return job
end

local function linkedCar(src)
    local best
    for netId, entry in pairs(Stations.vehicles or {}) do
        if entry.owner == src then
            local vehicle = NetworkGetEntityFromNetworkId(netId)
            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                if not best or netId > best.netId then best = { netId = netId, plate = entry.plate, model = entry.model } end
            end
        end
    end
    return best
end

local function drivenCar(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return nil end
    local plate = (GetVehicleNumberPlateText(vehicle) or ''):gsub('^%s+', ''):gsub('%s+$', '')
    return { netId = NetworkGetNetworkIdFromEntity(vehicle), plate = plate, any = true }
end

function UnitCams.DashOf(src)
    local C = cfg()
    if not C.dash then return nil end
    local car = linkedCar(src)
    if car then return car end
    if C.anyEmergencyVehicle then return drivenCar(src) end
    return nil
end

local function kindOf(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return 'foot' end
    return GetPedInVehicleSeat(vehicle, -1) == ped and 'driving' or 'riding'
end

function UnitCams.Units(viewer)
    local out = {}
    for _, src in ipairs(Framework.Cops(true)) do
        local ped = GetPlayerPed(src)
        if ped ~= 0 then
            local job = Framework.GetJob(src)
            local c = GetEntityCoords(ped)
            local dash = UnitCams.DashOf(src)
            out[#out + 1] = {
                src = src, name = Framework.GetName(src) or '', callsign = Units.Callsign(src) or '',
                rank = job and job.gradeLabel or '', dept = job and job.label or '',
                k = kindOf(ped), x = Util.Round(c.x, 1), y = Util.Round(c.y, 1), z = Util.Round(c.z, 1),
                dash = dash and { plate = dash.plate, any = dash.any == true } or nil,
                me = src == viewer or nil,
            }
        end
    end
    table.sort(out, function(a, b)
        if (a.me == true) ~= (b.me == true) then return b.me == true end
        if (a.callsign ~= '') ~= (b.callsign ~= '') then return a.callsign ~= '' end
        if a.callsign ~= b.callsign then return a.callsign < b.callsign end
        return a.name < b.name
    end)
    return out
end

local widened = {}

local function widen(src, at)
    local here = coordsOf(src)
    local radius = 800.0
    if here and at then radius = #(here - at) + 500.0 end
    radius = math.max(424.0, math.min(radius, 12000.0))
    SetPlayerCullingRadius(src, radius + 0.0)
    widened[src] = true
end

local function narrow(src)
    if not widened[src] then return end
    widened[src] = nil
    if GetPlayerName(src) then SetPlayerCullingRadius(src, 0.0) end
end

local function close(src, quiet)
    local s = UnitCams.sessions[src]
    UnitCams.sessions[src] = nil
    narrow(src)
    if not s then return end
    local seconds = os.time() - s.at
    if seconds >= 3 then
        Db.Log('unitcam', { citizenid = s.cid, name = s.name }, seconds, Text('unitcam_mode_' .. s.mode), s.officer)
    end
    if not quiet then TriggerClientEvent('XS-PoliceSystem:client:unitCamLost', src) end
end

local function targetAt(s)
    if s.mode ~= 'body' and s.netId then
        local vehicle = NetworkGetEntityFromNetworkId(s.netId)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then return GetEntityCoords(vehicle) end
        return nil
    end
    return coordsOf(s.target)
end

lib.callback.register('XS-PoliceSystem:server:unitCams', function(src, ctx)
    local job, err = UnitCams.Access(src, ctx)
    if not job then return false, err end
    return true, { units = UnitCams.Units(src), remote = not (type(ctx) == 'table' and ctx.place) }
end)

lib.callback.register('XS-PoliceSystem:server:unitCamWatch', function(src, ctx, target, mode)
    local job, err = UnitCams.Access(src, ctx)
    if not job then return false, err end
    local C = cfg()
    target = tonumber(target)
    mode = MODES[mode] and mode or 'body'
    if not target or not GetPlayerName(target) then return false, Text('err_unitcam_gone') end
    local them = Framework.GetJob(target)
    if not Framework.IsCop(them) then return false, Text('err_unitcam_gone') end
    if mode == 'body' and not C.body then return false, Text('err_unitcam_mode') end
    if mode == 'cabin' and not C.cabin then return false, Text('err_unitcam_mode') end
    local car
    if mode ~= 'body' then
        car = UnitCams.DashOf(target)
        if not car then return false, Text('err_unitcam_nodash') end
    end
    local previous = UnitCams.sessions[src]
    if previous and (previous.target ~= target or previous.mode ~= mode) then close(src, true) end
    local s = {
        target = target, mode = mode, netId = car and car.netId or nil, at = os.time(),
        cid = Framework.GetCitizenId(target) or '', name = Framework.GetName(target) or '', officer = officerOf(src, job),
    }
    UnitCams.sessions[src] = s
    local at = targetAt(s) or coordsOf(target)
    widen(src, at)
    return true, {
        target = target, mode = mode, netId = s.netId, plate = car and car.plate or nil, any = car and car.any or nil,
        coords = at and { x = at.x, y = at.y, z = at.z } or nil,
        name = s.name, callsign = Units.Callsign(target) or '', rank = them.gradeLabel or '', dept = them.label or ''
    }
end)

lib.callback.register('XS-PoliceSystem:server:unitCamStop', function(src)
    close(src, true)
    return true
end)

CreateThread(function()
    while true do
        Wait(4000)
        for watcher, s in pairs(UnitCams.sessions) do
            if not GetPlayerName(watcher) then
                UnitCams.sessions[watcher] = nil
                widened[watcher] = nil
            elseif not GetPlayerName(s.target) or not Framework.IsCop(Framework.GetJob(s.target)) then
                close(watcher)
            else
                local at = targetAt(s)
                if at then widen(watcher, at) elseif s.mode ~= 'body' then close(watcher) end
            end
        end
    end
end)

Framework.OnUnloaded(function(src)
    close(src, true)
    for watcher, s in pairs(UnitCams.sessions) do
        if s.target == src then close(watcher) end
    end
end)

exports('IsWatchingUnitCam', function(src) return UnitCams.sessions[tonumber(src) or -1] ~= nil end)
