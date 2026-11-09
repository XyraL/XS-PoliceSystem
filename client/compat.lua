local function nearest(name)
    local target = Me.NearestPlayer(Config.Wheel.range or 3.0)
    if not target then return Framework.Notify(Text('err_nobody_near'), 'error') end
    local ok, msg = Me.Await('action', name, target)
    Me.Result(ok, type(msg) == 'string' and msg or nil)
end

local function asCop(name)
    return function()
        if Me.IsCop() then Field.Run(name) else nearest(name) end
    end
end

local function only(name)
    return function() Field.Run(name) end
end

local EVENTS = {
    ['police:client:CuffPlayerSoft'] = asCop('cuff'),
    ['police:client:CuffPlayer'] = asCop('cuff'),
    ['police:client:EscortPlayer'] = asCop('escort'),
    ['police:client:KidnapPlayer'] = asCop('escort'),
    ['police:client:PutPlayerInVehicle'] = asCop('putInVehicle'),
    ['police:client:SetPlayerOutVehicle'] = asCop('takeOutVehicle'),
    ['police:client:RobPlayer'] = function() nearest('rob') end,
    ['police:client:SearchPlayer'] = only('search'),
    ['police:client:JailPlayer'] = only('jail'),
    ['police:client:CheckStatus'] = only('checkStatus'),
    ['police:client:CheckDistance'] = only('tracker'),
    ['police:client:SendPoliceEmergencyAlert'] = only('panic'),
    ['police:client:spawnCone'] = only('cone'),
    ['police:client:spawnBarrier'] = only('barrier'),
    ['police:client:spawnRoadSign'] = only('barrier'),
    ['police:client:spawnTent'] = only('barrier'),
    ['police:client:spawnLight'] = only('barrier'),
    ['police:client:SpawnSpikeStrip'] = only('spikes'),
    ['police:client:ImpoundVehicle'] = only('impound'),
    ['police:client:deleteObject'] = only('removeProp'),
}

for event, fn in pairs(EVENTS) do
    RegisterNetEvent(event, function() CreateThread(fn) end)
end

RegisterNetEvent('police:client:SeizeDriverLicense', function()
    if not Me.IsCop() then return end
    nearest('seizeLicense')
end)

RegisterNetEvent('police:client:spawnPObj', function(item)
    if type(item) == 'table' then item = item.args or item[1] end
    Field.Run(item == 'cone' and 'cone' or 'barrier')
end)

RegisterNetEvent('police:client:GetCuffed', function() end)
RegisterNetEvent('police:client:DeEscort', function() end)

RegisterNetEvent('police:client:SendToJail', function()
    TriggerServerEvent('XS-PoliceSystem:server:jailReturn')
end)

RegisterNetEvent('prison:client:Enter', function()
    TriggerServerEvent('XS-PoliceSystem:server:jailReturn')
end)

RegisterNetEvent('police:client:policeAlert', function(coords, text, camId)
    if not Me.IsCop() or not coords then return end
    Framework.Notify(Text('alert_notify', { text = text or '' }), 'error')
    camId = tonumber(camId)
    if camId and (Config.Cameras or {}).enabled and ((Config.Cameras or {}).list or {})[camId] then
        Cameras.last = camId
        Framework.Notify(Text('alert_camera', { id = camId }), 'inform')
    end
    TriggerEvent('XS-PoliceSystem:client:alertBlip', { x = coords.x, y = coords.y, z = coords.z }, text or Text('alert_title'), 'alert')
end)

AddEventHandler('XS-PoliceSystem:client:cuffChanged', function(on)
    TriggerEvent('police:client:cuffChanged', on)
end)

local toldMedical = false

RegisterNetEvent('XS-PoliceSystem:client:escorted', function(officer)
    local on = officer ~= nil and Field.IsDown()
    if on == toldMedical then return end
    toldMedical = on
    TriggerEvent('hospital:client:isEscorted', on)
end)

RegisterNetEvent('XS-PoliceSystem:client:escorting', function(target)
    TriggerEvent('hospital:client:SetEscortingState', target ~= nil)
    TriggerEvent('qb-kidnapping:client:SetKidnapping', target ~= nil)
end)

local function isCuffed() return Field.cuffed == true end

for _, name in ipairs({ 'qb-policejob', 'qbx_police' }) do
    AddEventHandler(('__cfx_export_%s_IsHandcuffed'):format(name), function(setCB) setCB(isCuffed) end)
end

exports('IsHandcuffed', isCuffed)
exports('IsOnDuty', function() return Me.IsCop() == true end)
