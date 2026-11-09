Field = { cuffed = false, escortedBy = nil, escorting = nil }

local CUFF_DICT, CUFF_CLIP = 'mp_arresting', 'idle'
local PAIRED = 'mp_arrest_paired'
local HANDS_UP = {
    { 'missminuteman_1ig_2', 'handsup_base' },
    { 'random@mugging3', 'handsup_standing_base' },
    { 'random@arrests@busted', 'idle_a' },
    { 'mp_am_hold_up', 'handsup_base' },
    { 'missminuteman_1ig_2', 'handsup_enter' },
}
local BLOCKED = { 21, 22, 23, 24, 25, 37, 44, 45, 75, 140, 141, 142, 143, 257, 263, 264 }

local function pedOf(serverId)
    local player = GetPlayerFromServerId(serverId)
    if not player or player == -1 then return 0 end
    local ped = GetPlayerPed(player)
    if ped == PlayerPedId() then return 0 end
    return ped
end

local function isDown()
    local bag = LocalPlayer.state
    if bag.isDead or bag.dead or IsEntityDead(PlayerPedId()) then return true end
    local meta = Framework.PlayerData().metadata or {}
    return meta.isdead == true or meta.inlaststand == true
end

Field.IsDown = isDown

local function standUp()
    local ped = PlayerPedId()
    if isDown() or GetVehiclePedIsIn(ped, false) ~= 0 then return end
    ClearPedTasksImmediately(ped)
end

local function closePhone()
    if GetResourceState('XS-Phone') ~= 'started' then return end
    pcall(function()
        if exports['XS-Phone']:IsPhoneOpen() then exports['XS-Phone']:Close() end
    end)
end

local function canPose(ped)
    return GetVehiclePedIsIn(ped, false) == 0 and not IsPedRagdoll(ped) and not IsPedGettingUp(ped) and not IsPedFalling(ped)
end

local function playCuffs(ped)
    if not Util.LoadAnim(CUFF_DICT) then return false end
    TaskPlayAnim(ped, CUFF_DICT, CUFF_CLIP, 8.0, -8.0, -1, 49, 0.0, false, false, false)
    return true
end

local function cuffLoop()
    CreateThread(function()
        local ped = PlayerPedId()
        closePhone()
        ClearPedSecondaryTask(ped)
        local now = GetGameTimer()
        local poseAt, phoneAt = now + 500, now + 500
        local floorSince, fresh
        local inCar = IsPedInAnyVehicle(ped, true)
        if canPose(ped) and playCuffs(ped) then poseAt = now + 1000 end
        while Field.cuffed do
            ped = PlayerPedId()
            now = GetGameTimer()
            local car = IsPedInAnyVehicle(ped, true)
            if inCar and not car then
                fresh = true
                poseAt = now + 300
            end
            inCar = car
            for _, control in ipairs(BLOCKED) do DisableControlAction(0, control, true) end
            DisablePlayerFiring(PlayerId(), true)
            if GetSelectedPedWeapon(ped) ~= `WEAPON_UNARMED` then SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true) end
            if IsPedRagdoll(ped) or IsPedGettingUp(ped) then
                floorSince = floorSince or now
                if now - floorSince > ((Config.Tackle or {}).seconds or 4) * 1000 + 4000 then
                    floorSince = nil
                    standUp()
                    poseAt = now
                end
            else
                floorSince = nil
            end
            if now >= poseAt then
                poseAt = now + 500
                if canPose(ped) then
                    if fresh then
                        fresh = false
                        ClearPedSecondaryTask(ped)
                        if playCuffs(ped) then poseAt = now + 1000 end
                    elseif not IsEntityPlayingAnim(ped, CUFF_DICT, CUFF_CLIP, 3) and playCuffs(ped) then
                        poseAt = now + 1000
                    end
                end
            end
            if now >= phoneAt then
                phoneAt = now + 500
                closePhone()
            end
            Wait(0)
        end
    end)
end

function Field.SetCuffed(on)
    on = on == true
    if Field.cuffed == on then return end
    Field.cuffed = on
    local ped = PlayerPedId()
    if on then
        SetPedCanPlayGestureAnims(ped, false)
        SetPedConfigFlag(ped, 184, true)
        cuffLoop()
    else
        SetEnableHandcuffs(ped, false)
        SetPedCanPlayGestureAnims(ped, true)
        SetPedConfigFlag(ped, 184, false)
        StopAnimTask(ped, CUFF_DICT, CUFF_CLIP, 1.0)
        ClearPedSecondaryTask(ped)
        if not Field.escortedBy then standUp() end
    end
    TriggerEvent('XS-PoliceSystem:client:cuffChanged', on)
end

