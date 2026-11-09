UnitCams = { feed = nil, ctx = nil, units = {}, listening = nil, muted = false, starting = false, token = 0 }

local EXIT = { 177, 200, 202 }
local MODE_KEYS = { [157] = 'body', [158] = 'dash', [160] = 'cabin' }
local FOV = { body = 100.0, dash = 72.0, cabin = 90.0 }
local SPINE = 24818

local function cfg()
    return Config.UnitCams or {}
end

local function yes(v)
    return v == true or v == 1
end

local function speedUnit()
    return (Config.Radar or {}).mph ~= false and 2.236936 or 3.6
end

local function placeOf(x, y, z)
    x, y, z = x + 0.0, y + 0.0, z + 0.0
    local a, b = GetStreetNameAtCoord(x, y, z)
    local zone = GetLabelText(GetNameOfZone(x, y, z))
    return GetStreetNameFromHashKey(a) or '', (b and b ~= 0) and GetStreetNameFromHashKey(b) or '', (zone and zone ~= 'NULL') and zone or ''
end

local function bearing(heading)
    return math.floor((360.0 - heading) % 360.0)
end

local function modes()
    local C = cfg()
    return { body = C.body ~= false, dash = C.dash ~= false, cabin = C.dash ~= false and C.cabin ~= false }
end

function UnitCams.CanRemote()
    local C = cfg()
    if not C.enabled or not C.remote or not Me.IsCop() then return false end
    local job = Framework.Job()
    if not job then return false end
    return job.isBoss or (job.grade or 0) >= (C.remoteGrade or 3)
end

local function fetch(ctx)
    local ok, data = Me.Await('unitCams', ctx)
    if not ok then return nil, data end
    local units = type(data) == 'table' and data.units or {}
    for _, u in ipairs(units) do
        u.street, u.cross, u.zone = placeOf(u.x or 0, u.y or 0, u.z or 0)
    end
    UnitCams.units = units
    return data
end

function UnitCams.Open(ctx)
    if UnitCams.feed or UnitCams.starting then return end
    if not cfg().enabled then return Framework.Notify(Text('err_unitcams_off'), 'error') end
    ctx = type(ctx) == 'table' and ctx or {}
    local data, err = fetch(ctx)
    if not data then return Framework.Notify(err or Text('err_failed'), 'error') end
    UnitCams.ctx = ctx
    Panels.Open('unitcams', { units = UnitCams.units, remote = data.remote, station = ctx.station, modes = modes() })
    UnitCams.token = UnitCams.token + 1
    local token = UnitCams.token
    CreateThread(function()
        while Panels.open == 'unitcams' and UnitCams.token == token do
            Wait(3000)
            if Panels.open ~= 'unitcams' or UnitCams.token ~= token then break end
            local fresh, why = fetch(ctx)
            if not fresh then
                Panels.Close('unitcams')
                Framework.Notify(why or Text('err_failed'), 'error')
                break
            end
            UI.Send('unitcams', 'units', { units = UnitCams.units })
        end
    end)
end

local function pedOf(src)
    local player = GetPlayerFromServerId(src)
    if player == -1 or not NetworkIsPlayerActive(player) then return nil end
    local ped = GetPlayerPed(player)
    if ped == 0 or not DoesEntityExist(ped) then return nil end
    return ped
end

local function carOf(netId)
    if not netId or not NetworkDoesNetworkIdExist(netId) then return nil end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    return vehicle
end

local function subjectOf(feed)
    if feed.mode == 'body' then return pedOf(feed.target) end
    return carOf(feed.netId)
end

local function boneOffset(vehicle, bone)
    local index = GetEntityBoneIndexByName(vehicle, bone)
    if index == -1 then return nil end
    local at = GetWorldPositionOfEntityBone(vehicle, index)
    return GetOffsetFromEntityGivenWorldCoords(vehicle, at.x, at.y, at.z)
end

local function mount(feed, entity)
    local fov = (cfg().fov or {})[feed.mode] or FOV[feed.mode]
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, fov + 0.0, false, 2)
    SetCamNearClip(cam, 0.05)
    if feed.mode == 'body' then
        AttachCamToPedBone(cam, entity, SPINE, 0.0, 0.22, 0.0, true)
        ShakeCam(cam, 'HAND_SHAKE', 0.3)
        return cam
    end
    local min, max = GetModelDimensions(GetEntityModel(entity))
    if feed.mode == 'dash' then
        local glass = boneOffset(entity, 'windscreen') or vector3(0.0, max.y * 0.3, max.z * 0.6)
        HardAttachCamToEntity(cam, entity, -2.0, 0.0, 0.0, 0.0, glass.y - 0.32, glass.z + 0.06, true)
    else
        local seat = boneOffset(entity, 'seat_dside_f') or vector3(-0.4, 0.0, min.z + 0.6)
        HardAttachCamToEntity(cam, entity, -24.0, 0.0, 180.0, 0.0, seat.y - 0.38, seat.z + 0.78, true)
    end
    ShakeCam(cam, 'ROAD_VIBRATION_SHAKE', 0.12)
    return cam
