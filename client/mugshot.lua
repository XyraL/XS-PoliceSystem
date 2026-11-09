Booking = { board = nil, props = {}, rendering = false, target = nil }

local BOARD, TEXT = `prop_police_id_board`, `prop_police_id_text`

local function scaleform(board)
    local handle = RequestScaleformMovie('MUGSHOT_BOARD_01')
    local untilAt = GetGameTimer() + 3000
    while not HasScaleformMovieLoaded(handle) and GetGameTimer() < untilAt do Wait(0) end
    if not HasScaleformMovieLoaded(handle) then return nil end
    BeginScaleformMovieMethod(handle, 'SET_BOARD')
    ScaleformMovieMethodAddParamTextureNameString(board.title or '')
    ScaleformMovieMethodAddParamTextureNameString(board.name or '')
    ScaleformMovieMethodAddParamTextureNameString(board.number or '')
    ScaleformMovieMethodAddParamTextureNameString(board.date or '')
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(0)
    EndScaleformMovieMethod()
    return handle
end

local function renderTarget()
    if not IsNamedRendertargetRegistered('ID_Text') then RegisterNamedRendertarget('ID_Text', false) end
    if not IsNamedRendertargetLinked(TEXT) then LinkNamedRendertarget(TEXT) end
    return GetNamedRendertargetRenderId('ID_Text')
end

local function render(board)
    if Booking.rendering then Booking.board = board return end
    Booking.board = board
    Booking.rendering = true
    CreateThread(function()
        local handle = scaleform(board)
        local target = handle and renderTarget() or 0
        while Booking.rendering and handle do
            SetTextRenderId(target)
            Set_2dLayer(4)
            DrawScaleformMovie(handle, 0.405, 0.37, 0.81, 0.74, 255, 255, 255, 255, 0)
            SetTextRenderId(GetDefaultScriptRendertargetRenderId())
            Wait(0)
        end
        if handle then SetScaleformMovieAsNoLongerNeeded(handle) end
        Booking.rendering = false
    end)
end

local function clearProps()
    for _, e in ipairs(Booking.props) do
        if DoesEntityExist(e) then DeleteEntity(e) end
    end
    Booking.props = {}
end

RegisterNetEvent('XS-PoliceSystem:client:mugshotPose', function(board)
    local ped = PlayerPedId()
    clearProps()
    if Util.LoadModel(BOARD) and Util.LoadModel(TEXT) then
        local c = GetEntityCoords(ped)
        local b = CreateObject(BOARD, c.x, c.y, c.z, true, true, false)
        local t = CreateObject(TEXT, c.x, c.y, c.z, true, true, false)
        AttachEntityToEntity(t, b, -1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        AttachEntityToEntity(b, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        Booking.props = { b, t }
        SetModelAsNoLongerNeeded(BOARD)
        SetModelAsNoLongerNeeded(TEXT)
    end
    local dict = GetEntityModel(ped) == `mp_f_freemode_01` and 'mp_character_creation@lineup@female_a' or 'mp_character_creation@lineup@male_a'
    if Util.LoadAnim(dict) then TaskPlayAnim(ped, dict, 'loop_raised', 8.0, -8.0, -1, 49, 0.0, false, false, false) end
    render(board)
    SetTimeout(20000, function()
        if #Booking.props > 0 then TriggerEvent('XS-PoliceSystem:client:mugshotEnd') end
    end)
end)

RegisterNetEvent('XS-PoliceSystem:client:mugshotEnd', function()
    Booking.rendering = false
    clearProps()
    local ped = PlayerPedId()
    StopAnimTask(ped, 'mp_character_creation@lineup@male_a', 'loop_raised', 1.0)
    StopAnimTask(ped, 'mp_character_creation@lineup@female_a', 'loop_raised', 1.0)
end)

local function finish(target)
    Booking.rendering = false
    if Booking.cam then
        RenderScriptCams(false, true, 300, true, true)
        DestroyCam(Booking.cam, false)
        Booking.cam = nil
    end
    Me.Await('mugshotEnd', target)
end

function Booking.Mugshot()
    local target, tped = Me.NearestPlayer(3.0)
    if not target then return Framework.Notify(Text('err_nobody_near'), 'error') end
    local ok, board = Me.Await('mugshotStart', target)
    if not ok then return Me.Result(false, board) end
    Booking.target = target
    render(board)
    Wait(1500)
    local head = GetPedBoneCoords(tped, 31086, 0.0, 0.0, 0.0)
    local fwd = GetEntityForwardVector(tped)
    local from = head + fwd * 1.35 + vector3(0.0, 0.0, 0.02)
    Booking.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', from.x, from.y, from.z, 0.0, 0.0, 0.0, 36.0, false, 0)
    PointCamAtCoord(Booking.cam, head.x, head.y, head.z - 0.12)
    SetCamActive(Booking.cam, true)
    RenderScriptCams(true, true, 400, true, true)
    Wait(900)
    PlaySoundFrontend(-1, 'Camera_Shoot', 'Phone_Soundset_Franklin', true)
    if GetResourceState('screenshot-basic') ~= 'started' then
        Wait(600)
        finish(target)
        return Framework.Notify(Text('mugshot_no_screenshot'), 'inform')
    end
    local done = false
    exports['screenshot-basic']:requestScreenshot({ encoding = 'jpg', quality = 0.92 }, function(data)
        done = true
        UI.Send('mugshot', 'crop', { image = data, target = target })
    end)
    local untilAt = GetGameTimer() + 5000
    while not done and GetGameTimer() < untilAt do Wait(50) end
    Wait(300)
    finish(target)
end

UI.Handle('mugshot:save', function(p)
    if type(p) ~= 'table' then return false end
    local ok, msg = Me.Await('mugshotSave', tonumber(p.target), p.image)
    Me.Result(ok, msg)
    return ok
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then clearProps() end
end)
