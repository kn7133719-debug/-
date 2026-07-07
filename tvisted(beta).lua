-- =========================================================
--  TWISTED [BETA] — Vehicle Fly Script
--  Executor: Delta
--  Bypass: AssemblyLinearVelocity + BodyForce (physics-based)
-- =========================================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player   = Players.LocalPlayer
local isMobile = UserInputService.TouchEnabled

local Config = {
    enabled      = false,
    flyMode      = false,
    flySpeed     = 350,
    hoverHeight  = 4,
    lerpFactor   = 10,
    autoUnanchor = true,
    stabilize    = true,
}

local State = {
    flyConn        = nil,
    gravForce      = nil,
    savedAnchors   = {},
    savedCollision = {},
    flyButton      = nil,
    healConn       = nil,
}

-- ============================================================
-- ПЕРЕХВАТ ТАЧА — обход блокировки VehicleSeat
-- ============================================================
local _touchActive = nil
local _touchStart  = nil
local _touchCur    = nil
local TOUCH_DEAD   = 12
local TOUCH_FULL   = 75

if isMobile then
    UserInputService.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.Touch then return end
        if _touchActive then return end
        local sw = workspace.CurrentCamera.ViewportSize.X
        if inp.Position.X < sw * 0.45 then
            _touchActive = inp
            _touchStart  = Vector2.new(inp.Position.X, inp.Position.Y)
            _touchCur    = _touchStart
        end
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if inp ~= _touchActive then return end
        _touchCur = Vector2.new(inp.Position.X, inp.Position.Y)
    end)

    UserInputService.InputEnded:Connect(function(inp)
        if inp ~= _touchActive then return end
        _touchActive = nil
        _touchStart  = nil
        _touchCur    = nil
    end)
end

local function getTouchDir()
    if not _touchStart or not _touchCur then return Vector2.zero end
    local delta = _touchCur - _touchStart
    local len   = delta.Magnitude
    if len < TOUCH_DEAD then return Vector2.zero end
    return delta.Unit * math.min((len - TOUCH_DEAD) / TOUCH_FULL, 1)
end

-- ============================================================

local _guiParent = player:WaitForChild("PlayerGui")
pcall(function() if gethui then _guiParent = gethui() end end)

local ScreenUI = Instance.new("ScreenGui")
ScreenUI.Name           = "TwFly"
ScreenUI.ResetOnSpawn   = false
ScreenUI.IgnoreGuiInset = true
ScreenUI.DisplayOrder   = 999
ScreenUI.Parent         = _guiParent

local function getVehicleRoot()
    local char = player.Character
    if not char then return nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil, nil end
    local seat = hum.SeatPart
    if not seat then return nil, nil end
    local model = seat:FindFirstAncestorWhichIsA("Model")
    if not model then return nil, nil end
    local root = model.PrimaryPart
    if root then return root, model end
    for _, name in ipairs({"Chassis","Body","Frame","Car","CarBody","VehicleBody","Hull","Base"}) do
        local p = model:FindFirstChild(name, true)
        if p and p:IsA("BasePart") then return p, model end
    end
    local heaviest, maxMass = nil, 0
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p.Mass > maxMass then heaviest = p; maxMass = p.Mass end
    end
    return (heaviest or seat), model
end

local function enableNoclip(model)
    State.savedCollision = {}
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then State.savedCollision[p] = p.CanCollide; p.CanCollide = false end
    end
end

local function disableNoclip()
    for part, val in pairs(State.savedCollision) do
        if part and part.Parent then part.CanCollide = val end
    end
    State.savedCollision = {}
end

local function unanchorVehicle(model)
    State.savedAnchors = {}
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p.Anchored then State.savedAnchors[p] = true; p.Anchored = false end
    end
end

local function restoreAnchors()
    for part in pairs(State.savedAnchors) do
        if part and part.Parent then part.Anchored = true end
    end
    State.savedAnchors = {}
end

local function stopFly()
    if State.flyConn then State.flyConn:Disconnect(); State.flyConn = nil end
    if State.gravForce and State.gravForce.Parent then State.gravForce:Destroy(); State.gravForce = nil end
    restoreAnchors()
    disableNoclip()
end

