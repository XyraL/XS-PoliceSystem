Scene = { zones = {} }

local function addZone(z)
    if type(z) ~= 'table' or not z.id or Scene.zones[z.id] then return end
    local handle = AddRoadNodeSpeedZone(z.x + 0.0, z.y + 0.0, z.z + 0.0, z.radius + 0.0, z.speed + 0.0, false)
    local blip
    if Me.IsCop() then
        blip = AddBlipForRadius(z.x + 0.0, z.y + 0.0, z.z + 0.0, z.radius + 0.0)
        SetBlipColour(blip, z.kind == 'stop' and 1 or 5)
        SetBlipAlpha(blip, 90)
    end
    Scene.zones[z.id] = { handle = handle, blip = blip, kind = z.kind }
end

local function removeZone(id)
    local z = Scene.zones[id]
    if not z then return end
    if z.handle then RemoveRoadNodeSpeedZone(z.handle) end
    if z.blip and DoesBlipExist(z.blip) then RemoveBlip(z.blip) end
    Scene.zones[id] = nil
end

RegisterNetEvent('XS-PoliceSystem:client:traffic', function(action, data)
    if action == 'add' then addZone(data) elseif action == 'remove' then removeZone(data) end
end)

function Scene.Traffic(kind)
    local ok, msg = Me.Await('traffic', kind)
    Me.Result(ok, msg)
end

function Scene.SearchVehicle()
    local ped = PlayerPedId()
    local inside = GetVehiclePedIsIn(ped, false)
    local vehicle = inside ~= 0 and inside or Me.NearestVehicle(4.0)
    if not vehicle or vehicle == 0 then return Framework.Notify(Text('err_no_vehicle'), 'error') end
    if inside == 0 then
        TaskTurnPedToFaceEntity(ped, vehicle, 800)
        SetVehicleDoorOpen(vehicle, 5, false, false)
    end
    local ok, msg = Me.Await('searchVehicle', Me.NetId(vehicle), inside ~= 0)
    if not ok then Me.Result(false, msg) end
end

CreateThread(function()
    while not Framework.Loaded() do Wait(1000) end
    Wait(2000)
    local list = Me.Await('trafficZones')
    for _, z in ipairs(type(list) == 'table' and list or {}) do addZone(z) end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for id in pairs(Scene.zones) do removeZone(id) end
end)
