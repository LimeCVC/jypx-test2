--[[
    JYPX // V1.0
    Комплексный скрипт для Roblox (Build a Boat for Treasure)
    Оптимизирован для мобильных устройств и эксплоитов (Xeno, Delta и др.)
    Модульная структура с защитой от вылетов (pcall).
]]

-- ==================== ЧАСТЬ 1: ОКРУЖЕНИЕ И СЕРВИСЫ ====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

-- Переменные для состояния
local isBuilding = false
local stopBuild = false
local previewActive = false

-- Конфигурация для мобильных устройств
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ==================== ЧАСТЬ 2: РАБОТА С ФАЙЛАМИ ====================
local FOLDER_PATH = "jypxBuild"
local SETTINGS_PATH = FOLDER_PATH .. "/Settings.json"

-- Убеждаемся, что папка существует
local function ensureFolder()
    if not isfolder(FOLDER_PATH) then
        makefolder(FOLDER_PATH)
    end
end
ensureFolder()

-- Настройки по умолчанию
local Settings = {
    uiScale = isMobile and 0.72 or 1.0,
    mobileMode = isMobile,
    previewTransparency = 0.5,
    autoPreview = true,
    flySpeed = 50,
    bhopSpeed = 32,
    bhopJump = 30,
    farmDuration = 30, -- Время полета к сундуку в секундах
    infBlockEnabled = false,
    skyHeight = 500,
    saveFormat = "ASU",
    primaryColor = Color3.fromRGB(255, 255, 255),
    secondaryColor = Color3.fromRGB(120, 120, 120),
    windowPosX = -1,
    windowPosY = -1,
    windowWidth = -1,
    windowHeight = -1,
    uiMinimized = false,
}

-- Загрузка настроек
local function loadSettings()
    if isfile(SETTINGS_PATH) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SETTINGS_PATH)) end)
        if ok and data then
            for k, v in pairs(data) do
                if Settings[k] ~= nil then
                    if type(v) == "table" and v.R then
                        Settings[k] = Color3.new(v.R, v.G, v.B)
                    else
                        Settings[k] = v
                    end
                end
            end
        end
    end
end
loadSettings()

-- Сохранение настроек
local function saveSettings()
    local d = {}
    for k, v in pairs(Settings) do
        if type(v) == "userdata" then
            d[k] = {R = v.R, G = v.G, B = v.B}
        else
            d[k] = v
        end
    end
    pcall(function() writefile(SETTINGS_PATH, HttpService:JSONEncode(d)) end)
end

-- Вспомогательные функции для работы с JSON
local function v3Str(v) return string.format("%.4f,%.4f,%.4f", v.X, v.Y, v.Z) end
local function strV3(s)
    local c = {}
    for v in s:gmatch("[^,]+") do table.insert(c, tonumber(v) or 0) end
    return #c >= 3 and Vector3.new(c[1], c[2], c[3]) or Vector3.new(0, 0, 0)
end

local function colStr(c) return string.format("%.4f,%.4f,%.4f", c.R, c.G, c.B) end
local function strCol(s)
    local c = {}
    for v in s:gmatch("[^,]+") do table.insert(c, tonumber(v) or 1) end
    return #c >= 3 and Color3.new(math.clamp(c[1], 0, 1), math.clamp(c[2], 0, 1), math.clamp(c[3], 0, 1)) or Color3.new(1, 1, 1)
end

local function cfStr(cf)
    return string.format("%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f", cf:GetComponents())
end

local function strCF(s)
    local c = {}
    for v in s:gmatch("[^,]+") do
        local n = tonumber(v:match("^%s*(.-)%s*$"))
        if n then table.insert(c, n) end
    end
    if #c >= 12 then return CFrame.new(table.unpack(c)) end
    return CFrame.new()
end

-- Конвертация блока в таблицу для JSON
local function blockToTable(block)
    if not block or not block:FindFirstChild("PPart") then return nil end
    local ppart = block.PPart
    return {
        Name = block.Name,
        Position = v3Str(ppart.Position),
        Rotation = v3Str(ppart.Rotation),
        Size = v3Str(ppart.Size),
        Color = colStr(ppart.Color),
        Transparency = ppart.Transparency,
        Anchored = ppart.Anchored,
        CanCollide = ppart.CanCollide,
        CFrame = cfStr(ppart.CFrame),
    }
end

-- Сохранение постройки в файл
local function saveBuildToFile(fileName)
    ensureFolder()
    local playerBlocks = Workspace:FindFirstChild("Plots") and Workspace.Plots:FindFirstChild(LocalPlayer.Name)
    if not playerBlocks then
        playerBlocks = Workspace:FindFirstChild(LocalPlayer.Name)
    end
    if not playerBlocks then return false, "Player blocks not found" end

    local buildData = {}
    for _, block in pairs(playerBlocks:GetChildren()) do
        if block:FindFirstChild("PPart") then
            local data = blockToTable(block)
            if data then
                table.insert(buildData, data)
            end
        end
    end

    if #buildData == 0 then return false, "No blocks found" end

    local json = HttpService:JSONEncode(buildData)
    pcall(function() writefile(FOLDER_PATH .. "/" .. fileName .. ".build", json) end)
    return true, "Build saved: " .. fileName
end

