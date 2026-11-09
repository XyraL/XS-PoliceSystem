Props = { owned = {}, panicAt = {} }

local function officer(src)
    local job = Framework.GetJob(src)
    if not Framework.IsCop(job) then return nil end
    return job
end

local function track(src, entity, kind)
    Props.owned[src] = Props.owned[src] or {}
    local list = Props.owned[src]
    list[#list + 1] = { entity = entity, kind = kind, at = os.time() }
end

local function count(src, kind)
    local n = 0
    for _, e in ipairs(Props.owned[src] or {}) do
        if DoesEntityExist(e.entity) and (not kind or e.kind == kind) then n = n + 1 end
    end
    return n
end

local function remove(src, entity)
    local list = Props.owned[src] or {}
    for i = #list, 1, -1 do
        if list[i].entity == entity then table.remove(list, i) end
    end
    if DoesEntityExist(entity) then DeleteEntity(entity) end
end

local function create(model, p)
    local hash = joaat(model)
    local entity = CreateObjectNoOffset(hash, p.x + 0.0, p.y + 0.0, p.z + 0.0, true, true, false)
    local waited = 0
    while (not entity or entity == 0 or not DoesEntityExist(entity)) and waited < 2000 do
        Wait(50)
        waited = waited + 50
    end
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    SetEntityHeading(entity, (p.w or 0.0) + 0.0)
    FreezeEntityPosition(entity, true)
    return entity
end

lib.callback.register('XS-PoliceSystem:server:placeProp', function(src, kind, p)
    if not officer(src) then return false, Text('err_police_only') end
    if not WheelLayout.Allowed(src, kind) then return false, Text('err_not_allowed') end
    if type(p) ~= 'table' or not tonumber(p.x) then return false, Text('err_failed') end
    local at = Places.Coords(src)
    if not at or #(at - vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0)) > 12.0 then return false, Text('err_too_far') end
    local model
    if kind == 'spikes' then
        if Config.Wheel.actions.spikes == false then return false, Text('err_failed') end
        if Config.Spikes.item and Config.Spikes.item ~= '' and not Inventory.Has(src, Config.Spikes.item, 1) then
            return false, Text('err_need_item', { item = Inventory.Label(Config.Spikes.item) })
        end
        if count(src, 'spikes') >= (Config.Spikes.max or 2) then return false, Text('err_prop_limit') end
        model = Config.Spikes.model
    else
        local def = (Config.Props.list or {})[kind]
        if not def or Config.Wheel.actions[kind] == false then return false, Text('err_failed') end
        if count(src) >= (Config.Props.max or 12) then return false, Text('err_prop_limit') end
        model = def.model
    end
    local entity = create(model, p)
    if not entity then return false, Text('err_failed') end
    track(src, entity, kind)
    if kind == 'spikes' then
        Entity(entity).state:set('xspSpikes', true, true)
        local seconds = Config.Spikes.seconds or 120
        SetTimeout(seconds * 1000, function()
            if DoesEntityExist(entity) then remove(src, entity) end
        end)
    end
    return true, NetworkGetNetworkIdFromEntity(entity)
end)

lib.callback.register('XS-PoliceSystem:server:removeProp', function(src, netId)
    if not officer(src) then return false, Text('err_police_only') end
    if not WheelLayout.Allowed(src, 'removeProp') then return false, Text('err_not_allowed') end
    local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if entity == 0 or not DoesEntityExist(entity) then return false, Text('err_no_prop') end
    local at = Places.Coords(src)
    if not at or #(at - GetEntityCoords(entity)) > 6.0 then return false, Text('err_too_far') end
    for owner, list in pairs(Props.owned) do
        for _, e in ipairs(list) do
            if e.entity == entity then
                remove(owner, entity)
                return true, Text('prop_removed')
            end
        end
    end
    return false, Text('err_no_prop')
end)

lib.callback.register('XS-PoliceSystem:server:panic', function(src)
    local job = officer(src)
    if not job then return false, Text('err_police_only') end
    if not WheelLayout.Allowed(src, 'panic') then return false, Text('err_not_allowed') end
    local now = os.time()
    if Props.panicAt[src] and now - Props.panicAt[src] < (Config.Panic.cooldownSeconds or 30) then return false, Text('err_slow_down') end
    Props.panicAt[src] = now
    local c = Places.Coords(src) or vector3(0.0, 0.0, 0.0)
    local name = Units.Label(src)
    for _, cop in ipairs(Framework.Cops(true)) do
        Framework.Notify(cop, Text('panic_alert', { name = name }), 'error')
        TriggerClientEvent('XS-PoliceSystem:client:alertBlip', cop, { x = c.x, y = c.y, z = c.z }, Text('panic_blip', { name = name }), 'panic')
    end
    Dispatch.Forward({ type = 'officer_backup', code = '10-99', title = Text('panic_blip', { name = name }), description = Text('panic_alert', { name = name }), coords = c, caller = name })
    TriggerEvent('XS-PoliceSystem:server:panic', src, c)
    return true
end)

Framework.OnUnloaded(function(src)
    for _, e in ipairs(Props.owned[src] or {}) do
        if DoesEntityExist(e.entity) then DeleteEntity(e.entity) end
    end
    Props.owned[src] = nil
    Props.panicAt[src] = nil
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, list in pairs(Props.owned) do
        for _, e in ipairs(list) do
            if DoesEntityExist(e.entity) then DeleteEntity(e.entity) end
        end
    end
end)
