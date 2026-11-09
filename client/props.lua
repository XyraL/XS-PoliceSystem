Props = { placing = false, spikes = {} }

local WHEELS = { { bone = 'wheel_lf', tyre = 0 }, { bone = 'wheel_rf', tyre = 1 }, { bone = 'wheel_lm1', tyre = 2 }, { bone = 'wheel_rm1', tyre = 3 }, { bone = 'wheel_lr', tyre = 4 }, { bone = 'wheel_rr', tyre = 5 } }
local CONFIRM, CANCEL, BACK, SCROLL_UP, SCROLL_DOWN = 38, 177, 25, 15, 14

local function modelFor(kind)
    if kind == 'spikes' then return Config.Spikes.model end
    local def = (Config.Props.list or {})[kind]
    return def and def.model
end

local function ground(x, y, z)
    local found, gz = GetGroundZFor_3dCoord(x, y, z + 1.0, false)
    if found == true or found == 1 then return gz end
    return z - 1.0
end

function Props.Place(kind)
    if Props.placing then return end
    local model = modelFor(kind)
    if not model then return end
    local hash = joaat(model)
    if not Util.LoadModel(hash) then return Framework.Notify(Text('err_bad_model', { model = model }), 'error') end
    Props.placing = true
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local ghost = CreateObjectNoOffset(hash, c.x, c.y, c.z, false, false, false)
    SetEntityAlpha(ghost, 150, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    SetModelAsNoLongerNeeded(hash)
    local turn = 0.0
    local reach = kind == 'spikes' and 3.0 or 1.6
    local result
    lib.showTextUI(Text('prop_place_hint'), { position = 'right-center' })
    while Props.placing do
        ped = PlayerPedId()
        if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then break end
        DisableControlAction(0, SCROLL_UP, true)
        DisableControlAction(0, SCROLL_DOWN, true)
        DisableControlAction(0, BACK, true)
        DisableControlAction(0, 24, true)
        DisablePlayerFiring(PlayerId(), true)
        local heading = GetEntityHeading(ped)
        local at = GetOffsetFromEntityInWorldCoords(ped, 0.0, reach, 0.0)
        local z = ground(at.x, at.y, at.z)
        if IsDisabledControlJustPressed(0, SCROLL_UP) then turn = turn + 10.0 end
        if IsDisabledControlJustPressed(0, SCROLL_DOWN) then turn = turn - 10.0 end
        local h = (heading + turn + (kind == 'spikes' and 90.0 or 0.0)) % 360.0
        SetEntityCoordsNoOffset(ghost, at.x, at.y, z, false, false, false)
        SetEntityHeading(ghost, h)
        PlaceObjectOnGroundProperly(ghost)
        if IsControlJustPressed(0, CONFIRM) then
            local p = GetEntityCoords(ghost)
            result = { x = p.x, y = p.y, z = p.z, w = h }
            break
        end
        if IsControlJustPressed(0, CANCEL) or IsDisabledControlJustPressed(0, BACK) then break end
        Wait(0)
    end
    lib.hideTextUI()
    if DoesEntityExist(ghost) then DeleteObject(ghost) end
    Props.placing = false
    if not result then return end
    if Util.LoadAnim('pickup_object') then
        TaskPlayAnim(PlayerPedId(), 'pickup_object', 'pickup_low', 8.0, -8.0, 1200, 48, 0.0, false, false, false)
    end
    local ok, err = Me.Await('placeProp', kind, result)
    if not ok then Framework.Notify(err or Text('err_failed'), 'error') end
end

local function modelNames()
    local list = { Config.Spikes.model }
    for _, def in pairs(Config.Props.list or {}) do list[#list + 1] = def.model end
    return list
end

local function propModels()
    local set = {}
    for _, name in ipairs(modelNames()) do set[joaat(name)] = true end
    return set
end

local function reachOf(obj, c)
    local mn, mx = GetModelDimensions(GetEntityModel(obj))
    local rel = GetOffsetFromEntityGivenWorldCoords(obj, c.x, c.y, c.z)
    local dx = math.max(mn.x - rel.x, 0.0, rel.x - mx.x)
    local dy = math.max(mn.y - rel.y, 0.0, rel.y - mx.y)
    return math.sqrt(dx * dx + dy * dy)
end

function Props.Remove(obj)
    if not obj or obj == 0 or not DoesEntityExist(obj) or not NetworkGetEntityIsNetworked(obj) then
        return Framework.Notify(Text('err_no_prop'), 'error')
    end
    if Util.LoadAnim('pickup_object') then
        TaskPlayAnim(PlayerPedId(), 'pickup_object', 'pickup_low', 8.0, -8.0, 1200, 48, 0.0, false, false, false)
    end
    local ok, msg = Me.Await('removeProp', NetworkGetNetworkIdFromEntity(obj))
    Me.Result(ok, msg)
end

function Props.RemoveNearest()
    local models = propModels()
    local c = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, 2.5
    for _, obj in ipairs(GetGamePool('CObject')) do
        if models[GetEntityModel(obj)] and NetworkGetEntityIsNetworked(obj) and #(GetEntityCoords(obj) - c) < 12.0 then
            local d = reachOf(obj, c)
            if d < bestDist then best, bestDist = obj, d end
        end
    end
    Props.Remove(best)
end

CreateThread(function()
    Wait(1500)
    Target.AddModels('props', modelNames(), {
        {
            label = Text('wheel_removeProp'), icon = 'fa-solid fa-hand', distance = 3.0,
            canInteract = function(entity)
                return Me.IsCop() and entity ~= 0 and NetworkGetEntityIsNetworked(entity) and not IsPedInAnyVehicle(PlayerPedId(), false)
            end,
            onSelect = function(entity) Props.Remove(entity) end,
        },
    })
end)

AddStateBagChangeHandler('xspSpikes', nil, function(bagName, _, value)
    if not value then return end
    CreateThread(function()
        local entity = 0
        for _ = 1, 50 do
            entity = GetEntityFromStateBagName(bagName)
            if entity ~= 0 then break end
            Wait(100)
        end
        if entity ~= 0 then Props.spikes[entity] = true end
    end)
end)

local function overStrip(strip, point, mn, mx)
    local rel = GetOffsetFromEntityGivenWorldCoords(strip, point.x, point.y, point.z)
    return rel.x >= mn.x - 0.1 and rel.x <= mx.x + 0.1 and rel.y >= mn.y - 0.25 and rel.y <= mx.y + 0.25 and math.abs(rel.z) < 1.2
end

CreateThread(function()
    local mn, mx
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped and next(Props.spikes) then
            local vc = GetEntityCoords(vehicle)
            for strip in pairs(Props.spikes) do
                if not DoesEntityExist(strip) then
                    Props.spikes[strip] = nil
                else
                    local d = #(GetEntityCoords(strip) - vc)
                    if d < 25.0 then
                        sleep = 0
                        if not mn then mn, mx = GetModelDimensions(GetEntityModel(strip)) end
                        for _, w in ipairs(WHEELS) do
                            local bone = GetEntityBoneIndexByName(vehicle, w.bone)
                            if bone ~= -1 and not IsVehicleTyreBurst(vehicle, w.tyre, false) then
                                local at = GetWorldPositionOfEntityBone(vehicle, bone)
                                if overStrip(strip, at, mn, mx) then SetVehicleTyreBurst(vehicle, w.tyre, true, 1000.0) end
                            end
                        end
                    elseif d < 120.0 then
                        sleep = math.min(sleep, 150)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