RegisterNetEvent('XS-PoliceSystem:client:cuffed', function(on)
    Field.SetCuffed(on)
    Framework.Notify(Text(on and 'you_are_cuffed' or 'you_are_uncuffed'), 'inform')
end)

RegisterNetEvent('XS-PoliceSystem:client:cuffAnim', function(target, on)
    local ped = PlayerPedId()
    if on and Util.LoadAnim(PAIRED) then
        TaskPlayAnim(ped, PAIRED, 'cop_p2_back_right', 3.0, 3.0, -1, 48, 0.0, false, false, false)
        Wait(3500)
        StopAnimTask(ped, PAIRED, 'cop_p2_back_right', 1.0)
    elseif not on and Util.LoadAnim(CUFF_DICT) then
        TaskPlayAnim(ped, CUFF_DICT, 'a_uncuff', 8.0, -8.0, -1, 48, 0.0, false, false, false)
        Wait(3000)
        StopAnimTask(ped, CUFF_DICT, 'a_uncuff', 1.0)
    end
end)

RegisterNetEvent('XS-PoliceSystem:client:getCuffedAnim', function(officer)
    local ped = PlayerPedId()
    local officerPed = pedOf(officer)
    if officerPed == 0 or not Util.LoadAnim(PAIRED) then return end
    closePhone()
    ClearPedSecondaryTask(ped)
    AttachEntityToEntity(ped, officerPed, 11816, -0.1, 0.45, 0.0, 0.0, 0.0, 20.0, false, false, false, false, 20, false)
    TaskPlayAnim(ped, PAIRED, 'crook_p2_back_right', 3.0, 3.0, -1, 32, 0.0, false, false, false)
    Wait(2500)
    DetachEntity(ped, true, false)
end)

local function endEscort()
    local ped = PlayerPedId()
    Field.escortedBy = nil
    DetachEntity(ped, true, false)
    if Field.noRagdoll then
        Field.noRagdoll = false
        SetPedCanRagdoll(ped, true)
        if IsPedRagdoll(ped) or IsPedGettingUp(ped) then standUp() end
    end
    if Field.cuffed and canPose(ped) then playCuffs(ped) end
end

