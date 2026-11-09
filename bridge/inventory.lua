Inventory = { name = nil }

if not Config then return end

local CANDIDATES = { 'ox_inventory', 'qb-inventory', 'qs-inventory', 'ps-inventory', 'codem-inventory', 'core_inventory' }

local function running(name)
    local state = GetResourceState(name)
    return state == 'started' or state == 'starting'
end

do
    local forced = Config.Bridges and Config.Bridges.inventory or 'auto'
    if forced ~= 'auto' then
        Inventory.name = forced
    else
        for _, res in ipairs(CANDIDATES) do
            if running(res) then Inventory.name = res break end
        end
    end
end

local function frameworkItems()
    if Framework.name == 'qbox' then return {} end
    return Framework.core and Framework.core.Shared and Framework.core.Shared.Items or {}
end

function Inventory.Label(item)
    if not item then return '' end
    if Inventory.name == 'ox_inventory' then
        local ok, items = pcall(function() return exports.ox_inventory:Items(item) end)
        if ok and type(items) == 'table' and items.label then return items.label end
    end
    local def = frameworkItems()[item]
    return def and def.label or item
end

local IMAGE_FOLDERS = {
    ['qb-inventory'] = 'nui://qb-inventory/html/images/',
    ['ps-inventory'] = 'nui://ps-inventory/html/images/',
    ['qs-inventory'] = 'nui://qs-inventory/web/dist/images/',
    ['codem-inventory'] = 'nui://codem-inventory/html/itemimages/',
    ['core_inventory'] = 'nui://core_inventory/html/img/',
}

local function imageFolder()
    if Inventory.name == 'codem-inventory' and running('codem-inventory-images') then return 'nui://codem-inventory-images/images/' end
    return IMAGE_FOLDERS[Inventory.name]
end

function Inventory.Image(item)
    if not item or item == '' then return '' end
    local custom = (Config.Armory or {}).images
    if type(custom) == 'string' and custom ~= '' and custom ~= 'auto' then
        if custom:find('%%s') then return custom:format(item) end
        return custom .. item .. '.png'
    end
    if Inventory.name == 'ox_inventory' then
        local ok, def = pcall(function() return exports.ox_inventory:Items(item) end)
        local image = ok and type(def) == 'table' and type(def.client) == 'table' and def.client.image or nil
        if type(image) == 'string' and image:find('://') then return image end
        local name = ok and type(def) == 'table' and type(def.name) == 'string' and def.name or item
        local folder = GetConvar('inventory:imagepath', 'nui://ox_inventory/web/images')
        return ('%s/%s'):format(folder, type(image) == 'string' and image ~= '' and image or (name .. '.png'))
    end
    local folder = imageFolder()
    if not folder then return '' end
    local def = frameworkItems()[item]
    local file = def and type(def.image) == 'string' and def.image ~= '' and def.image or (item .. '.png')
    if file:find('://') then return file end
    return folder .. file
end