end

local function filter(mode)
    local f = cfg().filter or {}
    ClearTimecycleModifier()
    if type(f[mode]) == 'string' and f[mode] ~= '' then
        SetTimecycleModifier(f[mode])
        SetTimecycleModifierStrength((tonumber(f.strength) or 0.45) + 0.0)
    end
end

local function remount(feed, entity)
    local old = feed.cam
    feed.cam, feed.entity = mount(feed, entity), entity
    SetCamActive(feed.cam, true)
    RenderScriptCams(true, false, 0, true, true)
    if old and DoesCamExist(old) then DestroyCam(old, false) end
    SetFocusEntity(entity)
end

local function attach(feed)
    local c = feed.coords
    if c then SetFocusPosAndVel(c.x + 0.0, c.y + 0.0, c.z + 0.0, 0.0, 0.0, 0.0) end
    local entity
    local untilAt = GetGameTimer() + 6000
    while GetGameTimer() < untilAt do
        entity = subjectOf(feed)
        if entity then break end
        Wait(50)
    end
    if not entity then return false, Text('err_unitcam_reach') end
    if feed.mode == 'cabin' and GetVehicleModelNumberOfSeats(GetEntityModel(entity)) < 3 then return false, Text('err_unitcam_nocabin') end
    remount(feed, entity)
    filter(feed.mode)
    feed.seen, feed.lost = GetGameTimer(), false
    return true
end

local function take(feed, info)
    feed.target, feed.mode, feed.netId, feed.coords = info.target, info.mode, info.netId, info.coords
    feed.plate, feed.any = info.plate, info.any == true
    feed.name, feed.callsign, feed.rank, feed.dept = info.name or '', info.callsign or '', info.rank or '', info.dept or ''
end

local function audioOn()
    return cfg().audio ~= false and not UnitCams.muted and GetResourceState('pma-voice') == 'started'
end

local function unlisten()
    if not UnitCams.listening then return end
    MumbleRemoveVoiceChannelListen(UnitCams.listening)
    UnitCams.listening = nil
end

local function listen(target)
    if not target or target == GetPlayerServerId(PlayerId()) or not audioOn() then return unlisten() end
    local channel = MumbleGetVoiceChannelFromServerId(target)
    if not channel or channel <= 0 then return unlisten() end
    if UnitCams.listening ~= channel then unlisten() end
    MumbleAddVoiceChannelListen(channel)
    UnitCams.listening = channel
end

local function osd(feed)
    UI.Send('unitfeed', 'show', {
        mode = feed.mode, src = feed.target, name = feed.name, callsign = feed.callsign, rank = feed.rank, dept = feed.dept,
        plate = feed.plate, any = feed.any, modes = modes(), audio = audioOn(), many = #UnitCams.units > 1,
        unit = (Config.Radar or {}).mph ~= false and 'MPH' or 'KM/H', back = feed.fromConsole == true,
    })
end

local function release(feed)
    if feed.cam and DoesCamExist(feed.cam) then DestroyCam(feed.cam, false) end
    RenderScriptCams(false, false, 0, true, true)
    ClearFocus()
    ClearTimecycleModifier()
    UnlockMinimapPosition()
    UnlockMinimapAngle()
    DisplayRadar(not feed.radarHidden)
    unlisten()
    if feed.hotbar then
        feed.hotbar = nil
        Inventory.HoldHotbar(false)
    end
    if feed.frozen then FreezeEntityPosition(PlayerPedId(), false) end
    UI.Send('unitfeed', 'hide', {})
end

local function stop(reason, back)
    local feed = UnitCams.feed
    if not feed then return end
    UnitCams.feed = nil
    DoScreenFadeOut(200)
    Wait(220)
    release(feed)
    DoScreenFadeIn(250)
    Me.Await('unitCamStop')
    if reason then Framework.Notify(reason, 'error') end
    if back then UnitCams.Open(feed.ctx) end
end

local function go(feed, target, mode)
    local ok, info = Me.Await('unitCamWatch', feed.ctx, target, mode)
    if not ok then return false, info end
    take(feed, info)
    return attach(feed)
end

function UnitCams.Switch(target, mode)
    local feed = UnitCams.feed
    if not feed or feed.busy then return end
    target, mode = tonumber(target) or feed.target, mode or feed.mode
    if target == feed.target and mode == feed.mode then return end
    feed.busy = true
    UI.Send('unitfeed', 'tune', {})
    local back = { target = feed.target, mode = feed.mode }
    local ok, err = go(feed, target, mode)
    if UnitCams.feed ~= feed then return end
    if not ok then
        Framework.Notify(err or Text('err_failed'), 'error')
        if feed.mode ~= back.mode or feed.target ~= back.target then
            if not go(feed, back.target, back.mode) then
                feed.busy = false
                return stop(Text('unitcam_lost'), feed.fromConsole)
            end
        end
    end
    feed.busy = false
    osd(feed)
    listen(feed.target)
