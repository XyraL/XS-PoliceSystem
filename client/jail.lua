JailClient = { state = nil, left = 0, working = false, spawned = false, queued = nil }

function JailClient.Inside()
    return JailClient.state ~= nil and not JailClient.state.escaped
end

local function female(ped)
    return GetEntityModel(ped) == `mp_f_freemode_01`
end

local function teleport(p)
    if type(p) ~= 'table' then return end
    DoScreenFadeOut(400)
    local until_ = GetGameTimer() + 2000
    while not IsScreenFadedOut() and GetGameTimer() < until_ do Wait(10) end
    local ped = PlayerPedId()
    RequestCollisionAtCoord(p.x + 0.0, p.y + 0.0, p.z + 0.0)
    SetEntityCoords(ped, p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false, false)
    SetEntityHeading(ped, (p.w or 0.0) + 0.0)
    local untilCollision = GetGameTimer() + 4000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < untilCollision do Wait(50) end
    Wait(300)
    DoScreenFadeIn(600)
end

local function jailOutfit(ped)
    local outfits = Config.Jail.outfits or {}
    return female(ped) and outfits.female or outfits.male
end

function JailClient.Stop()
    if lib.progressActive and lib.progressActive() then
        lib.cancelProgress()
        Wait(50)
    end
end

local function dressIn(state)
    if not Config.Jail.outfit then return end
    local ped = PlayerPedId()
    local outfit = jailOutfit(ped)
    if not state.look and not Clothing.Wears(ped, outfit) then
        if Me.Await('jailLook', Clothing.Snapshot(ped)) then state.look = true end
    end
    Clothing.Wear(ped, outfit)
end

local function apply(state, cell)
    JailClient.state = state
    JailClient.left = state.left or 0
    if Field.cuffed then Field.SetCuffed(false) end
    if Wheel and Wheel.open then Wheel.Close() end
    if cell then teleport(cell) end
    dressIn(state)
    UI.Send('jail', 'open', state)
    TriggerServerEvent('XS-PoliceSystem:server:jailReady')
end

RegisterNetEvent('XS-PoliceSystem:client:jailed', function(state, cell)
    if type(state) ~= 'table' then return end
    if JailClient.spawned then
        apply(state, cell)
    else
        JailClient.queued = { state = state, cell = cell }
    end
end)

RegisterNetEvent('XS-PoliceSystem:client:jailTime', function(left)
    if not JailClient.state then return end
    JailClient.left = tonumber(left) or JailClient.left
    UI.Send('jail', 'time', { left = JailClient.left })
end)

RegisterNetEvent('XS-PoliceSystem:client:escaped', function()
    if not JailClient.state then return end
    JailClient.state.escaped = true
    UI.Send('jail', 'escaped', {})
    SetTimeout(8000, function()
        if JailClient.state and JailClient.state.escaped then UI.Send('jail', 'close', {}) end
    end)
end)

RegisterNetEvent('XS-PoliceSystem:client:escapedState', function(state)
    if type(state) ~= 'table' then return end
    state.escaped = true
    JailClient.state = state
end)

RegisterNetEvent('XS-PoliceSystem:client:pendingBelongings', function()
    Framework.Notify(Text('released_pending'), 'inform')
end)

RegisterNetEvent('XS-PoliceSystem:client:released', function(spot, look, pending, reason)
    JailClient.state = nil
    UI.Send('jail', 'close', {})
    JailClient.Stop()
    teleport(spot)
    local ped = PlayerPedId()
    if look then Clothing.Restore(ped, look) end
    if Config.Jail.outfit and (not look or Clothing.Wears(ped, jailOutfit(ped))) then Clothing.ReloadSaved() end
    if reason == 'test' then
        Framework.Notify(Text(pending and 'released_pending' or 'jailtest_over'), 'success')
    else
        Framework.Notify(Text(pending and 'released_pending' or 'released'), 'success')
    end
end)

JailClient.doneAt = {}
JailClient.next = nil

local function perform(def, seconds, label)
    local anim
    if type(def) == 'table' and type(def.anim) == 'table' and def.anim.dict and Util.LoadAnim(def.anim.dict) then
        anim = { dict = def.anim.dict, clip = def.anim.clip, flag = def.anim.flag or 1 }
    else
        anim = { scenario = type(def) == 'table' and def.scenario or 'WORLD_HUMAN_HAMMERING' }
    end
    local done = lib.progressCircle({
        duration = math.floor((tonumber(seconds) or 10) * 1000), label = label, position = 'bottom', canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = anim,
    })
    ClearPedTasks(PlayerPedId())
    return done
