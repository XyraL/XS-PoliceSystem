MDT = { name = nil }

if not Config then return end

local function running(name)
    local state = GetResourceState(name)
    return state == 'started' or state == 'starting'
end

local ADAPTERS = {
    ['XS-MDT'] = function() ExecuteCommand('xs_mdt_open') end,
    ['ps-mdt'] = function() exports['ps-mdt']:OpenMDT() end,
    ['redutzu-mdt'] = function() TriggerEvent('redutzu-mdt:client:openMDT') end,
    ['kartik-mdt'] = function() exports['kartik-mdt']:openMDT() end,
    ['tk_mdt'] = function() exports.tk_mdt:openUI('police') end,
    ['drx_mdt'] = function()
        if not pcall(function() exports.drx_mdt:OpenMDT() end) then
            TriggerServerEvent('XS-PoliceSystem:server:openMdt')
        end
    end,
    ['codem-mdtv2'] = function() TriggerEvent('codem-mdtv2:toggleMDT') end,
    ['origen_police'] = function() exports['origen_police']:TogglePause() end,
    ['qs-dispatch'] = function() TriggerEvent('qs-dispatch:client:OpenMdt') end,
    ['lb-tablet'] = function() exports['lb-tablet']:ToggleOpen(true) end,
    ['qb-mdt'] = function() ExecuteCommand('mdt') end,
}

local ORDER = { 'XS-MDT', 'ps-mdt', 'redutzu-mdt', 'kartik-mdt', 'tk_mdt', 'drx_mdt', 'codem-mdtv2', 'origen_police', 'qs-dispatch', 'lb-tablet', 'qb-mdt' }

local function pick()
    local M = Config.MDT or {}
    local forced = M.resource or 'auto'
    if forced == 'none' then return nil end
    if forced == 'command' then return (M.command or '') ~= '' and 'command' or nil end
    if forced ~= 'auto' then return forced end
    for _, name in ipairs(ORDER) do
        if running(name) then return name end
    end
    if (M.command or '') ~= '' then return 'command' end
    return nil
end

function MDT.Available()
    MDT.name = pick()
    return MDT.name ~= nil
end

function MDT.CanOpenProfile()
    return pick() == 'XS-MDT'
end

function MDT.OpenProfile(target)
    target = tonumber(target)
    if target and pick() == 'XS-MDT' then
        TriggerServerEvent('XS-MDT:server:targetOpenProfile', target)
        return true
    end
    return MDT.Open()
end

function MDT.Open()
    local name = pick()
    MDT.name = name
    if not name then return false end
    if name == 'command' then
        ExecuteCommand(Config.MDT.command)
        return true
    end
    local open = ADAPTERS[name]
    if not open then
        ExecuteCommand((Config.MDT or {}).command ~= '' and Config.MDT.command or 'mdt')
        return true
    end
    local ok, err = pcall(open)
    if not ok then
        print(('^1[XS-PoliceSystem]^0 opening %s failed: %s'):format(name, tostring(err)))
        return false
    end
    return true
end