local function startFly()
    stopFly()
    local root, model = getVehicleRoot()
    if not root or not model then return false, "Сначала сядь в машину!" end

    if Config.autoUnanchor then unanchorVehicle(model) end
    enableNoclip(model)

    local bf = Instance.new("BodyForce")
    bf.Name   = "_TwFlyGravCancel"
    bf.Force  = Vector3.new(0, workspace.Gravity * (root.AssemblyMass or root.Mass), 0)
    bf.Parent = root
    State.gravForce = bf

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    State.flyConn = RunService.Heartbeat:Connect(function(dt)
        if not Config.flyMode then stopFly(); return end

        local vRoot, vModel = getVehicleRoot()
        if not vRoot then
            Config.flyMode = false
            if State.flyButton then
                State.flyButton.Text             = "FLY"
                State.flyButton.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
            end
            stopFly()
            pcall(function()
                Rayfield:Notify({Title="Car Fly", Content="Автовыкл: вышел из машины", Duration=3, Image=4483362458})
            end)
            return
        end

        if State.gravForce and State.gravForce.Parent then
            local mass = vRoot.AssemblyMass or vRoot.Mass
            if mass and mass > 0 then State.gravForce.Force = Vector3.new(0, workspace.Gravity * mass, 0) end
        end

        for _, p in ipairs(vModel:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end

        if Config.autoUnanchor then
            for _, p in ipairs(vModel:GetDescendants()) do
                if p:IsA("BasePart") and p.Anchored then p.Anchored = false end
            end
        end

        local cam       = workspace.CurrentCamera.CFrame
        local fwdFlat   = Vector3.new(cam.LookVector.X,  0, cam.LookVector.Z)
        local rightFlat = Vector3.new(cam.RightVector.X, 0, cam.RightVector.Z)
        if fwdFlat.Magnitude   > 0.001 then fwdFlat   = fwdFlat.Unit   end
        if rightFlat.Magnitude > 0.001 then rightFlat = rightFlat.Unit end

        local move = Vector3.zero

        if isMobile then
            local td = getTouchDir()
            if td.Magnitude > 0.01 then
                local dir3 = fwdFlat * (-td.Y) + rightFlat * td.X
                if dir3.Magnitude > 0.001 then
                    move = dir3.Unit * Config.flySpeed * td.Magnitude
                end
            end
        else
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + fwdFlat   * Config.flySpeed end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - fwdFlat   * Config.flySpeed end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - rightFlat * Config.flySpeed end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + rightFlat * Config.flySpeed end
        end

        rayParams.FilterDescendantsInstances = {vModel}
        local ray = workspace:Raycast(vRoot.Position, Vector3.new(0, -400, 0), rayParams)
        local vertVel = 0
        if ray then
            vertVel = math.clamp(((ray.Position.Y + Config.hoverHeight) - vRoot.Position.Y) * 12, -100, 100)
        end

        local lerpAmt = math.min(dt * Config.lerpFactor, 1)
        vRoot.AssemblyLinearVelocity = vRoot.AssemblyLinearVelocity:Lerp(
            Vector3.new(move.X, vertVel, move.Z), lerpAmt
        )

        if fwdFlat.Magnitude > 0.001 then
            vRoot.CFrame = vRoot.CFrame:Lerp(
                CFrame.lookAt(vRoot.Position, vRoot.Position + fwdFlat),
                math.min(dt * 7, 1)
            )
        end

        if Config.stabilize then
            vRoot.AssemblyAngularVelocity = vRoot.AssemblyAngularVelocity:Lerp(Vector3.zero, math.min(dt * 6, 1))
        end
    end)

    return true, "OK"
end

local function setFlyBtnState(on)
    if not State.flyButton then return end
    if on then
        State.flyButton.Text             = "FLY\nВКЛ"
        State.flyButton.BackgroundColor3 = Color3.fromRGB(0, 90, 200)
    else
        State.flyButton.Text             = "FLY"
        State.flyButton.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    end
end

local function createFlyButton()
    if State.flyButton then return end
    local btn = Instance.new("TextButton")
    btn.Name                   = "FlyBtn"
    btn.Size                   = UDim2.new(0, 100, 0, 100)
    btn.Position               = UDim2.new(1, -120, 1, -260)
    btn.BackgroundColor3       = Color3.fromRGB(22, 22, 30)
    btn.BackgroundTransparency = 0.05
    btn.Text                   = "FLY"
    btn.TextColor3             = Color3.fromRGB(255, 255, 255)
    btn.TextSize               = 26
    btn.Font                   = Enum.Font.GothamBold
    btn.BorderSizePixel        = 0
    btn.AutoButtonColor        = false
    btn.ZIndex                 = 10
    btn.Parent                 = ScreenUI
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0.5, 0); corner.Parent = btn
    local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(60,140,255); stroke.Thickness = 3; stroke.Parent = btn

    btn.MouseButton1Click:Connect(function()
        Config.flyMode = not Config.flyMode
        setFlyBtnState(Config.flyMode)
        if Config.flyMode then
            local ok, msg = startFly()
            if not ok then
                Config.flyMode = false; setFlyBtnState(false)
                Rayfield:Notify({Title="Fly", Content=msg, Duration=3, Image=4483362458})
            end
        else
            stopFly()
        end
    end)
    State.flyButton = btn
end

local function removeFlyButton()
    if not State.flyButton then return end
    State.flyButton:Destroy(); State.flyButton = nil
    Config.flyMode = false; stopFly()
