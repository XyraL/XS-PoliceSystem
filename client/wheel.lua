Wheel = { open = false, page = 'root', index = 1, stack = {}, layout = nil, favourites = {}, list = {} }

local SLOT_KEYS = { 157, 158, 160, 164, 165, 159, 161, 162, 163 }
local BLOCK = { 14, 15, 16, 17, 24, 25, 37, 44, 47, 140, 141, 142, 143, 177, 199, 200, 257, 263, 157, 158, 159, 160, 161, 162, 163, 164, 165 }

local function pinKey()
    return math.floor(tonumber(Config.Wheel.pinKey) or 47)
end

local function maxFavourites()
    return math.floor(tonumber(Config.Wheel.favourites) or 4)
end

local function layout()
    return Wheel.layout or WheelDefs.Default()
end

local function isFav(id)
    for _, fav in ipairs(Wheel.favourites) do
        if fav == id then return true end
    end
    return false
end

local function customOf(id)
    for _, c in ipairs(layout().custom or {}) do
        if c.id == id then return c end
    end
    return nil
end

local function pageOf(id)
    for _, p in ipairs(layout().pages or {}) do
        if p.id == id then return p end
    end
    return nil
end

local function actionEntry(id, job)
    local def = WheelDefs.Actions[id]
    if def then
        if (Config.Wheel.actions or {})[id] == false then return nil end
        if id == 'mdt' and not MDT.Available() then return nil end
        if id == 'unitCams' and not UnitCams.CanRemote() then return nil end
        if Evidence.Hides(id) then return nil end
        local o = (layout().actions or {})[id] or {}
        if not WheelDefs.Permits(o, job) then return nil end
        return { id = id, icon = o.icon or def.icon, label = (o.label and o.label ~= '') and o.label or nil, danger = def.danger }
    end
    local c = customOf(id)
    if c and WheelDefs.Permits(c, job) then
        return { id = id, icon = c.icon, label = c.label, danger = c.danger, custom = true }
    end
    return nil
end

