WheelLayout = { current = nil, favourites = {} }

local function str(value, max)
    return Util.Text(value, max)
end

local function slug(value, max)
    return (tostring(value or ''):lower():gsub('[^%w_%-]', '')):sub(1, max or 32)
end

local function jobList(raw)
    local out, seen = {}, {}
    for _, name in ipairs(type(raw) == 'table' and raw or {}) do
        local job = slug(name, 32)
        if job ~= '' and not seen[job] and #out < 10 then
            seen[job] = true
            out[#out + 1] = job
        end
    end
    return out
end

local function limits(raw)
    raw = type(raw) == 'table' and raw or {}
    return { jobs = jobList(raw.jobs), grade = Util.Clamp(math.floor(tonumber(raw.grade) or 0), 0, 50) }
end

local function icon(value)
    return WheelDefs.IsIcon(value) and value or nil
end

local function cleanValue(kind, value)
    value = str(value, 96)
    if kind == 'command' then return (value:gsub('^/', '')) end
    return (value:gsub('[^%w_:%-%.]', ''))
end

function WheelLayout.Sanitize(raw)
    raw = type(raw) == 'table' and raw or WheelDefs.Default()

    local custom, known = {}, {}
    for _, c in ipairs(type(raw.custom) == 'table' and raw.custom or {}) do
        if type(c) == 'table' and #custom < 24 then
            local kind = WheelDefs.Kinds[c.kind] and c.kind or 'command'
            local value = cleanValue(kind, c.value)
            local label = str(c.label, 32)
            if value ~= '' and label ~= '' then
                local id = tostring(c.id or '')
                if not id:match('^x[%w_]+$') or #id > 24 or known[id] then id = 'x' .. Util.Id('') end
                known[id] = true
                local entry = limits(c)
                entry.id, entry.label, entry.icon, entry.kind, entry.value = id, label, icon(c.icon) or 'paper', kind, value
                entry.danger = c.danger == true
                custom[#custom + 1] = entry
            end
        end
    end

    local actions = {}
    for id in pairs(WheelDefs.Actions) do
        local o = type(raw.actions) == 'table' and raw.actions[id] or nil
        if type(o) == 'table' then
            local entry = limits(o)
            entry.label, entry.icon = str(o.label, 32), icon(o.icon)
            actions[id] = entry
        end
    end

    local rawPages = type(raw.pages) == 'table' and raw.pages or {}
    local defs, order = {}, {}
    for _, p in ipairs(rawPages) do
        if type(p) == 'table' and #order < 12 then
            local id = tostring(p.id or '')
            local builtIn = id == 'root' or WheelDefs.Pages[id] ~= nil
            if not builtIn and (not id:match('^pg[%w_]+$') or #id > 24) then id = 'pg' .. Util.Id('') end
            if not defs[id] then
                local label = str(p.label, 32)
                if builtIn or label ~= '' then
                    defs[id] = { id = id, label = label, icon = icon(p.icon), raw = type(p.items) == 'table' and p.items or {} }
                    order[#order + 1] = id
                end
            end
        end
    end
    if not defs.root then
        defs.root = { id = 'root', label = '', raw = {} }
        table.insert(order, 1, 'root')
    end

    if type(raw.pages) == 'table' then
        local seen = {}
        if type(raw.seen) == 'table' then
            for _, id in ipairs(raw.seen) do seen[tostring(id)] = true end
        else
            local added = {}
            for _, id in ipairs(WheelDefs.Added or {}) do added[id] = true end
            for id in pairs(WheelDefs.Actions) do if not added[id] then seen[id] = true end end
        end
        local placed = {}
        for _, page in pairs(defs) do
            for _, ref in ipairs(page.raw) do placed[tostring(ref or '')] = true end
        end
        for _, page in ipairs(WheelDefs.Default().pages) do
            local into = defs[page.id]
            if into then
                for _, id in ipairs(page.items) do
                    if WheelDefs.Actions[id] and not seen[id] and not placed[id] then
                        into.raw[#into.raw + 1] = id
                        placed[id] = true
                    end
                end
            end
        end
    end

    local used, pageUsed = {}, { root = true }
    local function resolve(page)
        local items = {}
        for _, ref in ipairs(page.raw) do
            ref = tostring(ref or '')
            if #items >= 12 then break end
            if ref:sub(1, 1) == '@' then
                local target = ref:sub(2)
                if defs[target] and not pageUsed[target] then
                    pageUsed[target] = true
                    items[#items + 1] = ref
                end
            elseif (WheelDefs.Actions[ref] or known[ref]) and not used[ref] then
                used[ref] = true
                items[#items + 1] = ref
            end
        end
        page.items = items
    end

    local pages, queue = {}, { 'root' }
    while #queue > 0 do
        local id = table.remove(queue, 1)
        local page = defs[id]
        resolve(page)
        pages[#pages + 1] = { id = page.id, label = page.label, icon = page.icon, items = page.items }
        for _, ref in ipairs(page.items) do
            if ref:sub(1, 1) == '@' then queue[#queue + 1] = ref:sub(2) end
        end
    end

    local seen = {}
    for id in pairs(WheelDefs.Actions) do seen[#seen + 1] = id end
    table.sort(seen)
    return { pages = pages, actions = actions, custom = custom, seen = seen }
end

function WheelLayout.Load()
    local row = MySQL.single.await('SELECT `data` FROM `xs_police_settings` WHERE `name` = ?', { 'wheel' })
    WheelLayout.current = WheelLayout.Sanitize(row and Db.Decode(row.data, nil) or nil)
    return WheelLayout.current
end

function WheelLayout.Get()
    return WheelLayout.current or WheelLayout.Load()
end

function WheelLayout.Save(raw)
    local layout = WheelLayout.Sanitize(raw)
    MySQL.query.await('INSERT INTO `xs_police_settings` (`name`, `data`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `data` = VALUES(`data`)', { 'wheel', Db.Json(layout) })
    WheelLayout.current = layout
    TriggerClientEvent('XS-PoliceSystem:client:wheelLayout', -1, layout)
    return layout
end

function WheelLayout.Limits(id)
    local layout = WheelLayout.Get()
    if WheelDefs.Actions[id] then return layout.actions[id] end
    for _, c in ipairs(layout.custom) do
        if c.id == id then return c end
    end
    return nil
end

function WheelLayout.Allowed(src, id, job)
    if not WheelDefs.Actions[id] then return true end
    job = job or Framework.GetJob(src)
    if not Framework.IsCop(job) then return true end
    return WheelDefs.Permits(WheelLayout.Limits(id), job)
end

local function maxFavourites()
    return Util.Clamp(math.floor(tonumber(Config.Wheel.favourites) or 4), 0, 8)
end

local function cleanFavourites(list)
    local layout = WheelLayout.Get()
    local out, seen = {}, {}
    for _, id in ipairs(type(list) == 'table' and list or {}) do
        id = tostring(id or '')
        local exists = WheelDefs.Actions[id] ~= nil
        if not exists then
            for _, c in ipairs(layout.custom) do if c.id == id then exists = true break end end
        end
        if exists and not seen[id] and #out < maxFavourites() then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    return out
end

function WheelLayout.Favourites(cid)
    if not cid then return {} end
    if WheelLayout.favourites[cid] == nil then
        local row = MySQL.single.await('SELECT `data` FROM `xs_police_favourites` WHERE `citizenid` = ?', { cid })
        WheelLayout.favourites[cid] = cleanFavourites(row and Db.Decode(row.data, {}) or {})
    end
    return WheelLayout.favourites[cid]
end

lib.callback.register('XS-PoliceSystem:server:wheel', function(src)
    return WheelLayout.Get(), WheelLayout.Favourites(Framework.GetCitizenId(src))
end)

lib.callback.register('XS-PoliceSystem:server:wheelPin', function(src, id, on)
    if maxFavourites() == 0 then return false, Text('err_failed') end
    local job = Framework.GetJob(src)
    if not Framework.IsCop(job, true) then return false, Text('err_police_only') end
    local cid = Framework.GetCitizenId(src)
    if not cid then return false end
    id = tostring(id or '')
    local list = {}
    for _, fav in ipairs(WheelLayout.Favourites(cid)) do
        if fav ~= id then list[#list + 1] = fav end
    end
    if on then
        if #list >= maxFavourites() then return false, Text('wheel_pin_full', { max = maxFavourites() }) end
        list[#list + 1] = id
    end
    list = cleanFavourites(list)
    WheelLayout.favourites[cid] = list
    MySQL.query.await('INSERT INTO `xs_police_favourites` (`citizenid`, `data`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `data` = VALUES(`data`)', { cid, Db.Json(list) })
    return true, list
end)

lib.callback.register('XS-PoliceSystem:server:builderWheelSave', function(src, raw)
    if not Framework.IsAdmin(src) then return false, Text('err_not_admin') end
    local layout = WheelLayout.Save(raw)
    for cid, list in pairs(WheelLayout.favourites) do WheelLayout.favourites[cid] = cleanFavourites(list) end
    print(('^2[XS-PoliceSystem]^0 %s saved the wheel layout.'):format(GetPlayerName(src) or src))
    return true, layout
end)

lib.callback.register('XS-PoliceSystem:server:builderWheelReset', function(src)
    if not Framework.IsAdmin(src) then return false, Text('err_not_admin') end
    return true, WheelLayout.Save(WheelDefs.Default())
end)
