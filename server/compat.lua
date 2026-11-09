Compat = { alertAt = {} }

function Compat.CopCount(count)
    TriggerClientEvent('police:SetCopCount', -1, count or Duty.Count())
end

function Compat.Alert(coords, text, camId)
    if not coords then return end
    local c = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }
    for _, cop in ipairs(Framework.Cops(true)) do
        TriggerClientEvent('police:client:policeAlert', cop, vector3(c.x, c.y, c.z), text, camId)
        TriggerClientEvent('qb-phone:client:addPoliceAlert', cop, { title = Text('alert_title'), coords = c, description = text })
    end
end

RegisterNetEvent('police:server:policeAlert', function(text, camId, playerSource)
    local origin = tonumber(source)
    if not origin or origin <= 0 then origin = tonumber(playerSource) end
    if not origin then return end
    local now = GetGameTimer()
    if Compat.alertAt[origin] and now - Compat.alertAt[origin] < 3000 then return end
    Compat.alertAt[origin] = now
    Compat.Alert(Places.Coords(origin), Util.Text(text, 120), camId)
end)

RegisterNetEvent('police:server:UpdateCurrentCops', function()
    TriggerClientEvent('police:SetCopCount', source, Duty.Count())
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = player and player.PlayerData and player.PlayerData.source
    if src then TriggerClientEvent('police:SetCopCount', src, Duty.Count()) end
end)

CreateThread(function()
    while true do
        Wait(600000)
        Compat.CopCount(Duty.Count())
    end
end)

local function forcePresent()
    for _, src in ipairs(Framework.Players()) do
        local job = Framework.GetJob(src)
        if job and Util.IsCopJob(job) and (job.grade or 0) >= 2 then return true end
    end
    return false
end

local function dutyPlayers()
    local out = {}
    for _, src in ipairs(Framework.Cops(true)) do
        local job = Framework.GetJob(src)
        out[#out + 1] = { source = src, label = Units.Callsign(src) or 'NO CALLSIGN', job = job and job.name }
    end
    return out
end

CreateThread(function()
    local core = Framework.core
    if not core then
        local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
        core = ok and obj or nil
    end
    if not core or not core.Functions or not core.Functions.CreateCallback then return end
    core.Functions.CreateCallback('police:GetCops', function(_, cb) cb(Duty.Count()) end)
    core.Functions.CreateCallback('police:GetDutyPlayers', function(_, cb) cb(dutyPlayers()) end)
    core.Functions.CreateCallback('police:server:IsPoliceForcePresent', function(_, cb) cb(forcePresent()) end)
    core.Functions.CreateCallback('police:IsPlateFlagged', function(_, cb, plate) cb(Plates.IsFlagged(plate)) end)
    core.Functions.CreateCallback('police:server:IsPlateFlagged', function(_, cb, plate) cb(Plates.IsFlagged(plate)) end)
    core.Functions.CreateCallback('police:server:isPlayerDead', function(_, cb, target) cb(Field.IsDown(tonumber(target))) end)
    core.Functions.CreateCallback('police:GetPlayerStatus', function(_, cb, target) cb(tonumber(target) and Status.Texts(tonumber(target)) or {}) end)
    core.Functions.CreateCallback('prison:server:IsAlarmActive', function(_, cb) cb(Prison.Active()) end)
end)

lib.callback.register('qbx_police:server:isPoliceForcePresent', function() return forcePresent() or nil end)
lib.callback.register('police:server:isPlateFlagged', function(_, plate) return Plates.IsFlagged(plate) end)
lib.callback.register('police:GetPlayerStatus', function(_, target) return tonumber(target) and Status.Texts(tonumber(target)) or {} end)
lib.callback.register('police:server:isPlayerDead', function(_, target) return Field.IsDown(tonumber(target)) end)
lib.callback.register('police:server:CuffPlayer', function(src, target)
    Field.Act(src, 'cuff', target)
    return true
end)

local function nearestVehicle(src, range)
    local at = Places.Coords(src)
    if not at then return nil end
    local best, bestDist = nil, range or 6.0
    for _, vehicle in ipairs(GetAllVehicles()) do
        local d = #(GetEntityCoords(vehicle) - at)
        if d <= bestDist then best, bestDist = vehicle, d end
    end
    return best
end

local function relay(event, action)
    RegisterNetEvent(event, function(target)
        local src = source
        if type(target) ~= 'number' then target = Field.Closest(src) end
        if target then Field.Act(src, action, target) end
    end)
end

relay('police:server:CuffPlayer', 'cuff')
relay('police:server:EscortPlayer', 'escort')
relay('police:server:KidnapPlayer', 'escort')
relay('police:server:SetPlayerOutVehicle', 'takeOutVehicle')
relay('police:server:SearchPlayer', 'search')
relay('police:server:RobPlayer', 'rob')
relay('police:server:SeizeCash', 'seize')
relay('police:server:SeizeDriverLicense', 'seizeLicense')
relay('police:server:SetTracker', 'tracker')

RegisterNetEvent('evidence:server:UpdateStatus', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    for id, entry in pairs(data) do
        if type(entry) == 'table' then Status.Set(src, id, entry.time) end
    end
end)

RegisterNetEvent('police:server:PutPlayerInVehicle', function(target)
    local src = source
    if type(target) ~= 'number' then target = Field.Closest(src) end
    local vehicle = nearestVehicle(src)
    if target and vehicle then Field.Act(src, 'putInVehicle', target, { netId = NetworkGetNetworkIdFromEntity(vehicle) }) end
end)

RegisterNetEvent('police:server:BillPlayer', function(target, price)
    Field.Act(source, 'fine', target, { amount = price, reason = Text('fine_default_reason') })
end)

RegisterNetEvent('police:server:JailPlayer', function(target, minutes)
    Field.Act(source, 'jail', target, { months = minutes, reason = Text('no_reason') })
end)

local function trustedJail(target, minutes, reason)
    target = tonumber(target)
    if not target or not GetPlayerName(target) or Jail.inmates[target] then return false end
    return Jail.Send(target, tonumber(minutes) or 0, reason or Text('no_reason'), nil)
end

AddEventHandler('qb-prison:server:sendToJail', function(target, minutes) trustedJail(target, minutes, Text('mdt_sentence')) end)
AddEventHandler('prison:server:SendToJail', function(target, minutes) trustedJail(target, minutes, Text('mdt_sentence')) end)

local function ignore(event) RegisterNetEvent(event, function() end) end
ignore('police:server:SetHandcuffStatus')
ignore('prison:server:SetJailStatus')
ignore('police:server:UpdateBlips')
ignore('evidence:server:CreateCasing')

RegisterNetEvent('evidence:server:CreateFingerDrop', function(coords)
    if not Evidence.Ours() then return Evidence.Forward('fingerprint', source, coords) end
    Forensics.Fingerprint(source, coords)
end)

RegisterNetEvent('evidence:server:CreateBloodDrop', function(_, _, coords)
    if not Evidence.Ours() then return Evidence.Forward('blood', source, coords) end
    Forensics.Blood(source, coords)
end)

AddEventHandler('playerDropped', function()
    Compat.alertAt[source] = nil
end)

RegisterNetEvent('XS-PoliceSystem:server:openMdt', function()
    local src = source
    if not Framework.IsCopSource(src) or GetResourceState('drx_mdt') ~= 'started' then return end
    pcall(function() exports.drx_mdt:OpenMDT(src) end)
end)