end

local function step(feed, dir)
    local units = UnitCams.units or {}
    local at = 0
    for i, u in ipairs(units) do
        if u.src == feed.target then at = i end
    end
    for n = 1, #units do
        local u = units[((at - 1 + dir * n) % #units) + 1]
        if u.src ~= feed.target and (feed.mode == 'body' or u.dash) then return u.src end
    end
    return nil
end

local function ahead(vehicle)
    local range = (Config.Radar or {}).range or 60.0
    local from = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 3.0, 0.4)
    local to = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, range + 0.0, 0.4)
    local ray = StartShapeTestCapsule(from.x, from.y, from.z, to.x, to.y, to.z, 3.0, 10, vehicle, 7)
    local _, hit, _, _, entity = GetShapeTestResult(ray)
    if (hit == true or hit == 1) and entity and entity ~= 0 and IsEntityAVehicle(entity) then
        return math.floor(GetEntitySpeed(entity) * speedUnit() + 0.5)
    end
    return nil
end

local function hurt(feed)
    local me = PlayerPedId()
    local health, armour = GetEntityHealth(me), GetPedArmour(me)
    if health > feed.health then feed.health = health end
    if armour > feed.armour then feed.armour = armour end
    return IsEntityDead(me) or IsPedRagdoll(me) or health < feed.health or armour < feed.armour
end

local function pressed(list)
    for _, control in ipairs(list) do
        if IsDisabledControlJustPressed(0, control) then return true end
    end
    return false
end

local function controls(feed)
    if pressed({ 34, 174 }) or pressed({ 35, 175 }) then
        local target = step(feed, pressed({ 34, 174 }) and -1 or 1)
        if target then CreateThread(function() UnitCams.Switch(target, feed.mode) end) end
        return
    end
    for control, mode in pairs(MODE_KEYS) do
        if IsDisabledControlJustPressed(0, control) and mode ~= feed.mode then
            if modes()[mode] then CreateThread(function() UnitCams.Switch(feed.target, mode) end) end
            return
        end
    end
    if IsDisabledControlJustPressed(0, 244) then
        UnitCams.muted = not UnitCams.muted
        listen(feed.target)
        UI.Send('unitfeed', 'audio', { on = audioOn() })
    end
end

local function follow(feed, subject, state)
    local speed = GetEntitySpeed(subject)
    if feed.mode == 'body' then
        local rot = GetEntityRotation(subject, 2)
        SetCamRot(feed.cam, rot.x - 4.0, 0.0, rot.z, 2)
        state.amp = state.amp + (math.min(1.6, 0.3 + speed * 0.22) - state.amp) * 0.08
    else
        state.amp = state.amp + (math.min(0.9, 0.12 + speed * 0.025) - state.amp) * 0.05
    end
    SetCamShakeAmplitude(feed.cam, state.amp)
    if cfg().minimap ~= false then
        local c = GetEntityCoords(subject)
        LockMinimapPosition(c.x, c.y)
        LockMinimapAngle(math.floor(GetEntityHeading(subject)) % 360)
    end
end

local function hud()
    if cfg().minimap ~= false then
        for i = 1, 22 do HideHudComponentThisFrame(i) end
        DisplayRadar(true)
    else
        HideHudAndRadarThisFrame()
    end
end

local function run(feed)
    CreateThread(function()
        local state = { amp = 0.3 }
        while UnitCams.feed == feed do
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true)
            hud()
            if hurt(feed) then
                stop(Text('unitcam_hurt'))
                break
            end
            if pressed(EXIT) then
                stop(nil, feed.fromConsole)
                break
            end
            if not feed.busy then
                controls(feed)
                local subject = subjectOf(feed)
                if subject then
                    feed.seen = GetGameTimer()
                    if subject ~= feed.entity then remount(feed, subject) end
                    if feed.lost then
                        feed.lost = false
                        UI.Send('unitfeed', 'signal', { ok = true })
                    end
                    follow(feed, subject, state)
                elseif GetGameTimer() - feed.seen > (cfg().signalLoss or 8) * 1000 then
                    stop(Text('unitcam_lost'))
                    break
                elseif not feed.lost then
                    feed.lost = true
                    UI.Send('unitfeed', 'signal', { ok = false })
                end
            end
            Wait(0)
        end
    end)
end

