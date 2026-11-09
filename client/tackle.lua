local DIVE_DICT, DIVE_CLIP = 'missmic2ig_11', 'mic_2_ig_11_intro_goon'
local lastTackle = 0

local function inFront(range)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local best, bestDist = nil, range
    for _, player in ipairs(GetActivePlayers()) do
        local other = GetPlayerPed(player)
        if other ~= ped and other ~= 0 and not IsPedInAnyVehicle(other, false) and not IsEntityDead(other) then
            local diff = GetEntityCoords(other) - pos
            local dist = #diff
            if dist > 0.1 and dist <= bestDist and (diff.x * fwd.x + diff.y * fwd.y) / dist > 0.4 then
                best, bestDist = GetPlayerServerId(player), dist
            end
        end
    end
    return best
end

local function tackle()
    local c = Config.Tackle or {}
    if not c.enabled or (Wheel and Wheel.open) then return end
    if not c.anyone and not Me.IsCop() then return end
    local ped = PlayerPedId()
    if Field.cuffed or IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) or IsPedRagdoll(ped) or not IsPedSprinting(ped) then return end
    local now = GetGameTimer()
    if now - lastTackle < (c.cooldown or 10) * 1000 then return end
    local target = inFront(c.range or 2.5)
    if not target then return end
    lastTackle = now
    TriggerServerEvent('XS-PoliceSystem:server:tackle', target)
    if Util.LoadAnim(DIVE_DICT) then
        TaskPlayAnim(ped, DIVE_DICT, DIVE_CLIP, 8.0, -8.0, 3000, 0, 0.0, false, false, false)
    end
    Wait(900)
    SetPedToRagdoll(ped, 1200, 1200, 0, false, false, false)
end

RegisterNetEvent('XS-PoliceSystem:client:tackled', function(_, heading)
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then return end
    local ms = ((Config.Tackle or {}).seconds or 4) * 1000
    local h = math.rad(tonumber(heading) or GetEntityHeading(ped))
    SetPedToRagdoll(ped, ms, ms, 0, false, false, false)
    ApplyForceToEntityCenterOfMass(ped, 1, -math.sin(h) * 6.0, math.cos(h) * 6.0, 0.0, false, false, true, false)
    Framework.Notify(Text('tackled_you'), 'error')
end)

do
    local command = (Config.Tackle or {}).command or 'policetackle'
    RegisterCommand('+' .. command, function() CreateThread(tackle) end, false)
    RegisterCommand('-' .. command, function() end, false)
    RegisterKeyMapping('+' .. command, Text('keybind_tackle'), 'keyboard', (Config.Tackle or {}).key or 'G')
end
