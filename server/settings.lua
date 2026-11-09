Settings.defaults = {}
Settings.overrides = {}
Settings.boot = {}

local function snapshot()
    if Settings.snapped then return end
    for _, def in ipairs(Settings.fields) do Settings.defaults[def.key] = Util.Copy(Settings.Read(def.key)) end
    Settings.snapped = true
end

local function applyAll()
    for _, def in ipairs(Settings.fields) do
        local value = Settings.overrides[def.key]
        if value == nil then value = Settings.defaults[def.key] end
        Settings.Write(def.key, Util.Copy(value))
    end
end

function Settings.Values()
    local out = {}
    for _, def in ipairs(Settings.fields) do out[def.key] = Settings.Read(def.key) end
    return out
end

local function broadcast(target)
    TriggerClientEvent('XS-PoliceSystem:client:settings', target or -1, Settings.Values())
end

function Settings.Load()
    snapshot()
    local row = MySQL.single.await('SELECT `data` FROM `xs_police_settings` WHERE `name` = ?', { 'config' })
    local raw = row and Db.Decode(row.data, {}) or {}
    Settings.overrides = {}
    for key, value in pairs(type(raw) == 'table' and raw or {}) do
        local def = Settings.byKey[key]
        if def then
            local clean = Settings.Clean(def, value)
            if clean ~= nil and not Settings.Same(clean, Settings.defaults[key]) then Settings.overrides[key] = clean end
        end
    end
    applyAll()
    for _, def in ipairs(Settings.fields) do
        if def.restart then Settings.boot[def.key] = Util.Copy(Settings.Read(def.key)) end
    end
    broadcast()
end

function Settings.Save(changes, resets)
    for key, value in pairs(type(changes) == 'table' and changes or {}) do
        local def = Settings.byKey[key]
        if def then
            local clean = Settings.Clean(def, value)
            if clean ~= nil then
                if Settings.Same(clean, Settings.defaults[key]) then Settings.overrides[key] = nil else Settings.overrides[key] = clean end
            end
        end
    end
    for _, key in ipairs(type(resets) == 'table' and resets or {}) do
        if Settings.byKey[key] then Settings.overrides[key] = nil end
    end
    MySQL.query.await('INSERT INTO `xs_police_settings` (`name`, `data`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `data` = VALUES(`data`)', { 'config', Db.Json(Settings.overrides) })
    applyAll()
    broadcast()
    return Settings.Values()
end

function Settings.Builder()
    return {
        sections = Settings.Public(), values = Settings.Values(), defaults = Settings.defaults, boot = Settings.boot,
    }
end

lib.callback.register('XS-PoliceSystem:server:settings', function()
    return Settings.Values()
end)

lib.callback.register('XS-PoliceSystem:server:builderSettingsSave', function(src, payload)
    if not Framework.IsAdmin(src) then return false, Text('err_not_admin') end
    payload = type(payload) == 'table' and payload or {}
    local values = Settings.Save(payload.changes, payload.resets)
    local count = 0
    for _ in pairs(Settings.overrides) do count = count + 1 end
    print(('^2[XS-PoliceSystem]^0 %s saved the settings (%d changed from config.lua).'):format(GetPlayerName(src) or src, count))
    return true, { values = values, boot = Settings.boot }
end)
