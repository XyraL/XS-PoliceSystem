if not Config.Commands then return end

local function say(src, ok, msg)
    if type(msg) == 'string' and msg ~= '' then Framework.Notify(src, msg, ok and 'success' or 'error') end
end

local function cop(src)
    if Framework.IsCopSource(src) then return true end
    Framework.Notify(src, Text('err_police_only'), 'error')
    return false
end

local function nearest(src)
    local target = Field.Closest(src, (Config.Wheel.range or 3.0) + 0.5)
    if not target then Framework.Notify(src, Text('err_nobody_near'), 'error') end
    return target
end

local function onNearest(name)
    return function(src)
        local target = nearest(src)
        if not target then return end
        local ok, msg = Field.Act(src, name, target)
        say(src, ok, msg)
    end
end

local function run(name)
    return function(src)
        if cop(src) then TriggerClientEvent('XS-PoliceSystem:client:run', src, name) end
    end
end

local idParam = { name = 'id', type = 'playerId', help = Text('cmd_player_id') }

lib.addCommand('cuff', { help = Text('cmd_cuff') }, onNearest('cuff'))
lib.addCommand('sc', { help = Text('cmd_cuff') }, onNearest('cuff'))
lib.addCommand('escort', { help = Text('cmd_escort') }, onNearest('escort'))
lib.addCommand('seizecash', { help = Text('cmd_seizecash') }, onNearest('seize'))
lib.addCommand('takedrivinglicense', { help = Text('cmd_takelicence') }, function(src)
    if not cop(src) then return end
    local target = nearest(src)
    if not target then return end
    say(src, Field.Act(src, 'licenceSet', target, { kind = 'driver', on = false }))
end)
lib.addCommand('anklet', { help = Text('cmd_anklet') }, onNearest('tracker'))
lib.addCommand('spikestrip', { help = Text('cmd_spikestrip') }, run('spikes'))
lib.addCommand('cam', { help = Text('cmd_cam'), params = { { name = 'camera', type = 'number', help = Text('cmd_cam_param'), optional = true } } }, function(src, args)
    if not cop(src) then return end
    TriggerClientEvent('XS-PoliceSystem:client:camera', src, tonumber(args.camera))
end)

lib.addCommand('pobject', { help = Text('cmd_pobject'), params = { { name = 'type', type = 'string', help = 'cone, barrier, delete' } } }, function(src, args)
    if not cop(src) then return end
    local kind = tostring(args.type or ''):lower()
    local action = (kind == 'delete' and 'removeProp') or (kind == 'cone' and 'cone') or 'barrier'
    TriggerClientEvent('XS-PoliceSystem:client:run', src, action)
end)

local function licenceCommand(on)
    return function(src, args)
        if not cop(src) then return end
        local target = tonumber(args.id)
        if not target or not GetPlayerName(target) then return Framework.Notify(src, Text('err_no_player'), 'error') end
        say(src, Field.Act(src, 'licenceSet', target, { kind = tostring(args.licence or ''):lower(), on = on }))
    end
end
local licenceParams = { idParam, { name = 'licence', type = 'string', help = 'driver, weapon' } }
lib.addCommand('grantlicense', { help = Text('cmd_grantlicence'), params = licenceParams }, licenceCommand(true))
lib.addCommand('revokelicense', { help = Text('cmd_revokelicence'), params = licenceParams }, licenceCommand(false))

lib.addCommand('fine', { help = Text('cmd_fine'), params = { idParam, { name = 'amount', type = 'number', help = Text('form_amount') }, { name = 'reason', type = 'longString', help = Text('form_reason'), optional = true } } }, function(src, args)
    if not cop(src) then return end
    say(src, Field.Act(src, 'fine', tonumber(args.id), { amount = args.amount, reason = args.reason or Text('fine_default_reason') }))
end)

lib.addCommand('flagplate', { help = Text('cmd_flagplate'), params = { { name = 'plate', type = 'string', help = Text('cmd_plate') }, { name = 'reason', type = 'longString', help = Text('form_reason') } } }, function(src, args)
    if not cop(src) then return end
    local ok, res = Plates.Flag(args.plate, args.reason, 0, Units.Label(src))
    say(src, ok, ok and Text('plate_flagged', { plate = res }) or res)
end)

