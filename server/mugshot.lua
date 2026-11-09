Mugshot = { cache = {}, posing = {}, allowed = {} }

local MAX = 200000

function Mugshot.Get(cid)
    if not cid then return nil end
    if Mugshot.cache[cid] == nil then
        local row = MySQL.single.await('SELECT `image` FROM `xs_police_mugshots` WHERE `citizenid` = ?', { cid })
        Mugshot.cache[cid] = row and row.image or false
    end
    return Mugshot.cache[cid] or nil
end

local function officerOf(src)
    local job = Framework.GetJob(src)
    return Framework.IsCop(job) and job or nil
end

local function stop(target)
    if Mugshot.posing[target] then
        Mugshot.posing[target] = nil
        TriggerClientEvent('XS-PoliceSystem:client:mugshotEnd', target)
    end
end

lib.callback.register('XS-PoliceSystem:server:mugshotStart', function(src, target)
    if not officerOf(src) then return false, Text('err_police_only') end
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return false, Text('err_no_player') end
    local me, them = Places.Coords(src), Places.Coords(target)
    if not me or not them or #(me - them) > 4.0 then return false, Text('err_too_far') end
    if not Field.Restrained(target) then return false, Text('err_not_restrained') end
    local cid = Framework.GetCitizenId(target) or ''
    local board = {
        title = (Config.Mugshot or {}).title or 'LOS SANTOS POLICE DEPT',
        name = (Framework.GetName(target) or ''):upper(),
        number = cid,
        date = os.date('%d/%m/%Y'),
    }
    Mugshot.posing[target] = src
    Mugshot.allowed[target] = { src = src, untilAt = os.time() + 30 }
    TriggerClientEvent('XS-PoliceSystem:client:mugshotPose', target, board)
    return true, board
end)

lib.callback.register('XS-PoliceSystem:server:mugshotSave', function(src, target, image)
    target = tonumber(target)
    local allowed = target and Mugshot.allowed[target]
    if not officerOf(src) or not allowed or allowed.src ~= src or allowed.untilAt < os.time() then return false, Text('err_failed') end
    Mugshot.allowed[target] = nil
    stop(target)
    if type(image) ~= 'string' or #image > MAX or not image:find('^data:image/jpeg;base64,') then return false, Text('err_failed') end
    local cid = Framework.GetCitizenId(target)
    if not cid then return false, Text('err_no_player') end
    MySQL.query.await('INSERT INTO `xs_police_mugshots` (`citizenid`, `image`, `officer`, `taken_at`) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE `image` = VALUES(`image`), `officer` = VALUES(`officer`), `taken_at` = VALUES(`taken_at`)',
        { cid, image, Units.Label(src), os.time() })
    Mugshot.cache[cid] = image
    TriggerEvent('XS-PoliceSystem:server:mugshot', target, cid, image)
    return true, Text('mugshot_saved')
end)

lib.callback.register('XS-PoliceSystem:server:mugshotEnd', function(src, target)
    target = tonumber(target)
    if target and Mugshot.posing[target] == src then stop(target) end
    return true
end)

AddEventHandler('playerDropped', function()
    local src = source
    Mugshot.posing[src], Mugshot.allowed[src] = nil, nil
    for target, officer in pairs(Mugshot.posing) do
        if officer == src then stop(target) end
    end
end)

exports('GetMugshot', function(cid) return Mugshot.Get(cid) end)