end

-- ============================================================
-- АВТО-ХИЛ
-- ============================================================
local function startHeal()
    if State.healConn then return end
    State.healConn = RunService.Heartbeat:Connect(function()
        local char = player.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
    end)
end

local function stopHeal()
    if State.healConn then
        State.healConn:Disconnect()
        State.healConn = nil
    end
end

-- ============================================================
-- RAYFIELD GUI
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name             = "Twisted BETA — Vehicle Fly",
    LoadingTitle     = "VehicleFly | Delta",
    LoadingSubtitle  = "Physics AC Bypass",
    ConfigurationSaving = { Enabled = false },
    Discord          = { Enabled = false },
    KeySystem        = false,
})

local TabMain = Window:CreateTab("Полёт", 4483362458)
local TabInfo = Window:CreateTab("Инфо",  4483362458)

TabMain:CreateSection("Персонаж")

TabMain:CreateToggle({
    Name         = "Авто-хил (бессмертие)",
    CurrentValue = false,
    Flag         = "AutoHeal",
    Callback     = function(val)
        if val then
            startHeal()
            Rayfield:Notify({
                Title    = "Авто-хил",
                Content  = "Здоровье восстанавливается постоянно.",
                Duration = 3,
                Image    = 4483362458,
            })
        else
            stopHeal()
        end
    end,
})

TabMain:CreateSection("Управление машиной")

TabMain:CreateToggle({
    Name         = "Кнопка FLY на экране",
    CurrentValue = false,
    Flag         = "CarFly",
    Callback     = function(val)
        Config.enabled = val
        if val then
            createFlyButton()
            Rayfield:Notify({
                Title    = "Car Fly",
                Content  = "FLY появился. Управляй родным джойстиком слева.",
                Duration = 4,
                Image    = 4483362458,
            })
        else
            removeFlyButton()
        end
    end,
})

TabMain:CreateToggle({
    Name         = "Авто-разанкор (для задеплоенных машин)",
    CurrentValue = true,
    Flag         = "AutoUnanchor",
    Callback     = function(val) Config.autoUnanchor = val end,
})

TabMain:CreateToggle({
    Name         = "Стабилизация вращения",
    CurrentValue = true,
    Flag         = "Stabilize",
    Callback     = function(val) Config.stabilize = val end,
})

TabMain:CreateSection("Скорости")

TabMain:CreateSlider({
    Name         = "Скорость полёта",
    Range        = {50, 2000},
    Increment    = 50,
    Suffix       = " st/s",
    CurrentValue = Config.flySpeed,
    Flag         = "FlySpeed",
    Callback     = function(val) Config.flySpeed = val end,
})

TabMain:CreateSlider({
    Name         = "Высота парения над землёй",
    Range        = {1, 40},
    Increment    = 1,
    Suffix       = " ст.",
    CurrentValue = Config.hoverHeight,
    Flag         = "HoverHeight",
    Callback     = function(val) Config.hoverHeight = val end,
})

TabMain:CreateSlider({
    Name         = "Плавность разгона",
    Range        = {1, 30},
    Increment    = 1,
    Suffix       = "x",
    CurrentValue = Config.lerpFactor,
    Flag         = "LerpFactor",
    Callback     = function(val) Config.lerpFactor = val end,
})

TabInfo:CreateSection("Управление")
TabInfo:CreateLabel("1. Сядь в машину")
TabInfo:CreateLabel("2. Включи тогл Кнопка FLY")
TabInfo:CreateLabel("3. Нажми FLY справа снизу")
TabInfo:CreateLabel("4. Веди пальцем слева — как при ходьбе")
TabInfo:CreateLabel("Машина парит сама — вверх/вниз авто")
TabInfo:CreateLabel("Машина смотрит куда смотрит камера")
TabInfo:CreateLabel("Noclip — сквозь объекты")

TabInfo:CreateSection("Bypass")
TabInfo:CreateLabel("AssemblyLinearVelocity = физическая скорость")
TabInfo:CreateLabel("BodyForce = гравитация отменена физически")
TabInfo:CreateLabel("Lerp = плавный разгон, нет спайков")
TabInfo:CreateLabel("Humanoid не трогаем → WalkSpeed AC молчит")

RunService.Heartbeat:Connect(function()
    if not Config.flyMode then return end
    local ok = pcall(function()
        local char = player.Character
        if not char then error() end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or not hum.SeatPart then error() end
    end)
    if not ok then
        Config.flyMode = false
        if State.flyButton then
            State.flyButton.Text             = "FLY"
            State.flyButton.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
        end
        stopFly()
        pcall(function()
            Rayfield:Notify({Title="Car Fly", Content="Автовыкл: вышел из машины", Duration=3, Image=4483362458})
        end)
    end
end)