Cameras = { active = nil, cam = nil, offline = {}, last = nil }

local EXIT = { 177, 200, 25 }

local function list()
    return (Config.Cameras or {}).list or {}
end

local function ids()
    local out = {}
    for id in pairs(list()) do out[#out + 1] = id end
    table.sort(out)
    return out
end

local function step(id, dir)
    local all = ids()
    for i, v in ipairs(all) do
        if v == id then return all[((i - 1 + dir) % #all) + 1] end
    end
    return all[1]
end

local function place(id)
    local c = list()[id]
    if not c then return false end
    if Cameras.cam then DestroyCam(Cameras.cam, false) end
    local r = c.r or {}
    Cameras.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.coords.x + 0.0, c.coords.y + 0.0, c.coords.z + 0.0, (r.x or -30.0) + 0.0, (r.y or 0.0) + 0.0, (r.z or 0.0) + 0.0, 60.0, false, 0)
    SetCamActive(Cameras.cam, true)
    RenderScriptCams(true, false, 0, true, true)
    SetFocusPosAndVel(c.coords.x + 0.0, c.coords.y + 0.0, c.coords.z + 0.0, 0.0, 0.0, 0.0)
    Cameras.active = id
    Cameras.base = { x = (r.x or -30.0) + 0.0, z = (r.z or 0.0) + 0.0 }
    Cameras.yaw, Cameras.pitch, Cameras.fov = 0.0, 0.0, 60.0
    UI.Send('cctv', 'show', { id = id, label = c.label or ('CAM ' .. id), offline = Cameras.offline[id] == true, rotate = c.canRotate == true })
    return true
end

function Cameras.Close()
    if not Cameras.active then return end
    Cameras.active = nil
    DoScreenFadeOut(200)
    Wait(220)
    if Cameras.cam then DestroyCam(Cameras.cam, false) end
    Cameras.cam = nil
    RenderScriptCams(false, false, 0, true, true)
    ClearFocus()
    ClearTimecycleModifier()
    FreezeEntityPosition(PlayerPedId(), false)
    UI.Send('cctv', 'hide', {})
    DoScreenFadeIn(200)
end

function Cameras.View(id)
    id = tonumber(id)
    if not id or not list()[id] then return Framework.Notify(Text('err_no_camera'), 'error') end
    if not Me.IsCop() then return Framework.Notify(Text('err_police_only'), 'error') end
    if Cameras.active then
        place(id)
        return
    end
    DoScreenFadeOut(200)
    Wait(220)
    FreezeEntityPosition(PlayerPedId(), true)
    place(id)
    SetTimecycleModifier('scanline_cam_cheap')
    SetTimecycleModifierStrength(1.0)
    DoScreenFadeIn(200)
    CreateThread(function()
        while Cameras.active do
            DisableAllControlActions(0)
            HideHudAndRadarThisFrame()
            local c = list()[Cameras.active]
            if c and c.canRotate then
                Cameras.yaw = Util.Clamp(Cameras.yaw - GetDisabledControlNormal(0, 1) * 4.0, -70.0, 70.0)
                Cameras.pitch = Util.Clamp(Cameras.pitch - GetDisabledControlNormal(0, 2) * 3.0, -35.0, 25.0)
            end
            if IsDisabledControlJustPressed(0, 241) then Cameras.fov = math.max(20.0, Cameras.fov - 5.0) end
            if IsDisabledControlJustPressed(0, 242) then Cameras.fov = math.min(70.0, Cameras.fov + 5.0) end
            if Cameras.cam then
                SetCamRot(Cameras.cam, Cameras.base.x + Cameras.pitch, 0.0, Cameras.base.z + Cameras.yaw, 2)
                SetCamFov(Cameras.cam, Cameras.fov)
            end
            if IsDisabledControlJustPressed(0, 34) or IsDisabledControlJustPressed(0, 174) then place(step(Cameras.active, -1)) end
            if IsDisabledControlJustPressed(0, 35) or IsDisabledControlJustPressed(0, 175) then place(step(Cameras.active, 1)) end
            for _, control in ipairs(EXIT) do
                if IsDisabledControlJustPressed(0, control) then
                    Cameras.Close()
                    break
                end
            end
            if IsEntityDead(PlayerPedId()) or not Me.IsCop() then Cameras.Close() end
            Wait(0)
        end
    end)
end

function Cameras.OpenPicker()
    if not (Config.Cameras or {}).enabled then return end
    local out = {}
    for _, id in ipairs(ids()) do
        local c = list()[id]
        out[#out + 1] = { id = id, label = c.label or ('CAM ' .. id), online = Cameras.offline[id] ~= true }
    end
    Panels.Open('cameras', { cameras = out, last = Cameras.last })
end

UI.Handle('cameras:watch', function(p)
    local id = tonumber(p and p.id)
    if not id then return false end
    Panels.Close('cameras')
    CreateThread(function()
        Wait(150)
        Cameras.View(id)
    end)
    return true
end)

RegisterNetEvent('XS-PoliceSystem:client:camera', function(id)
    if id then CreateThread(function() Cameras.View(id) end) else Cameras.OpenPicker() end
end)

RegisterNetEvent('police:client:ActiveCamera', function(id)
    id = tonumber(id)
    CreateThread(function()
        if id == 0 then Cameras.Close() else Cameras.View(id) end
    end)
end)

RegisterNetEvent('police:client:DisableAllCameras', function()
    for id in pairs(list()) do Cameras.offline[id] = true end
end)

RegisterNetEvent('police:client:EnableAllCameras', function()
    Cameras.offline = {}
end)

RegisterNetEvent('police:client:SetCamera', function(key, online)
    local keys = type(key) == 'table' and key or { key }
    for _, id in ipairs(keys) do
        id = tonumber(id)
        if id then Cameras.offline[id] = online == false or nil end
    end
end)

Framework.OnUnloaded(function()
    if Cameras.active then CreateThread(Cameras.Close) end
end)