-- Загрузка постройки из файла
local function loadBuildFromFile(fileName)
    local path = FOLDER_PATH .. "/" .. fileName .. ".build"
    if not isfile(path) then return nil, "File not found" end

    local json = pcall(function() return readfile(path) end)
    if not json then return nil, "Cannot read file" end

    local data = pcall(function() return HttpService:JSONDecode(json) end)
    if not data or type(data) ~= "table" then return nil, "Invalid JSON" end

    return data, "Build loaded: " .. fileName
end

-- ==================== ЧАСТЬ 3: ПОСТРОЙКА ====================
-- Создание превью постройки
local PreviewFolder = Workspace:FindFirstChild("JYPX_Preview") or Instance.new("Folder")
PreviewFolder.Name = "JYPX_Preview"
PreviewFolder.Parent = Workspace

local function clearPreview()
    for _, obj in pairs(PreviewFolder:GetChildren()) do
        obj:Destroy()
    end
    previewActive = false
end

local function createPreview(buildData)
    clearPreview()

    if not buildData or #buildData == 0 then return false end

    local myZone = nil
    for _, zone in pairs(Workspace:GetChildren()) do
        if zone:FindFirstChild("TeamColor") and zone.TeamColor.Value == LocalPlayer.TeamColor then
            myZone = zone
            break
        end
    end

    local origin = myZone and myZone.CFrame or CFrame.new(0, 50, 0)

    for _, blockData in ipairs(buildData) do
        local template = ReplicatedStorage:FindFirstChild("BuildingParts") and ReplicatedStorage.BuildingParts:FindFirstChild(blockData.Name)
        if not template then continue end

        local pb = template:Clone()
        local ppart = pb:FindFirstChild("PPart")
        if not ppart then continue end

        -- Применяем данные из файла
        if blockData.Position then
            local pos = strV3(blockData.Position)
            local cf = CFrame.new(pos)
            if blockData.Rotation then
                local rot = strV3(blockData.Rotation)
                cf = cf * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
            end
            ppart.CFrame = origin:ToWorldSpace(cf)
        elseif blockData.CFrame then
            ppart.CFrame = origin:ToWorldSpace(strCF(blockData.CFrame))
        end

        if blockData.Size then ppart.Size = strV3(blockData.Size) end
        if blockData.Color then ppart.Color = strCol(blockData.Color) end
        if blockData.Transparency then ppart.Transparency = blockData.Transparency end

        -- Делаем прозрачным для превью
        ppart.Transparency = Settings.previewTransparency
        ppart.CanCollide = false
        ppart.Anchored = true

        pb.Parent = PreviewFolder
    end

    -- Добавляем Highlight для лучшей видимости
    if #PreviewFolder:GetChildren() > 0 then
        local highlight = Instance.new("Highlight")
        highlight.Adornee = PreviewFolder
        highlight.FillColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.7
        highlight.OutlineTransparency = 0.2
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = PreviewFolder
    end

    previewActive = true
    return true
end

-- Постройка из файла
local function pasteBuild(buildData, statusCb)
    if isBuilding then return false end
    if not buildData or #buildData == 0 then return false end

    isBuilding = true
    stopBuild = false

    local total = #buildData
    local placed = 0

    -- Находим зону игрока
    local myZone = nil
    for _, zone in pairs(Workspace:GetChildren()) do
        if zone:FindFirstChild("TeamColor") and zone.TeamColor.Value == LocalPlayer.TeamColor then
            myZone = zone
            break
        end
    end

    if not myZone then
        isBuilding = false
        return false, "Zone not found"
    end

    -- Получаем инструменты
    local placeTool = Character:FindFirstChild("BuildingTool")
    local placeRF = placeTool and placeTool:FindFirstChild("RF")
    local scaleTool = Character:FindFirstChild("ScalingTool")
    local scaleRF = scaleTool and scaleTool:FindFirstChild("RF")

    if not placeRF then
        isBuilding = false
        return false, "BuildingTool not found"
    end

    -- Постройка блоков
    for i, blockData in ipairs(buildData) do
        if stopBuild then break end

        local template = ReplicatedStorage:FindFirstChild("BuildingParts") and ReplicatedStorage.BuildingParts:FindFirstChild(blockData.Name)
        if not template then continue end

        -- Определяем позицию
        local cf
        if blockData.CFrame then
            cf = myZone.CFrame:ToWorldSpace(strCF(blockData.CFrame))
        elseif blockData.Position then
            local pos = strV3(blockData.Position)
            cf = CFrame.new(pos)
            if blockData.Rotation then
                local rot = strV3(blockData.Rotation)
                cf = cf * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
            end
            cf = myZone.CFrame:ToWorldSpace(cf)
        else
            continue
        end

        -- Размеры и цвет
        local size = blockData.Size and strV3(blockData.Size) or Vector3.new(4, 1, 4)
        local color = blockData.Color and strCol(blockData.Color) or Color3.new(1, 1, 1)

        -- Отправка RemoteEvent для постройки
        pcall(function()
            placeRF:InvokeServer(
                blockData.Name,
                0, -- ID блока (можно получить из BlockData)
                myZone,
                myZone.CFrame:ToObjectSpace(cf),
                true
            )
        end)

        -- Локальная постройка (резервный вариант)
        task.spawn(function()
            pcall(function()
                local newBlock = template:Clone()
                local ppart = newBlock:FindFirstChild("PPart")
                if ppart then
                    ppart.CFrame = cf
                    ppart.Size = size
                    ppart.Color = color
                    newBlock.Parent = myZone
                end
            end)
        end)

        placed = placed + 1
        if statusCb then
            statusCb("Building " .. placed .. "/" .. total, placed / total * 100)
        end

        -- Задержка для мобильных устройств
        task.wait(0.05)
    end

    isBuilding = false
    return true, "Built " .. placed .. " blocks"
