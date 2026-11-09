for _, item in ipairs({ Config.Cuffs.item, Config.Spikes.item, (Config.Forensics or {}).bleach, 'prison_shiv' }) do
    if item and item ~= '' then
        Inventory.Useable(item, function(src)
            TriggerClientEvent('XS-PoliceSystem:client:useItem', src, item)
        end)
    end
end
