Service = { state = nil, next = nil, busy = false, blip = nil }

local function pickNext(skip)
    local list = Service.state and Service.state.spots or {}
    if #list == 0 then return nil end
    local choices = {}
    for _, s in ipairs(list) do
        if s.id ~= skip or #list == 1 then choices[#choices + 1] = s end
    end
    return choices[math.random(1, #choices)]
end

local function clearBlip()
    if Service.blip and DoesBlipExist(Service.blip) then RemoveBlip(Service.blip) end
    Service.blip = nil
end

local function setNext(spot)
    Service.next = spot
    clearBlip()
    if not spot then return end
    local blip = AddBlipForCoord(spot.x + 0.0, spot.y + 0.0, spot.z + 0.0)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 17)
    SetBlipScale(blip, 0.75)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Text('service_hud'))
    EndTextCommandSetBlipName(blip)
    Service.blip = blip
end

local function groundOf(s)
    if s.gz then return s.gz end
    local found, ground = GetGroundZFor_3dCoord(s.x + 0.0, s.y + 0.0, s.z + 1.5, false)
    if (found == true or found == 1) and math.abs(ground - s.z) < 3.0 then
        s.gz = ground
        return ground
    end
    return s.z
end

local function hud()
    if not Service.state then return UI.Send('service', 'hide', {}) end
    UI.Send('service', 'show', { left = Service.state.left, reason = Service.state.reason, place = Service.state.place })
end

local function work(spot)
    if Service.busy then return end
    Service.busy = true
    local ok, seconds = Me.Await('serviceBegin', spot.id)
    if not ok then
        Service.busy = false
        return Me.Result(false, seconds)
    end
    local done = lib.progressCircle({
        duration = (tonumber(seconds) or 8) * 1000, label = Text('service_working'), position = 'bottom', canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = { scenario = 'WORLD_HUMAN_JANITOR' },
    })
    ClearPedTasks(PlayerPedId())
    if done and Service.state then
        local okTask, res = Me.Await('serviceTask', spot.id)
        if okTask and type(res) == 'table' and not res.done and Service.state then
            Service.state.left = res.left
            setNext(pickNext(spot.id))
            hud()
        elseif not okTask then
            Me.Result(false, res)
        end
    end
    Service.busy = false
end

local function loop()
    CreateThread(function()
        while Service.state do
            local s = Service.next
            local sleep = 500
            if s then
                local pos = GetEntityCoords(PlayerPedId())
                local flat = #(vector2(pos.x, pos.y) - vector2(s.x, s.y))
                if flat < 60.0 then
                    sleep = 0
                    local z = groundOf(s)
                    DrawMarker(1, s.x, s.y, z + 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.1, 1.1, 0.35, 255, 150, 30, 140, false, false, 2, false, nil, nil, false)
                    DrawMarker(2, s.x, s.y, z + 1.3, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.35, 0.35, 0.35, 255, 170, 60, 200, true, true, 2, false, nil, nil, false)
                    if flat < 1.4 and math.abs(pos.z - z) < 2.5 and not Service.busy then
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName(Text('service_hint'))
                        EndTextCommandDisplayHelp(0, false, false, -1)
                        if IsControlJustReleased(0, 38) then CreateThread(function() work(s) end) end
                    end
                end
            end
            DisablePlayerFiring(PlayerId(), true)
            Wait(sleep)
        end
        clearBlip()
    end)
end

RegisterNetEvent('XS-PoliceSystem:client:service', function(state)
    local fresh = Service.state == nil
    Service.state = state
    setNext(pickNext(nil))
    hud()
    if fresh then loop() end
end)

RegisterNetEvent('XS-PoliceSystem:client:serviceDone', function()
    Service.state = nil
    setNext(nil)
    hud()
end)

Framework.OnUnloaded(function()
    Service.state = nil
    setNext(nil)
    hud()
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then clearBlip() end
end)
