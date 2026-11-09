RegisterNetEvent('evidence:client:SetStatus', function(id, seconds)
    TriggerServerEvent('XS-PoliceSystem:server:status', tostring(id or ''), tonumber(seconds) or 0)
end)

exports('SetStatus', function(id, seconds)
    TriggerServerEvent('XS-PoliceSystem:server:status', tostring(id or ''), tonumber(seconds) or 0)
end)
