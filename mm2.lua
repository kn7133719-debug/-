-- ============================================================
--  MM2 Auto Coin Collector | Delta Injector
--  Dev: @atidia | https://t.me/lourens_script
--  v3 — Mobile fix: Humanoid:MoveTo + WalkSpeed, без BodyPosition
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
    CoinNames        = { "Coin", "BeachBall" },
    WalkSpeedFarm    = 30,   -- скорость во время сбора
    WalkSpeedDefault = 16,   -- вернуть после
    CollectPause     = 0.18,
    TickDelay        = 0.15,
    MaxCoins         = 40,
    PostResetDelay   = 8,
    RoundPollDelay   = 3,
    AntiIdleDelay    = 2,
    MoveTimeout      = 6,    -- таймаут MoveTo (сек)
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
-- HELPERS
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
-- ДЕТЕКЦИЯ РАУНДА
-- Первичная: CoinContainer существует и содержит монеты
-- Вторичная: Timer.Visible (резервная)
-- ============================================================
local function getCoinContainer()
    return workspace:FindFirstChild("CoinContainer")
end

local function isRoundActive()
    -- Первичная проверка — самая надёжная
    local container = getCoinContainer()
    if container and #container:GetChildren() > 0 then
        return true
    end
    -- Вторичная через GUI
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

local function mapLoaded()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name == "Spawns" and v.Parent and v.Parent.Name ~= "Lobby" then
            return true
        end
    end
    return false
end

local function isMurderer()
    return lp.Backpack:FindFirstChild("Knife") ~= nil
end

-- ============================================================
-- МОНЕТЫ
-- ============================================================
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
-- ДВИЖЕНИЕ: Humanoid:MoveTo + WalkSpeed
-- ЕДИНСТВЕННЫЙ метод который не ломает мобильные контролы
-- BodyPosition — DEPRECATED и убивает прыжок на мобиле
-- CFrame-lerp в цикле — блокирует управление
-- MoveTo работает ВМЕСТЕ с character controller
-- ============================================================
local function moveTo(hum, hrp, targetPos)
    if not hum or not hrp then return end

    local dist = (targetPos - hrp.Position).Magnitude
    if dist < 3 then return end

    -- Ускоряем ходьбу на время сбора
    local prevSpeed  = hum.WalkSpeed
    hum.WalkSpeed    = CFG.WalkSpeedFarm

    -- Говорим Humanoid идти к цели
    hum:MoveTo(targetPos)

    -- Ждём с таймаутом (не бесконечно)
    local arrived   = false
    local conn
    conn = hum.MoveToFinished:Connect(function(reached)
        arrived = true
    end)

    local start = tick()
    while not arrived and (tick() - start) < CFG.MoveTimeout and State.Running do
        -- Прерываем если монету уже подобрали
        if (targetPos - hrp.Position).Magnitude < 4 then break end
        task.wait(0.1)
    end

    conn:Disconnect()

    -- Возвращаем нормальную скорость
    hum.WalkSpeed = prevSpeed
end

-- ============================================================
-- НOCLIP — ТОЛЬКО для прохода сквозь стены
-- ВАЖНО: НЕ в Stepped-цикле, НЕ на все части
-- Только momentary, только когда нужно
-- Stepped на всех частях = прыжок на мобиле исчезает
-- ============================================================
local function momentaryNoclip(char)
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            p.CanCollide = false
        end
    end
    -- Сбрасываем через 0.5 сек (не постоянно!)
    task.delay(0.5, function()
        if not char or not char.Parent then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = true
            end
        end
    end)
end

-- ============================================================
-- СБОР МОНЕТЫ
-- ============================================================
local function collectCoin(char, hrp, hum, coin)
    if not coinAlive(coin) then return false end

    local target = coin.Position + Vector3.new(0, 2, 0)

    -- Если монета далеко — идём к ней
    if (hrp.Position - target).Magnitude > 5 then
        momentaryNoclip(char)
        moveTo(hum, hrp, target)
    end

    -- Монету могли собрать пока шли
    if not coinAlive(coin) then return false end

    local ok = pcall(function()
        -- Одиночный CFrame сет (не цикл!)
        hrp.CFrame = CFrame.new(coin.Position + Vector3.new(0, 2, 0))
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
-- АНТИ-АФК
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

    while State.Running do
        task.wait(CFG.TickDelay)

        pcall(function()

            -- ОЖИДАНИЕ РАУНДА
            if State.Phase == "waiting" then
                if isRoundActive() then
                    task.wait(2) -- даём монетам заспавниться
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

                -- Раунд кончился?
                if not isRoundActive() then
                    State.Phase = "waiting"
                    return
                end

                -- Лимит?
                if State.Collected >= CFG.MaxCoins then
                    State.Phase = "resetting"
                    return
                end

                local char, hrp, hum = getChar()
                if not char then task.wait(1) return end

                -- Убийца — пропускаем
                if isMurderer() then task.wait(1) return end

                local coins = getCoins()
                if #coins == 0 then
                    task.wait(1)
                    -- Если монет нет 2 чека подряд — раунд кончился
                    if #getCoins() == 0 then
                        State.Phase = "waiting"
                    end
                    return
                end

                local coin = nearest(hrp.Position, coins)
                if not coin then return end

                if collectCoin(char, hrp, hum, coin) then
                    State.Collected = State.Collected + 1
                end
            end
        end)
    end

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

local counter = Tab:CreateLabel("Монет: 0 / 40  |  Фаза: idle")
RunService.Heartbeat:Connect(function()
    pcall(function()
        counter:Set(
            "Монет: " .. State.Collected .. " / " .. CFG.MaxCoins ..
            "  |  Фаза: " .. State.Phase
        )
    end)
end)