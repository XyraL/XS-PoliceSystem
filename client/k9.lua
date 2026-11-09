K9 = { dog = nil, follow = true, inCar = false, busy = false, mode = nil, token = 0 }

local SIT = { 'creatures@rottweiler@amb@world_dog_sitting@base', 'base' }
local BARK = { 'creatures@rottweiler@amb@world_dog_barking@idle_a', 'idle_a' }
local GROUP = 'XSP_K9'

local function cfg()
    return Config.K9 or {}
end

local function alive()
    return K9.dog ~= nil and DoesEntityExist(K9.dog) and not IsEntityDead(K9.dog)
end

local function need()
    if alive() then return true end
    Framework.Notify(Text('err_no_k9'), 'error')
    return false
end

local function relationship()
    AddRelationshipGroup(GROUP)
    local hash = joaat(GROUP)
    SetRelationshipBetweenGroups(3, hash, `PLAYER`)
    SetRelationshipBetweenGroups(3, `PLAYER`, hash)
    return hash
end

local function follow()
    if not alive() then return end
    ClearPedTasks(K9.dog)
    TaskFollowToOffsetOfEntity(K9.dog, PlayerPedId(), 0.6, -0.9, 0.0, 7.0, -1, 1.2, true)
    K9.follow = true
end

local function sit()
    ClearPedTasks(K9.dog)
    if Util.LoadAnim(SIT[1]) then TaskPlayAnim(K9.dog, SIT[1], SIT[2], 8.0, -8.0, -1, 1, 0.0, false, false, false) end
    K9.follow = false
end

local function bark()
    if Util.LoadAnim(BARK[1]) then TaskPlayAnim(K9.dog, BARK[1], BARK[2], 8.0, -8.0, 2500, 0, 0.0, false, false, false) end
end

local function begin(mode)
    K9.token = K9.token + 1
    K9.busy, K9.mode = true, mode
    ClearPedTasks(K9.dog)
    return K9.token
end

local function still(token)
    return alive() and K9.token == token
end

local function recall()
    K9.token = K9.token + 1
    K9.busy, K9.mode = false, nil
    follow()
end

local function finish(token, wasFollowing)
    if K9.token ~= token or not alive() then return end
    K9.token = K9.token + 1
    K9.busy, K9.mode = false, nil
    if wasFollowing then follow() else sit() end
end

local function waitNear(token, where, near, timeout)
    local untilAt = GetGameTimer() + timeout
    while still(token) and GetGameTimer() < untilAt do
        local p = where()
        if not p then return false end
        if #(GetEntityCoords(K9.dog) - p) <= near then return true end
        Wait(150)
    end
    return false
end

local function walkTo(token, p, speed, near, timeout)
    TaskFollowNavMeshToCoord(K9.dog, p.x + 0.0, p.y + 0.0, p.z + 0.0, speed or 2.0, -1, near or 0.4, false, 0.0)
    return waitNear(token, function() return p end, (near or 0.4) + 0.6, timeout or 4000)
end

local function goToPed(token, target, near, timeout)
    TaskGoToEntity(K9.dog, target, -1, near or 1.2, 3.0, 1073741824.0, 0)
    return waitNear(token, function() return DoesEntityExist(target) and GetEntityCoords(target) or nil end, (near or 1.2) + 0.6, timeout or 9000)
end

local function face(token, target, ms)
    if not still(token) or not DoesEntityExist(target) then return end
    TaskTurnPedToFaceEntity(K9.dog, target, ms)
    Wait(ms)
end

local function cuffed(serverId)
    local ok, on = pcall(function() return Player(serverId).state.xspCuffed end)
    return ok and on == true
end

function K9.Dismiss(quiet)
    if K9.dog and DoesEntityExist(K9.dog) then DeleteEntity(K9.dog) end
    K9.dog, K9.inCar, K9.busy, K9.mode = nil, false, false, nil
    K9.token = K9.token + 1
    if not quiet then Framework.Notify(Text('k9_dismissed'), 'inform') end
end

local function watch()
    CreateThread(function()
        while K9.dog do
            if not alive() then
                K9.Dismiss(true)
                Framework.Notify(Text('k9_lost'), 'error')
                break
            end
            if not Me.IsCop() then
                K9.Dismiss(true)
                break
            end
            if K9.follow and not K9.busy and not K9.inCar then
                local ped = PlayerPedId()
                local dist = #(GetEntityCoords(K9.dog) - GetEntityCoords(ped))
                if dist > 30.0 and GetVehiclePedIsIn(ped, false) == 0 then
                    local at = GetOffsetFromEntityInWorldCoords(ped, 0.6, -1.4, 0.0)
                    SetEntityCoords(K9.dog, at.x, at.y, at.z, false, false, false, false)
                    follow()
                end
            end
            Wait(1000)
        end
    end)
end

