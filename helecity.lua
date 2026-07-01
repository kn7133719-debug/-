local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local HeavyGravity  = false
local CarFly        = false
local FLY_SPEED     = 80
local MAX_FLY_HEIGHT = 80
local InstantHeal   = false
local NoClip        = false
local ButtonsLocked = false
local ZondActive    = false

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local Window = Rayfield:CreateWindow({
    Name = "Helicity Hub",
    LoadingTitle = "Storm Chaser Script",
    LoadingSubtitle = "v8 — Zond Fix",
    Theme = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
})

local MainTab     = Window:CreateTab("Main",     4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HelicityHub"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player.PlayerGui

-- ========================
-- DRAG
-- ========================

local function makeDraggable(dragSource, dragTarget)
    dragTarget = dragTarget or dragSource
    local dragging  = false
    local dragInput = nil
    local dragStart = nil
    local startPos  = nil

    dragSource.InputBegan:Connect(function(input)
        if ButtonsLocked then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = dragTarget.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragSource.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging and not ButtonsLocked then
            local delta = input.Position - dragStart
            dragTarget.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ========================
-- КОНТЕЙНЕР FLY + ENABLE
-- ========================

local btnContainer = Instance.new("Frame")
btnContainer.Name = "BtnContainer"
btnContainer.Size = UDim2.new(0, 110, 0, 126)
btnContainer.Position = UDim2.new(0.5, -55, 0, 10)
btnContainer.BackgroundTransparency = 1
btnContainer.Visible = false
btnContainer.Parent = screenGui

local gripBar = Instance.new("Frame")
gripBar.Name = "GripBar"
gripBar.Size = UDim2.new(1, 0, 0, 18)
gripBar.Position = UDim2.new(0, 0, 0, 0)
gripBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
gripBar.BackgroundTransparency = 0.2
gripBar.Parent = btnContainer
local gripCorner = Instance.new("UICorner")
gripCorner.CornerRadius = UDim.new(0, 8)
gripCorner.Parent = gripBar
local gripLabel = Instance.new("TextLabel")
gripLabel.Size = UDim2.new(1, 0, 1, 0)
gripLabel.BackgroundTransparency = 1
gripLabel.Text = "· · · · · · ·"
gripLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
gripLabel.TextSize = 11
gripLabel.Font = Enum.Font.Code
gripLabel.Parent = gripBar

makeDraggable(gripBar, btnContainer)

local function makeInnerBtn(text, yOffset, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 110, 0, 48)
    btn.Position = UDim2.new(0, 0, 0, yOffset + 22)
    btn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    btn.BackgroundTransparency = 0.15
    btn.TextColor3 = color
    btn.Text = text
    btn.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
    btn.TextSize = 15
    btn.Parent = btnContainer
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = btn
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 2
    stroke.Parent = btn
    return btn, stroke
end

local enableBtn, enableStroke = makeInnerBtn("⚡ ENABLE", 0,  Color3.fromRGB(255, 200, 50))
enableBtn.Visible = false
local flyBtn, flyStroke       = makeInnerBtn("✈  FLY",   56, Color3.fromRGB(80, 255, 80))

-- ========================
-- КНОПКА ZOND
-- ========================

local zondFrame = Instance.new("Frame")
zondFrame.Name = "ZondFrame"
zondFrame.Size = UDim2.new(0, 110, 0, 70)
zondFrame.Position = UDim2.new(0.5, 65, 0, 10)
zondFrame.BackgroundTransparency = 1
zondFrame.Visible = false
zondFrame.Parent = screenGui

local zondGrip = Instance.new("Frame")
zondGrip.Size = UDim2.new(1, 0, 0, 18)
zondGrip.Position = UDim2.new(0, 0, 0, 0)
zondGrip.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
zondGrip.BackgroundTransparency = 0.2
zondGrip.Parent = zondFrame
local zondGripCorner = Instance.new("UICorner")
zondGripCorner.CornerRadius = UDim.new(0, 8)
zondGripCorner.Parent = zondGrip
local zondGripLabel = Instance.new("TextLabel")
zondGripLabel.Size = UDim2.new(1, 0, 1, 0)
zondGripLabel.BackgroundTransparency = 1
zondGripLabel.Text = "· · · · · · ·"
zondGripLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
zondGripLabel.TextSize = 11
zondGripLabel.Font = Enum.Font.Code
zondGripLabel.Parent = zondGrip

makeDraggable(zondGrip, zondFrame)

local zondBtn = Instance.new("TextButton")
zondBtn.Size = UDim2.new(0, 110, 0, 48)
zondBtn.Position = UDim2.new(0, 0, 0, 22)
zondBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
zondBtn.BackgroundTransparency = 0.15
zondBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
zondBtn.Text = "📡  ZOND"
zondBtn.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
zondBtn.TextSize = 15
zondBtn.Parent = zondFrame
local zondCorner = Instance.new("UICorner")
zondCorner.CornerRadius = UDim.new(0, 12)
zondCorner.Parent = zondBtn
local zondStroke = Instance.new("UIStroke")
zondStroke.Color = Color3.fromRGB(255, 60, 60)
zondStroke.Thickness = 2
zondStroke.Parent = zondBtn

local function setZondGreen()
    zondBtn.TextColor3 = Color3.fromRGB(80, 255, 80)
    zondStroke.Color   = Color3.fromRGB(80, 255, 80)
end
local function setZondRed()
    zondBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
    zondStroke.Color   = Color3.fromRGB(255, 60, 60)
end

local function setFlyGreen()
    flyBtn.TextColor3 = Color3.fromRGB(80, 255, 80)
    flyStroke.Color   = Color3.fromRGB(80, 255, 80)
end
local function setFlyRed()
    flyBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
    flyStroke.Color   = Color3.fromRGB(255, 60, 60)
end

-- ========================
-- HELPERS
-- ========================

local function getCharacter()
    local char = player.Character
    if not char then return nil, nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return nil, nil, nil end
    return char, hum, hrp
end

local function getCurrentVehicle()
    local _, hum = getCharacter()
    if not hum then return nil, nil end
    local seat = hum.SeatPart
    if not seat or not seat:IsA("VehicleSeat") then return nil, nil end
    return seat.Parent, seat
end

local function getAllParts(model)
    local parts = {}
    for _, v in ipairs(model:GetDescendants()) do
        if v:IsA("BasePart") then table.insert(parts, v) end
    end
    return parts
end

local function cleanupNamed(model, name)
    if not model then return end
    for _, part in ipairs(getAllParts(model)) do
        local obj = part:FindFirstChild(name)
        if obj then obj:Destroy() end
    end
end

-- ========================
-- ЗАЩИТА ОТ УРОНА
-- ========================

local healConn = nil

local DAMAGE_STATES = {
    Enum.HumanoidStateType.Freefall,
    Enum.HumanoidStateType.FallingDown,
    Enum.HumanoidStateType.Flying,
    Enum.HumanoidStateType.Jumping,
    Enum.HumanoidStateType.Landed,
}

local function enableDamageProtection()
    local _, hum = getCharacter()
    if not hum then return end
    for _, state in ipairs(DAMAGE_STATES) do
        pcall(function() hum:SetStateEnabled(state, false) end)
    end
    if healConn then healConn:Disconnect() end
    healConn = RunService.RenderStepped:Connect(function()
        local _, h = getCharacter()
        if h and h.Health < h.MaxHealth and h.Health > 0 then
            h.Health = h.MaxHealth
        end
    end)
end

local function disableDamageProtection()
    local _, hum = getCharacter()
    if hum then
        for _, state in ipairs(DAMAGE_STATES) do
            pcall(function() hum:SetStateEnabled(state, true) end)
        end
    end
    if healConn then healConn:Disconnect() healConn = nil end
end

-- ========================
-- INSTANT HEAL
-- ========================

local instantHealConn = nil

local function startInstantHeal()
    if instantHealConn then instantHealConn:Disconnect() end
    instantHealConn = RunService.RenderStepped:Connect(function()
        local _, h = getCharacter()
        if h and h.Health > 0 and h.Health < h.MaxHealth then
            h.Health = h.MaxHealth
        end
    end)
end

local function stopInstantHeal()
    if instantHealConn then instantHealConn:Disconnect() instantHealConn = nil end
end

-- ========================
-- NOCLIP
-- ========================

local noClipConn = nil

local function startNoClip()
    if noClipConn then noClipConn:Disconnect() end
    noClipConn = RunService.RenderStepped:Connect(function()
        if not NoClip then return end
        local vehicle = getCurrentVehicle()
        if vehicle then
            for _, part in ipairs(getAllParts(vehicle)) do
                part.CanCollide = false
            end
        end
    end)
end

local function stopNoClip()
    if noClipConn then noClipConn:Disconnect() noClipConn = nil end
    local vehicle = getCurrentVehicle()
    if vehicle then
        for _, part in ipairs(getAllParts(vehicle)) do
            part.CanCollide = true
        end
    end
end

-- ========================
-- ZOND ЛОГИКА (исправленная)
-- ========================

local deployedProbe  = nil
local PROBE_TOOL_NAMES = {"Probe", "Sonde", "TurtleProbe", "Zond", "WeatherProbe"}

local function findProbeTool()
    local char = player.Character
    if char then
        for _, name in ipairs(PROBE_TOOL_NAMES) do
            local t = char:FindFirstChild(name)
            if t and t:IsA("Tool") then return t end
        end
    end
    for _, name in ipairs(PROBE_TOOL_NAMES) do
        local t = player.Backpack:FindFirstChild(name)
        if t and t:IsA("Tool") then return t end
    end
    return nil
end

local function findDeployedProbeInWorkspace()
    local _, _, hrp = getCharacter()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            for _, name in ipairs(PROBE_TOOL_NAMES) do
                if obj.Name == name or obj.Name == (name .. "Model") then
                    local creator = obj:FindFirstChild("Creator") or obj:FindFirstChild("Owner")
                    if creator and (creator.Value == player or creator.Value == player.Name) then
                        return obj
                    end
                    if hrp then
                        local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                        if primary and (primary.Position - hrp.Position).Magnitude < 30 then
                            return obj
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function placeZond()
    local char, hum, hrp = getCharacter()
    if not char or not hum or not hrp then
        Rayfield:Notify({Title="Helicity Hub", Content="Персонаж не найден!", Duration=3})
        return
    end
    local tool = findProbeTool()
    if not tool then
        Rayfield:Notify({Title="Helicity Hub", Content="Зонд не найден в инвентаре!\nВозьми Probe из арсенала.", Duration=4})
        return
    end
    pcall(function() hum:EquipTool(tool) end)
    task.wait(0.15)
    local equipped = char:FindFirstChildOfClass("Tool")
    if equipped then
        local re = equipped:FindFirstChildOfClass("RemoteEvent")
        if re then
            pcall(function() re:FireServer(hrp.Position - Vector3.new(0, 3, 0)) end)
        end
        pcall(function() equipped:Activate() end)
        task.wait(0.3)
    end
    ZondActive = true
    setZondGreen()
    task.wait(0.5)
    deployedProbe = findDeployedProbeInWorkspace()
end

-- ИСПРАВЛЕНИЕ: используем серверные механики подбора вместо client-side Destroy()
local function removeZond()
    local char, hum, hrp = getCharacter()

    local probe = (deployedProbe and deployedProbe.Parent) and deployedProbe
                  or findDeployedProbeInWorkspace()

    if probe and probe.Parent then
        local primary = probe.PrimaryPart or probe:FindFirstChildWhichIsA("BasePart")

        if primary and hrp then
            local oldCF = hrp.CFrame

            -- Телепортируемся к зонду
            hrp.CFrame = CFrame.new(primary.Position + Vector3.new(0, 4, 0))
            task.wait(0.25)

            -- 1. ProximityPrompt (основной способ в Helicity)
            for _, obj in ipairs(probe:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    pcall(function() fireproximityprompt(obj) end)
                    task.wait(0.15)
                end
            end

            -- 2. ClickDetector
            for _, obj in ipairs(probe:GetDescendants()) do
                if obj:IsA("ClickDetector") then
                    pcall(function() fireclickdetector(obj) end)
                    task.wait(0.15)
                end
            end

            -- 3. RemoteEvent с именами связанными с подбором
            for _, obj in ipairs(probe:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    local n = obj.Name:lower()
                    if n:find("pick") or n:find("collect") or n:find("remov")
                    or n:find("retriev") or n:find("recall") or n:find("return") then
                        pcall(function() obj:FireServer() end)
                        task.wait(0.15)
                    end
                end
            end

            -- Возвращаем персонажа на место
            task.wait(0.1)
            hrp.CFrame = oldCF
        end
    end

    deployedProbe = nil
    ZondActive    = false
    setZondRed()
end

zondBtn.MouseButton1Click:Connect(function()
    if ZondActive then removeZond() else placeZond() end
end)

-- ========================
-- CAR FLY
-- ========================

local flyConn    = nil
local flyBV      = nil
local flyBG      = nil
local flyPrimary = nil

local function startFly()
    local vehicle, seat = getCurrentVehicle()
    if not vehicle then
        Rayfield:Notify({Title="Helicity Hub", Content="Сначала сядь в машину!", Duration=3})
        CarFly = false
        setFlyRed()
        return
    end
    flyPrimary = vehicle.PrimaryPart or seat
    for _, name in ipairs({"_FlyBV", "_FlyBG"}) do
        local old = flyPrimary:FindFirstChild(name)
        if old then old:Destroy() end
    end
    flyBV = Instance.new("BodyVelocity")
    flyBV.Name = "_FlyBV"
    flyBV.Velocity = Vector3.new(0, 0, 0)
    flyBV.MaxForce = Vector3.new(1e8, 1e8, 1e8)
    flyBV.P = 1e5
    flyBV.Parent = flyPrimary
    flyBG = Instance.new("BodyGyro")
    flyBG.Name = "_FlyBG"
    flyBG.MaxTorque = Vector3.new(1e7, 1e7, 1e7)
    flyBG.P = 1e5
    flyBG.D = 300
    flyBG.CFrame = flyPrimary.CFrame
    flyBG.Parent = flyPrimary
    enableDamageProtection()
    if NoClip then startNoClip() end
    local cam = workspace.CurrentCamera
    if flyConn then flyConn:Disconnect() end
    flyConn = RunService.RenderStepped:Connect(function()
        if not CarFly or not flyPrimary or not flyPrimary.Parent then return end
        local camCF = cam.CFrame
        local fwd   = camCF.LookVector
        local right = camCF.RightVector
        local up    = Vector3.new(0, 1, 0)
        local dir   = Vector3.new(0, 0, 0)
        if isMobile then
            local _, hum = getCharacter()
            if hum then
                local md = hum.MoveDirection
                if md.Magnitude > 0.1 then
                    dir = Vector3.new(md.X, 0, md.Z)
                end
            end
        else
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + fwd   end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - fwd   end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + right end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then dir = dir + up end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - up end
        end
        if dir.Magnitude > 0 then dir = dir.Unit end
        local currentY  = flyPrimary.Position.Y
        local groundY   = 0
        local rp = RaycastParams.new()
        local ray = workspace:Raycast(flyPrimary.Position, Vector3.new(0, -500, 0), rp)
        if ray then groundY = ray.Position.Y end
        local relativeHeight = currentY - groundY
        local vy = dir.Y * FLY_SPEED
        if relativeHeight >= MAX_FLY_HEIGHT and dir.Y > 0 then vy = 0 end
        if relativeHeight <= 2 and dir.Y < 0 then vy = 0 end
        flyBV.Velocity = Vector3.new(dir.X * FLY_SPEED, vy, dir.Z * FLY_SPEED)
        local lookFlat = Vector3.new(fwd.X, 0, fwd.Z)
        if lookFlat.Magnitude > 0.01 then
            flyBG.CFrame = CFrame.new(flyPrimary.Position, flyPrimary.Position + lookFlat)
        end
    end)
end

local function stopFly()
    if flyConn then flyConn:Disconnect() flyConn = nil end
    if flyBV and flyBV.Parent then flyBV:Destroy() flyBV = nil end
    if flyBG and flyBG.Parent then flyBG:Destroy() flyBG = nil end
    disableDamageProtection()
    stopNoClip()
end

local function toggleFly()
    CarFly = not CarFly
    if CarFly then setFlyGreen() startFly()
    else setFlyRed() stopFly() end
end

flyBtn.MouseButton1Click:Connect(toggleFly)

-- ========================
-- HEAVY GRAVITY
-- ========================

local gravityConn   = nil
local gravityForces = {}

local function enableHeavyGravity()
    local vehicle = getCurrentVehicle()
    if not vehicle then
        Rayfield:Notify({Title="Helicity Hub", Content="Сначала сядь в машину!", Duration=3})
        HeavyGravity = false
        return
    end
    cleanupNamed(vehicle, "_HeavyGrav")
    cleanupNamed(vehicle, "_HeavyGyro")
    gravityForces = {}
    for _, part in ipairs(getAllParts(vehicle)) do
        local bf = Instance.new("BodyForce")
        bf.Name = "_HeavyGrav"
        bf.Force = Vector3.new(0, -part:GetMass() * 9000, 0)
        bf.Parent = part
        table.insert(gravityForces, {force = bf, part = part})
    end
    local primary = vehicle.PrimaryPart or vehicle:FindFirstChildWhichIsA("BasePart")
    if primary then
        local gyro = Instance.new("BodyGyro")
        gyro.Name = "_HeavyGyro"
        gyro.MaxTorque = Vector3.new(1e8, 0, 1e8)
        gyro.P = 2e6
        gyro.D = 800
        gyro.CFrame = CFrame.new(primary.Position)
        gyro.Parent = primary
    end
    if gravityConn then gravityConn:Disconnect() end
    gravityConn = RunService.RenderStepped:Connect(function()
        if not HeavyGravity then
            gravityConn:Disconnect()
            local v2 = getCurrentVehicle()
            if v2 then
                cleanupNamed(v2, "_HeavyGrav")
                cleanupNamed(v2, "_HeavyGyro")
            end
            gravityForces = {}
            return
        end
        for _, entry in ipairs(gravityForces) do
            if entry.force and entry.force.Parent and entry.part and entry.part.Parent then
                entry.force.Force = Vector3.new(0, -entry.part:GetMass() * 9000, 0)
            end
        end
    end)
end

local function disableHeavyGravity()
    if gravityConn then gravityConn:Disconnect() end
    gravityForces = {}
    local vehicle = getCurrentVehicle()
    if vehicle then
        cleanupNamed(vehicle, "_HeavyGrav")
        cleanupNamed(vehicle, "_HeavyGyro")
    end
end

local function setEnableGreen()
    enableBtn.TextColor3 = Color3.fromRGB(80, 255, 80)
    enableStroke.Color   = Color3.fromRGB(80, 255, 80)
end
local function setEnableYellow()
    enableBtn.TextColor3 = Color3.fromRGB(255, 200, 50)
    enableStroke.Color   = Color3.fromRGB(255, 200, 50)
end

enableBtn.MouseButton1Click:Connect(function()
    HeavyGravity = not HeavyGravity
    if HeavyGravity then setEnableGreen() enableHeavyGravity()
    else setEnableYellow() disableHeavyGravity() end
end)

-- ========================
-- RAYFIELD — MAIN
-- ========================

MainTab:CreateToggle({
    Name = "Car Fly — кнопка появится вверху",
    CurrentValue = false,
    Flag = "CarFlyMaster",
    Callback = function(val)
        if val then
            btnContainer.Visible = true
            CarFly = true
            setFlyGreen()
            startFly()
        else
            if not enableBtn.Visible then btnContainer.Visible = false end
            CarFly = false
            setFlyRed()
            stopFly()
        end
    end,
})

MainTab:CreateToggle({
    Name = "Heavy Gravity — Защита от EF5",
    CurrentValue = false,
    Flag = "HeavyGravToggle",
    Callback = function(val)
        HeavyGravity = val
        if val then
            enableBtn.Visible    = true
            btnContainer.Visible = true
            setEnableGreen()
            enableHeavyGravity()
        else
            enableBtn.Visible = false
            if not CarFly then btnContainer.Visible = false end
            disableHeavyGravity()
        end
    end,
})

MainTab:CreateToggle({
    Name = "Показать кнопку Зонд",
    CurrentValue = false,
    Flag = "ZondBtnToggle",
    Callback = function(val)
        zondFrame.Visible = val
        if not val and ZondActive then removeZond() end
    end,
})

-- ========================
-- RAYFIELD — SETTINGS
-- ========================

SettingsTab:CreateToggle({
    Name = "Закрепить кнопки (запретить перетаскивание)",
    CurrentValue = false,
    Flag = "LockBtns",
    Callback = function(val)
        ButtonsLocked = val
    end,
})

SettingsTab:CreateToggle({
    Name = "Мгновенное восстановление HP",
    CurrentValue = false,
    Flag = "InstantHealToggle",
    Callback = function(val)
        InstantHeal = val
        if val then startInstantHeal() else stopInstantHeal() end
    end,
})

SettingsTab:CreateToggle({
    Name = "Нет коллизий при полёте (noclip)",
    CurrentValue = false,
    Flag = "NoClipToggle",
    Callback = function(val)
        NoClip = val
        if val and CarFly then startNoClip()
        elseif not val then stopNoClip() end
    end,
})

SettingsTab:CreateSlider({
    Name = "Скорость полёта",
    Range = {20, 300},
    Increment = 10,
    Suffix = " studs/s",
    CurrentValue = FLY_SPEED,
    Flag = "FlySpeedSlider",
    Callback = function(val) FLY_SPEED = val end,
})

SettingsTab:CreateSlider({
    Name = "Макс. высота полёта",
    Range = {20, 200},
    Increment = 10,
    Suffix = " studs",
    CurrentValue = MAX_FLY_HEIGHT,
    Flag = "MaxHeightSlider",
    Callback = function(val) MAX_FLY_HEIGHT = val end,
})

SettingsTab:CreateLabel("Урон от торнадо = proximity зона + Freefall state")
SettingsTab:CreateLabel("Защита: все airborne-стейты выкл + heal loop каждый кадр")
SettingsTab:CreateLabel("Высота ограничена чтобы не влетать в тело торнадо")