end

local function showTime(info)
    if type(info) ~= 'table' or not info.left then return end
    JailClient.left = info.left
    UI.Send('jail', 'time', { left = info.left })
end

local function markNext(work, from)
    local cooldown = (Config.Jail.spotCooldown or 90) * 1000
    local now = GetGameTimer()
    local best, bestDist
    for _, spot in ipairs(work.spots or {}) do
        local done = JailClient.doneAt[spot.id]
        if spot.id ~= from.id and (not done or now - done >= cooldown) then
            local d = #(vector3(spot.x, spot.y, spot.z) - vector3(from.x, from.y, from.z))
            if not bestDist or d < bestDist then best, bestDist = spot, d end
        end
    end
    JailClient.next = best and { x = best.x + 0.0, y = best.y + 0.0, z = best.z + 0.0, label = work.label, untilAt = now + 120000 } or nil
end

function JailClient.Work(work, spot)
    if JailClient.working or not JailClient.Inside() then return end
    JailClient.working = true
    local ok, seconds = Me.Await('jailJobStart', work.id, spot.id)
    if not ok then
        JailClient.working = false
        return Framework.Notify(seconds or Text('err_failed'), 'error')
    end
    local done = perform((Config.Jail.activities or {})[work.activity], seconds, work.label)
    JailClient.working = false
    if not done then return end
    local okDone, info = Me.Await('jailJob', work.id, spot.id)
    if not okDone then return Framework.Notify(info or Text('err_failed'), 'error') end
    JailClient.doneAt[spot.id] = GetGameTimer()
    showTime(info)
    Framework.Notify((info.pay or 0) > 0 and Text('job_done_paid', { seconds = info.credit or 0, pay = info.pay, wallet = info.wallet or 0 }) or Text('job_done', { seconds = info.credit or 0 }), 'success')
    if info.found then Framework.Notify(Text('job_found', { item = info.found }), 'inform') end
    markNext(work, spot)
end

function JailClient.Workout(p)
    if JailClient.working or not JailClient.Inside() then return end
    JailClient.working = true
    local ok, seconds = Me.Await('workoutStart', p.id)
    if not ok then
        JailClient.working = false
        return Framework.Notify(seconds or Text('err_failed'), 'error')
    end
    local def = (Config.Jail.exercises or {})[p.exercise] or {}
    SetEntityHeading(PlayerPedId(), (p.w or 0.0) + 0.0)
    local done = perform(def, seconds, def.label or Text('point_workout'))
    JailClient.working = false
    if not done then return end
    local okDone, info = Me.Await('workout', p.id)
    if not okDone then return Framework.Notify(info or Text('err_failed'), 'error') end
    showTime(info)
    if (info.credit or 0) > 0 then
        Framework.Notify(Text('workout_done_credit', { seconds = info.credit }), 'success')
    else
        Framework.Notify(Text('workout_done'), 'success')
    end
end

function JailClient.Canteen(p)
    local ok, data = Me.Await('canteenMenu', p.id)
    if not ok then return Framework.Notify(data or Text('err_failed'), 'error') end
    data.point = p.id
    Panels.Open('canteen', data)
end

UI.Handle('canteen:take', function(d)
    if type(d) ~= 'table' then return false end
    local ok, msg = Me.Await('canteen', d.point, d.meal)
    if ok then Panels.Close('canteen') end
    return ok, msg
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local n = JailClient.next
        if n and JailClient.Inside() then
            if GetGameTimer() > n.untilAt or #(GetEntityCoords(PlayerPedId()) - vector3(n.x, n.y, n.z)) < 2.5 then
                JailClient.next = nil
            else
                sleep = 0
                DrawMarker(2, n.x, n.y, n.z + 1.3, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.35, 0.35, 0.35, 255, 170, 60, 200, true, true, 2, false, nil, nil, false)
            end
        elseif n then
            JailClient.next = nil
        end
        Wait(sleep)
    end
end)

local function spawned()
    JailClient.spawned = true
    local queued = JailClient.queued
    JailClient.queued = nil
    if queued then apply(queued.state, queued.cell) end
end

Framework.OnLoaded(function()
    SetTimeout(1500, spawned)
end)

Framework.OnUnloaded(function()
    JailClient.spawned = false
    JailClient.queued = nil
    JailClient.state = nil
    UI.Send('jail', 'close', {})
end)

CreateThread(function()
    while not Framework.name do Wait(200) end
    Wait(2000)
    if Framework.Loaded() then
        spawned()
        TriggerServerEvent('XS-PoliceSystem:server:jailSync')
    end
end)