function K9.Call()
    if alive() then return K9.Dismiss() end
    local ped = PlayerPedId()
    local model = joaat(cfg().model or 'a_c_shepherd')
    if not Util.LoadModel(model) then return Framework.Notify(Text('err_failed'), 'error') end
    local at = GetOffsetFromEntityInWorldCoords(ped, 0.6, -1.4, 0.0)
    local dog = CreatePed(28, model, at.x, at.y, at.z, GetEntityHeading(ped), true, true)
    SetModelAsNoLongerNeeded(model)
    if not dog or dog == 0 then return Framework.Notify(Text('err_failed'), 'error') end
    local ok, err = Me.Await('k9', Me.NetId(dog))
    if not ok then
        DeleteEntity(dog)
        return Me.Result(false, err)
    end
    SetBlockingOfNonTemporaryEvents(dog, true)
    SetPedFleeAttributes(dog, 0, false)
    SetPedCombatAttributes(dog, 46, true)
    SetEntityInvincible(dog, cfg().invincible ~= false)
    SetPedRelationshipGroupHash(dog, relationship())
    K9.dog, K9.inCar, K9.busy, K9.mode = dog, false, false, nil
    follow()
    Framework.Notify(Text('k9_called'), 'success')
    watch()
end

function K9.ToggleFollow()
    if not need() or K9.inCar then return end
    if K9.busy then
        recall()
        return Framework.Notify(Text('k9_follow'), 'inform')
    end
    if K9.follow then
        sit()
        Framework.Notify(Text('k9_stay'), 'inform')
    else
        follow()
        Framework.Notify(Text('k9_follow'), 'inform')
    end
end

local function sniffTarget()
    if GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then return nil end
    local entity = Me.LookedAt(cfg().sniffRange or 8.0, K9.dog)
    if entity and IsEntityAPed(entity) and IsPedAPlayer(entity) then
        local vehicle = GetVehiclePedIsIn(entity, false)
        if vehicle ~= 0 then return 'vehicle', Me.NetId(vehicle), vehicle end
        local player = NetworkGetPlayerIndexFromPed(entity)
        if player and player ~= -1 then return 'person', GetPlayerServerId(player), entity end
    elseif entity and IsEntityAVehicle(entity) then
        return 'vehicle', Me.NetId(entity), entity
    end
    local player, other = Me.FacingPlayer(5.0)
    if player then return 'person', player, other end
    local vehicle = Me.NearestVehicle(6.0)
    if vehicle and vehicle ~= 0 then return 'vehicle', Me.NetId(vehicle), vehicle end
    return nil
end

