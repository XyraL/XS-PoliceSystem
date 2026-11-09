Plates = { flags = {}, speedAt = {}, alertAt = {} }

function Plates.Norm(plate)
    return (tostring(plate or ''):upper():gsub('%s+', ''))
end

function Plates.Load()
    Plates.flags = {}
    local now = os.time()
    for _, r in ipairs(MySQL.query.await('SELECT `plate`, `reason`, `officer`, `created_at`, `expires_at` FROM `xs_police_flags`') or {}) do
        local expires = tonumber(r.expires_at) or 0
        if expires == 0 or expires > now then
            Plates.flags[Plates.Norm(r.plate)] = { reason = r.reason or '', officer = r.officer or '', at = tonumber(r.created_at) or 0, expires = expires }
        end
    end
end

function Plates.Sync(target)
    local out = {}
    for plate, f in pairs(Plates.flags) do out[plate] = f.reason end
    if target then return TriggerClientEvent('XS-PoliceSystem:client:flags', target, out) end
    for _, cop in ipairs(Framework.Cops(true)) do TriggerClientEvent('XS-PoliceSystem:client:flags', cop, out) end
end

function Plates.Get(plate)
    plate = Plates.Norm(plate)
    local f = Plates.flags[plate]
    if f and f.expires > 0 and f.expires <= os.time() then
        Plates.flags[plate] = nil
        MySQL.query('DELETE FROM `xs_police_flags` WHERE `plate` = ?', { plate })
        Plates.Sync()
        return nil
    end
    return f
end

function Plates.IsFlagged(plate)
    return Plates.Get(plate) ~= nil
end

function Plates.Flag(plate, reason, hours, officer)
    plate = Plates.Norm(plate)
    if plate == '' or #plate > 8 then return false, Text('err_plate') end
    reason = Util.Text(reason, 160)
    if reason == '' then return false, Text('err_need_reason') end
    hours = Util.Clamp(math.floor(tonumber(hours) or 0), 0, (Config.Plates or {}).maxHours or 720)
    local now = os.time()
    local expires = hours > 0 and now + hours * 3600 or 0
    Plates.flags[plate] = { reason = reason, officer = officer or '', at = now, expires = expires }
    MySQL.query.await('INSERT INTO `xs_police_flags` (`plate`, `reason`, `officer`, `created_at`, `expires_at`) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `reason` = VALUES(`reason`), `officer` = VALUES(`officer`), `created_at` = VALUES(`created_at`), `expires_at` = VALUES(`expires_at`)',
        { plate, reason, officer or '', now, expires })
    Plates.Sync()
    TriggerEvent('XS-PoliceSystem:server:plateFlagged', plate, reason, officer or '')
    return true, plate
end

function Plates.Unflag(plate)
    plate = Plates.Norm(plate)
    if not Plates.flags[plate] then return false end
    Plates.flags[plate] = nil
    MySQL.query.await('DELETE FROM `xs_police_flags` WHERE `plate` = ?', { plate })
    Plates.Sync()
    TriggerEvent('XS-PoliceSystem:server:plateUnflagged', plate)
    return true
end

function Plates.Alert(plate, coords, where)
    plate = Plates.Norm(plate)
    local f = Plates.Get(plate)
    if not f or not coords then return false end
    local now = os.time()
    if Plates.alertAt[plate] and now - Plates.alertAt[plate] < 60 then return false end
    Plates.alertAt[plate] = now
    local text = Text('plate_alert', { plate = plate, reason = f.reason, where = where ~= '' and where or Text('evidence_unknown') })
    for _, cop in ipairs(Framework.Cops(true)) do
        Framework.Notify(cop, text, 'error')
        TriggerClientEvent('XS-PoliceSystem:client:alertBlip', cop, { x = coords.x, y = coords.y, z = coords.z }, Text('plate_blip', { plate = plate }), 'alert')
    end
    Dispatch.Forward({ type = 'flagged_plate', code = '10-28', title = Text('plate_blip', { plate = plate }), description = text, coords = coords })
    return true
end

local function officer(src)
    local job = Framework.GetJob(src)
    return Framework.IsCop(job) and job or nil
end

lib.callback.register('XS-PoliceSystem:server:flags', function(src)
    if not officer(src) then return {} end
    local out = {}
    for plate, f in pairs(Plates.flags) do out[plate] = f.reason end
    return out
end)