end

-- ==================== ЧАСТЬ 4: ЭКСПЛОИТЫ ====================
-- Переменные для управления функциями
local noclipActive = false
local flyActive = false
local bhopEnabled = false
local farmActive = false

-- Noclip
local noclipConn = nil
local function toggleNoclip()
    noclipActive = not noclipActive

    if noclipActive then
        noclipConn = RunService.Stepped:Connect(function()
            if LocalPlayer.Character then
                for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if noclipConn then
            noclipConn:Disconnect()
            noclipConn = nil
        end
        if LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- Fly
local flyConn = nil
local flyBV = nil
local function toggleFly()
    flyActive = not flyActive

    if flyActive then
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            flyBV = Instance.new("BodyVelocity")
            flyBV.Name = "FlyBV"
            flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            flyBV.Parent = hrp
        end

        flyConn = RunService.Heartbeat:Connect(function()
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not hrp or not flyBV then return end

            local cam = Workspace.CurrentCamera
            local move = Vector3.zero

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end

            if move.Magnitude > 0 then
                flyBV.Velocity = move.Unit * Settings.flySpeed
            else
                flyBV.Velocity = Vector3.zero
            end
        end)
    else
        if flyConn then
            flyConn:Disconnect()
            flyConn = nil
        end
        if flyBV then
            flyBV:Destroy()
            flyBV = nil
        end
    end
end

-- BunnyHop (Банихоп)
local bhopConn = nil
local bhopKeys = {W = 0, S = 0, D = 0, A = 0, Space = 0}

local function initBhop()
    if bhopConn then return end

    UserInputService.InputBegan:Connect(function(inp, gp)
        if inp.KeyCode and bhopKeys[inp.KeyCode.Name] ~= nil then
            bhopKeys[inp.KeyCode.Name] = 1
        end
    end)

    UserInputService.InputEnded:Connect(function(inp, gp)
        if inp.KeyCode and bhopKeys[inp.KeyCode.Name] ~= nil then
            bhopKeys[inp.KeyCode.Name] = 0
        end
    end)

    bhopConn = RunService.RenderStepped:Connect(function()
        local hrp = LocalPlayer.Character and LocalCharacter:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end

        -- Автопрыжок
        if bhopKeys.Space > 0 and humanoid:GetState() == Enum.HumanoidStateType.Landed then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end

        -- Управление скоростью и направлением
        local moveDir = Vector3.zero
        if bhopKeys.W > 0 then moveDir = moveDir + hrp.CFrame.LookVector end
        if bhopKeys.S > 0 then moveDir = moveDir - hrp.CFrame.LookVector end
        if bhopKeys.A > 0 then moveDir = moveDir - hrp.CFrame.RightVector end
        if bhopKeys.D > 0 then moveDir = moveDir + hrp.CFrame.RightVector end

        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
            humanoid:MoveTo(hrp.Position + moveDir * 10)
        end
    end)
end

-- Auto Farm
local farmConn = nil
local function toggleFarm()
    farmActive = not farmActive

    if farmActive then
        task.spawn(function()
            local stages = Workspace:FindFirstChild("BoatStages")
            if not stages then
                farmActive = false
                return
            end

            local normalStages = stages:FindFirstChild("NormalStages")
            if not normalStages then
                farmActive = false
                return
            end

            local theEnd = normalStages:FindFirstChild("TheEnd")
            local goldenChest = theEnd and theEnd:FindFirstChild("GoldenChest")
            local trigger = goldenChest and goldenChest:FindFirstChild("Trigger")

            if not trigger then
                farmActive = false
                return
            end

            local duration = Settings.farmDuration or 30
            local runs = 0

            while farmActive do
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then
                    task.wait(1)
                    continue
                end

                -- Летим к сундуку
                local startPos = hrp.Position
                local endPos = trigger.Position + Vector3.new(0, 5, 0)
                local startTime = tick()

                while tick() - startTime < duration and farmActive do
                    local progress = (tick() - startTime) / duration
                    local targetPos = startPos:lerp(endPos, progress)

                    -- Плавное движение с помощью BodyVelocity
                    local bv = hrp:FindFirstChild("FarmBV")
                    if not bv then
                        bv = Instance.new("BodyVelocity")
                        bv.Name = "FarmBV"
                        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                        bv.Parent = hrp
                    end

                    local velocity = (targetPos - hrp.Position) * 2
                    bv.Velocity = velocity

                    task.wait(0.05)
                end

                -- Касаемся сундука
                if hrp and trigger then
                    local bv = hrp:FindFirstChild("FarmBV")
                    if bv then bv:Destroy() end

                    hrp.CFrame = trigger.CFrame * CFrame.new(0, 2, 0)
                    task.wait(0.5)

                    -- Срабатываем триггер
                    pcall(function()
                        firetouchinterest(hrp, trigger, 0)
                        task.wait()
                        firetouchinterest(hrp, trigger, 1)
                    end)

                    task.wait(2)
                end

                -- Перезапуск
                local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.Health = 0
                else
                    LocalPlayer.Character:BreakJoints()
                end

                runs = runs + 1
                task.wait(3) -- Ждем возрождения
            end
        end)
    end
end

-- ==================== ЧАСТЬ 5: СОЗДАНИЕ ИНТЕРФЕЙСА ====================
local UI = nil
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "JYPX_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = CoreGui

-- Настройки стилей
local Colors = {
    BG = Color3.fromRGB(8, 8, 8),
    Panel = Color3.fromRGB(18, 18, 18),
    PanelSoft = Color3.fromRGB(14, 14, 14),
    PanelElevated = Color3.fromRGB(24, 24, 24),
    Border = Color3.fromRGB(255, 255, 255),
    Text = Color3.fromRGB(255, 255, 255),
    Muted = Color3.fromRGB(140, 140, 140),
    ActiveBG = Color3.fromRGB(255, 255, 255),
    ActiveText = Color3.fromRGB(0, 0, 0),
    Green = Color3.fromRGB(80, 200, 80),
    Red = Color3.fromRGB(200, 80, 80),
}

-- Функция для стилизации кнопок
local function stylizeButton(btn, bgColor, strokeColor)
    btn.BackgroundColor3 = bgColor or Colors.Panel
    btn.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    local stroke = Instance.new("UIStroke")
    stroke.Color = strokeColor or Colors.Border
    stroke.Transparency = 0.5
    stroke.Thickness = 1
    stroke.Parent = btn
    return btn
end

-- Создаем главное окно
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 640, 0, 420)
MainFrame.Position = UDim2.new(0.5, -320, 0.5, -210)
MainFrame.BackgroundColor3 = Colors.BG
MainFrame.BackgroundTransparency = 0.15
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Parent = ScreenGui