RegisterNetEvent('XS-PoliceSystem:client:escorted', function(officer)
    local ped = PlayerPedId()
    if not officer then return endEscort() end
    Field.escortedBy = officer
    if not isDown() then
        Field.noRagdoll = true
        SetPedCanRagdoll(ped, false)
        if IsPedRagdoll(ped) or IsPedGettingUp(ped) then standUp() end
    end
    CreateThread(function()
        while Field.escortedBy == officer do
            local officerPed = pedOf(officer)
            if officerPed == 0 or not DoesEntityExist(officerPed) then break end
            if not IsEntityAttachedToEntity(ped, officerPed) then
                AttachEntityToEntity(ped, officerPed, 11816, 0.45, 0.45, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
            end
            if IsPedInAnyVehicle(officerPed, false) then break end
            Wait(250)
        end
        if Field.escortedBy == officer then endEscort() end
    end)
end)

RegisterNetEvent('XS-PoliceSystem:client:escorting', function(target)
    Field.escorting = target
end)

RegisterNetEvent('XS-PoliceSystem:client:putInVehicle', function(netId)
    local vehicle = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or 0
    if vehicle == 0 then return end
    endEscort()
    local ped = PlayerPedId()
    for _, seat in ipairs({ 1, 2, 0 }) do
        if IsVehicleSeatFree(vehicle, seat) then
            TaskWarpPedIntoVehicle(ped, vehicle, seat)
            return
        end
    end
end)

RegisterNetEvent('XS-PoliceSystem:client:takeOutVehicle', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then TaskLeaveVehicle(ped, vehicle, 16) end
end)

lib.callback.register('XS-PoliceSystem:client:handsUp', function()
    local ped = PlayerPedId()
    for _, clip in ipairs(HANDS_UP) do
        if IsEntityPlayingAnim(ped, clip[1], clip[2], 3) then return true end
    end
    return false
end)

lib.callback.register('XS-PoliceSystem:client:resist', function()
    if Field.cuffed or IsEntityDead(PlayerPedId()) then return false end
    local ok, passed = pcall(lib.skillCheck, Config.Cuffs.resistDifficulty or { 'easy' }, { 'e' })
    return ok and passed == true
end)

local function act(name, target, extra)
    local ok, msg, data = Me.Await('action', name, target, extra)
    if ok and type(msg) == 'table' then return ok, nil, msg end
    return ok, msg, data
end

local function needPerson(range)
    local target = Me.NearestPlayer(range)
    if not target then
        Framework.Notify(Text('err_nobody_near'), 'error')
        return nil
    end
    return target
end

local function needVehicle(range)
    local vehicle = Me.NearestVehicle(range or 5.0)
    if vehicle == 0 then
        Framework.Notify(Text('err_no_vehicle'), 'error')
        return nil
    end
    return vehicle
end

local function personAction(name)
    local target = needPerson()
    if not target then return end
    local ok, msg = act(name, target)
    Me.Result(ok, msg)
end

local function procedure(seconds, label, scenario)
    local done = lib.progressCircle({
        duration = math.floor(seconds * 1000), label = label, position = 'bottom', canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = scenario and { scenario = scenario } or nil,
    })
    ClearPedTasks(PlayerPedId())
    return done
end

local function test(name, label)
    local target = needPerson()
    if not target then return end
    if not procedure(3, label, 'CODE_HUMAN_MEDIC_TIME_OF_DEATH') then return end
    local ok, msg, data = act(name, target)
    if not ok then return Me.Result(false, msg) end
    Panels.Open('tests', data and data.test or {})
end

local function occupant(range)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    for _, player in ipairs(GetActivePlayers()) do
        local other = GetPlayerPed(player)
        if other ~= ped and IsPedInAnyVehicle(other, false) and #(GetEntityCoords(other) - coords) <= (range or 6.0) then
            return GetPlayerServerId(player)
        end
    end
    return nil
end

Field.Actions = {
    cuff = function() personAction('cuff') end,
    escort = function() personAction('escort') end,
    search = function() personAction('search') end,
    seize = function() personAction('seize') end,
    gsr = function()
        local target = needPerson()
        if not target then return end
        local ok, msg = act('gsr', target)
        Me.Result(ok, msg, 'inform')
    end,
    fingerprint = function()
        local target = needPerson()
        if not target then return end
        local ped = PlayerPedId()
        if Util.LoadAnim(CUFF_DICT) then TaskPlayAnim(ped, CUFF_DICT, 'a_uncuff', 8.0, -8.0, -1, 49, 0.0, false, false, false) end
        local done = lib.progressCircle({
            duration = ((Config.Forensics or {}).printSeconds or 4) * 1000, label = Text('prints_taking'), position = 'bottom', canCancel = true,
            disable = { move = true, car = true, combat = true },
        })
        StopAnimTask(ped, CUFF_DICT, 'a_uncuff', 1.0)
        if not done then return end
        local ok, msg, data = act('fingerprint', target)
        if not ok then return Me.Result(false, msg) end
        local scan = data and data.scan or {}
        scan.mdt = MDT.Available()
        scan.mdtProfile = MDT.CanOpenProfile()
        Panels.Open('scanner', scan)
    end,
    breathalyzer = function() test('breathalyzer', Text('testing_breath')) end,
    drugswab = function() test('drugswab', Text('testing_swab')) end,
    checkStatus = function()
        local target = needPerson()
        if not target then return end
        local ok, msg, data = act('status', target)
        if not ok then return Me.Result(false, msg) end
        local list = data and data.statuses or {}
        if #list == 0 then return Framework.Notify(Text('status_none'), 'inform') end
        for _, line in ipairs(list) do Framework.Notify(line, 'inform') end
    end,
    licences = function()
        local target = needPerson()
        if not target then return end
        local ok, msg, data = act('licences', target)
        if not ok then return Me.Result(false, msg) end
        Panels.Open('licences', data and data.licences or {})
    end,
    tracker = function() personAction('tracker') end,
    flagPlate = function()
        local vehicle = Me.NearestVehicle(8.0)
        local plate = vehicle ~= 0 and ((GetVehicleNumberPlateText(vehicle) or ''):gsub('^%s+', ''):gsub('%s+$', '')) or ''
        Panels.Open('form', { kind = 'flag', plate = plate, current = Radar.flags[Radar.Key(plate)], maxHours = (Config.Plates or {}).maxHours or 720 })
    end,
    cameras = function() Cameras.OpenPicker() end,
    unitCams = function() UnitCams.Open() end,
    service = function()
        local target = needPerson()
        if not target then return end
        Panels.Open('form', { kind = 'service', target = target, max = (Config.Service or {}).maxTasks or 50 })
    end,
    solitary = function() personAction('solitary') end,
    searchVehicle = function() Scene.SearchVehicle() end,
    dustPrints = function() Forensics.Dust() end,
    slowTraffic = function() Scene.Traffic('slow') end,
    stopTraffic = function() Scene.Traffic('stop') end,
    k9Call = function() K9.Call() end,
    k9Follow = function() K9.ToggleFollow() end,
    k9Search = function() K9.Search() end,
    k9Attack = function() K9.Attack() end,
    k9Car = function() K9.Car() end,
    k9Track = function() K9.Track() end,
    k9Guard = function() K9.Guard() end,
    k9Bark = function() K9.Bark() end,
    idcheck = function()
        local target = needPerson()
        if not target then return end
        local ok, msg, data = act('idcheck', target)
        if not ok then return Me.Result(false, msg) end
        Panels.Open('idcard', data and data.card or {})
    end,
    putInVehicle = function()
        local target = needPerson()
        if not target then return end
        local vehicle = needVehicle(6.0)
        if not vehicle then return end
        local ok, msg = act('putInVehicle', target, { netId = Me.NetId(vehicle) })
        Me.Result(ok, msg)
    end,
    takeOutVehicle = function()
        local target = occupant(6.0)
        if not target then return Framework.Notify(Text('err_nobody_in_vehicle'), 'error') end
        local ok, msg = act('takeOutVehicle', target)
        Me.Result(ok, msg)
    end,
    impound = function() ImpoundClient.Start() end,
    checkPlate = function()
        local vehicle = needVehicle(6.0)
        if not vehicle then return end
        local ok, info = Me.Await('checkPlate', Me.NetId(vehicle))
        if not ok then return Me.Result(false, info) end
        if info.owner then
            Framework.Notify(Text('plate_owner', { plate = info.plate, owner = info.owner ~= '' and info.owner or Text('unknown') }), 'inform')
        else
            Framework.Notify(Text('plate_unregistered', { plate = info.plate }), 'inform')
        end
        if (tonumber(info.wanted) or 0) > 0 then
            Framework.Notify(Text('plate_owner_wanted', { count = info.wanted }), 'error')
        end
        if info.flag then
            PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
            Framework.Notify(Text('plate_flag_warn', { reason = info.flag }), 'error')
        end
    end,
    cone = function() Props.Place('cone') end,
    barrier = function() Props.Place('barrier') end,
    spikes = function() Props.Place('spikes') end,
    removeProp = function() Props.RemoveNearest() end,
    fine = function()
        local target = needPerson()
        if not target then return end
        Panels.Open('form', { kind = 'fine', target = target, max = Config.Fines.max })
    end,
    jail = function() Field.Jail() end,
    mdt = function()
        if not MDT.Open() then Framework.Notify(Text('err_no_mdt'), 'error') end
    end,
    panic = function()
        local ok, err = Me.Await('panic')
        if ok then Framework.Notify(Text('panic_sent'), 'success') else Framework.Notify(err or Text('err_failed'), 'error') end
    end,
}

function Field.Jail()
    if not Config.Jail.enabled then return Framework.Notify(Text('err_jail_off'), 'error') end
    local target = needPerson()
    if not target then return end
    Panels.Open('form', { kind = 'jail', target = target, max = Config.Jail.maxMonths, minutesPerMonth = Config.Jail.minutesPerMonth })
end

function Field.SubmitForm(p)
    if p.kind == 'flag' then
        if p.remove then return Me.Await('unflagPlate', p.plate) end
        return Me.Await('flagPlate', p.plate, p.reason, p.hours)
    end
    local target = tonumber(p.target)
    if not target then return false, Text('err_no_player') end
    if p.kind == 'fine' then
        return act('fine', target, { amount = p.amount, reason = p.reason })
    elseif p.kind == 'jail' then
        return act('jail', target, { months = p.months, reason = p.reason })
    elseif p.kind == 'service' then
        return act('service', target, { tasks = p.tasks, reason = p.reason })
    end
    return false, Text('err_failed')
end

UI.Handle('licence:set', function(p)
    if type(p) ~= 'table' then return false end
    local ok, msg = act('licenceSet', tonumber(p.target), { kind = p.kind, on = p.on == true })
    if not ok then return false, msg end
    local okList, _, data = act('licences', tonumber(p.target))
    return true, { message = msg, licences = okList and data and data.licences or nil }
end)

RegisterNetEvent('XS-PoliceSystem:client:run', function(name)
    Field.Run(name)
end)

function Field.Run(name)
    local fn = Field.Actions[name]
    if not fn then return end
    if not Me.IsCop() then return Framework.Notify(Text('err_police_only'), 'error') end
    CreateThread(fn)
end

Framework.OnLoaded(function()
    local meta = Framework.PlayerData().metadata or {}
    if meta.ishandcuffed then
        SetTimeout(2500, function() Field.SetCuffed(true) end)
    end
end)

Framework.OnUnloaded(function()
    Field.SetCuffed(false)
    endEscort()
    Field.escorting = nil
end)

CreateThread(function()
    Wait(2000)
    local meta = Framework.PlayerData().metadata or {}
    if meta.ishandcuffed then Field.SetCuffed(true) end
end)
