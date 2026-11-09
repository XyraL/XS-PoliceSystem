Heli = { on = false, light = false }

local FOV_MAX, FOV_MIN = 80.0, 8.0
local VISION = { 'heli_vision_normal', 'heli_vision_night', 'heli_vision_thermal' }

local function models()
    local out = {}
    for _, m in ipairs((Config.Heli or {}).models or { 'polmav' }) do out[joaat(m)] = true end
    return out
end

local function policeHeli()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or not models()[GetEntityModel(vehicle)] then return 0 end
    return vehicle
end

local function forward(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local n = math.abs(math.cos(x))
    return vector3(-math.sin(z) * n, math.cos(z) * n, math.sin(x))
end

local function inView(cam, heli)
    local from = GetCamCoord(cam)
    local to = from + forward(GetCamRot(cam, 2)) * 600.0
    local ray = StartShapeTestCapsule(from.x, from.y, from.z, to.x, to.y, to.z, 2.5, 10, heli, 7)
    local _, hit, _, _, entity = GetShapeTestResult(ray)
    if (hit == true or hit == 1) and entity and entity ~= 0 and IsEntityAVehicle(entity) then return entity end
    return nil
end

local function streetAt(c)
    local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
    local street = GetStreetNameFromHashKey(s1) or ''
    if s2 and s2 ~= 0 then street = street .. ' / ' .. GetStreetNameFromHashKey(s2) end
    return street
end

local function plateOf(vehicle)
    return (GetVehicleNumberPlateText(vehicle) or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function setVision(mode)
    SetNightvision(mode == 2)
    SetSeethrough(mode == 3)
end

local function camera(heli)
    Heli.on = true
    local fov, vision, locked, scan, reported = (FOV_MAX + FOV_MIN) * 0.5, 1, nil, 0, nil
    local cam = CreateCam('DEFAULT_SCRIPTED_FLY_CAMERA', true)
    AttachCamToEntity(cam, heli, 0.0, 0.0, -1.5, true)
    SetCamRot(cam, 0.0, 0.0, GetEntityHeading(heli), 2)
    SetCamFov(cam, fov)
    RenderScriptCams(true, false, 0, true, false)
    SetTimecycleModifier('heliGunCam')
    SetTimecycleModifierStrength(0.3)
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    UI.Send('heli', 'show', {})
    local ped = PlayerPedId()
    local nextInfo = 0
    while Heli.on and not IsEntityDead(ped) and GetVehiclePedIsIn(ped, false) == heli and GetEntityHeightAboveGround(heli) > 1.5 do
        HideHudAndRadarThisFrame()
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 22, true)
        if IsControlJustPressed(0, 51) then Heli.on = false end
        if IsControlJustPressed(0, 74) and (GetPedInVehicleSeat(heli, -1) == ped or GetPedInVehicleSeat(heli, 0) == ped) then
            Heli.light = not Heli.light
            TriggerServerEvent('XS-PoliceSystem:server:spotlight', Heli.light)
        end
        if IsDisabledControlJustPressed(0, 25) then
            vision = vision % 3 + 1
            setVision(vision)
            PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
        end
        if IsControlJustPressed(0, 241) then fov = math.max(FOV_MIN, fov - 3.0) end
        if IsControlJustPressed(0, 242) then fov = math.min(FOV_MAX, fov + 3.0) end
        local current = GetCamFov(cam)
        SetCamFov(cam, current + (fov - current) * 0.08)
        local zoom = (fov - FOV_MIN) / (FOV_MAX - FOV_MIN)
        if locked then
            if not DoesEntityExist(locked) or IsDisabledControlJustPressed(0, 22) then
                local rot = GetCamRot(cam, 2)
                DestroyCam(cam, false)
                cam = CreateCam('DEFAULT_SCRIPTED_FLY_CAMERA', true)
                AttachCamToEntity(cam, heli, 0.0, 0.0, -1.5, true)
                SetCamRot(cam, rot.x, 0.0, rot.z, 2)
                SetCamFov(cam, fov)
                RenderScriptCams(true, false, 0, true, false)
                locked, scan, reported = nil, 0, nil
                PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
            else
                PointCamAtEntity(cam, locked, 0.0, 0.0, 0.0, true)
            end
        else
            local x = GetDisabledControlNormal(0, 220)
            local y = GetDisabledControlNormal(0, 221)
            if x ~= 0.0 or y ~= 0.0 then
                local rot = GetCamRot(cam, 2)
                SetCamRot(cam, math.max(math.min(20.0, rot.x - y * 3.0 * (zoom + 0.1)), -89.5), 0.0, rot.z - x * 3.0 * (zoom + 0.1), 2)
            end
            local target = inView(cam, heli)
            if target and IsDisabledControlJustPressed(0, 22) then scan = 1 end
            if target and scan > 0 then
                scan = scan + 2
                if scan >= 100 then
                    locked, scan = target, 100
                    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                end
            elseif not target then
                scan = 0
            end
        end
        local now = GetGameTimer()
        if now >= nextInfo then
            nextInfo = now + 200
            local rot = GetCamRot(cam, 2)
            local info = { vision = Text(VISION[vision]), zoom = math.floor((1 - zoom) * 100), heading = math.floor((360 - rot.z) % 360), altitude = math.floor(GetEntityCoords(heli).z), scan = scan }
            if locked then
                local c = GetEntityCoords(locked)
                local plate = plateOf(locked)
                local flagged = Radar and Radar.flags[Radar.Key(plate)]
                info.target = {
                    model = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(locked))), plate = plate,
                    speed = math.floor(GetEntitySpeed(locked) * (((Config.Radar or {}).mph ~= false) and 2.236936 or 3.6)),
                    unit = ((Config.Radar or {}).mph ~= false) and 'MPH' or 'KM/H', street = streetAt(c), flagged = flagged,
                }
                if flagged and reported ~= plate then
                    reported = plate
                    CreateThread(function() Me.Await('plateSeen', plate, Me.NetId(locked), info.target.street) end)
                end
            end
            UI.Send('heli', 'update', info)
        end
        Wait(0)
    end
    Heli.on = false
    UI.Send('heli', 'hide', {})
    ClearTimecycleModifier()
    setVision(1)
    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(cam, false)
end

RegisterNetEvent('XS-PoliceSystem:client:spotlight', function(serverId, state)
    local player = GetPlayerFromServerId(serverId)
    if not player or player == -1 then return end
    local vehicle = GetVehiclePedIsIn(GetPlayerPed(player), false)
    if vehicle ~= 0 then SetVehicleSearchlight(vehicle, state == true, false) end
end)

CreateThread(function()
    while true do
        local heli = (Config.Heli or {}).enabled and Me.IsCop() and policeHeli() or 0
        if heli == 0 then
            Wait(1500)
        else
            local ped = PlayerPedId()
            local front = GetPedInVehicleSeat(heli, -1) == ped or GetPedInVehicleSeat(heli, 0) == ped
            local high = GetEntityHeightAboveGround(heli) > 1.5
            if high and not Heli.on then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(Text('heli_hint'))
                EndTextCommandDisplayHelp(0, false, false, -1)
                if IsControlJustPressed(0, 51) then camera(heli) end
                if IsControlJustPressed(0, 154) and (GetPedInVehicleSeat(heli, 1) == ped or GetPedInVehicleSeat(heli, 2) == ped) then
                    TaskRappelFromHeli(ped, 1)
                end
            end
            if front and IsControlJustPressed(0, 74) then
                Heli.light = not Heli.light
                TriggerServerEvent('XS-PoliceSystem:server:spotlight', Heli.light)
                PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
            end
            Wait(0)
        end
    end
end)
