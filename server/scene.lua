Scene = { zones = {}, nextZone = 0, down = {} }

local function officer(src)
    local job = Framework.GetJob(src)
    return Framework.IsCop(job) and job or nil
end

lib.callback.register('XS-PoliceSystem:server:searchVehicle', function(src, netId, glovebox)
    if not officer(src) then return false, Text('err_police_only') end
    if not WheelLayout.Allowed(src, 'searchVehicle') then return false, Text('err_not_allowed') end
    if Field.IsCuffed(src) or Field.IsDown(src) then return false, Text('err_cannot_now') end
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false, Text('err_no_vehicle') end
    local me = Places.Coords(src)
    if not me or #(me - GetEntityCoords(vehicle)) > 7.0 then return false, Text('err_too_far') end
    local kind = glovebox and 'glovebox' or 'trunk'
    if not Inventory.OpenVehicle(src, vehicle, kind) then return false, Text('err_failed') end
    Db.Log('vsearch', nil, 0, ('%s searched (%s)'):format(Plates.Norm(GetVehicleNumberPlateText(vehicle)), kind),
        { citizenid = Framework.GetCitizenId(src), name = Framework.GetName(src) or '', job = officer(src).name })
    return true
end)

local function zoneView(z)
    return { id = z.id, kind = z.kind, x = z.x, y = z.y, z = z.z, radius = z.radius, speed = z.speed }
end

function Scene.Zones()
    local out = {}
    for _, z in pairs(Scene.zones) do out[#out + 1] = zoneView(z) end
    return out
end

local function removeZone(id)
    if not Scene.zones[id] then return end
    Scene.zones[id] = nil
    TriggerClientEvent('XS-PoliceSystem:client:traffic', -1, 'remove', id)
end

lib.callback.register('XS-PoliceSystem:server:traffic', function(src, kind)
    if kind ~= 'slow' and kind ~= 'stop' then return false end
    if not officer(src) then return false, Text('err_police_only') end
    if not WheelLayout.Allowed(src, kind == 'slow' and 'slowTraffic' or 'stopTraffic') then return false, Text('err_not_allowed') end
    local c = Places.Coords(src)
    if not c then return false end
    local cfg = Config.Traffic or {}
    local mine = 0
    for id, z in pairs(Scene.zones) do
        if z.owner == src then
            mine = mine + 1
            if z.kind == kind and #(vector3(z.x, z.y, z.z) - c) < (cfg.radius or 40.0) then
                removeZone(id)
                return true, Text('traffic_cleared')
            end
        end
    end
    if mine >= (cfg.perOfficer or 3) then return false, Text('err_traffic_max') end
    Scene.nextZone = Scene.nextZone + 1
    local z = {
        id = Scene.nextZone, owner = src, kind = kind, x = c.x, y = c.y, z = c.z, at = os.time(),
        radius = cfg.radius or 40.0, speed = kind == 'stop' and 0.0 or (cfg.slowSpeed or 5.0),
    }
    Scene.zones[z.id] = z
    TriggerClientEvent('XS-PoliceSystem:client:traffic', -1, 'add', zoneView(z))
    return true, Text(kind == 'stop' and 'traffic_stopped' or 'traffic_slowed')
end)

lib.callback.register('XS-PoliceSystem:server:trafficZones', function()
    return Scene.Zones()
end)

local function officerDown(src)
    local label = Units.Label(src)
    local c = Places.Coords(src)
    if not c then return end
    for _, cop in ipairs(Framework.Cops(true)) do
        if cop ~= src then
            Framework.Notify(cop, Text('officer_down', { name = label }), 'error')
            TriggerClientEvent('XS-PoliceSystem:client:alertBlip', cop, { x = c.x, y = c.y, z = c.z }, Text('officer_down_blip', { name = label }), 'panic')
        end
    end
    Dispatch.Forward({ type = 'officer_down', code = '10-99', title = Text('officer_down_blip', { name = label }), description = Text('officer_down', { name = label }), coords = c, caller = label })
    TriggerEvent('XS-PoliceSystem:server:officerDown', src, c)
end

function Scene.CheckDown()
    if (Config.OfficerDown or {}).enabled == false then return end
    local seen = {}
    for _, cop in ipairs(Framework.Cops(true)) do
        seen[cop] = true
        local isDown = Field.IsDown(cop)
        if isDown and not Scene.down[cop] then
            Scene.down[cop] = true
            officerDown(cop)
        elseif not isDown then
            Scene.down[cop] = nil
        end
    end
    for src in pairs(Scene.down) do
        if not seen[src] then Scene.down[src] = nil end
    end
end

CreateThread(function()
    while true do
        Wait(2000)
        Scene.CheckDown()
        local limit = ((Config.Traffic or {}).minutes or 20) * 60
        local now = os.time()
        for id, z in pairs(Scene.zones) do
            if now - z.at > limit or not GetPlayerName(z.owner) then removeZone(id) end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Scene.down[src] = nil
    for id, z in pairs(Scene.zones) do
        if z.owner == src then removeZone(id) end
    end
end)
