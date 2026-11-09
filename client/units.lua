Units = { blips = {}, at = 0 }

local SPRITES = { foot = 1, car = 56, bike = 56, heli = 43, plane = 423, boat = 427 }

local function colour(job)
    local list = (Config.UnitBlips or {}).colours or {}
    return list[job] or 38
end

local function clear(src)
    local b = Units.blips[src]
    if b and DoesBlipExist(b.blip) then RemoveBlip(b.blip) end
    Units.blips[src] = nil
end

local function clearAll()
    for src in pairs(Units.blips) do clear(src) end
end

local function style(blip, u)
    SetBlipSprite(blip, SPRITES[u.k] or 1)
    SetBlipColour(blip, u.p and 1 or colour(u.j))
    SetBlipScale(blip, u.k == 'foot' and 0.8 or 0.9)
    SetBlipAsShortRange(blip, true)
    SetBlipCategory(blip, 7)
    ShowHeadingIndicatorOnBlip(blip, u.k == 'foot')
    SetBlipFlashes(blip, u.p == true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(u.l or '')
    EndTextCommandSetBlipName(blip)
end

RegisterNetEvent('XS-PoliceSystem:client:units', function(list)
    if type(list) ~= 'table' or not Me.IsCop() then return clearAll() end
    Units.at = GetGameTimer()
    local me = GetPlayerServerId(PlayerId())
    local seen = {}
    for _, u in ipairs(list) do
        if u.s ~= me then
            seen[u.s] = true
            local player = GetPlayerFromServerId(u.s)
            local ped = (player and player ~= -1) and GetPlayerPed(player) or 0
            if ped ~= 0 and not DoesEntityExist(ped) then ped = 0 end
            local b = Units.blips[u.s]
            if b and (b.ped ~= ped or not DoesBlipExist(b.blip)) then
                clear(u.s)
                b = nil
            end
            if not b then
                local blip = ped ~= 0 and AddBlipForEntity(ped) or AddBlipForCoord(u.x + 0.0, u.y + 0.0, u.z + 0.0)
                b = { blip = blip, ped = ped }
                Units.blips[u.s] = b
            elseif ped == 0 then
                SetBlipCoords(b.blip, u.x + 0.0, u.y + 0.0, u.z + 0.0)
            end
            local key = ('%s|%s|%s|%s'):format(u.k, u.j, u.l, tostring(u.p))
            if b.key ~= key then
                b.key = key
                style(b.blip, u)
            end
            if ped == 0 and u.k ~= 'foot' then SetBlipRotation(b.blip, math.floor(tonumber(u.h) or 0)) end
        end
    end
    for src in pairs(Units.blips) do
        if not seen[src] then clear(src) end
    end
end)

CreateThread(function()
    while true do
        Wait(2000)
        local stale = (((Config.UnitBlips or {}).seconds or 2) * 3 + 2) * 1000
        if next(Units.blips) and (GetGameTimer() - Units.at > stale or not Me.IsCop()) then clearAll() end
    end
end)

Framework.OnUnloaded(clearAll)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then clearAll() end
end)