lib.callback.register('XS-PoliceSystem:server:flagPlate', function(src, plate, reason, hours)
    if not officer(src) then return false, Text('err_police_only') end
    if not WheelLayout.Allowed(src, 'flagPlate') then return false, Text('err_not_allowed') end
    local ok, res = Plates.Flag(plate, reason, hours, Units.Label(src))
    if not ok then return false, res end
    Db.Log('flag', nil, tonumber(hours) or 0, res .. ': ' .. Util.Text(reason, 160), { citizenid = Framework.GetCitizenId(src), name = Framework.GetName(src) or '', job = officer(src).name })
    return true, Text('plate_flagged', { plate = res })
end)

lib.callback.register('XS-PoliceSystem:server:unflagPlate', function(src, plate)
    if not officer(src) then return false, Text('err_police_only') end
    if not Plates.Unflag(plate) then return false, Text('plate_not_flagged', { plate = Plates.Norm(plate) }) end
    return true, Text('plate_unflagged', { plate = Plates.Norm(plate) })
end)

lib.callback.register('XS-PoliceSystem:server:plateSeen', function(src, plate, netId, where)
    if not officer(src) then return false end
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    local coords = (vehicle ~= 0 and DoesEntityExist(vehicle)) and GetEntityCoords(vehicle) or Places.Coords(src)
    return Plates.Alert(plate, coords, Util.Text(where, 80))
end)

local function speedOf(vehicle)
    local v = GetEntityVelocity(vehicle)
    local ms = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    return ms * (((Config.SpeedCameras or {}).mph ~= false) and 2.236936 or 3.6)
end

RegisterNetEvent('XS-PoliceSystem:server:speedCamera', function(index, where)
    local src = source
    local c = Config.SpeedCameras or {}
    local cam = c.enabled and (c.list or {})[tonumber(index) or 0]
    if not cam then return end
    local ped = GetPlayerPed(src)
    local vehicle = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end
    local at = vector3(cam.coords.x + 0.0, cam.coords.y + 0.0, cam.coords.z + 0.0)
    if #(GetEntityCoords(vehicle) - at) > 35.0 then return end
    local key = src .. ':' .. index
    local now = os.time()
    if Plates.speedAt[key] and now - Plates.speedAt[key] < 30 then return end
    Plates.speedAt[key] = now
    where = Util.Text(where, 80)
    local plate = Plates.Norm(GetVehicleNumberPlateText(vehicle))
    Plates.Alert(plate, at, where)
    if Framework.IsCopSource(src) then return end
    local over = math.floor(speedOf(vehicle) - (tonumber(cam.limit) or 35))
    if over <= 0 or not c.fines then return end
    local fine
    for _, band in ipairs(c.fines) do
        if over <= band.over then fine = band.fine break end
    end
    if not fine or fine <= 0 then return end
    if not Framework.RemoveMoney(src, 'bank', fine, 'Speed camera') then return end
    if c.society and Banking.name then Banking.Deposit(c.account or 'police', fine, 'Speed camera ' .. plate) end
    Db.Log('speeding', { citizenid = Framework.GetCitizenId(src), name = Framework.GetName(src) or '' }, fine, ('%s, %d over at %s'):format(plate, over, where), { citizenid = '', name = '', job = c.society and (c.account or 'police') or '' })
    Framework.Notify(src, Text('speed_fined', { amount = fine, over = over, unit = c.mph ~= false and 'mph' or 'km/h' }), 'error')
end)

RegisterNetEvent('police:server:FlaggedPlateTriggered', function(coords, plate, street)
    local me = Places.Coords(source)
    if not me then return end
    local at = me
    if type(coords) == 'table' or type(coords) == 'vector3' then
        local c = vector3(tonumber(coords.x) or 0.0, tonumber(coords.y) or 0.0, tonumber(coords.z) or 0.0)
        if #(me - c) <= 60.0 then at = c end
    end
    Plates.Alert(plate, at, Util.Text(street, 80))
end)

RegisterNetEvent('XS-PoliceSystem:server:spotlight', function(state)
    local src = source
    if not Framework.IsCopSource(src) then return end
    TriggerClientEvent('XS-PoliceSystem:client:spotlight', -1, src, state == true)
end)

exports('FlagPlate', function(plate, reason, hours) return Plates.Flag(plate, reason, hours, 'API') end)
exports('UnflagPlate', function(plate) return Plates.Unflag(plate) end)
exports('IsPlateFlagged', function(plate) return Plates.IsFlagged(plate) end)

AddEventHandler('playerDropped', function()
    local src = tostring(source)
    for key in pairs(Plates.speedAt) do
        if key:sub(1, #src + 1) == src .. ':' then Plates.speedAt[key] = nil end
    end
end)