if IsDuplicityVersion() then
    function Inventory.Count(src, item)
        if not item or item == '' then return 0 end
        if Inventory.name == 'ox_inventory' then
            return exports.ox_inventory:Search(src, 'count', item) or 0
        end
        if Inventory.name == 'qs-inventory' then
            local ok, total = pcall(function() return exports['qs-inventory']:GetItemTotalAmount(src, item) end)
            if ok then return tonumber(total) or 0 end
        end
        local player = Framework.GetPlayer(src)
        if not player then return 0 end
        local found = player.Functions.GetItemByName(item)
        return found and (found.amount or found.count) or 0
    end

    function Inventory.Has(src, item, amount)
        return Inventory.Count(src, item) >= (amount or 1)
    end

    function Inventory.CanCarry(src, item, amount)
        if Inventory.name == 'ox_inventory' then
            return exports.ox_inventory:CanCarryItem(src, item, amount or 1) == true
        end
        if Inventory.name == 'qb-inventory' then
            local ok, can = pcall(function() return exports['qb-inventory']:CanAddItem(src, item, amount or 1) end)
            if ok then return can ~= false end
        end
        return true
    end

    function Inventory.Add(src, item, amount, metadata)
        amount = amount or 1
        if not item then return false end
        if Inventory.name == 'ox_inventory' then
            return exports.ox_inventory:AddItem(src, item, amount, metadata) and true or false
        end
        if Inventory.name == 'qb-inventory' then
            local ok, added = pcall(function() return exports['qb-inventory']:AddItem(src, item, amount, false, metadata, 'XS-PoliceSystem') end)
            if ok then
                if added then TriggerClientEvent('qb-inventory:client:ItemBox', src, frameworkItems()[item] or { name = item, label = item }, 'add', amount) end
                return added and true or false
            end
        end
        local player = Framework.GetPlayer(src)
        if not player then return false end
        return player.Functions.AddItem(item, amount, nil, metadata) and true or false
    end

    function Inventory.Remove(src, item, amount, metadata)
        amount = amount or 1
        if not item then return false end
        if Inventory.name == 'ox_inventory' then
            return exports.ox_inventory:RemoveItem(src, item, amount, metadata) and true or false
        end
        if Inventory.name == 'qb-inventory' then
            local ok, removed = pcall(function() return exports['qb-inventory']:RemoveItem(src, item, amount, false, 'XS-PoliceSystem') end)
            if ok then
                if removed then TriggerClientEvent('qb-inventory:client:ItemBox', src, frameworkItems()[item] or { name = item, label = item }, 'remove', amount) end
                return removed and true or false
            end
        end
        local player = Framework.GetPlayer(src)
        if not player then return false end
        return player.Functions.RemoveItem(item, amount) and true or false
    end

    function Inventory.Clear(src, keep)
        keep = keep or {}
        if Inventory.name == 'ox_inventory' then
            exports.ox_inventory:ClearInventory(src, #keep > 0 and keep or nil)
            return true
        end
        if Inventory.name == 'qb-inventory' then
            local ok = pcall(function() exports['qb-inventory']:ClearInventory(src, keep) end)
            if ok then return true end
        end
        local player = Framework.GetPlayer(src)
        if not player then return false end
        player.Functions.ClearInventory(keep)
        return true
    end

    function Inventory.Items()
        local out = {}
        if Inventory.name == 'ox_inventory' then
            local ok, items = pcall(function() return exports.ox_inventory:Items() end)
            for name, def in pairs(ok and items or {}) do out[#out + 1] = { name = name, label = def.label or name, image = Inventory.Image(name) } end
        else
            for name, def in pairs(frameworkItems()) do out[#out + 1] = { name = name, label = def.label or name, image = Inventory.Image(name) } end
        end
        table.sort(out, function(a, b) return a.label < b.label end)
        return out
    end

    function Inventory.Useable(item, handler)
        if not item or item == '' or Inventory.name == 'ox_inventory' then return end
        if Framework.name == 'qbox' then
            pcall(function() exports.qbx_core:CreateUseableItem(item, handler) end)
        elseif Framework.core then
            Framework.core.Functions.CreateUseableItem(item, handler)
        end
    end

    function Inventory.OpenStash(src, id, label, slots, weight, groups, coords)
        if Inventory.name == 'ox_inventory' then
            exports.ox_inventory:RegisterStash(id, label, slots, weight, false, groups, coords)
            return 'client'
        end
        if Inventory.name == 'qb-inventory' then
            local ok = pcall(function()
                exports['qb-inventory']:OpenInventory(src, id, { label = label, maxweight = weight, slots = slots })
            end)
            if ok then return 'server' end
        end
        return 'legacy'
    end

    function Inventory.OpenLocker(src, base, label, slots, weight, coords, groups)
        if Inventory.name == 'ox_inventory' then
            exports.ox_inventory:RegisterStash(base, label, slots, weight, true, groups, coords)
            return 'client', base
        end
        local id = ('%s_%s'):format(base, Framework.GetCitizenId(src) or tostring(src))
        if Inventory.name == 'qb-inventory' then
            local ok = pcall(function()
                exports['qb-inventory']:OpenInventory(src, id, { label = label, maxweight = weight, slots = slots })
            end)
            if ok then return 'server', id end
        end
        return 'legacy', id
    end

    function Inventory.OpenPlayer(src, target)
        if Inventory.name == 'ox_inventory' then
            return pcall(function() exports.ox_inventory:forceOpenInventory(src, 'player', target) end)
        end
        if Inventory.name == 'qb-inventory' then
            local ok = pcall(function() exports['qb-inventory']:OpenInventoryById(src, target) end)
            if ok then return true end
        end
        TriggerClientEvent('XS-PoliceSystem:client:openPlayerInventory', src, target)
        return true
    end

    function Inventory.Snapshot(src)
        local out = {}
        if Inventory.name == 'ox_inventory' then
            local ok, items = pcall(function() return exports.ox_inventory:GetInventoryItems(src) end)
            for _, slot in pairs(ok and items or {}) do
                if slot and slot.name and (slot.count or 0) > 0 then
                    out[#out + 1] = { name = slot.name, count = slot.count, metadata = slot.metadata }
                end
            end
            return out
        end
        local player = Framework.GetPlayer(src)
        for _, slot in pairs(player and player.PlayerData.items or {}) do
            if slot and slot.name and (slot.amount or slot.count or 0) > 0 then
                out[#out + 1] = { name = slot.name, count = slot.amount or slot.count, metadata = slot.info or slot.metadata }
            end
        end
        return out
    end

    local function trimPlate(plate)
        return (tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', ''))
    end

    function Inventory.OpenVehicle(src, vehicle, kind)
        local plate = trimPlate(GetVehicleNumberPlateText(vehicle))
        if plate == '' then return false end
        local size = ((Config.SearchVehicle or {})[kind]) or { slots = 30, weight = 100000 }
        if Inventory.name == 'ox_inventory' then
            local id = (kind == 'trunk' and 'trunk' or 'glove') .. plate
            return pcall(function() exports.ox_inventory:forceOpenInventory(src, kind, { id = id, netid = NetworkGetNetworkIdFromEntity(vehicle) }) end)
        end
        if Inventory.name == 'qb-inventory' then
            local ok = pcall(function()
                exports['qb-inventory']:OpenInventory(src, kind .. '-' .. plate, { label = kind .. '-' .. plate, maxweight = size.weight, slots = size.slots })
            end)
            if ok then return true end
        end
        TriggerClientEvent('XS-PoliceSystem:client:openVehicleInventory', src, kind, plate, size)
        return true
    end

    local function addNames(out, items)
        for _, slot in pairs(type(items) == 'table' and items or {}) do
            if type(slot) == 'table' and slot.name and (slot.count or slot.amount or 1) > 0 then out[#out + 1] = slot.name end
        end
    end

    function Inventory.VehicleItems(plate)
        plate = trimPlate(plate)
        local out = {}
        if plate == '' then return out end
        if Inventory.name == 'ox_inventory' then
            for _, id in ipairs({ 'trunk' .. plate, 'glove' .. plate }) do
                local ok, items = pcall(function() return exports.ox_inventory:GetInventoryItems(id) end)
                if ok then addNames(out, items) end
            end
            return out
        end
        for _, kind in ipairs({ 'trunk', 'glovebox' }) do
            local id = kind .. '-' .. plate
            local ok, inv = pcall(function() return exports['qb-inventory']:GetInventory(id) end)
            if ok and type(inv) == 'table' then
                addNames(out, inv.items or inv)
            else
                local okRow, row = pcall(MySQL.single.await, 'SELECT `items` FROM `inventories` WHERE `identifier` = ?', { id })
                if okRow and row then
                    addNames(out, Db.Decode(row.items, {}))
                else
                    local legacy = kind == 'trunk' and 'trunkitems' or 'gloveboxitems'
                    local okOld, old = pcall(MySQL.single.await, ('SELECT `items` FROM `%s` WHERE `plate` = ?'):format(legacy), { plate })
                    if okOld and old then addNames(out, Db.Decode(old.items, {})) end
                end
            end
        end
        return out
    end

    lib.callback.register('XS-PoliceSystem:server:itemCount', function(src, item)
        return Inventory.Count(src, tostring(item or ''))
    end)

    local hotbarHook
    if Inventory.name == 'qb-inventory' then
        CreateThread(function()
            local untilAt = GetGameTimer() + 30000
            while GetResourceState('qb-inventory') ~= 'started' and GetGameTimer() < untilAt do Wait(500) end
            pcall(function()
                hotbarHook = exports['qb-inventory']:AddHook('ItemUsed', function(_, data)
                    local src = type(data) == 'table' and tonumber(data.source)
                    if src and Player(src).state.xspHotbarOff then return false end
                end)
            end)
        end)
    end

    AddEventHandler('onResourceStop', function(name)
        if name ~= GetCurrentResourceName() or not hotbarHook then return end
        pcall(function() exports['qb-inventory']:RemoveHook('ItemUsed', hotbarHook) end)
    end)
else
    local holds, saved = 0, nil

    function Inventory.HoldHotbar(on)
        local bag = LocalPlayer.state
        if on then
            holds = holds + 1
            if holds > 1 then return end
            saved = { hotkeys = bag.invHotkeys, busy = bag.inv_busy }
            bag:set('invHotkeys', false, false)
            bag:set('inv_busy', true, false)
            bag:set('xspHotbarOff', true, true)
            return
        end
        if holds == 0 then return end
        holds = holds - 1
        if holds > 0 then return end
        local was = saved or {}
        saved = nil
        if bag.invHotkeys == false then bag:set('invHotkeys', was.hotkeys, false) end
        if bag.inv_busy == true then bag:set('inv_busy', was.busy, false) end
        bag:set('xspHotbarOff', false, true)
    end

    AddEventHandler('onResourceStop', function(name)
        if name ~= GetCurrentResourceName() or holds == 0 then return end
        holds = 1
        Inventory.HoldHotbar(false)
    end)

    local cache, cacheAt = {}, {}

    function Inventory.Count(item)
        if not item or item == '' then return 0 end
        if Inventory.name == 'ox_inventory' then
            return exports.ox_inventory:Search('count', item) or 0
        end
        local now = GetGameTimer()
        if cacheAt[item] and now - cacheAt[item] < 1500 then return cache[item] or 0 end
        local count = lib.callback.await('XS-PoliceSystem:server:itemCount', false, item) or 0
        cache[item], cacheAt[item] = count, now
        return count
    end

    function Inventory.Has(item, amount)
        return Inventory.Count(item) >= (amount or 1)
    end

    function Inventory.Invalidate()
        cache, cacheAt = {}, {}
    end

    function Inventory.OpenStash(mode, id, label, slots, weight)
        if mode == 'client' then
            exports.ox_inventory:openInventory('stash', id)
        elseif mode == 'legacy' then
            if Inventory.name == 'qs-inventory' then
                pcall(function() exports['qs-inventory']:RegisterStash(id, slots, weight) end)
            end
            TriggerServerEvent('inventory:server:OpenInventory', 'stash', id, { maxweight = weight, slots = slots })
            TriggerEvent('inventory:client:SetCurrentStash', id)
        end
    end

    RegisterNetEvent('XS-PoliceSystem:client:invalidateInventory', function()
        Inventory.Invalidate()
    end)

    RegisterNetEvent('XS-PoliceSystem:client:openVehicleInventory', function(kind, plate, size)
        size = size or {}
        TriggerServerEvent('inventory:server:OpenInventory', kind, plate, { maxweight = size.weight, slots = size.slots })
        TriggerEvent('inventory:client:SetCurrentStash', plate)
    end)

    RegisterNetEvent('XS-PoliceSystem:client:openPlayerInventory', function(target)
        TriggerServerEvent('inventory:server:OpenInventory', 'otherplayer', target)
    end)
end
