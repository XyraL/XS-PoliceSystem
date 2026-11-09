Me = { places = {}, blips = {} }

function Util.LoadModel(hash, timeout)
    if type(hash) == 'string' then hash = joaat(hash) end
    if not IsModelInCdimage(hash) then return false end
    return pcall(lib.requestModel, hash, timeout or 5000) and HasModelLoaded(hash)
end

function Util.LoadAnim(dict, timeout)
    if not DoesAnimDictExist(dict) then return false end
    return pcall(lib.requestAnimDict, dict, timeout or 3000) and HasAnimDictLoaded(dict)
end

function Me.IsCop()
    return Framework.IsCopLocal()
end

function Me.NearestPlayer(range)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local best, bestPed, bestDist = nil, nil, range or Config.Wheel.range or 3.0
    for _, player in ipairs(GetActivePlayers()) do
        local other = GetPlayerPed(player)
        if other ~= ped and other ~= 0 and IsEntityVisible(other) then
            local dist = #(GetEntityCoords(other) - coords)
            if dist <= bestDist then best, bestPed, bestDist = GetPlayerServerId(player), other, dist end
        end
    end
    return best, bestPed, best and bestDist or nil
end

local function camForward()
    local rot = GetGameplayCamRot(2)
    local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
    return vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
end

local function probe(from, to, ignore)
    local ray = StartShapeTestCapsule(from.x, from.y, from.z, to.x, to.y, to.z, 0.45, 1 + 2 + 4 + 8, ignore, 7)
    local status, hit, _, _, entity = GetShapeTestResult(ray)
    local untilAt = GetGameTimer() + 200
    while status == 1 and GetGameTimer() < untilAt do
        Wait(0)
        status, hit, _, _, entity = GetShapeTestResult(ray)
    end
    if (hit == true or hit == 1) and entity and entity ~= 0 then return entity end
    return nil
end

function Me.LookedAt(range, skip)
    local ped = PlayerPedId()
    local aimed, entity = GetEntityPlayerIsFreeAimingAt(PlayerId())
    if (aimed == true or aimed == 1) and entity and entity ~= 0 and entity ~= ped and entity ~= skip then return entity end
    local from = GetGameplayCamCoord()
    local reach = (range or 10.0) + #(from - GetEntityCoords(ped))
    local to = from + camForward() * reach
    local hit = probe(from, to, ped)
    if hit and hit == skip then hit = probe(GetEntityCoords(skip), to, skip) end
    if hit == ped or hit == skip then return nil end
    if hit and #(GetEntityCoords(hit) - GetEntityCoords(ped)) > (range or 10.0) + 2.0 then return nil end
    return hit
end

function Me.FacingPlayer(range)
    local ped = PlayerPedId()
    local me = GetEntityCoords(ped)
    local fwd = camForward()
    local flat = math.sqrt(fwd.x * fwd.x + fwd.y * fwd.y) + 0.0001
    local best, bestPed, bestScore
    for _, player in ipairs(GetActivePlayers()) do
        local other = GetPlayerPed(player)
        if other ~= ped and other ~= 0 and IsEntityVisible(other) then
            local d = GetEntityCoords(other) - me
            local dist = #d
            local across = math.sqrt(d.x * d.x + d.y * d.y)
            if dist <= (range or 5.0) and across > 0.05 then
                local dot = (d.x * fwd.x + d.y * fwd.y) / (across * flat)
                if dot > 0.8 then
                    local score = dist * (2.0 - dot)
                    if not bestScore or score < bestScore then best, bestPed, bestScore = GetPlayerServerId(player), other, score end
                end
            end
        end
    end
    return best, bestPed
end

function Me.PersonAhead(range, skip)
    local entity = Me.LookedAt(range, skip)
    if entity and IsEntityAPed(entity) and IsPedAPlayer(entity) then
        local player = NetworkGetPlayerIndexFromPed(entity)
        if player and player ~= -1 then return GetPlayerServerId(player), entity end
    end
    return Me.FacingPlayer(range)
end

function Me.NearestVehicle(range)
    local ped = PlayerPedId()
    local inside = GetVehiclePedIsIn(ped, false)
    if inside ~= 0 then return inside end
    local vehicle = lib.getClosestVehicle(GetEntityCoords(ped), range or 5.0, true)
    return vehicle or 0
end

function Me.NetId(entity)
    if not entity or entity == 0 or not NetworkGetEntityIsNetworked(entity) then return nil end
    return NetworkGetNetworkIdFromEntity(entity)
end

function Me.Await(name, ...)
    return lib.callback.await('XS-PoliceSystem:server:' .. name, false, ...)
end

function Me.Result(ok, message, kind)
    if message and message ~= '' then Framework.Notify(message, kind or (ok and 'success' or 'error')) end
    return ok
end

local function soundFor(kind)
    if kind == 'panic' then
        PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
    else
        PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', true)
    end
end

RegisterNetEvent('XS-PoliceSystem:client:alertBlip', function(c, label, kind)
    if type(c) ~= 'table' then return end
    local B = (Config.Blips or {})[kind] or (Config.Blips or {}).panic or {}
    local blip = AddBlipForCoord(c.x + 0.0, c.y + 0.0, c.z + 0.0)
    SetBlipSprite(blip, B.sprite or 161)
    SetBlipColour(blip, B.colour or 1)
    SetBlipScale(blip, B.scale or 1.2)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or '')
    EndTextCommandSetBlipName(blip)
    soundFor(kind)
    Me.blips[#Me.blips + 1] = blip
    SetTimeout((Config.Panic.blipSeconds or 90) * 1000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

RegisterNetEvent('XS-PoliceSystem:client:places', function(list)
    Me.places = type(list) == 'table' and list or {}
    Stations.Build()
end)

CreateThread(function()
    while not Framework.name do Wait(200) end
    local list = Me.Await('places')
    if type(list) == 'table' then
        Me.places = list
        Stations.Build()
    end
end)

Framework.OnJob(function()
    Stations.Build()
end)

Framework.OnLoaded(function()
    SetTimeout(1000, Stations.Build)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(Me.blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)

RegisterCommand('policediag', function()
    local job = Framework.Job() or {}
    local lines = {
        ('framework: %s'):format(tostring(Framework.name)),
        ('inventory: %s'):format(tostring(Inventory.name)),
        ('target: %s'):format(tostring(Target.Detect())),
        ('clothing: %s'):format(tostring(Clothing.name or 'auto')),
        ('job: %s grade %s, on duty %s, counts as police %s'):format(tostring(job.name), tostring(job.grade), tostring(job.onDuty), tostring(Me.IsCop())),
        ('places loaded: %d'):format(#(Me.places or {})),
        ('cuffed: %s, in jail: %s'):format(tostring(Field.cuffed), tostring(JailClient.Inside())),
        ('wheel: /%s, key %s'):format(Config.Wheel.command or 'policewheel', Config.Wheel.key or 'F6'),
    }
    for _, line in ipairs(lines) do print('[XS-PoliceSystem] ' .. line) end
    Framework.Notify(Text('diag_printed'), 'inform')
end, false)
