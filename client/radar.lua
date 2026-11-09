Radar = { flags = {}, shown = false, locked = false, seen = {} }

function Radar.Key(plate)
    return (tostring(plate or ''):upper():gsub('%s+', ''))
end

local function cfg()
    return Config.Radar or {}
end

local function unit()
    return cfg().mph ~= false and 2.236936 or 3.6
end

local function plateOf(vehicle)
    return ((GetVehicleNumberPlateText(vehicle) or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function policeCar(vehicle)
    if vehicle == 0 then return false end
    local class = GetVehicleClass(vehicle)
    for _, c in ipairs(cfg().classes or { 18 }) do
        if c == class then return true end
    end
    return false
end

local function streetAt(c)
    local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
    local street = GetStreetNameFromHashKey(s1) or ''
    if s2 and s2 ~= 0 then street = street .. ' / ' .. GetStreetNameFromHashKey(s2) end
    return street
end

local function target(vehicle, dir)
    local range = cfg().range or 60.0
    local from = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, dir * 3.0, 0.4)
    local to = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, dir * range, 0.4)
    local ray = StartShapeTestCapsule(from.x, from.y, from.z, to.x, to.y, to.z, 3.0, 10, vehicle, 7)
    local _, hit, _, _, entity = GetShapeTestResult(ray)
    if (hit == true or hit == 1) and entity and entity ~= 0 and IsEntityAVehicle(entity) then return entity end
    return nil
end

local function read(vehicle, dir)
    local hit = target(vehicle, dir)
    if not hit then return nil end
    local plate = plateOf(hit)
    local flagged = Radar.flags[Radar.Key(plate)]
    if flagged and (not Radar.seen[plate] or GetGameTimer() - Radar.seen[plate] > 60000) then
        Radar.seen[plate] = GetGameTimer()
        PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
        Framework.Notify(Text('plate_is_flagged', { plate = plate, reason = flagged }), 'error')
        local netId = Me.NetId(hit)
        local where = streetAt(GetEntityCoords(hit))
        CreateThread(function() Me.Await('plateSeen', plate, netId, where) end)
    end
    return { speed = math.floor(GetEntitySpeed(hit) * unit() + 0.5), plate = plate, flagged = flagged }
end

local last = {}
local function loop()
    CreateThread(function()
        local fast = 0
        while Radar.shown do
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            if not policeCar(vehicle) or not Me.IsCop() then
                Radar.shown = false
                break
            end
            if not Radar.locked then
                local front, rear = read(vehicle, 1), read(vehicle, -1)
                local top = math.max(front and front.speed or 0, rear and rear.speed or 0)
                fast = math.max(top, fast * 0.97)
                last = { front = front, rear = rear, fast = math.floor(fast) }
            end
            UI.Send('radar', 'update', {
                patrol = math.floor(GetEntitySpeed(vehicle) * unit() + 0.5), unit = cfg().mph ~= false and 'MPH' or 'KM/H',
                front = last.front, rear = last.rear, fast = last.fast, locked = Radar.locked,
            })
            Wait(250)
        end
        UI.Send('radar', 'hide', {})
    end)
end

function Radar.Toggle()
    if not cfg().enabled or not Me.IsCop() then return end
    if Radar.shown then
        Radar.shown = false
        return
    end
    if not policeCar(GetVehiclePedIsIn(PlayerPedId(), false)) then return end
    Radar.shown, Radar.locked, last = true, false, {}
    UI.Send('radar', 'show', {})
    loop()
end

function Radar.Lock()
    if not Radar.shown then return end
    Radar.locked = not Radar.locked
    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

do
    local command = cfg().command or 'policeradar'
    RegisterCommand(command, Radar.Toggle, false)
    RegisterCommand(command .. 'lock', Radar.Lock, false)
    RegisterKeyMapping(command, Text('keybind_radar'), 'keyboard', cfg().key or 'F5')
    RegisterKeyMapping(command .. 'lock', Text('keybind_radar_lock'), 'keyboard', cfg().lockKey or 'NUMPAD5')
end

RegisterNetEvent('XS-PoliceSystem:client:flags', function(list)
    Radar.flags = {}
    for plate, reason in pairs(type(list) == 'table' and list or {}) do Radar.flags[Radar.Key(plate)] = reason end
end)

local inside
CreateThread(function()
    local wasCop = false
    while true do
        local cop = Framework.Loaded() and Me.IsCop()
        if cop ~= wasCop then
            wasCop = cop
            if cop then
                local list = Me.Await('flags')
                Radar.flags = {}
                for plate, reason in pairs(type(list) == 'table' and list or {}) do Radar.flags[Radar.Key(plate)] = reason end
            else
                Radar.flags = {}
                Radar.shown = false
            end
        end
        local sc = Config.SpeedCameras or {}
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if sc.enabled and vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped and GetVehicleClass(vehicle) ~= 18 then
            local pos = GetEntityCoords(vehicle)
            local near
            for i, cam in ipairs(sc.list or {}) do
                if #(pos - vector3(cam.coords.x + 0.0, cam.coords.y + 0.0, cam.coords.z + 0.0)) < 20.0 then near = i break end
            end
            if near and near ~= inside then
                TriggerServerEvent('XS-PoliceSystem:server:speedCamera', near, streetAt(pos))
                PlaySoundFrontend(-1, 'Camera_Shoot', 'Phone_Soundset_Franklin', true)
            end
            inside = near
            Wait(200)
        else
            inside = nil
            Wait(1000)
        end
    end
end)