-- Стилизация главного окна
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 6)
mainCorner.Parent = MainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Colors.Border
mainStroke.Transparency = 0.4
mainStroke.Thickness = 1
mainStroke.Parent = MainFrame

-- Ресайз хендл (уголок для изменения размера)
local ResizeHandle = Instance.new("TextButton")
ResizeHandle.Name = "ResizeHandle"
ResizeHandle.Size = UDim2.new(0, 20, 0, 20)
ResizeHandle.Position = UDim2.new(1, -22, 1, -22)
ResizeHandle.BackgroundTransparency = 1
ResizeHandle.Text = ""
ResizeHandle.ZIndex = 100
ResizeHandle.Parent = MainFrame

-- Логика ресайза
local isResizing = false
local resizeStartMouse = Vector2.new()
local resizeStartSize = Vector2.new()
local minWidth = 500
local minHeight = 350

ResizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = true
        resizeStartMouse = Vector2.new(input.Position.X, input.Position.Y)
        resizeStartSize = MainFrame.AbsoluteSize
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not isResizing then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end

    local delta = Vector2.new(input.Position.X, input.Position.Y) - resizeStartMouse
    local newWidth = math.clamp(resizeStartSize.X + delta.X, minWidth, Workspace.CurrentCamera.ViewportSize.X - 20)
    local newHeight = math.clamp(resizeStartSize.Y + delta.Y, minHeight, Workspace.CurrentCamera.ViewportSize.Y - 20)

    MainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)

    -- Обновляем размеры внутренних элементов
    for _, child in pairs(MainFrame:GetDescendants()) do
        if child.Name == "ContentFrame" or child.Name == "ScrollFrame" then
            pcall(function()
                child.Size = UDim2.new(1, -120, 1, -60)
            end)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = false
    end
end)

-- Шапка
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 44)
Header.BackgroundColor3 = Colors.PanelElevated
Header.BackgroundTransparency = 0.1
Header.BorderSizePixel = 0
Header.ZIndex = 2
Header.Parent = MainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 6)
headerCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.5, 0, 0, 24)
Title.Position = UDim2.new(0, 14, 0, 10)
Title.BackgroundTransparency = 1
Title.Text = "JYPX // V1.0"
Title.TextColor3 = Colors.Text
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 3
Title.Parent = Header

-- Кнопка закрытия
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -14)
CloseBtn.BackgroundColor3 = Colors.Panel
CloseBtn.BackgroundTransparency = 0
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Colors.Text
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.ZIndex = 4
CloseBtn.Parent = Header
stylizeButton(CloseBtn, Colors.Panel, Colors.Border)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Левая панель с вкладками
local TabsBar = Instance.new("Frame")
TabsBar.Size = UDim2.new(0, 100, 1, -60)
TabsBar.Position = UDim2.new(0, 10, 0, 54)
TabsBar.BackgroundColor3 = Colors.PanelSoft
TabsBar.BackgroundTransparency = 0.1
TabsBar.BorderSizePixel = 0
TabsBar.ClipsDescendants = true
TabsBar.Parent = MainFrame

local tabsCorner = Instance.new("UICorner")
tabsCorner.CornerRadius = UDim.new(0, 4)
tabsCorner.Parent = TabsBar

local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Vertical
tabsLayout.Padding = UDim.new(0, 4)
tabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabsLayout.Parent = TabsBar

