-- ============================================================
--  MM2 Auto Coin Collector | Delta Injector
--  Dev: @atidia | https://t.me/lourens_script
--  FIX: BodyPosition+BodyGyro вместо CFrame-lerp (не блокирует управление)
--  ОСИНТ: workspace.CoinContainer, Timer.Visible, PathfindingService
-- ============================================================

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local VirtualInput = game:GetService("VirtualInputManager")
local lp           = Players.LocalPlayer
local PlayerGui    = lp:WaitForChild("PlayerGui")

-- ============================================================
-- RAYFIELD
-- ============================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============================================================
-- CONFIG
-- ============================================================
local CFG = {
    CoinNames       = { "Coin", "BeachBall" },
    MoveSpeed       = 30,    -- WalkSpeed во время сбора
    CollectPause    = 0.18,
    TickDelay       = 0.12,
    MaxCoins        = 40,
    PostResetDelay  = 7,
    RoundPollDelay  = 3,
    AntiIdleDelay   = 2,
    -- BodyPosition параметры (из оригинальных MM2 скриптов)
    BP_Force        = 999999,
    BP_P            = 40000,
    BG_P            = 10000,
    WaypointDelay   = 0.15,  -- задержка между waypoints (как в оригинале)
    StuckThreshold  = 0.1,   -- считаем застрявшим если прошли < 0.1 studs
}

-- ============================================================
-- STATE
-- ============================================================
local State = {
    Running   = false,
    Collected = 0,
    Phase     = "idle",
}

-- ============================================================
-- HELPERS: персонаж
-- ============================================================
local function getChar()
    local c   = lp.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if not c or not hrp or not hum or hum.Health <= 0 then
        return nil, nil, nil
    end
    return c, hrp, hum
end

-- ============================================================
-- ОСИНТ: детекция раунда через PlayerGui.MainGUI.Game.Timer
-- Подтверждено из FullAuto/Source.lua (Zyn-ic/MM2-AutoFarm)
-- ============================================================
local function isRoundActive()
    local ok, res = pcall(function()
        local mg = PlayerGui:FindFirstChild("MainGUI")
        if not mg then return false end
        local g = mg:FindFirstChild("Game")
        if not g then return false end
        local t = g:FindFirstChild("Timer")
        return t and t.Visible == true
    end)
    return ok and res == true
end

-- Карта загружена: "Spawns" в workspace не в Lobby
-- (из Zyn-ic FullAuto: rt:Map())
local function mapLoaded()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name == "Spawns"
           and v.Parent
           and v.Parent.Name ~= "Lobby" then
            return true
        end
    end
    return false
end

-- Убийца → не собираем (из FullAuto: player.Backpack:FindFirstChild("Knife"))
local function isMurderer()
    return lp.Backpack:FindFirstChild("Knife") ~= nil
end

-- ============================================================
-- МОНЕТЫ
-- ============================================================
local function getCoinContainer()
    return workspace:FindFirstChild("CoinContainer")
end

local function coinAlive(coin)
    return coin
        and coin.Parent ~= nil
        and coin:IsA("BasePart")
        and coin.Transparency < 0.95
end

local function isCoinName(name)
    for _, n in ipairs(CFG.CoinNames) do
        if name == n then return true end
    end
    return false
end

