-- ============================================================
--  MM2 Auto Coin Collector | Delta Injector
--  Dev: @atidia | https://t.me/lourens_script
--  v7 — плавный полёт сквозь стены, без кика Error 267
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local lp         = Players.LocalPlayer
local PlayerGui  = lp:WaitForChild("PlayerGui")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============================================================
-- STATE
-- ============================================================
local Running   = false
local Collected = 0
local Phase     = "idle"

-- ============================================================
-- ПЕРСОНАЖ
-- ============================================================
local function getChar()
    local c   = lp.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if not c or not hrp or not hum or hum.Health <= 0 then return nil,nil,nil end
    return c, hrp, hum
end

-- ============================================================
-- NOCLIP — сквозь стены
-- CanCollide = false каждый Stepped-кадр
-- ============================================================
local noclipConn

local function startNoclip()
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

local function stopNoclip()
    if noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
    end
end

-- ============================================================
-- ПЛАВНЫЙ ПОЛЁТ К МОНЕТЕ
-- Скорость: 60 studs/сек, шаг: 3 studs каждые 0.05с
-- Античит не видит — нет прыжков > 5 studs за кадр
-- ============================================================
local FLY_SPEED    = 60   -- studs в секунду
local FLY_STEP     = 0.05 -- секунд между шагами
local FLY_ARRIVE   = 3    -- studs — считаем "добрались"

local function flyTo(hrp, target)
    local stepDist = FLY_SPEED * FLY_STEP -- 3 studs за шаг

    while Running do
        if not hrp or not hrp.Parent then break end

        local pos  = hrp.Position
        local diff = target - pos
        local dist = diff.Magnitude

        if dist <= FLY_ARRIVE then break end

        local move = math.min(stepDist, dist)
        hrp.CFrame = CFrame.new(pos + diff.Unit * move)

        task.wait(FLY_STEP)
    end
end

-- ============================================================
-- ПОИСК МОНЕТ (3 метода от надёжного к fallback)
-- ============================================================
local function getMap()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name == "Spawns" and v.Parent and v.Parent.Name ~= "Lobby" then
            return v.Parent
        end
    end
end

local function getCoins()
    local coins = {}
    local seen  = {}

    -- Метод 1: Map → CoinContainer
    local map = getMap()
    local container = map and map:FindFirstChild("CoinContainer")

    -- Метод 2: рекурсивный поиск
    if not container then
        container = workspace:FindFirstChild("CoinContainer", true)
    end

    if container then
        -- по TouchTransmitter (самый точный)
        for _, d in ipairs(container:GetDescendants()) do
            if d:IsA("TouchTransmitter") and d.Parent and d.Parent:IsA("BasePart") then
                local coin = d.Parent
                if not seen[coin] then
                    seen[coin] = true
                    table.insert(coins, coin)
                end
            end
        end
        -- fallback: прямые BasePart дети
        if #coins == 0 then
            for _, obj in ipairs(container:GetChildren()) do
                if obj:IsA("BasePart") and not seen[obj] then
                    seen[obj] = true
                    table.insert(coins, obj)
                end
            end
        end
    end

    -- Метод 3: по имени во всём workspace
    if #coins == 0 then
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart")
               and (v.Name == "Coin" or v.Name == "Coin_Server" or v.Name == "BeachBall")
               and not seen[v] then
                seen[v] = true
                table.insert(coins, v)
            end
        end
    end

    return coins
end

local function nearest(pos, coins, skipped)
    local best, bestD = nil, math.huge
    for _, c in ipairs(coins) do
        if c and c.Parent and not skipped[c] then
            local d = (pos - c.Position).Magnitude
            if d < bestD then best, bestD = c, d end
        end
    end
    return best
end

-- ============================================================
-- РАУНД АКТИВЕН
-- ============================================================
local function isRoundActive()
    if #getCoins() > 0 then return true end
    local ok, res = pcall(function()
        local mg = PlayerGui:FindFirstChild("MainGUI")
        if not mg then return false end
        local g  = mg:FindFirstChild("Game")
        if not g then return false end
        local t  = g:FindFirstChild("Timer")
        return t and t.Visible == true
    end)
    return ok and res == true
end

-- ============================================================
-- СБОР МОНЕТЫ
-- 1. Плавно летим (сквозь стены, без кика)
-- 2. firetouchinterest
-- 3. Проверяем исчезла ли монета
-- ============================================================
local function collectCoin(hrp, coin)
    if not coin or not coin.Parent then return true end

    -- Плавный полёт к монете (не телепорт!)
    local target = coin.Position + Vector3.new(0, 2.5, 0)
    flyTo(hrp, target)

    -- Монету могли подобрать пока летели
    if not coin or not coin.Parent then return true end

    -- Touch
    pcall(function()
        firetouchinterest(hrp, coin, 0)
        task.wait(0.1)
        firetouchinterest(hrp, coin, 1)
    end)

    task.wait(0.2)
    return not coin.Parent
end

-- ============================================================
-- ГЛАВНЫЙ ЦИКЛ
-- ============================================================
local function mainLoop()
    Collected = 0
    Phase     = "waiting"
    local skipped = {}
    startNoclip()

    while Running do
        task.wait(0.1)
        pcall(function()

            if Phase == "waiting" then
                skipped   = {}
                Collected = 0
                if isRoundActive() then
                    task.wait(1.5)
                    Phase = "collecting"
                else
                    task.wait(3)
                end
                return
            end

            if Phase == "resetting" then
                local _, _, hum = getChar()
                if hum then pcall(function() hum.Health = 0 end) end
                task.wait(8)
                Phase = "waiting"
                return
            end

            if Phase == "collecting" then
                if not isRoundActive() then
                    Phase = "waiting"
                    return
                end

                if Collected >= 40 then
                    Phase = "resetting"
                    return
                end

                local _, hrp, _ = getChar()
                if not hrp then task.wait(1) return end

                local char = lp.Character
                if lp.Backpack:FindFirstChild("Knife")
                   or (char and char:FindFirstChild("Knife")) then
                    task.wait(0.5)
                    return
                end

                local coins    = getCoins()
                local coin     = nearest(hrp.Position, coins, skipped)

                if not coin then
                    task.wait(1)
                    if #getCoins() == 0 then Phase = "waiting" end
                    return
                end

                local ok = collectCoin(hrp, coin)
                if ok then
                    Collected = Collected + 1
                else
                    skipped[coin] = true
                end

                task.wait(0.2)
            end
        end)
    end

    stopNoclip()
    Phase = "idle"
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
    Name         = "Auto Collect",
    CurrentValue = false,
    Flag         = "AutoCollect",
    Callback     = function(v)
        Running = v
        if v then task.spawn(mainLoop) end
    end,
})

Tab:CreateLabel("40 монет → ресет → следующий раунд")
Tab:CreateLabel("Dev: @atidia  |  t.me/lourens_script")

local info = Tab:CreateLabel("Монет: 0/40  |  idle")
RunService.Heartbeat:Connect(function()
    pcall(function()
        info:Set("Монет: " .. Collected .. "/40  |  " .. Phase)
    end)
end)