local tabsPad = Instance.new("UIPadding")
tabsPad.PaddingTop = UDim.new(0, 6)
tabsPad.PaddingBottom = UDim.new(0, 6)
tabsPad.Parent = TabsBar

-- Контентная область
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -120, 1, -60)
ContentArea.Position = UDim2.new(0, 114, 0, 54)
ContentArea.BackgroundTransparency = 1
ContentArea.ClipsDescendants = true
ContentArea.Parent = MainFrame

-- Создание вкладок
local function createTab(name, label)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Tab"
    btn.Size = UDim2.new(0.9, 0, 0, 44)
    btn.BackgroundColor3 = Colors.PanelElevated
    btn.BackgroundTransparency = 0.1
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextColor3 = Colors.Muted
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.TextWrapped = true
    btn.Parent = TabsBar
    stylizeButton(btn, Colors.PanelElevated, Colors.Border)

    local frame = Instance.new("ScrollingFrame")
    frame.Name = name .. "Frame"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.ClipsDescendants = true
    frame.ScrollBarThickness = 0
    frame.CanvasSize = UDim2.new(0, 0, 0, 0)
    frame.Visible = false
    frame.Parent = ContentArea

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        frame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)

    btn.MouseButton1Click:Connect(function()
        -- Скрываем все фреймы
        for _, child in pairs(ContentArea:GetChildren()) do
            if child:IsA("ScrollingFrame") then
                child.Visible = false
            end
        end
        -- Сбрасываем стили кнопок
        for _, child in pairs(TabsBar:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = Colors.PanelElevated
                child.BackgroundTransparency = 0.1
                child.TextColor3 = Colors.Muted
            end
        end
        -- Активируем текущую
        frame.Visible = true
        btn.BackgroundColor3 = Colors.ActiveBG
        btn.BackgroundTransparency = 0
        btn.TextColor3 = Colors.ActiveText
    end)

    return btn, frame, layout
end

-- Создаем вкладки
local buildBtn, buildFrame, buildLayout = createTab("Build", "BUILD")
local blocksBtn, blocksFrame, blocksLayout = createTab("Blocks", "BLOCKS")
local exploitsBtn, exploitsFrame, exploitsLayout = createTab("Exploits", "EXPLOITS")
local settingsBtn, settingsFrame, settingsLayout = createTab("Settings", "SETTINGS")

-- Активируем первую вкладку
buildBtn.MouseButton1Click:Fire()

-- ==================== ЧАСТЬ 6: НАПОЛНЕНИЕ UI ====================
-- Вспомогательные функции для создания элементов
local function createLabel(text, parent)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Colors.Text
    lbl.TextSize = 13
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
    return lbl
end

local function createButton(text, parent, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = Colors.PanelElevated
    btn.BackgroundTransparency = 0
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Colors.Text
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = parent
    stylizeButton(btn, Colors.PanelElevated, Colors.Border)

    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)

    return btn
end

local function createInput(placeholder, parent, callback)
    local inp = Instance.new("TextBox")
    inp.Size = UDim2.new(1, 0, 0, 34)
    inp.BackgroundColor3 = Colors.PanelSoft
    inp.BackgroundTransparency = 0
    inp.BorderSizePixel = 0
    inp.PlaceholderText = placeholder
    inp.PlaceholderColor3 = Colors.Muted
    inp.Text = ""
    inp.TextColor3 = Colors.Text
    inp.TextSize = 12
    inp.Font = Enum.Font.Gotham
    inp.TextXAlignment = Enum.TextXAlignment.Left
    inp.Parent = parent
    stylizeButton(inp, Colors.PanelSoft, Colors.Border)

    inp.FocusLost:Connect(function()
        if callback then callback(inp.Text) end
    end)

    return inp
end

local function createSlider(label, minVal, maxVal, defaultVal, parent, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 44)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.4, 0, 0, 20)
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label .. ": " .. tostring(defaultVal)
    lbl.TextColor3 = Colors.Muted
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.15, 0, 0, 20)
    valueLabel.Position = UDim2.new(0.85, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(defaultVal)
    valueLabel.TextColor3 = Colors.Text
    valueLabel.TextSize = 11
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = container

    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(0.85, 0, 0, 6)
    slider.Position = UDim2.new(0, 0, 0, 26)
    slider.BackgroundColor3 = Colors.PanelElevated
    slider.BorderSizePixel = 0
    slider.Parent = container
    stylizeButton(slider, Colors.PanelElevated, Colors.Border)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = Colors.ActiveBG
    fill.BorderSizePixel = 0
    fill.Parent = slider
    stylizeButton(fill, Colors.ActiveBG, nil)

    local dragging = false
    slider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)

    slider.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    slider.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end

        local relativeX = math.clamp((input.Position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
        local value = minVal + (maxVal - minVal) * relativeX
        value = math.floor(value + 0.5)

        fill.Size = UDim2.new(relativeX, 0, 1, 0)
        valueLabel.Text = tostring(value)
        lbl.Text = label .. ": " .. tostring(value)

        if callback then callback(value) end
    end)

    return container
end

-- ==================== ЧАСТЬ 7: НАПОЛНЕНИЕ ВКЛАДОК ====================
-- Вкладка BUILD
createLabel("BUILD CONTROLS", buildFrame)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 28)
statusLabel.BackgroundColor3 = Colors.PanelSoft
statusLabel.BackgroundTransparency = 0
statusLabel.BorderSizePixel = 0
statusLabel.Text = "  Ready"
statusLabel.TextColor3 = Colors.Text
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.GothamSemibold
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = buildFrame
stylizeButton(statusLabel, Colors.PanelSoft, Colors.Border)

