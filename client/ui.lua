UI = { focus = {}, rpc = {}, ready = false, queue = {} }

function UI.Send(app, action, data)
    local message = { app = app, action = action, data = data }
    if not UI.ready then
        UI.queue[#UI.queue + 1] = message
        return
    end
    SendNUIMessage(message)
end

local function applyFocus()
    local wantFocus, wantCursor, keepInput = false, false, false
    for _, f in pairs(UI.focus) do
        wantFocus = true
        if f.cursor then wantCursor = true end
        if f.keepInput then keepInput = true end
    end
    SetNuiFocus(wantFocus, wantCursor)
    SetNuiFocusKeepInput(keepInput)
end

function UI.Focus(owner, on, opts)
    if on then
        UI.focus[owner] = { cursor = not (opts and opts.cursor == false), keepInput = opts and opts.keepInput == true }
    else
        UI.focus[owner] = nil
    end
    applyFocus()
end

function UI.HasFocus(owner)
    return UI.focus[owner] ~= nil
end

function UI.Handle(name, fn)
    UI.rpc[name] = fn
end

RegisterNUICallback('ready', function(_, cb)
    UI.ready = true
    SendNUIMessage({ app = 'core', action = 'boot', data = { locale = TextTable(), config = UI.PublicConfig() } })
    for _, message in ipairs(UI.queue) do SendNUIMessage(message) end
    UI.queue = {}
    cb(true)
end)

RegisterNUICallback('rpc', function(data, cb)
    local handler = type(data) == 'table' and UI.rpc[data.name] or nil
    if not handler then
        cb({ ok = false, error = Text('err_failed') })
        return
    end
    local ok, a, b = pcall(handler, data.payload)
    if not ok then
        print(('^1[XS-PoliceSystem]^0 NUI %s failed: %s'):format(tostring(data.name), tostring(a)))
        cb({ ok = false, error = Text('err_failed') })
        return
    end
    if a == false then
        cb({ ok = false, error = b or Text('err_failed') })
    else
        cb({ ok = true, data = a == true and b or a })
    end
end)

RegisterNUICallback('close', function(data, cb)
    local app = type(data) == 'table' and data.app or nil
    if app and UI.closers and UI.closers[app] then
        pcall(UI.closers[app])
    else
        UI.focus = {}
        applyFocus()
    end
    cb(true)
end)

UI.closers = {}

function UI.OnClose(app, fn)
    UI.closers[app] = fn
end

function UI.PublicConfig()
    return {
        wheel = { actions = Config.Wheel.actions, holdToOpen = Config.Wheel.holdToOpen == true },
        props = Config.Props.list,
        fineMax = Config.Fines.max or 50000,
        maxMonths = Config.Jail.maxMonths or 300,
        minutesPerMonth = Config.Jail.minutesPerMonth or 1,
    }
end

function UI.Await(name, ...)
    local result = table.pack(lib.callback.await('XS-PoliceSystem:server:' .. name, false, ...))
    return table.unpack(result, 1, result.n)
end
