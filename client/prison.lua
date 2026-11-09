PrisonAlarm = { list = {}, ringing = false }

local function start()
    if PrisonAlarm.ringing then return end
    local tries = 0
    while not PrepareAlarm('PRISON_ALARMS') and tries < 50 do
        tries = tries + 1
        Wait(100)
    end
    StartAlarm('PRISON_ALARMS', false)
    PrisonAlarm.ringing = true
end

local function stop()
    if not PrisonAlarm.ringing then return end
    StopAlarm('PRISON_ALARMS', true)
    PrisonAlarm.ringing = false
end

local function near()
    local pos = GetEntityCoords(PlayerPedId())
    for _, a in pairs(PrisonAlarm.list) do
        if #(pos - vector3(a.x, a.y, a.z)) <= a.radius then return true end
    end
    return false
end

RegisterNetEvent('XS-PoliceSystem:client:prisonAlarm', function(a)
    if type(a) ~= 'table' or not a.id then return end
    PrisonAlarm.list[a.id] = a.on and a or nil
    if not next(PrisonAlarm.list) then stop() end
end)

RegisterNetEvent('XS-PoliceSystem:client:solitary', function(seconds)
    seconds = tonumber(seconds) or 0
    if seconds > 0 then
        Framework.Notify(Text('solitary_you', { minutes = math.ceil(seconds / 60) }), 'error')
    else
        Framework.Notify(Text('solitary_over'), 'inform')
    end
end)

CreateThread(function()
    while not Framework.Loaded() do Wait(1000) end
    local list = Me.Await('prisonAlarms')
    for _, a in ipairs(type(list) == 'table' and list or {}) do PrisonAlarm.list[a.id] = a end
    while true do
        if next(PrisonAlarm.list) then
            if near() then start() else stop() end
            Wait(2000)
        else
            stop()
            Wait(3000)
        end
    end
end)
