Units = {}

local UNSET = { [''] = true, ['NO CALLSIGN'] = true }

function Units.Callsign(src)
    local value = Framework.GetMetaData(src, 'callsign')
    if type(value) ~= 'string' or UNSET[value] then return nil end
    return value
end

function Units.Label(src)
    local name = Framework.GetName(src) or ''
    local callsign = Units.Callsign(src)
    return callsign and (callsign .. ' ' .. name) or name
end

function Units.CleanCallsign(value)
    local max = (Config.Callsign or {}).max or 10
    value = (Util.Text(value, 32):upper():gsub('[^%w%-/ ]', ''))
    value = (value:gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', ''))
    if value == '' or #value > max then return nil end
    return value
end

local function kindOf(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return 'foot', ped end
    local t = GetVehicleType(vehicle)
    if t == 'heli' or t == 'plane' or t == 'bike' then return t, vehicle end
    if t == 'boat' or t == 'submarine' then return 'boat', vehicle end
    return 'car', vehicle
end

function Units.List()
    local extra = {}
    for _, name in ipairs((Config.UnitBlips or {}).jobs or {}) do extra[name] = true end
    local panicFor = (Config.Panic or {}).blipSeconds or 90
    local now = os.time()
    local out = {}
    local tracking = (Config.Tracker or {}).enabled
    for _, src in ipairs(Framework.Players()) do
        local job = Framework.GetJob(src)
        if tracking and Framework.GetMetaData(src, 'tracker') == true then
            local ped = GetPlayerPed(src)
            if ped ~= 0 then
                local c = GetEntityCoords(ped)
                out[#out + 1] = { s = -src, x = Util.Round(c.x, 1), y = Util.Round(c.y, 1), z = Util.Round(c.z, 1), h = 0, k = 'tracked', j = '', l = Text('tracker_blip', { name = Framework.GetName(src) or '' }) }
            end
        end
        if job and (Framework.IsCop(job) or (extra[job.name] and job.onDuty)) then
            local ped = GetPlayerPed(src)
            if ped ~= 0 then
                local c = GetEntityCoords(ped)
                local kind, entity = kindOf(ped)
                local callsign = Units.Callsign(src)
                local name = Framework.GetName(src) or ''
                local panicAt = Props and Props.panicAt[src]
                out[#out + 1] = {
                    s = src, x = Util.Round(c.x, 1), y = Util.Round(c.y, 1), z = Util.Round(c.z, 1),
                    h = math.floor(tonumber(GetEntityHeading(entity)) or 0), k = kind, j = job.name,
                    l = callsign and Text('unit_blip', { callsign = callsign, name = name }) or name,
                    p = (panicAt and now - panicAt < panicFor) or nil,
                }
            end
        end
    end
    return out
end

CreateThread(function()
    while true do
        local b = Config.UnitBlips or {}
        Wait(math.max(1, tonumber(b.seconds) or 2) * 1000)
        if b.enabled ~= false then
            local cops = Framework.Cops(true)
            if #cops > 0 then
                local list = Units.List()
                for _, cop in ipairs(cops) do TriggerClientEvent('XS-PoliceSystem:client:units', cop, list) end
            end
        end
    end
end)

local command = (Config.Callsign or {}).command
if command and command ~= '' then
    lib.addCommand(command, {
        help = Text('cmd_callsign'),
        params = { { name = 'callsign', type = 'longString', help = Text('cmd_callsign_param') } },
    }, function(src, args)
        if not Framework.IsCop(Framework.GetJob(src), true) then return Framework.Notify(src, Text('err_police_only'), 'error') end
        local value = Units.CleanCallsign(args.callsign)
        if not value then return Framework.Notify(src, Text('err_callsign', { max = (Config.Callsign or {}).max or 10 }), 'error') end
        Framework.SetMetaData(src, 'callsign', value)
        Framework.Notify(src, Text('callsign_set', { callsign = value }), 'success')
    end)
end

exports('GetCallsign', function(src) return Units.Callsign(tonumber(src)) end)
