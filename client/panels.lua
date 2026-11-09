Panels = { open = nil }

local APPS = { 'armory', 'garage', 'office', 'form', 'idcard', 'evidence', 'impound', 'impoundlot', 'canteen', 'prisonshop', 'scanner', 'tests', 'cameras', 'licences', 'lab', 'unitcams' }

function Panels.Open(app, data)
    if Panels.open and Panels.open ~= app then Panels.Close(Panels.open) end
    Panels.open = app
    UI.Send(app, 'open', data or {})
    UI.Focus(app, true)
end

function Panels.Close(app)
    app = app or Panels.open
    if not app then return end
    UI.Send(app, 'close', {})
    UI.Focus(app, false)
    if Panels.open == app then Panels.open = nil end
end

for _, app in ipairs(APPS) do
    UI.OnClose(app, function() Panels.Close(app) end)
end

Framework.OnUnloaded(function() Panels.Close() end)

UI.Handle('armory:take', function(p)
    if type(p) ~= 'table' then return false end
    local ok, msg = Me.Await('armoryTake', p.place, p.point, p.item, p.qty)
    if ok then Inventory.Invalidate() end
    return ok, msg
end)

UI.Handle('garage:spawn', function(p)
    if type(p) ~= 'table' then return false end
    local ok, err = Stations.SpawnVehicle(p.place, p.point, p.kind, p.model)
    if ok then Panels.Close('garage') end
    return ok, err
end)

UI.Handle('boss:refresh', function(p)
    return Me.Await('boss', p and p.place, p and p.point)
end)

UI.Handle('boss:hire', function(p)
    return Me.Await('bossHire', p.place, p.point, p.target, p.grade)
end)

UI.Handle('boss:grade', function(p)
    return Me.Await('bossGrade', p.place, p.point, p.cid, p.grade)
end)

UI.Handle('boss:fire', function(p)
    return Me.Await('bossFire', p.place, p.point, p.cid)
end)

UI.Handle('boss:callsign', function(p)
    return Me.Await('bossCallsign', p.place, p.point, p.cid, p.callsign)
end)

UI.Handle('lab:start', function(p)
    if type(p) ~= 'table' then return false end
    return Me.Await('labStart', p.place, p.point, p.key)
end)

UI.Handle('lab:analyse', function(p)
    if type(p) ~= 'table' then return false end
    return Me.Await('labAnalyse', p.place, p.point, p.key)
end)

UI.Handle('boss:money', function(p)
    return Me.Await('bossMoney', p.place, p.point, p.direction, p.amount)
end)

UI.Handle('boss:notes', function(p)
    return Me.Await('bossNotes', p.place, p.point, p.cid)
end)

UI.Handle('boss:note', function(p)
    return Me.Await('bossNote', p.place, p.point, p.cid, p.kind, p.text)
end)

UI.Handle('boss:noteDelete', function(p)
    return Me.Await('bossNoteDelete', p.place, p.point, p.id)
end)

UI.Handle('boss:armory', function(p)
    return Me.Await('bossArmory', p.place, p.point, p.list)
end)

UI.Handle('boss:fleet', function(p)
    return Me.Await('bossFleet', p.place, p.point, p.vehicles, p.helicopters)
end)

UI.Handle('boss:log', function(p)
    return Me.Await('bossLog', p.place, p.point, p.filter)
end)

UI.Handle('evidence:open', function(p)
    if type(p) ~= 'table' then return false end
    local ok, info = Me.Await('evidenceOpen', p.place, p.point, p.number, p.label)
    if not ok then return false, info end
    Panels.Close('evidence')
    SetTimeout(150, function() Stations.OpenStash(info) end)
    return true
end)

UI.Handle('form:submit', function(p)
    if type(p) ~= 'table' then return false end
    local ok, msg = Field.SubmitForm(p)
    if ok then Panels.Close('form') end
    return ok, msg
end)

UI.Handle('scanner:mdt', function(d)
    if type(d) ~= 'table' then return false end
    Panels.Close('scanner')
    if not MDT.OpenProfile(d.target) then return false, Text('err_no_mdt') end
    return true
end)
