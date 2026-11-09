Prison = { alarms = {} }

local function jailCenter(place)
    return Jail.Center(place)
end

function Prison.Active()
    local now = os.time()
    for _, untilAt in pairs(Prison.alarms) do
        if untilAt > now then return true end
    end
    return false
end

local function send(place, on)
    local c = jailCenter(place)
    if not c then return end
    TriggerClientEvent('XS-PoliceSystem:client:prisonAlarm', -1, {
        id = place.id, x = c.x, y = c.y, z = c.z, radius = Jail.Reach(place) * 1.5, on = on,
    })
end

function Prison.Alarm(placeId, minutes)
    local place = Places.Get(tonumber(placeId) or placeId)
    if not place or place.kind ~= 'jail' then return false end
    Prison.alarms[place.id] = os.time() + math.floor((tonumber(minutes) or Config.Jail.alarmMinutes or 3) * 60)
    GlobalState.xspPrisonAlarm = true
    send(place, true)
    TriggerEvent('XS-PoliceSystem:server:prisonAlarm', place.id, true)
    return true
end

function Prison.StopAlarm(placeId)
    local place = Places.Get(tonumber(placeId) or placeId)
    if not place or not Prison.alarms[place.id] then return false end
    Prison.alarms[place.id] = nil
    GlobalState.xspPrisonAlarm = Prison.Active()
    send(place, false)
    TriggerEvent('XS-PoliceSystem:server:prisonAlarm', place.id, false)
    return true
end

function Prison.Break(placeId, minutes)
    local place = Places.Get(tonumber(placeId) or placeId)
    if not place or not Prison.Alarm(place.id, minutes) then return false end
    local c = jailCenter(place)
    local text = Text('prison_break', { jail = place.name })
    for _, cop in ipairs(Framework.Cops(true)) do
        Framework.Notify(cop, text, 'error')
        if c then TriggerClientEvent('XS-PoliceSystem:client:alertBlip', cop, { x = c.x, y = c.y, z = c.z }, Text('prison_break_blip'), 'escape') end
    end
    if c then Dispatch.Forward({ type = 'custom', code = '10-98', title = Text('prison_break_blip'), description = text, coords = vector3(c.x, c.y, c.z), sprite = 188 }) end
    return true
end

function Prison.Solitary(officer, target)
    local inmate = Jail.inmates[target]
    if not inmate or inmate.escaped then return false, Text('err_not_in_jail') end
    if not officer.isBoss and (officer.grade or 0) < ((Config.Grades or {}).jail or 0) then return false, Text('err_grade') end
    local place = Places.Get(inmate.jailId)
    local cells = place and place.points.solitary or {}
    local ped = GetPlayerPed(target)
    if inmate.solitary and inmate.solitary > os.time() then
        inmate.solitary = nil
        local cell = Jail.PickCell(place)
        if cell and ped ~= 0 then SetEntityCoords(ped, cell.x + 0.0, cell.y + 0.0, cell.z + 0.0, false, false, false, false) end
        TriggerClientEvent('XS-PoliceSystem:client:solitary', target, 0)
        return true, Text('solitary_out', { name = inmate.name })
    end
    if #cells == 0 then return false, Text('err_no_solitary') end
    local minutes = (Config.Jail.solitaryMinutes or 5)
    inmate.solitary = os.time() + minutes * 60
    local cell = cells[math.random(1, #cells)]
    if ped ~= 0 then SetEntityCoords(ped, cell.x + 0.0, cell.y + 0.0, cell.z + 0.0, false, false, false, false) end
    TriggerClientEvent('XS-PoliceSystem:client:solitary', target, minutes * 60)
    Db.Log('solitary', { citizenid = inmate.cid, name = inmate.name }, minutes, 'Sent to solitary', officer)
    return true, Text('solitary_in', { name = inmate.name, minutes = minutes })
end

function Prison.Tick(src, inmate, place)
    if inmate.solitary and inmate.solitary <= os.time() then
        inmate.solitary = nil
        local cell = Jail.PickCell(place)
        local ped = GetPlayerPed(src)
        if cell and ped ~= 0 then SetEntityCoords(ped, cell.x + 0.0, cell.y + 0.0, cell.z + 0.0, false, false, false, false) end
        TriggerClientEvent('XS-PoliceSystem:client:solitary', src, 0)
    end
end

lib.callback.register('XS-PoliceSystem:server:prisonAlarms', function()
    local out, now = {}, os.time()
    for id, untilAt in pairs(Prison.alarms) do
        local place = Places.Get(id)
        local c = place and jailCenter(place)
        if c and untilAt > now then out[#out + 1] = { id = id, x = c.x, y = c.y, z = c.z, radius = Jail.Reach(place) * 1.5, on = true } end
    end
    return out
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for id, untilAt in pairs(Prison.alarms) do
            if untilAt <= now then Prison.StopAlarm(id) end
        end
    end
end)

exports('StartPrisonAlarm', function(jailId, minutes) return Prison.Alarm(jailId, minutes) end)
exports('StopPrisonAlarm', function(jailId) return Prison.StopAlarm(jailId) end)
exports('PrisonBreak', function(jailId, minutes) return Prison.Break(jailId, minutes) end)
exports('IsPrisonAlarmActive', function() return Prison.Active() end)