-- Ввод имени файла
createLabel("FILE NAME", buildFrame)
local fileInput = createInput("Enter file name...", buildFrame)

-- Кнопки
createButton("Save Build", buildFrame, function()
    local fileName = fileInput.Text
    if fileName == "" then
        statusLabel.Text = "  Enter a file name"
        return
    end
    local success, msg = saveBuildToFile(fileName)
    statusLabel.Text = "  " .. msg
end)

createButton("Preview Build", buildFrame, function()
    local fileName = fileInput.Text
    if fileName == "" then
        statusLabel.Text = "  Enter a file name"
        return
    end
    local data, msg = loadBuildFromFile(fileName)
    if not data then
        statusLabel.Text = "  " .. msg
        return
    end
    if createPreview(data) then
        statusLabel.Text = "  Preview created (" .. #data .. " blocks)"
    else
        statusLabel.Text = "  Failed to create preview"
    end
end)

createButton("Clear Preview", buildFrame, function()
    clearPreview()
    statusLabel.Text = "  Preview cleared"
end)

createButton("Build", buildFrame, function()
    local fileName = fileInput.Text
    if fileName == "" then
        statusLabel.Text = "  Enter a file name"
        return
    end
    local data, msg = loadBuildFromFile(fileName)
    if not data then
        statusLabel.Text = "  " .. msg
        return
    end

    pasteBuild(data, function(message, progress)
        statusLabel.Text = "  " .. message
    end)

    statusLabel.Text = "  Build finished"
end)

createButton("Stop Build", buildFrame, function()
    stopBuild = true
    statusLabel.Text = "  Stopping..."
    task.wait(0.5)
    statusLabel.Text = "  Stopped"
end)

-- Вкладка BLOCKS
createLabel("BLOCK INFORMATION", blocksFrame)

local blocksInfo = Instance.new("TextLabel")
blocksInfo.Size = UDim2.new(1, 0, 0, 60)
blocksInfo.BackgroundColor3 = Colors.PanelSoft
blocksInfo.BackgroundTransparency = 0
blocksInfo.BorderSizePixel = 0
blocksInfo.Text = "No build loaded"
blocksInfo.TextColor3 = Colors.Muted
blocksInfo.TextSize = 11
blocksInfo.Font = Enum.Font.Gotham
blocksInfo.TextWrapped = true
blocksInfo.TextXAlignment = Enum.TextXAlignment.Left
blocksInfo.TextYAlignment = Enum.TextYAlignment.Top
blocksInfo.Parent = blocksFrame
stylizeButton(blocksInfo, Colors.PanelSoft, Colors.Border)

createButton("Refresh Blocks", blocksFrame, function()
    -- Обновляем информацию о блоках
    local folder = Workspace:FindFirstChild("Plots") and Workspace.Plots:FindFirstChild(LocalPlayer.Name)
    if not folder then
        folder = Workspace:FindFirstChild(LocalPlayer.Name)
    end
    if not folder then
        blocksInfo.Text = "No blocks found for player"
        return
    end

    local blockCounts = {}
    for _, block in pairs(folder:GetChildren()) do
        if block:FindFirstChild("PPart") then
            blockCounts[block.Name] = (blockCounts[block.Name] or 0) + 1
        end
    end

    local text = "Blocks in build:\n"
    for name, count in pairs(blockCounts) do
        text = text .. name .. ": " .. count .. "\n"
    end
    blocksInfo.Text = text
end)

-- Вкладка EXPLOITS
createLabel("EXPLOITS", exploitsFrame)

-- Создаем под-вкладки
local subTabsBar = Instance.new("Frame")
subTabsBar.Size = UDim2.new(1, 0, 0, 32)
subTabsBar.BackgroundTransparency = 1
subTabsBar.Parent = exploitsFrame

local subTabsLayout = Instance.new("UIListLayout")
subTabsLayout.FillDirection = Enum.FillDirection.Horizontal
subTabsLayout.Padding = UDim.new(0, 2)
subTabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
subTabsLayout.Parent = subTabsBar

local subContent = Instance.new("Frame")
subContent.Size = UDim2.new(1, 0, 1, -38)
subContent.Position = UDim2.new(0, 0, 0, 38)
subContent.BackgroundTransparency = 1
subContent.ClipsDescendants = true
subContent.Parent = exploitsFrame