local function readout(feed, subject)
    local c = GetEntityCoords(subject)
    local street, cross, zone = placeOf(c.x, c.y, c.z)
    local car = feed.mode ~= 'body' and subject or GetVehiclePedIsIn(subject, false)
    local player = GetPlayerFromServerId(feed.target)
    return {
        street = street, cross = cross, zone = zone,
        heading = bearing(GetEntityHeading(subject)),
        speed = math.floor(GetEntitySpeed(subject) * speedUnit() + 0.5),
        inCar = car ~= 0,
        lights = car ~= 0 and yes(IsVehicleSirenOn(car)),
        siren = car ~= 0 and yes(IsVehicleSirenAudioOn(car)),
        talking = player ~= -1 and yes(MumbleIsPlayerTalking(player)),
        radar = feed.mode == 'dash' and cfg().radar ~= false and ahead(subject) or nil,
    }
end

local function tick(feed)
    CreateThread(function()
        local refresh = GetGameTimer() + 6000
        while UnitCams.feed == feed do
            Wait(500)
            if UnitCams.feed ~= feed then break end
            RequestCollisionAtCoord(feed.at.x, feed.at.y, feed.at.z)
            if not feed.busy and not feed.lost and feed.entity and DoesEntityExist(feed.entity) then
                UI.Send('unitfeed', 'tick', readout(feed, feed.entity))
            end
            if not feed.busy then listen(feed.target) end
            if GetGameTimer() > refresh then
                refresh = GetGameTimer() + 6000
                fetch(feed.ctx)
            end
        end
    end)
end

function UnitCams.Watch(target, mode, ctx, fromConsole)
    target = tonumber(target)
    if not target then return end
    if UnitCams.feed then return UnitCams.Switch(target, mode) end
    if UnitCams.starting then return end
    local me = PlayerPedId()
    if IsEntityDead(me) then return end
    local vehicle = GetVehiclePedIsIn(me, false)
    if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == me and GetEntitySpeed(vehicle) > 1.0 then
        return Framework.Notify(Text('err_unitcam_moving'), 'error')
    end
    ctx = type(ctx) == 'table' and ctx or {}
    UnitCams.starting = true
    if not fromConsole then
        local data, err = fetch(ctx)
        if not data then
            UnitCams.starting = false
            return Framework.Notify(err or Text('err_failed'), 'error')
        end
    end
    local ok, info = Me.Await('unitCamWatch', ctx, target, mode)
    if not ok then
        UnitCams.starting = false
        return Framework.Notify(info or Text('err_failed'), 'error')
    end
    DoScreenFadeOut(250)
    Wait(270)
    local feed = {
        ctx = ctx, fromConsole = fromConsole == true, frozen = vehicle == 0, radarHidden = IsRadarHidden(),
        health = GetEntityHealth(me), armour = GetPedArmour(me), at = GetEntityCoords(me),
    }
    if feed.frozen then FreezeEntityPosition(me, true) end
    take(feed, info)
    local attached, err = attach(feed)
    UnitCams.starting = false
    if not attached then
        release(feed)
        DoScreenFadeIn(250)
        Me.Await('unitCamStop')
        if fromConsole then UnitCams.Open(ctx) end
        return Framework.Notify(err or Text('err_unitcam_reach'), 'error')
    end
    UnitCams.feed = feed
    feed.hotbar = true
    Inventory.HoldHotbar(true)
    osd(feed)
    listen(feed.target)
    run(feed)
    tick(feed)
    Wait(150)
    DoScreenFadeIn(300)
end

UI.Handle('unitcams:watch', function(p)
    if type(p) ~= 'table' or not tonumber(p.src) then return false end
    local target, mode, ctx = tonumber(p.src), p.mode, UnitCams.ctx
    Panels.Close('unitcams')
    UnitCams.token = UnitCams.token + 1
    CreateThread(function()
        Wait(150)
        UnitCams.Watch(target, mode, ctx, true)
    end)
    return true
end)

RegisterNetEvent('XS-PoliceSystem:client:unitCamLost', function()
    if UnitCams.feed then CreateThread(function() stop(Text('unitcam_lost')) end) end
end)

exports('WatchUnit', function(serverId, mode)
    serverId = tonumber(serverId)
    if not cfg().enabled or not serverId or UnitCams.feed or UnitCams.starting then return false end
    CreateThread(function() UnitCams.Watch(serverId, mode or 'body', {}, false) end)
    return true
end)

exports('OpenUnitCams', function()
    if not cfg().enabled or UnitCams.feed then return false end
    CreateThread(function() UnitCams.Open() end)
    return true
end)

exports('IsWatchingUnitCam', function() return UnitCams.feed ~= nil end)

Framework.OnUnloaded(function()
    local feed = UnitCams.feed
    UnitCams.feed = nil
    if feed then release(feed) end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() or not UnitCams.feed then return end
    release(UnitCams.feed)
    UnitCams.feed = nil
end)