local function aroundCar(vehicle)
    local min, max = GetModelDimensions(GetEntityModel(vehicle))
    local w, l = (max.x - min.x) / 2 + 0.7, (max.y - min.y) / 2 + 0.6
    local spots = {}
    for _, o in ipairs({ { w, l * 0.6 }, { w, -l * 0.6 }, { 0.0, -l }, { -w, -l * 0.6 }, { -w, l * 0.6 } }) do
        spots[#spots + 1] = GetOffsetFromEntityInWorldCoords(vehicle, o[1], o[2], 0.0)
    end
    local here, first, best = GetEntityCoords(K9.dog), 1, nil
    for i, p in ipairs(spots) do
        local d = #(p - here)
        if not best or d < best then first, best = i, d end
    end
    local out = {}
    for n = 0, #spots - 1 do out[#out + 1] = spots[(first - 1 + n) % #spots + 1] end
    return out
end

function K9.Search()
    if not need() or K9.inCar or K9.busy then return end
    local kind, target, entity = sniffTarget()
    if not kind or not target then return Framework.Notify(Text('err_nobody_near'), 'error') end
    local wasFollowing = K9.follow
    local token = begin('sniff')
    if kind == 'vehicle' then
        for _, p in ipairs(aroundCar(entity)) do
            if not still(token) then break end
            walkTo(token, p, 1.4, 0.4, 3500)
        end
    else
        goToPed(token, entity, 1.0, 9000)
        for _, side in ipairs({ 0.8, -0.8 }) do
            if not still(token) or not DoesEntityExist(entity) then break end
            walkTo(token, GetOffsetFromEntityInWorldCoords(entity, side, -0.3, 0.0), 1.0, 0.3, 2500)
        end
    end
    face(token, entity, 900)
    if not still(token) then return end
    local ok, hit = Me.Await('k9Sniff', kind, target)
    if not still(token) then return end
    if ok and hit then
        Framework.Notify(Text(kind == 'vehicle' and 'k9_alert_vehicle' or 'k9_alert_person'), 'error')
        bark()
        Wait(2600)
        if still(token) then sit() Wait(2500) end
    elseif ok then
        Framework.Notify(Text('k9_clear'), 'inform')
    else
        Me.Result(false, hit)
    end
    finish(token, wasFollowing)
end

local function attack(target)
    local token = begin('attack')
    SetPedCombatAttributes(K9.dog, 5, true)
    SetPedCombatAttributes(K9.dog, 46, true)
    SetPedCombatMovement(K9.dog, 3)
    SetPedCombatRange(K9.dog, 0)
    SetPedCombatAbility(K9.dog, 2)
    TaskCombatPed(K9.dog, target, 0, 16)
    SetPedKeepTask(K9.dog, true)
    local dog = K9.dog
    SetTimeout(math.floor((cfg().attackSeconds or 8) * 1000), function()
        if K9.dog == dog and K9.token == token and alive() then recall() end
    end)
end

function K9.Attack()
    if not need() or K9.inCar then return end
    local _, target = Me.PersonAhead(cfg().attackRange or 25.0, K9.dog)
    if not target or target == PlayerPedId() then return Framework.Notify(Text('err_nobody_near'), 'error') end
    attack(target)
    Framework.Notify(Text('k9_attack'), 'inform')
end

function K9.Bark()
    if not need() or K9.inCar or K9.busy then return end
    local _, target = Me.PersonAhead(15.0, K9.dog)
    local wasFollowing = K9.follow
    local token = begin('bark')
    if target then face(token, target, 800) end
    if still(token) then
        bark()
        Wait(2600)
    end
    finish(token, wasFollowing)
end

function K9.Guard()
    if not need() or K9.inCar then return end
    local serverId, target = Me.PersonAhead(10.0, K9.dog)
    if not target then return Framework.Notify(Text('err_nobody_near'), 'error') end
    local token = begin('guard')
    Framework.Notify(Text('k9_guard'), 'inform')
    if not goToPed(token, target, 1.4, 9000) then
        if K9.token == token then recall() end
        return
    end
    face(token, target, 700)
    if not still(token) then return end
    sit()
    local start = GetEntityCoords(target)
    local limit = cfg().guardDistance or 5.0
    local untilAt = GetGameTimer() + math.floor((cfg().guardMinutes or 5) * 60000)
    while still(token) and GetGameTimer() < untilAt do
        if not DoesEntityExist(target) or cuffed(serverId) then break end
        if GetVehiclePedIsIn(target, false) ~= 0 then
            Framework.Notify(Text('k9_guard_lost'), 'inform')
            break
        end
        if #(GetEntityCoords(target) - start) > limit or IsPedSprinting(target) then
            Framework.Notify(Text('k9_guard_flee'), 'error')
            return attack(target)
        end
        Wait(250)
    end
    if K9.token == token then recall() end
end

function K9.Track()
    if not need() or K9.inCar or K9.busy then return end
    local ok, info = Me.Await('k9Track')
    if not ok then return Me.Result(false, info) end
    if type(info) ~= 'table' then return Framework.Notify(Text('k9_no_trail'), 'inform') end
    local token = begin('track')
    Framework.Notify(Text('k9_tracking'), 'inform')
    local function pedOf()
        local player = GetPlayerFromServerId(info.target)
        local ped = (player and player ~= -1) and GetPlayerPed(player) or 0
        return ped ~= 0 and DoesEntityExist(ped) and ped or nil
    end
    local target = pedOf()
    if not target then
        walkTo(token, vector3(info.x, info.y, info.z), 3.0, 2.5, 15000)
        target = pedOf()
    end
    if not target or not goToPed(token, target, 1.6, 20000) then
        if K9.token == token then
            Framework.Notify(Text('k9_no_trail'), 'inform')
            recall()
        end
        return
    end
    face(token, target, 700)
    if not still(token) then return end
    Framework.Notify(Text('k9_found'), 'error')
    bark()
    Wait(2600)
    if still(token) then sit() end
    local untilAt = GetGameTimer() + 10000
    while still(token) and GetGameTimer() < untilAt do Wait(250) end
    if K9.token == token then recall() end
end

function K9.Car()
    if not need() then return end
    if K9.busy then recall() end
    if K9.inCar then
        local vehicle = GetVehiclePedIsIn(K9.dog, false)
        local at = GetOffsetFromEntityInWorldCoords(vehicle ~= 0 and vehicle or PlayerPedId(), -1.8, -1.2, 0.0)
        SetEntityCoords(K9.dog, at.x, at.y, at.z, false, false, false, false)
        K9.inCar = false
        follow()
        return
    end
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then vehicle = Me.NearestVehicle(6.0) end
    if not vehicle or vehicle == 0 then return Framework.Notify(Text('err_no_vehicle'), 'error') end
    for _, seat in ipairs({ 1, 2, 0 }) do
        if IsVehicleSeatFree(vehicle, seat) then
            ClearPedTasks(K9.dog)
            TaskWarpPedIntoVehicle(K9.dog, vehicle, seat)
            K9.inCar = true
            return
        end
    end
    Framework.Notify(Text('err_no_seat'), 'error')
end

Framework.OnUnloaded(function() K9.Dismiss(true) end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then K9.Dismiss(true) end
end)
