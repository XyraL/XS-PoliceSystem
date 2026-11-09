Duty = { count = 0 }

function Duty.Count()
    return #Framework.Cops(true)
end

function Duty.Broadcast()
    local count = Duty.Count()
    if count == Duty.count then return count end
    Duty.count = count
    GlobalState.xspCops = count
    TriggerEvent('XS-PoliceSystem:server:copCount', count)
    if Compat and Compat.CopCount then Compat.CopCount(count) end
    return count
end

function Duty.Changed(src, on)
    TriggerEvent('XS-PoliceSystem:server:dutyChanged', src, on == true)
    Duty.Broadcast()
end

AddEventHandler('QBCore:Server:SetDuty', function() SetTimeout(300, Duty.Broadcast) end)
AddEventHandler('QBCore:Server:OnJobUpdate', function() SetTimeout(300, Duty.Broadcast) end)
AddEventHandler('QBCore:Server:PlayerLoaded', function() SetTimeout(1000, Duty.Broadcast) end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function() SetTimeout(500, Duty.Broadcast) end)
AddEventHandler('playerDropped', function() SetTimeout(500, Duty.Broadcast) end)

CreateThread(function()
    while true do
        Wait(30000)
        Duty.Broadcast()
    end
end)

exports('GetCopCount', function() return Duty.Count() end)