local function createSubTab(label, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 70, 1, 0)
    btn.BackgroundColor3 = Colors.PanelSoft
    btn.BackgroundTransparency = 0
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextColor3 = Colors.Muted
    btn.TextSize = 10
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = subTabsBar
    stylizeButton(btn, Colors.PanelSoft, Colors.Border)

    btn.MouseButton1Click:Connect(function()
        for _, child in pairs(subTabsBar:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = Colors.PanelSoft
                child.TextColor3 = Colors.Muted
            end
        end
        btn.BackgroundColor3 = Colors.ActiveBG
        btn.TextColor3 = Colors.ActiveText
        if callback then callback() end
    end)

    return btn
end

-- Контейнеры для под-вкладок
local infContainer = Instance.new("ScrollingFrame")
infContainer.Size = UDim2.new(1, 0, 1, 0)
infContainer.BackgroundTransparency = 1
infContainer.ClipsDescendants = true
infContainer.ScrollBarThickness = 0
infContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
infContainer.Parent = subContent
infContainer.Visible = false

local miscContainer = Instance.new("ScrollingFrame")
miscContainer.Size = UDim2.new(1, 0, 1, 0)
miscContainer.BackgroundTransparency = 1
miscContainer.ClipsDescendants = true
miscContainer.ScrollBarThickness = 0
miscContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
miscContainer.Parent = subContent
miscContainer.Visible = false

local moveContainer = Instance.new("ScrollingFrame")
moveContainer.Size = UDim2.new(1, 0, 1, 0)
moveContainer.BackgroundTransparency = 1
moveContainer.ClipsDescendants = true
moveContainer.ScrollBarThickness = 0
moveContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
moveContainer.Parent = subContent
moveContainer.Visible = false

local visualContainer = Instance.new("ScrollingFrame")
visualContainer.Size = UDim2.new(1, 0, 1, 0)
visualContainer.BackgroundTransparency = 1
visualContainer.ClipsDescendants = true
visualContainer.ScrollBarThickness = 0
visualContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
visualContainer.Parent = subContent
visualContainer.Visible = false

-- Создаем под-вкладки
createSubTab("INF", function()
    for _, child in pairs(subContent:GetChildren()) do
        if child:IsA("ScrollingFrame") then child.Visible = false end
    end
    infContainer.Visible = true
end)

createSubTab("MISC", function()
    for _, child in pairs(subContent:GetChildren()) do
        if child:IsA("ScrollingFrame") then child.Visible = false end
    end
    miscContainer.Visible = true
end)

createSubTab("MOVE", function()
    for _, child in pairs(subContent:GetChildren()) do
        if child:IsA("ScrollingFrame") then child.Visible = false end
    end
    moveContainer.Visible = true
end)

createSubTab("VISUAL", function()
    for _, child in pairs(subContent:GetChildren()) do
        if child:IsA("ScrollingFrame") then child.Visible = false end
    end
    visualContainer.Visible = true
end)

-- Наполняем INF
createLabel("INF BLOCK", infContainer)
local infToggle = createButton("Inf Block: OFF", infContainer, function()
    Settings.infBlockEnabled = not Settings.infBlockEnabled
    infToggle.Text = "Inf Block: " .. (Settings.infBlockEnabled and "ON" or "OFF")
    infToggle.BackgroundColor3 = Settings.infBlockEnabled and Color3.fromRGB(16, 32, 16) or Colors.PanelElevated
end)
infToggle.BackgroundColor3 = Settings.infBlockEnabled and Color3.fromRGB(16, 32, 16) or Colors.PanelElevated

-- Наполняем MISC
createLabel("SHOP", miscContainer)
createButton("Buy Pine Tree", miscContainer, function()
    pcall(function()
        Workspace.ItemBoughtFromShop:InvokeServer("PineTree", 1)
    end)
end)
createButton("Buy Dragon Harpoon", miscContainer, function()
    pcall(function()
        Workspace.PromptRobuxEvent:InvokeServer(1109792341, "Product")
    end)
end)
createButton("Buy Cookie Wheels", miscContainer, function()
    pcall(function()
        Workspace.PromptRobuxEvent:InvokeServer(1126385328, "Product")
    end)
end)

createLabel("TELEPORTS", miscContainer)
createButton("Easter Event", miscContainer, function()
    pcall(function()
        TeleportService:Teleport(1930863474)
    end)
end)
createButton("Christmas Event", miscContainer, function()
    pcall(function()
        TeleportService:Teleport(1930866268)
    end)
end)

-- Наполняем MOVE
createLabel("MOVEMENT", moveContainer)

local noclipBtn = createButton("NoClip: OFF", moveContainer, function()
    toggleNoclip()
    noclipBtn.Text = "NoClip: " .. (noclipActive and "ON" or "OFF")
    noclipBtn.BackgroundColor3 = noclipActive and Color3.fromRGB(16, 32, 16) or Colors.PanelElevated
end)

local flyBtn = createButton("Fly: OFF", moveContainer, function()
    toggleFly()
    flyBtn.Text = "Fly: " .. (flyActive and "ON" or "OFF")
    flyBtn.BackgroundColor3 = flyActive and Color3.fromRGB(16, 32, 16) or Colors.PanelElevated
end)

createSlider("Fly Speed", 10, 300, Settings.flySpeed, moveContainer, function(value)
    Settings.flySpeed = value
end)

createSlider("Bhop Speed", 10, 60, Settings.bhopSpeed, moveContainer, function(value)
    Settings.bhopSpeed = value
end)

local bhopBtn = createButton("BunnyHop: OFF", moveContainer, function()
    bhopEnabled = not bhopEnabled
    bhopBtn.Text = "BunnyHop: " .. (bhopEnabled and "ON" or "OFF")
    bhopBtn.BackgroundColor3 = bhopEnabled and Color3.fromRGB(16, 32, 16) or Colors.PanelElevated
    if bhopEnabled then
        initBhop()
    else
        if bhopConn then
            bhopConn:Disconnect()
            bhopConn = nil
        end
    end
end)

-- Наполняем VISUAL (ESP и т.д.)
createLabel("VISUAL", visualContainer)
local espEnabled = false
local espConn = nil

local espBtn = createButton("ESP: OFF", visualContainer, function()
    espEnabled = not espEnabled
    espBtn.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
    espBtn.BackgroundColor3 = espEnabled and Color3.fromRGB(16, 32, 16) or Colors.PanelElevated

    if espEnabled then
        -- Создаем ESP с помощью BillboardGui
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local character = player.Character
                if character and character:FindFirstChild("HumanoidRootPart") then
                    local hrp = character.HumanoidRootPart
                    local esp = Instance.new("BillboardGui")
                    esp.Name = "JYPX_ESP"
                    esp.Size = UDim2.new(0, 100, 0, 30)
                    esp.Adornee = hrp
                    esp.AlwaysOnTop = true
                    esp.StudsOffset = Vector3.new(0, 3, 0)
                    esp.Parent = hrp

                    local label = Instance.new("TextLabel")
                    label.Size = UDim2.new(1, 0, 1, 0)
                    label.BackgroundTransparency = 1
                    label.Text = player.Name
                    label.TextColor3 = player.TeamColor.Color
                    label.TextSize = 12
                    label.Font = Enum.Font.GothamBold
                    label.TextStrokeTransparency = 0.2
                    label.TextStrokeColor3 = Color3.new(0, 0, 0)
                    label.Parent = esp
                end
            end
        end
    else
        -- Удаляем ESP
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local character = player.Character
                if character then
                    for _, child in pairs(character:GetDescendants()) do
                        if child.Name == "JYPX_ESP" then
                            child:Destroy()
                        end
                    end
                end
            end
        end
    end
end)

-- Обработка новых игроков для ESP
Players.PlayerAdded:Connect(function(player)
    if espEnabled then
        player.CharacterAdded:Connect(function(character)
            task.wait(0.5)
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local esp = Instance.new("BillboardGui")
                esp.Name = "JYPX_ESP"
                esp.Size = UDim2.new(0, 100, 0, 30)
                esp.Adornee = hrp
                esp.AlwaysOnTop = true
                esp.StudsOffset = Vector3.new(0, 3, 0)
                esp.Parent = hrp

                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = player.Name
                label.TextColor3 = player.TeamColor.Color
                label.TextSize = 12
                label.Font = Enum.Font.GothamBold
                label.TextStrokeTransparency = 0.2
                label.TextStrokeColor3 = Color3.new(0, 0, 0)
                label.Parent = esp
            end
        end)
    end
end)

-- Вкладка SETTINGS
createLabel("UI SETTINGS", settingsFrame)

local autoPreviewBtn = createButton("Auto Preview: " .. (Settings.autoPreview and "ON" or "OFF"), settingsFrame, function()
    Settings.autoPreview = not Settings.autoPreview
    autoPreviewBtn.Text = "Auto Preview: " .. (Settings.autoPreview and "ON" or "OFF")
    autoPreviewBtn.BackgroundColor3 = Settings.autoPreview and Color3.fromRGB(16, 32, 16) or Colors.PanelElevated
end)
autoPreviewBtn.BackgroundColor3 = Settings.autoPreview and Color3.fromRGB(16, 32, 16) or Colors.PanelElevated

createSlider("UI Scale", 0.5, 2.0, Settings.uiScale, settingsFrame, function(value)
    Settings.uiScale = value
    MainFrame.Size = UDim2.new(0, 640 * value, 0, 420 * value)
    MainFrame.Position = UDim2.new(0.5, -320 * value, 0.5, -210 * value)
end)

createSlider("Preview Transparency", 0, 1, Settings.previewTransparency, settingsFrame, function(value)
    Settings.previewTransparency = value
    if previewActive then
        for _, obj in pairs(PreviewFolder:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.Transparency = value
            end
        end
    end
end)

createLabel("SAVE SETTINGS", settingsFrame)
createButton("Save All Settings", settingsFrame, function()
    saveSettings()
    statusLabel.Text = "  Settings saved"
end)

-- ==================== ЧАСТЬ 8: ЗАПУСК И НАСТРОЙКА ====================
-- Активируем первую под-вкладку Exploits
for _, child in pairs(subTabsBar:GetChildren()) do
    if child:IsA("TextButton") then
        child.MouseButton1Click:Fire()
        break
    end
end

-- Активируем Build вкладку
buildBtn.MouseButton1Click:Fire()

-- Автозагрузка превью при загрузке файла
local function handleFileLoad(fileName)
    if Settings.autoPreview then
        local data, msg = loadBuildFromFile(fileName)
        if data then
            createPreview(data)
        end
    end
end

-- Автоматическая очистка превью при выходе
LocalPlayer.CharacterAdded:Connect(function()
    clearPreview()
end)

-- ==================== ЧАСТЬ 9: ЗАЩИТА ОТ ВЫЛЕТОВ ====================
-- Глобальная обработка ошибок
local function safeCall(func, ...)
    local args = {...}
    pcall(function()
        func(unpack(args))
    end)
end

-- Периодическое сохранение настроек
task.spawn(function()
    while true do
        task.wait(60)
        pcall(saveSettings)
    end
end)

print("JYPX // V1.0 loaded successfully!")
