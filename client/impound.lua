ImpoundClient = { vehicle = nil }

local function lots()
    local out = {}
    local c = GetEntityCoords(PlayerPedId())
    for _, place in ipairs(Me.places or {}) do
        if place.kind == 'impound' then
            local p = Stations.BlipAt(place)
            out[#out + 1] = {
                id = place.id, name = place.name, fee = place.fee or 0,
                distance = p and math.floor(#(c - vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0))) or nil,
            }
        end
    end
    table.sort(out, function(a, b) return (a.distance or 1e9) < (b.distance or 1e9) end)
    return out
end

local function modelLabel(vehicle)
    local name = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local label = GetLabelText(name)
    if not label or label == 'NULL' then return name end
    return label
end

local function vehicleType(hash)
    if IsThisModelAHeli(hash) then return 'heli' end
    if IsThisModelAPlane(hash) then return 'plane' end
    if IsThisModelABike(hash) or IsThisModelAQuadbike(hash) then return 'bike' end
    if IsThisModelABoat(hash) then return 'boat' end
    return 'automobile'
end

local function run(vehicle, opts)
    local done = lib.progressCircle({
        duration = ((Config.Impound or {}).seconds or 6) * 1000, label = Text('impounding'), position = 'bottom', canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = { scenario = 'WORLD_HUMAN_CLIPBOARD' },
    })
    ClearPedTasks(PlayerPedId())
    if not done then return end
    if not DoesEntityExist(vehicle) then return Framework.Notify(Text('err_no_vehicle'), 'error') end
    opts = opts or {}
    opts.condition = { fuel = GetVehicleFuelLevel(vehicle) }
    local ok, msg = Me.Await('impound', Me.NetId(vehicle), opts)
    Me.Result(ok, msg)
end

function ImpoundClient.Start()
    local vehicle = Me.NearestVehicle(5.0)
    if vehicle == 0 then return Framework.Notify(Text('err_no_vehicle'), 'error') end
    if GetVehiclePedIsIn(PlayerPedId(), false) == vehicle then return Framework.Notify(Text('err_get_out'), 'error') end
    local list = lots()
    if #list == 0 then return run(vehicle, nil) end
    local I = Config.Impound or {}
    ImpoundClient.vehicle = vehicle
    Panels.Open('impound', {
        plate = Util.Text(GetVehicleNumberPlateText(vehicle), 16), model = modelLabel(vehicle), lots = list,
        holds = I.holds or { 0, 24 }, hold = I.defaultHold or 0, maxHours = I.maxHours or 168, minFee = I.minFee or 0, maxFee = I.maxFee or 25000,
    })
end

UI.Handle('impound:submit', function(p)
    if type(p) ~= 'table' then return false end
    local vehicle = ImpoundClient.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then
        Panels.Close('impound')
        return false, Text('err_no_vehicle')
    end
    if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(vehicle)) > 8.0 then return false, Text('err_too_far') end
    local reason = Util.Text(p.reason, 160)
    if reason == '' then return false, Text('err_need_reason') end
    Panels.Close('impound')
    ImpoundClient.vehicle = nil
    CreateThread(function()
        run(vehicle, { lot = tonumber(p.lot), hours = tonumber(p.hours), fee = tonumber(p.fee), reason = reason, policeHold = p.policeHold == true })
    end)
    return true
end)

local function prepare(info)
    local vehicle = 0
    local timeout = GetGameTimer() + 10000
    while GetGameTimer() < timeout do
        if NetworkDoesNetworkIdExist(info.netId) then
            vehicle = NetworkGetEntityFromNetworkId(info.netId)
            if vehicle ~= 0 and DoesEntityExist(vehicle) then break end
        end
        Wait(100)
    end
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local deadline = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < deadline do
        NetworkRequestControlOfEntity(vehicle)
        Wait(50)
    end
    if type(info.mods) == 'table' and next(info.mods) then pcall(lib.setVehicleProperties, vehicle, info.mods) end
    SetVehicleNumberPlateText(vehicle, info.plate)
    if tonumber(info.engine) then SetVehicleEngineHealth(vehicle, tonumber(info.engine) + 0.0) end
    if tonumber(info.body) then SetVehicleBodyHealth(vehicle, tonumber(info.body) + 0.0) end
    Fuel.Set(vehicle, (tonumber(info.fuel) or 100.0) + 0.0)
    SetVehicleOnGroundProperly(vehicle)
end

UI.Handle('impoundlot:refresh', function(p)
    if type(p) ~= 'table' then return false end
    local ok, data = Me.Await('impoundDesk', p.place, p.point)
    if not ok then return false, data end
    data.place, data.point = p.place, p.point
    return true, data
end)

UI.Handle('impoundlot:release', function(p)
    if type(p) ~= 'table' then return false end
    local hash = joaat(tostring(p.model or ''))
    local kind = IsModelInCdimage(hash) and vehicleType(hash) or 'automobile'
    local ok, info = Me.Await('impoundRelease', p.place, p.point, p.id, kind)
    if not ok then return false, info end
    Panels.Close('impoundlot')
    CreateThread(function() prepare(info) end)
    return true, Text('impound_released', { plate = info.plate })
end)

UI.Handle('impoundlot:manage', function(p)
    if type(p) ~= 'table' then return false end
    return Me.Await('impoundManage', p.place, p.point, p.id, p.action)
end)
