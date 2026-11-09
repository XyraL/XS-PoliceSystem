Stations = { keys = {}, blips = {}, clerks = {}, built = false }

local ICONS = {
    duty = 'fa-solid fa-clock', locker = 'fa-solid fa-shirt', armory = 'fa-solid fa-gun', garage = 'fa-solid fa-car',
    helipad = 'fa-solid fa-helicopter', evidence = 'fa-solid fa-box-archive', lab = 'fa-solid fa-flask', booking = 'fa-solid fa-id-card', boss = 'fa-solid fa-star', camroom = 'fa-solid fa-video',
    store = 'fa-solid fa-square-parking', stash = 'fa-solid fa-lock', job = 'fa-solid fa-wrench', canteen = 'fa-solid fa-utensils',
    collect = 'fa-solid fa-bag-shopping', workout = 'fa-solid fa-dumbbell', desk = 'fa-solid fa-car-on',
    clerk = 'fa-solid fa-cash-register', trader = 'fa-solid fa-smoking', craft = 'fa-solid fa-screwdriver-wrench', tunnel = 'fa-solid fa-person-digging', fence = 'fa-solid fa-scissors',
    hide = 'fa-solid fa-box-open', bed = 'fa-solid fa-bed',
}

local function v3(p) return vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0) end

local function clear()
    for _, key in ipairs(Stations.keys) do Target.Remove(key) end
    Stations.keys = {}
    for _, blip in ipairs(Stations.blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    Stations.blips = {}
end

local function serves(place)
    local job = Framework.Job()
    if not job or not Util.IsCopJob(job) then return false end
    if #(place.jobs or {}) == 0 then return true end
    for _, name in ipairs(place.jobs) do
        if name == job.name then return true end
    end
    return false
end

local function onDuty()
    return Me.IsCop()
end

local function firstPoint(place)
    for _, list in pairs(place.points or {}) do
        if list[1] then return list[1] end
    end
    return nil
end

function Stations.BlipAt(place)
    return place.blipAt or place.center or firstPoint(place)
end

function Stations.MakeBlip(p, b, label)
    local blip = AddBlipForCoord(p.x + 0.0, p.y + 0.0, p.z + 0.0)
    SetBlipSprite(blip, math.floor(tonumber(b.sprite) or 1))
    SetBlipColour(blip, math.floor(tonumber(b.colour) or 0))
    SetBlipScale(blip, (tonumber(b.scale) or 0.8) + 0.0)
    SetBlipAsShortRange(blip, b.short ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or '')
    EndTextCommandSetBlipName(blip)
    return blip
end

local function blipVisible(b)
    if b.who ~= 'police' and b.who ~= 'duty' then return true end
    local job = Framework.Job()
    if not job or not Util.IsCopJob(job) then return false end
    return b.who == 'police' or Me.IsCop()
end

local function addBlip(place)
    local b = type(place.blip) == 'table' and place.blip or { show = place.blip ~= false }
    if b.show == false or not blipVisible(b) then return end
    local p = Stations.BlipAt(place)
    if not p then return end
    local B = (Config.Blips or {})[place.kind] or {}
    b.sprite, b.colour, b.scale = b.sprite or B.sprite, b.colour or B.colour, b.scale or B.scale
    Stations.blips[#Stations.blips + 1] = Stations.MakeBlip(p, b, (b.label and b.label ~= '') and b.label or place.name)
end

local function add(place, kind, p, options)
    local key = ('%s_%s_%s'):format(place.id, kind, p.id)
    Target.AddPoint(key, v3(p), 1.2, options)
    Stations.keys[#Stations.keys + 1] = key
end

local function openStash(info)
    Inventory.OpenStash(info.mode, info.id, info.label, info.slots, info.weight)
end

local function vehicleType(model)
    local hash = joaat(model)
    if IsThisModelAHeli(hash) then return 'heli' end
    if IsThisModelAPlane(hash) then return 'plane' end
    if IsThisModelABike(hash) or IsThisModelAQuadbike(hash) then return 'bike' end
    if IsThisModelABoat(hash) then return 'boat' end
    return 'automobile'
end

local function takeVehicle(info)
    DoScreenFadeOut(300)
    local vehicle = 0
    local timeout = GetGameTimer() + 10000
    while GetGameTimer() < timeout do
        if NetworkDoesNetworkIdExist(info.netId) then
            vehicle = NetworkGetEntityFromNetworkId(info.netId)
            if vehicle ~= 0 and DoesEntityExist(vehicle) then break end
        end
        Wait(100)
    end
    if vehicle == 0 then
        DoScreenFadeIn(400)
        return Framework.Notify(Text('err_spawn_failed'), 'error')
    end
    local untilControl = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < untilControl do
        NetworkRequestControlOfEntity(vehicle)
        Wait(50)
    end
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleModKit(vehicle, 0)
    if (info.livery or -1) >= 0 then
        SetVehicleLivery(vehicle, info.livery)
        SetVehicleMod(vehicle, 48, info.livery, false)
    end
    if info.extras and #info.extras > 0 then
        local wanted = {}
        for _, e in ipairs(info.extras) do wanted[e] = true end
        for id = 0, 20 do
            if DoesExtraExist(vehicle, id) then SetVehicleExtra(vehicle, id, not wanted[id]) end
        end
    end
    SetVehicleDirtLevel(vehicle, 0.0)
    Fuel.Set(vehicle, Config.Garage.fuel or 100.0)
    SetVehicleEngineOn(vehicle, true, true, false)
    local ped = PlayerPedId()
    local untilSeat = GetGameTimer() + 5000
    while GetVehiclePedIsIn(ped, false) ~= vehicle and GetGameTimer() < untilSeat do
        SetPedIntoVehicle(ped, vehicle, -1)
        Wait(100)
    end
    DoScreenFadeIn(400)
end

function Stations.SpawnVehicle(placeId, pointId, kind, model)
    local place
    for _, pl in ipairs(Me.places) do if pl.id == placeId then place = pl break end end
    local p
    for _, point in ipairs(place and place.points[kind] or {}) do if point.id == pointId then p = point break end end
    if not p then return false, Text('err_failed') end
    local spawn = p.spawn or p
    if IsAnyVehicleNearPoint(spawn.x + 0.0, spawn.y + 0.0, spawn.z + 0.0, 3.0) then return false, Text('err_spawn_blocked') end
    if not IsModelInCdimage(joaat(model)) then return false, Text('err_bad_model', { model = model }) end
    local ok, info = Me.Await('spawnVehicle', placeId, pointId, kind, model, vehicleType(model))
    if not ok then return false, info end
    CreateThread(function() takeVehicle(info) end)
    return true
end

local function storeVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then vehicle = lib.getClosestVehicle(GetEntityCoords(ped), 8.0, true) or 0 end
    if vehicle == 0 or not Entity(vehicle).state.xspVehicle then return Framework.Notify(Text('err_not_station_vehicle'), 'error') end
    if GetVehiclePedIsIn(ped, false) == vehicle then
        TaskLeaveVehicle(ped, vehicle, 0)
        Wait(1200)
    end
    local ok, err = Me.Await('storeVehicle', NetworkGetNetworkIdFromEntity(vehicle))
    Me.Result(ok, ok and Text('vehicle_stored') or err)
end

local function nearStationVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then vehicle = lib.getClosestVehicle(GetEntityCoords(ped), 8.0, true) or 0 end
    return vehicle ~= 0 and Entity(vehicle).state.xspVehicle == true
end

local function stationPoints(place)
    if not serves(place) then return end
    for _, p in ipairs(place.points.duty or {}) do
        add(place, 'duty', p, { {
            label = Text('duty_toggle'), icon = ICONS.duty,
            onSelect = function()
                local ok, on = Me.Await('duty', place.id, p.id)
                if ok then Framework.Notify(Text(on and 'duty_on' or 'duty_off'), 'success') else Framework.Notify(on or Text('err_failed'), 'error') end
            end,
        } })
    end
    for _, p in ipairs(place.points.locker or {}) do
        add(place, 'locker', p, {
            { label = Text('locker_outfits'), icon = ICONS.locker, onSelect = function()
                if not Clothing.OpenOutfits() then Framework.Notify(Text('err_no_clothing'), 'error') end
            end },
            { label = Text('locker_open'), icon = ICONS.stash, onSelect = function()
                local ok, info = Me.Await('locker', place.id, p.id)
                if ok then openStash(info) else Framework.Notify(info or Text('err_failed'), 'error') end
            end },
        })
    end
    for _, p in ipairs(place.points.armory or {}) do
        add(place, 'armory', p, { { label = Text('armory_open'), icon = ICONS.armory, canInteract = onDuty, onSelect = function()
            local ok, data = Me.Await('armory', place.id, p.id)
            if not ok then return Framework.Notify(data or Text('err_failed'), 'error') end
            Panels.Open('armory', { place = place.id, point = p.id, station = data.station, items = data.items })
        end } })
    end
    for _, kind in ipairs({ 'garage', 'helipad' }) do
        for _, p in ipairs(place.points[kind] or {}) do
            add(place, kind, p, {
                { label = Text(kind == 'helipad' and 'helipad_open' or 'garage_open'), icon = ICONS[kind], canInteract = onDuty, onSelect = function()
                    local ok, data = Me.Await('garage', place.id, p.id, kind)
                    if not ok then return Framework.Notify(data or Text('err_failed'), 'error') end
                    Panels.Open('garage', { place = place.id, point = p.id, kind = kind, station = data.station, vehicles = data.vehicles })
                end },
                { label = Text('vehicle_store'), icon = ICONS.store, canInteract = nearStationVehicle, onSelect = storeVehicle },
            })
        end
    end
    for _, p in ipairs(place.points.evidence or {}) do
        add(place, 'evidence', p, { { label = Text('evidence_open'), icon = ICONS.evidence, canInteract = onDuty, onSelect = function()
            local ok, data = Me.Await('evidence', place.id, p.id)
            if not ok then return Framework.Notify(data or Text('err_failed'), 'error') end
            data.place, data.point = place.id, p.id
            Panels.Open('evidence', data)
        end } })
    end
    for _, p in ipairs(Evidence.Ours() and place.points.lab or {}) do
        add(place, 'lab', p, { { label = Text('lab_open'), icon = ICONS.lab, canInteract = onDuty, onSelect = function()
            local ok, data = Me.Await('labOpen', place.id, p.id)
            if not ok then return Framework.Notify(data or Text('err_failed'), 'error') end
            data.place, data.point = place.id, p.id
            Panels.Open('lab', data)
        end } })
    end
    for _, p in ipairs(place.points.booking or {}) do
        add(place, 'booking', p, { { label = Text('booking_open'), icon = ICONS.booking, canInteract = onDuty, onSelect = function()
            Field.Jail()
        end }, { label = Text('mugshot_take'), icon = 'fa-solid fa-camera', canInteract = onDuty, onSelect = function()
            CreateThread(Booking.Mugshot)
        end } })
    end
    for _, p in ipairs(place.points.boss or {}) do
        add(place, 'boss', p, { { label = Text('boss_open'), icon = ICONS.boss, onSelect = function()
            local ok, data = Me.Await('boss', place.id, p.id)
            if not ok then return Framework.Notify(data or Text('err_failed'), 'error') end
            data.place, data.point = place.id, p.id
            Panels.Open('office', data)
        end } })
    end
    for _, p in ipairs(place.points.camroom or {}) do
        add(place, 'camroom', p, { { label = Text('unitcams_open'), icon = ICONS.camroom, canInteract = onDuty, onSelect = function()
            UnitCams.Open({ place = place.id, point = p.id, station = place.name })
        end } })
    end
end

local function inside()
    return JailClient.Inside()
end

local function bedStash()
    return (Config.Jail.bedStash or {}).enabled ~= false and JailClient.Inside()
end

local function jailPoints(place)
    for _, work in ipairs(place.work or {}) do
        for _, spot in ipairs(work.spots or {}) do
            add(place, 'work_' .. work.id, spot, { { label = work.label, icon = ICONS.job, canInteract = inside, onSelect = function()
                JailClient.Work(work, spot)
            end } })
        end
    end
    for _, p in ipairs(place.points.workout or {}) do
        local def = (Config.Jail.exercises or {})[p.exercise] or {}
        add(place, 'workout', p, { { label = def.label or Text('point_workout'), icon = ICONS.workout, canInteract = inside, onSelect = function()
            JailClient.Workout(p)
        end } })
    end
    for _, p in ipairs(place.points.canteen or {}) do
        add(place, 'canteen', p, { { label = Text('canteen_take'), icon = ICONS.canteen, canInteract = inside, onSelect = function()
            JailClient.Canteen(p)
        end } })
    end
    for _, p in ipairs(place.points.clerk or {}) do
        add(place, 'clerk', p, { { label = Text('commissary_open'), icon = ICONS.clerk, canInteract = inside, onSelect = function() InmateClient.Commissary(p) end } })
    end
    for _, p in ipairs(place.points.trader or {}) do
        add(place, 'trader', p, { { label = Text('trader_open'), icon = ICONS.trader, canInteract = inside, onSelect = function() InmateClient.Trader(p) end } })
    end
    for _, p in ipairs(place.points.craft or {}) do
        add(place, 'craft', p, { { label = Text('workbench_open'), icon = ICONS.craft, canInteract = inside, onSelect = function() InmateClient.Workbench(p) end } })
    end
    for _, p in ipairs(place.points.hide or {}) do
        add(place, 'hide', p, { { label = Text('hide_open'), icon = ICONS.hide, canInteract = inside, onSelect = function() InmateClient.Stash('hiddenStash', p) end } })
    end
    for _, p in ipairs(place.points.cell or {}) do
        add(place, 'bed', p, { { label = Text('bed_open'), icon = ICONS.bed, canInteract = bedStash, onSelect = function() InmateClient.Stash('bedStash', p) end } })
    end
    for _, kind in ipairs({ 'tunnel', 'fence' }) do
        for _, p in ipairs(place.points[kind] or {}) do
            add(place, kind, p, { { label = Text(kind == 'tunnel' and 'tunnel_dig' or 'fence_cut'), icon = ICONS[kind], canInteract = inside, onSelect = function() InmateClient.Dig(kind, p) end } })
        end
    end
    for _, p in ipairs(place.points.release or {}) do
        add(place, 'release', p, { { label = Text('collect_belongings'), icon = ICONS.collect, canInteract = function() return not JailClient.Inside() end, onSelect = function()
            local ok, msg = Me.Await('collect')
            Me.Result(ok, msg)
        end } })
    end
end

function Stations.OpenStash(info)
    openStash(info)
end

local function impoundPoints(place)
    for _, p in ipairs(place.points.desk or {}) do
        add(place, 'desk', p, { { label = Text('impound_desk_open'), icon = ICONS.desk, onSelect = function()
            local ok, data = Me.Await('impoundDesk', place.id, p.id)
            if not ok then return Framework.Notify(data or Text('err_failed'), 'error') end
            data.place, data.point = place.id, p.id
            Panels.Open('impoundlot', data)
        end } })
    end
end

function Stations.Build()
    clear()
    for _, place in ipairs(Me.places or {}) do
        if place.kind == 'station' then
            stationPoints(place)
        elseif place.kind == 'jail' then
            jailPoints(place)
        elseif place.kind == 'impound' then
            impoundPoints(place)
        end
        addBlip(place)
    end
end

local function dropClerk(key)
    local ped = Stations.clerks[key]
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
    Stations.clerks[key] = nil
end

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    clear()
    for key in pairs(Stations.clerks) do dropClerk(key) end
end)

local function spawnClerk(model, p)
    if not Util.LoadModel(model) then return nil end
    local hash = joaat(model)
    local ped = CreatePed(4, hash, p.x + 0.0, p.y + 0.0, p.z + 0.0, (p.w or 0.0) + 0.0, false, true)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return nil end
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    return ped
end

CreateThread(function()
    while true do
        local c = GetEntityCoords(PlayerPedId())
        local wanted = {}
        for _, place in ipairs(Me.places or {}) do
            if place.kind == 'impound' and type(place.clerk) == 'string' and place.clerk ~= '' then
                for _, p in ipairs(place.points.desk or {}) do
                    local key = ('%s_%s_%s'):format(place.id, p.id, place.clerk)
                    if #(c - v3(p)) < 80.0 then
                        wanted[key] = true
                        if not Stations.clerks[key] or not DoesEntityExist(Stations.clerks[key]) then
                            Stations.clerks[key] = spawnClerk(place.clerk, p)
                        end
                    end
                end
            end
        end
        for key in pairs(Stations.clerks) do
            if not wanted[key] then dropClerk(key) end
        end
        Wait(1500)
    end
end)

local function markerPoints()
    local out = {}
    local inside = JailClient and JailClient.Inside()
    for _, place in ipairs(Me.places or {}) do
        if place.markers == true then
            if place.kind == 'station' and serves(place) then
                for _, list in pairs(place.points or {}) do
                    for _, p in ipairs(list) do out[#out + 1] = p end
                end
            elseif place.kind == 'jail' then
                for _, kind in ipairs(inside and { 'canteen', 'workout' } or { 'release' }) do
                    for _, p in ipairs(place.points[kind] or {}) do out[#out + 1] = p end
                end
                if inside then
                    for _, work in ipairs(place.work or {}) do
                        for _, spot in ipairs(work.spots or {}) do out[#out + 1] = spot end
                    end
                end
            elseif place.kind == 'impound' then
                for _, p in ipairs(place.points.desk or {}) do out[#out + 1] = p end
            end
        end
    end
    return out
end

CreateThread(function()
    local points, builtAt = {}, 0
    while true do
        local sleep = 1500
        if GetGameTimer() - builtAt > 1000 then
            points, builtAt = markerPoints(), GetGameTimer()
        end
        local c = GetEntityCoords(PlayerPedId())
        for _, p in ipairs(points) do
            local d = #(c - vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0))
            if d < 12.0 then
                sleep = 0
                DrawMarker(27, p.x + 0.0, p.y + 0.0, p.z + 0.03, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.7, 0.7, 0.7, 59, 130, 246, d < 2.0 and 160 or 90, false, false, 2, true, nil, nil, false)
            elseif d < 40.0 then
                sleep = math.min(sleep, 400)
            end
        end
        Wait(sleep)
    end
end)