lib.addCommand('unflagplate', { help = Text('cmd_unflagplate'), params = { { name = 'plate', type = 'string', help = Text('cmd_plate') } } }, function(src, args)
    if not cop(src) then return end
    local plate = Plates.Norm(args.plate)
    if Plates.Unflag(plate) then say(src, true, Text('plate_unflagged', { plate = plate })) else say(src, false, Text('plate_not_flagged', { plate = plate })) end
end)

lib.addCommand('plateinfo', { help = Text('cmd_plateinfo'), params = { { name = 'plate', type = 'string', help = Text('cmd_plate') } } }, function(src, args)
    if not cop(src) then return end
    local plate = Plates.Norm(args.plate)
    local f = Plates.Get(plate)
    Framework.Notify(src, f and Text('plate_is_flagged', { plate = plate, reason = f.reason }) or Text('plate_not_flagged', { plate = plate }), f and 'error' or 'inform')
end)

lib.addCommand('ankletlocation', { help = Text('cmd_ankletlocation'), params = { { name = 'citizenid', type = 'string', help = 'Citizen ID' } } }, function(src, args)
    if not cop(src) then return end
    local target = Framework.GetPlayerByCitizenId(tostring(args.citizenid or ''))
    local tsrc = target and target.PlayerData.source
    if not tsrc or Framework.GetMetaData(tsrc, 'tracker') ~= true then return Framework.Notify(src, Text('err_no_tracker'), 'error') end
    local c = Places.Coords(tsrc)
    if not c then return end
    TriggerClientEvent('XS-PoliceSystem:client:alertBlip', src, { x = c.x, y = c.y, z = c.z }, Text('tracker_blip', { name = Framework.GetName(tsrc) or '' }), 'alert')
end)

lib.addCommand('takedna', { help = Text('cmd_takedna'), params = { idParam } }, function(src, args)
    if not cop(src) then return end
    local target = tonumber(args.id)
    if not target or not GetPlayerName(target) then return Framework.Notify(src, Text('err_no_player'), 'error') end
    say(src, Field.Act(src, 'takedna', target))
end)

local function clear(kind)
    return function(src)
        if not cop(src) then return end
        local n = Forensics.Clear(src, kind, 10.0)
        say(src, n > 0, Text('evidence_cleared', { count = n }))
    end
end
lib.addCommand('clearcasings', { help = Text('cmd_clearcasings') }, clear('casing'))
lib.addCommand('clearblood', { help = Text('cmd_clearblood') }, clear('blood'))

local function pay(job, key)
    return function(src, args)
        if not cop(src) then return end
        local target = tonumber(args.id)
        local tjob = target and Framework.GetJob(target)
        if not tjob or tjob.name ~= job then return Framework.Notify(src, Text('err_wrong_job', { job = job }), 'error') end
        local amount = ((Config.Pay or {})[key]) or 500
        local officerJob = Framework.GetJob(src)
        if (Config.Pay or {}).fromSociety ~= false and Banking.name then
            if not Banking.Withdraw(Stations.Society(officerJob), amount, ('Paid %s %s'):format(job, Framework.GetName(target) or target)) then
                return Framework.Notify(src, Text('err_no_money'), 'error')
            end
        end
        Framework.AddMoney(target, 'bank', amount, 'Paid by police')
        Framework.Notify(target, Text('paid_you', { amount = amount }), 'success')
        Framework.Notify(src, Text('paid', { amount = amount, name = Framework.GetName(target) or target }), 'success')
    end
end
lib.addCommand('paytow', { help = Text('cmd_paytow'), params = { idParam } }, pay('tow', 'tow'))
lib.addCommand('paylawyer', { help = Text('cmd_paylawyer'), params = { idParam } }, pay('lawyer', 'lawyer'))

local reportAt = {}
lib.addCommand('911p', { help = Text('cmd_911p'), params = { { name = 'message', type = 'longString', help = Text('cmd_911p_param') } } }, function(src, args)
    local now = os.time()
    if reportAt[src] and now - reportAt[src] < 30 then return Framework.Notify(src, Text('err_slow_down'), 'error') end
    local message = Util.Text(args.message, 160)
    if message == '' then return end
    reportAt[src] = now
    Compat.Alert(Places.Coords(src), Text('report_911', { name = Framework.GetName(src) or '', message = message }))
    Framework.Notify(src, Text('report_sent'), 'success')
end)

AddEventHandler('playerDropped', function() reportAt[source] = nil end)
