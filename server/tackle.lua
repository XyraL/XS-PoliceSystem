Tackle = { at = {} }

RegisterNetEvent('XS-PoliceSystem:server:tackle', function(target)
    local src = source
    local c = Config.Tackle or {}
    if not c.enabled then return end
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return end
    if not c.anyone and not Framework.IsCopSource(src) then return end
    if Field.IsCuffed(src) or Field.IsDown(src) or Jail.IsInmate(src) then return end
    local now = GetGameTimer()
    if Tackle.at[src] and now - Tackle.at[src] < (c.cooldown or 10) * 1000 then return end
    local a, b = GetPlayerPed(src), GetPlayerPed(target)
    if a == 0 or b == 0 or GetVehiclePedIsIn(a, false) ~= 0 or GetVehiclePedIsIn(b, false) ~= 0 then return end
    if #(GetEntityCoords(a) - GetEntityCoords(b)) > (c.range or 2.5) + 2.0 then return end
    Tackle.at[src] = now
    TriggerClientEvent('XS-PoliceSystem:client:tackled', target, src, tonumber(GetEntityHeading(a)) or 0.0)
    TriggerEvent('XS-PoliceSystem:server:tackled', target, src)
end)

AddEventHandler('playerDropped', function()
    Tackle.at[source] = nil
end)
