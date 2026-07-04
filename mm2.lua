-- ============================================================
--  MM2 Auto Coin Collector | Delta Injector
--  Dev: @atidia | https://t.me/lourens_script
--  ОСИНТ: workspace.CoinContainer, Timer.Visible, Lerp CFrame
-- ============================================================

-- SERVICES
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local VirtualInput = game:GetService("VirtualInputManager")
local lp           = Players.LocalPlayer
local PlayerGui    = lp:WaitForChild("PlayerGui")

-- ============================================================
-- RAYFIELD GUI
-- ============================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============================================================
-- CONFIG
-- ============================================================
local CFG = {
    CoinNames      = { "Coin", "BeachBall" },
    MoveSpeed      = 30,
    CollectPause   = 0.18,
    TickDelay      = 0.12,
    MaxCoins       = 40,
    PostResetDelay = 7,
    RoundPollDelay = 3,
    AntiIdleDelay  = 2,
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

-- Раунд активен: Timer.Visible == true (из FullAuto source подтверждено)
local function isRoundActive()
    local ok, res = pcall(function()
        local mg = PlayerGui:FindFirstChild("MainGUI")
        if not mg then return false end
        local game_ = mg:FindFirstChild("Game")
        if not game_ then return false end
        local timer = game_:FindFirstChild("Timer")
        return timer and timer.Visible
    end)
    return ok and res == true
end

-- Карта загружена: ищем "Spawns" не в Lobby
local function mapLoaded()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name == "Spawns" and v.Parent and v.Parent.Name ~= "Lobby" then
            return true
        end
    end
    return false
end

-- Игрок — убийца → не собираем монеты
local function isMurderer()
    return lp.Backpack:FindFirstChild("Knife") ~= nil
end

-- Получить CoinContainer (обновляется при смене карты)
local function getCoinContainer()
    return workspace:FindFirstChild("CoinContainer")
end

-- Монета жива: не удалена другим игроком
local function coinAlive(coin)
    return coin
        and coin.Parent ~= nil
        and coin:IsA("BasePart")
        and coin.Transparency < 0.95
end

-- Валидное имя монеты
local function isCoinName(name)
    for _, n in ipairs(CFG.CoinNames) do
        if name == n then return true end
    end
    return false
end

-- Все живые монеты из CoinContainer
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

-- Ближайшая монета
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
-- NOCLIP (чтобы проходить сквозь стены к монетам)
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
    -- восстанавливаем коллизию HRP
    local c = lp.Character
    if c then
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CanCollide = true end
    end
end

-- ============================================================
-- ПЛАВНОЕ ДВИЖЕНИЕ (Lerp CFrame, ~30 studs/sec)
-- Не телепорт — медленное перемещение, безопаснее для анти-чита
-- ============================================================
local function moveTo(hrp, targetPos)
    local startPos = hrp.Position
    local dist     = (targetPos - startPos).Magnitude
    if dist < 2 then return end

    local duration  = dist / CFG.MoveSpeed
    local startTime = tick()

    while State.Running do
        local alpha = math.min((tick() - startTime) / duration, 1)
        hrp.CFrame  = CFrame.new(startPos:Lerp(targetPos, alpha))

        local remaining = (targetPos - hrp.Position).Magnitude
        if remaining < 2.5 or alpha >= 1 then break end

        task.wait(0.05)
    end
end

-- ============================================================
-- СБОР МОНЕТЫ
-- ============================================================
local function collectCoin(hrp, coin)
    if not coinAlive(coin) then return false end

    moveTo(hrp, coin.Position + Vector3.new(0, 1.5, 0))

    if not coinAlive(coin) then return false end

    local ok = pcall(function()
        hrp.CFrame = CFrame.new(coin.Position)
        task.wait(0.05)
        firetouchinterest(hrp, coin, 0)
        task.wait(CFG.CollectPause)
        firetouchinterest(hrp, coin, 1)
    end)

    return ok
end

-- ============================================================
-- РЕСЕТ ПЕРСОНАЖА
-- ============================================================
local function doReset()
    local _, _, hum = getChar()
    if hum then
        pcall(function() hum.Health = 0 end)
    end
end

-- ============================================================
-- АНТИ-АФК (симулируем клик каждые 2 сек)
-- ============================================================
local antiIdleConn
local function startAntiIdle()
    if antiIdleConn then return end
    antiIdleConn = task.spawn(function()
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
    if antiIdleConn then
        task.cancel(antiIdleConn)
        antiIdleConn = nil
    end
end

-- ============================================================
-- ГЛАВНЫЙ ЦИКЛ (машина состояний)
-- idle → waiting → collecting → resetting → waiting → ...
-- ============================================================
local function mainLoop()
    State.Collected = 0
    State.Phase     = "waiting"
    startAntiIdle()
    enableNoclip()

    while State.Running do
        task.wait(CFG.TickDelay)

        pcall(function()

            -- ── ОЖИДАНИЕ РАУНДА ──────────────────────────────
            if State.Phase == "waiting" then
                if isRoundActive() and mapLoaded() then
                    State.Phase     = "collecting"
                    State.Collected = 0
                else
                    task.wait(CFG.RoundPollDelay)
                end
                return
            end

            -- ── РЕСЕТ ПОСЛЕ 40 МОНЕТ ─────────────────────────
            if State.Phase == "resetting" then
                doReset()
                task.wait(CFG.PostResetDelay)
                State.Phase = "waiting"
                return
            end

            -- ── СБОР МОНЕТ ───────────────────────────────────
            if State.Phase == "collecting" then
                -- Раунд кончился?
                if not isRoundActive() then
                    State.Phase = "waiting"
                    return
                end

                -- Лимит достигнут?
                if State.Collected >= CFG.MaxCoins then
                    State.Phase = "resetting"
                    return
                end

                local char, hrp, hum = getChar()
                if not char then task.wait(1) return end

                -- Убийца — монеты не собираем (выглядим нормально)
                if isMurderer() then task.wait(1) return end

                local coins = getCoins()
                if #coins == 0 then
                    -- монет нет → раунд возможно кончился
                    task.wait(1)
                    if #getCoins() == 0 then
                        State.Phase = "waiting"
                    end
                    return
                end

                local coin = nearest(hrp.Position, coins)
                if not coin then return end

                local grabbed = collectCoin(hrp, coin)
                if grabbed then
                    State.Collected = State.Collected + 1
                end
            end
        end)
    end

    -- Выключили → чистим
    disableNoclip()
    stopAntiIdle()
    State.Phase = "idle"
end

-- ============================================================
-- RAYFIELD ОКНО
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

-- Кнопка вкл/выкл
Tab:CreateToggle({
    Name         = "Auto Collect Coins",
    CurrentValue = false,
    Flag         = "AutoCollect",
    Callback     = function(v)
        State.Running = v
        if v then
            task.spawn(mainLoop)
        end
    end,
})

-- Инфо
Tab:CreateLabel("Собирает 40 монет → ресет → ждёт раунд")
Tab:CreateLabel("Dev: @atidia  |  t.me/lourens_script")

-- Счётчик — обновляется каждый тик
local counter = Tab:CreateLabel("Монет: 0 / 40   |   Фаза: idle")
RunService.Heartbeat:Connect(function()
    pcall(function()
        counter:Set(
            "Монет: " .. State.Collected .. " / " .. CFG.MaxCoins ..
            "   |   Фаза: " .. State.Phase
        )
    end)
end)