local function pageEntries(id, job, depth)
    local page = pageOf(id)
    local out = {}
    for _, ref in ipairs(page and page.items or {}) do
        if ref:sub(1, 1) == '@' then
            local sub = pageOf(ref:sub(2))
            if sub and depth < 4 and #pageEntries(sub.id, job, depth + 1) > 0 then
                local base = WheelDefs.Pages[sub.id] or {}
                out[#out + 1] = { id = sub.id, icon = sub.icon or base.icon or 'paper', label = (sub.label and sub.label ~= '') and sub.label or nil, page = true }
            end
        else
            local entry = actionEntry(ref, job)
            if entry then out[#out + 1] = entry end
        end
    end
    return out
end

local function items(page)
    local job = Framework.Job()
    local list = pageEntries(page, job, 0)
    for _, entry in ipairs(list) do
        if not entry.page and isFav(entry.id) then entry.fav = true end
    end
    if page == 'root' then
        local present, favs = {}, {}
        for _, entry in ipairs(list) do present[entry.id] = true end
        for _, id in ipairs(Wheel.favourites) do
            if not present[id] then
                local entry = actionEntry(id, job)
                if entry then
                    entry.fav = true
                    favs[#favs + 1] = entry
                end
            end
        end
        for i = #favs, 1, -1 do table.insert(list, 1, favs[i]) end
    end
    return list
end

local function targetInfo()
    local range = Config.Wheel.range or 3.0
    local player, ped, dist = Me.NearestPlayer(range)
    local vehicle = Me.NearestVehicle(6.0)
    local info = {}
    if player then info.person = { id = player, distance = Util.Round(dist, 1) } end
    if vehicle ~= 0 then info.vehicle = { plate = (GetVehicleNumberPlateText(vehicle) or ''):gsub('^%s+', ''):gsub('%s+$', '') } end
    return info, ped, vehicle
end

local lastSent
local function push(force)
    Wheel.list = items(Wheel.page)
    local list = Wheel.list
    if Wheel.index > #list then Wheel.index = #list end
    if Wheel.index < 1 then Wheel.index = 1 end
    local info = targetInfo()
    local current = list[Wheel.index]
    local page = pageOf(Wheel.page)
    local state = {
        page = Wheel.page, pageLabel = page and page.label ~= '' and page.label or nil,
        index = Wheel.index, items = list, target = info, back = #Wheel.stack > 0,
        pin = (maxFavourites() > 0 and current and not current.page) and { pinned = current.fav == true } or nil,
    }
    local encoded = json.encode(state)
    if force or encoded ~= lastSent then
        lastSent = encoded
        UI.Send('wheel', 'state', state)
    end
end

function Wheel.Close()
    if not Wheel.open then return end
    Wheel.open = false
    Inventory.HoldHotbar(false)
    Wheel.page, Wheel.index, Wheel.stack = 'root', 1, {}
    lastSent = nil
    UI.Send('wheel', 'close', {})
end

local function back()
    if #Wheel.stack == 0 then return Wheel.Close() end
    local prev = table.remove(Wheel.stack)
    Wheel.page, Wheel.index = prev.page, prev.index
    push(true)
end

local function run(entry)
    if not entry.custom then return Field.Run(entry.id) end
    local c = customOf(entry.id)
    if not c then return end
    if c.kind == 'client' then
        TriggerEvent(c.value)
    elseif c.kind == 'server' then
        TriggerServerEvent(c.value)
    else
        ExecuteCommand(c.value)
    end
end

local function choose(index)
    local entry = Wheel.list[index]
    if not entry then return end
    if entry.page then
        Wheel.stack[#Wheel.stack + 1] = { page = Wheel.page, index = index }
        Wheel.page, Wheel.index = entry.id, 1
        UI.Send('wheel', 'pulse', { index = index })
        push(true)
        return
    end
    UI.Send('wheel', 'pulse', { index = index })
    Wheel.Close()
    run(entry)
end

local pinning = false
local function togglePin()
    local entry = Wheel.list[Wheel.index]
    if pinning or not entry or entry.page then return end
    pinning = true
    local on = not isFav(entry.id)
    CreateThread(function()
        local ok, res = Me.Await('wheelPin', entry.id, on)
        pinning = false
        if not ok then return Framework.Notify(res or Text('err_failed'), 'error') end
        Wheel.favourites = type(res) == 'table' and res or {}
        Framework.Notify(Text(on and 'wheel_pinned' or 'wheel_unpinned'), 'success')
        if Wheel.open then
            local list = items(Wheel.page)
            for i, e in ipairs(list) do
                if e.id == entry.id and not e.page then Wheel.index = i break end
            end
            push(true)
        end
    end)
end

local function highlight(ped, vehicle)
    if ped and ped ~= 0 then
        local c = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
        DrawMarker(2, c.x, c.y, c.z + 0.45, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.18, 0.18, 0.18, 96, 165, 250, 200, true, true, 2, false)
    end
    if vehicle and vehicle ~= 0 and (Wheel.page == 'vehicle') then
        local c = GetEntityCoords(vehicle)
        DrawMarker(0, c.x, c.y, c.z + 1.6, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35, 96, 165, 250, 170, true, true, 2, false)
    end
end

function Wheel.Open()
    if Wheel.open then return end
    if not Me.IsCop() or IsPauseMenuActive() or IsEntityDead(PlayerPedId()) or Field.cuffed then return end
    if JailClient and JailClient.Inside() then return end
    Wheel.open = true
    Inventory.HoldHotbar(true)
    Wheel.page, Wheel.index, Wheel.stack = 'root', 1, {}
    UI.Send('wheel', 'open', {})
    push(true)
    CreateThread(function()
        local tick = 0
        while Wheel.open do
            for _, control in ipairs(BLOCK) do DisableControlAction(0, control, true) end
            DisableControlAction(0, pinKey(), true)
            DisablePlayerFiring(PlayerId(), true)
            local list = Wheel.list
            local moved = false
            if IsDisabledControlJustPressed(0, 15) then Wheel.index = Wheel.index - 1 moved = true end
            if IsDisabledControlJustPressed(0, 14) then Wheel.index = Wheel.index + 1 moved = true end
            if moved then
                if Wheel.index < 1 then Wheel.index = #list end
                if Wheel.index > #list then Wheel.index = 1 end
                push(true)
            end
            for slot, control in ipairs(SLOT_KEYS) do
                if slot <= #list and IsDisabledControlJustPressed(0, control) then
                    Wheel.index = slot
                    choose(slot)
                    break
                end
            end
            if not Wheel.open then break end
            if maxFavourites() > 0 and IsDisabledControlJustPressed(0, pinKey()) then togglePin() end
            if IsDisabledControlJustPressed(0, 24) then choose(Wheel.index) end
            if Wheel.open and (IsDisabledControlJustPressed(0, 25) or IsDisabledControlJustPressed(0, 177)) then back() end
            if Wheel.open and IsDisabledControlJustPressed(0, 200) then Wheel.Close() end
            if not Wheel.open then break end
            local _, ped, vehicle = targetInfo()
            highlight(ped, vehicle)
            tick = tick + 1
            if tick % 15 == 0 then push(false) end
            if IsEntityDead(PlayerPedId()) or not Me.IsCop() then Wheel.Close() end
            Wait(0)
        end
    end)
end

function Wheel.Load()
    local layoutData, favourites = Me.Await('wheel')
    if type(layoutData) == 'table' then Wheel.layout = layoutData end
    Wheel.favourites = type(favourites) == 'table' and favourites or {}
end

RegisterNetEvent('XS-PoliceSystem:client:wheelLayout', function(data)
    if type(data) ~= 'table' then return end
    Wheel.layout = data
    if Wheel.open then push(true) end
end)

local command = Config.Wheel.command or 'policewheel'

RegisterCommand('+' .. command, function()
    if Config.Wheel.holdToOpen then
        Wheel.Open()
    elseif Wheel.open then
        Wheel.Close()
    else
        Wheel.Open()
    end
end, false)

RegisterCommand('-' .. command, function()
    if Config.Wheel.holdToOpen and Wheel.open then
        local entry = Wheel.list[Wheel.index]
        if entry and not entry.page then
            choose(Wheel.index)
        else
            Wheel.Close()
        end
    end
end, false)

RegisterKeyMapping('+' .. command, Text('keybind_wheel'), 'keyboard', Config.Wheel.key or 'F6')

Framework.OnUnloaded(function()
    Wheel.Close()
    Wheel.favourites = {}
end)
Framework.OnLoaded(function()
    SetTimeout(1500, Wheel.Load)
end)
Framework.OnJob(function()
    if Wheel.open and not Me.IsCop() then Wheel.Close() end
end)

CreateThread(function()
    while not Framework.name do Wait(200) end
    Wait(2500)
    if Framework.Loaded() then Wheel.Load() end
end)
