local ignored = {}
for _, hash in ipairs(Config.Gsr.ignoredWeapons or {}) do ignored[hash] = true end

CreateThread(function()
    local reportedAt, residue = 0, false
    while true do
        local ped = PlayerPedId()
        if IsPedArmed(ped, 4) then
            local weapon = GetSelectedPedWeapon(ped)
            if IsPedShooting(ped) and not ignored[weapon] then
                residue = true
                Forensics.Shot(ped, weapon)
                if GetGameTimer() - reportedAt > 10000 then
                    reportedAt = GetGameTimer()
                    TriggerServerEvent('XS-PoliceSystem:server:shot')
                end
            end
            Wait(0)
        else
            if residue and Config.Gsr.waterClears and IsPedSwimming(ped) then
                residue = false
                TriggerServerEvent('XS-PoliceSystem:server:washed')
            end
            Wait(500)
        end
    end
end)
