-- Rivals 終極整合測試版
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ========== 設定 ==========
local Settings = {
    masterEnabled = false,

    -- 虛空躲藏
    voidEnabled = true,
    voidY = -300,                    -- 虛空 Y 座標

    -- 不死保護
    godMode = true,                  -- 血量鎖住
    antiKill = true,                 -- 防止被擊殺

    -- 瞬移爆頭
    teleportKill = true,
    shotsPerFrame = 30,

    -- 敵人斷線
    forceDisconnect = true,

    -- 隊伍保護
    teamCheck = true,

    -- 顯示敵人結構
    debugMode = true                 -- 開啟後會印出敵人角色結構
}

-- ========== 工具函式 ==========
local function printDebug(msg)
    if Settings.debugMode then
        print("[Rivals外掛] " .. msg)
    end
end

-- 找角色的主要部件
local function getCharacterParts(character)
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    local head = character:FindFirstChild("Head")

    -- 如果找不到標準名稱，自動找替代
    if not head then
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("BasePart") and string.lower(child.Name) == "head" then
                head = child
                break
            end
        end
    end

    if not rootPart then
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("BasePart") and string.find(string.lower(child.Name), "root") then
                rootPart = child
                break
            end
        end
    end

    return rootPart, humanoid, head
end

-- Team Check
local function isEnemy(player)
    if not Settings.teamCheck then return true end

    local localTeam = localPlayer.Team
    local playerTeam = player.Team

    if not localTeam and not playerTeam then return true end
    if not localTeam or not playerTeam then return true end

    return localTeam ~= playerTeam
end

-- 取得所有敵人
local function getAllEnemies()
    local enemies = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and isEnemy(player) then
            local character = player.Character
            if character then
                local rootPart, humanoid, head = getCharacterParts(character)

                if head and humanoid and humanoid.Health > 0 then
                    table.insert(enemies, {
                        player = player,
                        character = character,
                        head = head,
                        humanoid = humanoid,
                        rootPart = rootPart
                    })
                end
            end
        end
    end

    return enemies
end

-- 取得最近敵人
local function getClosestEnemy()
    local closest = nil
    local minDist = math.huge

    for _, enemy in ipairs(getAllEnemies()) do
        local dist = (enemy.head.Position - camera.CFrame.Position).Magnitude
        if dist < minDist then
            minDist = dist
            closest = enemy
        end
    end

    return closest
end

-- ========== 不死保護 ==========
local function godModeProtection()
    if not Settings.godMode then return end

    local character = localPlayer.Character
    if not character then return end

    local rootPart, humanoid, head = getCharacterParts(character)

    if humanoid then
        humanoid.Health = math.huge
        humanoid.MaxHealth = math.huge
    end
end

-- ========== 虛空躲藏 ==========
local function hideInVoid()
    if not Settings.voidEnabled then return end

    local character = localPlayer.Character
    if not character then return end

    local rootPart, humanoid, head = getCharacterParts(character)

    if rootPart then
        rootPart.CFrame = CFrame.new(0, Settings.voidY, 0)
        printDebug("已躲進虛空：Y = " .. Settings.voidY)
    end
end

-- ========== 超高速射擊 ==========
local function rapidFire()
    for i = 1, Settings.shotsPerFrame do
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, nil, 0)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, nil, 0)
    end
end

-- ========== 瞬移爆頭 ==========
local function teleportKillEnemy(enemy)
    local character = localPlayer.Character
    if not character then return end

    local rootPart, humanoid, head = getCharacterParts(character)
    if not rootPart or not head then return end

    -- 保存視角
    local lockedCamera = camera.CFrame

    -- 瞬移到敵人頭部
    rootPart.CFrame = CFrame.new(enemy.head.Position)
    printDebug("瞬移到敵人：" .. enemy.player.Name)

    -- 射擊
    rapidFire()

    -- 恢復視角
    camera.CFrame = lockedCamera

    -- 回虛空
    task.wait(0.01)
    hideInVoid()
end

-- ========== 強制斷線 ==========
local function forceDisconnectEnemy(enemy)
    if not Settings.forceDisconnect then return end

    printDebug("嘗試斷線：" .. enemy.player.Name)

    -- 方法一：移除 Humanoid
    if enemy.humanoid then
        enemy.humanoid:Destroy()
    end

    -- 方法二：移除 RootPart
    if enemy.rootPart then
        enemy.rootPart:Destroy()
    end

    -- 方法三：移除角色
    if enemy.character then
        enemy.character.Parent = nil
    end
end

-- ========== 主迴圈 ==========
local function mainLoop()
    printDebug("外掛啟動")

    while Settings.masterEnabled do
        -- 1. 不死
        godModeProtection()

        -- 2. 躲虛空
        hideInVoid()

        -- 3. 取得敵人
        local enemies = getAllEnemies()

        if #enemies == 0 then
            printDebug("沒有敵人")
        else
            printDebug("發現敵人數量：" .. #enemies)

            -- 依照距離排序
            table.sort(enemies, function(a, b)
                local distA = (a.head.Position - camera.CFrame.Position).Magnitude
                local distB = (b.head.Position - camera.CFrame.Position).Magnitude
                return distA < distB
            end)

            -- 4. 處理每個敵人
            for _, enemy in ipairs(enemies) do
                if Settings.masterEnabled == false then break end

                -- 確認敵人還活著
                if enemy.humanoid and enemy.humanoid.Health > 0 then
                    -- 瞬移爆頭
                    if Settings.teleportKill then
                        teleportKillEnemy(enemy)
                    end

                    -- 敵人沒死就斷線
                    task.wait(0.01)
                    if enemy.humanoid and enemy.humanoid.Health > 0 then
                        forceDisconnectEnemy(enemy)
                    end

                    -- 回虛空
                    hideInVoid()
                end
            end
        end

        task.wait(0.1)
    end
end

-- ========== 開關 ==========
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.T and not gameProcessed then
        Settings.masterEnabled = not Settings.masterEnabled

        if Settings.masterEnabled then
            print("========================")
            print("Rivals 終極外掛啟動")
            print("========================")
            task.spawn(mainLoop)
        else
            print("外掛已關閉")
        end
    end
end)