local function getCoins()
    local container = getCoinContainer()
    if not container then return {} end
    local list = {}
    for _, obj in ipairs(container:GetChildren()) do
        if isCoinName(obj.Name) and coinAlive(obj) then
            list[#list + 1] = obj
        end
    end
    return list
end

local function nearest(pos, coins)
    local best, bestD = nil, math.huge
    for _, c in ipairs(coins) do
        if coinAlive(c) then
            local d = (pos - c.Position).Magnitude
            if d < bestD then best, bestD = c, d end
        end
    end
    return best
end

-- ============================================================
-- NOCLIP
-- ============================================================
local noclipConn
local function enableNoclip()
    if noclipConn then return end
    noclipConn = RunService.Stepped:Connect(function()
        local c = lp.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = false
            end
        end
    end)
end

local function disableNoclip()
    if noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
    end
end

-- ============================================================
-- ДВИЖЕНИЕ: BodyPosition + BodyGyro
-- ИЗ ОСИНТ: именно этот метод используют все рабочие MM2 скрипты
-- НЕ блокирует управление (в отличие от CFrame-lerp в цикле)
-- ============================================================
local function moveTo(hrp, targetPos)
    if not hrp or not hrp.Parent then return end
    local dist = (targetPos - hrp.Position).Magnitude
    if dist < 3 then return end

    -- Создаём BodyPosition
    local bp = Instance.new("BodyPosition")
    bp.P        = CFG.BP_P
    bp.MaxForce = Vector3.new(CFG.BP_Force, CFG.BP_Force, CFG.BP_Force)
    bp.Position = targetPos
    bp.Parent   = hrp

    -- Создаём BodyGyro (поворачиваем к цели)
    local bg = Instance.new("BodyGyro")
    bg.P          = CFG.BG_P
    bg.MaxTorque  = Vector3.new(99999, 99999, 99999)
    bg.CFrame     = CFrame.new(hrp.Position, targetPos)
    bg.Parent     = hrp

    local lastPos = hrp.Position
    local timeout = math.max(dist / CFG.MoveSpeed * 2, 3)
    local start   = tick()

    while State.Running do
        task.wait(CFG.WaypointDelay)

        if not hrp or not hrp.Parent then break end

        local remaining = (targetPos - hrp.Position).Magnitude

        -- Дошли
        if remaining < 3 then break end

        -- Таймаут
        if tick() - start > timeout then break end

        -- Застряли (как в оригинальном Pastebin скрипте)
        if (hrp.Position - lastPos).Magnitude < CFG.StuckThreshold then break end
        lastPos = hrp.Position
    end

    -- Удаляем моверы — управление возвращается немедленно
    if bp and bp.Parent then bp:Destroy() end
    if bg and bg.Parent then bg:Destroy() end
end

-- ============================================================
-- СБОР МОНЕТЫ
-- ============================================================
local function collectCoin(hrp, coin)
    if not coinAlive(coin) then return false end

    moveTo(hrp, coin.Position + Vector3.new(0, 1.5, 0))

    if not coinAlive(coin) then return false end

    local ok = pcall(function()
        hrp.CFrame = CFrame.new(coin.Position) -- одиночный сет, не цикл
        task.wait(0.05)
        firetouchinterest(hrp, coin, 0)
        task.wait(CFG.CollectPause)
        firetouchinterest(hrp, coin, 1)
    end)

    return ok
end

-- ============================================================
-- РЕСЕТ
-- ============================================================
local function doReset()
    local _, _, hum = getChar()
    if hum then pcall(function() hum.Health = 0 end) end
end

-- ============================================================
-- АНТИ-АФК (VirtualInputManager — из Pastebin FullAuto)
-- ============================================================
local antiIdleThread
local function startAntiIdle()
    if antiIdleThread then return end
    antiIdleThread = task.spawn(function()
        while State.Running do
            pcall(function()
                VirtualInput:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                VirtualInput:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
            task.wait(CFG.AntiIdleDelay)
        end
    end)
end

local function stopAntiIdle()
    if antiIdleThread then
        task.cancel(antiIdleThread)
        antiIdleThread = nil
    end
end

-- ============================================================
-- ГЛАВНЫЙ ЦИКЛ
-- ============================================================
local function mainLoop()
    State.Collected = 0
    State.Phase     = "waiting"
    startAntiIdle()
    enableNoclip()

    while State.Running do
        task.wait(CFG.TickDelay)

        pcall(function()

            -- ОЖИДАНИЕ РАУНДА
            if State.Phase == "waiting" then
                if isRoundActive() and mapLoaded() then
                    State.Phase     = "collecting"
                    State.Collected = 0
                else
                    task.wait(CFG.RoundPollDelay)
                end
                return
            end

            -- РЕСЕТ
            if State.Phase == "resetting" then
                doReset()
                task.wait(CFG.PostResetDelay)
                State.Phase = "waiting"
                return
            end

            -- СБОР
            if State.Phase == "collecting" then
                if not isRoundActive() then
                    State.Phase = "waiting"
                    return
                end

                if State.Collected >= CFG.MaxCoins then
                    State.Phase = "resetting"
                    return
                end

                local char, hrp, hum = getChar()
                if not char then task.wait(1) return end

                if isMurderer() then task.wait(1) return end

                local coins = getCoins()
                if #coins == 0 then
                    task.wait(1)
                    if #getCoins() == 0 then
                        State.Phase = "waiting"
                    end
                    return
                end

                local coin = nearest(hrp.Position, coins)
                if not coin then return end

                if collectCoin(hrp, coin) then
                    State.Collected = State.Collected + 1
                end
            end
        end)
    end

    disableNoclip()
    stopAntiIdle()
    State.Phase = "idle"
end

-- ============================================================
-- GUI
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name                   = "MM2 Coin Bot",
    LoadingTitle           = "MM2 Auto Collector",
    LoadingSubtitle        = "t.me/lourens_script",
    Theme                  = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings   = true,
    ConfigurationSaving    = { Enabled = false },
    KeySystem              = false,
})

local Tab = Window:CreateTab("Main", 4483362458)

Tab:CreateToggle({
    Name         = "Auto Collect Coins",
    CurrentValue = false,
    Flag         = "AutoCollect",
    Callback     = function(v)
        State.Running = v
        if v then task.spawn(mainLoop) end
    end,
})

Tab:CreateLabel("Собирает 40 монет → ресет → ждёт раунд")
Tab:CreateLabel("Dev: @atidia  |  t.me/lourens_script")

local counter = Tab:CreateLabel("Монет: 0 / 40   |   Фаза: idle")
RunService.Heartbeat:Connect(function()
    pcall(function()
        counter:Set(
            "Монет: " .. State.Collected .. " / " .. CFG.MaxCoins ..
            "   |   Фаза: " .. State.Phase
        )
    end)
end)