--===================================================================================--
--                             JYPX // V1.1 - BUILD A BOAT FOR TREASURE               --
--===================================================================================--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")

-- Проверка и создание папки для сохранений в файловой системе эксплоита
if not isfolder("jypxBuild") then
    makefolder("jypxBuild")
end

--===================================================================================--
-- [ГЛОБАЛЬНЫЕ НАСТРОЙКИ И ФЛАГИ СОСТОЯНИЯ ЧИТА]
--===================================================================================--
_G.Building = false
_G.BuildDelay = 0.05
_G.AutoFarm = false
_G.FarmDuration = 25 -- Оптимальное время пролета стадий в секундах
_G.NoClip = false
_G.Fly = false
_G.FlySpeed = 50
_G.BHop = false
_G.BhopSpeed = 25
_G.BhopJump = 40
_G.ESP_Enabled = false

local Cam = Workspace.CurrentCamera
local PreviewModel = nil

--===================================================================================--
-- [МОДУЛЬ 1: АВТО-БИЛД (ЛОГИКА И СЕРИАЛИЗАЦИЯ ДАННЫХ)]
--===================================================================================--

local function sanitizeCFrame(cf) return {cf:GetComponents()} end
local function toCFrame(tbl) return CFrame.new(unpack(tbl)) end
local function sanitizeColor(color) return {color.R, color.G, color.B} end

-- Функция экспорта (Safe Build)
local function safeBuild(fileName)
    local targetFolder = Workspace:FindFirstChild("jypxBuild") or Workspace.Plots:FindFirstChild(LocalPlayer.Name)
    if not targetFolder then return end
    local blocksData = {}
    for _, block in ipairs(targetFolder:GetDescendants()) do
        if block:IsA("BasePart") then
            pcall(function()
                table.insert(blocksData, {
                    ID = block:GetAttribute("BlockID") or block.Name,
                    Name = block.Name,
                    Position = sanitizeCFrame(block.CFrame),
                    Size = {block.Size.X, block.Size.Y, block.Size.Z},
                    Color = sanitizeColor(block.Color),
                    Transparency = block.Transparency,
                    Anchored = block.Anchored,
                    CanCollide = block.CanCollide
                })
            end)
        end
    end
    writefile("jypxBuild/" .. fileName .. ".build", HttpService:JSONEncode(blocksData))
end

-- Удаление старого превью
local function clearPreview()
    if PreviewModel then PreviewModel:Destroy() PreviewModel = nil end
end

-- Функция предпросмотра (Preview)
local function previewBuild(fileName)
    clearPreview()
    local success, content = pcall(function() return readfile("jypxBuild/" .. fileName .. ".build") end)
    if not success then return end
    local blocksData = HttpService:JSONDecode(content)
    PreviewModel = Instance.new("Model")
    PreviewModel.Name = "JYPX_Preview"
    PreviewModel.Parent = Workspace

    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(0, 255, 255)
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0.2
    hl.Parent = PreviewModel

    for _, data in ipairs(blocksData) do
        local part = Instance.new("Part")
        part.Size = Vector3.new(unpack(data.Size))
        part.CFrame = toCFrame(data.Position)
        part.Color = Color3.new(unpack(data.Color))
        part.Transparency = 0.5
        part.CanCollide = false
        part.Anchored = true
        part.Parent = PreviewModel
    end
end

-- Функция постройки (Build)
local function startBuild(fileName)
    _G.Building = true
    local success, content = pcall(function() return readfile("jypxBuild/" .. fileName .. ".build") end)
    if not success then _G.Building = false return end
    local blocksData = HttpService:JSONDecode(content)
    for _, data in ipairs(blocksData) do
        if not _G.Building then break end
        pcall(function()
            local part = Instance.new("Part")
            part.Name = data.Name
            part.Size = Vector3.new(unpack(data.Size))
            part.CFrame = toCFrame(data.Position)
            part.Color = Color3.new(unpack(data.Color))
            part.Transparency = data.Transparency
            part.CanCollide = data.CanCollide
            part.Anchored = data.Anchored
            part.Parent = Workspace.Plots:FindFirstChild(LocalPlayer.Name) or Workspace
        end)
        task.wait(_G.BuildDelay)
    end
    _G.Building = false
end

--===================================================================================--
-- [МОДУЛЬ 2: АВТОФАРМ С АВТО-СПУСКОМ ПОД ВОДОПАД]
--===================================================================================--
local FarmStages = {
    Vector3.new(-50, 55, 200),
    Vector3.new(-50, 55, 1000),
    Vector3.new(-50, 55, 2000),
    Vector3.new(-50, 55, 3000),
    Vector3.new(-50, 55, 4000),
    Vector3.new(-50, 55, 5000),
    Vector3.new(-50, 55, 6000),
    Vector3.new(-50, 55, 7500),  -- Финал верхней стадии перед обрывом
    Vector3.new(-50, -10, 9000), -- КРИТИЧЕСКИЙ СПУСК: Уходим по высоте Y вниз под водопад
    Vector3.new(-60, -15, 9400), -- Залет прямо к сундуку в пещеру
}

task.spawn(function()
    while true do
        task.wait(1)
        if _G.AutoFarm and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = LocalPlayer.Character.HumanoidRootPart
            
            for _, stagePos in ipairs(FarmStages) do
                if not _G.AutoFarm then break end
                
                local distance = (hrp.Position - stagePos).Magnitude
                local speed = distance / (_G.FarmDuration / #FarmStages)
                
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                bv.Velocity = (stagePos - hrp.Position).Unit * speed
                bv.Parent = hrp
                
                while (hrp.Position - stagePos).Magnitude > 12 and _G.AutoFarm do
                    pcall(function()
                        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                            if part:IsA("BasePart") then part.CanCollide = false end
                        end
                    end)
                    task.wait(0.05)
                end
                bv:Destroy()
            end
            
            if _G.AutoFarm then
                task.wait(2.5) -- Тайм-аут на сбор награды из сундука
                if LocalPlayer.Character:FindFirstChild("Humanoid") then
                    LocalPlayer.Character.Humanoid:BreakJoints()
                end
                LocalPlayer.CharacterAdded:Wait()
                task.wait(1.2)
            end
        end
    end
end)

--===================================================================================--
-- [МОДУЛЬ 3: ДВИЖЕНИЯ И ЧИТЫ (FLY, NO-CLIP, BHOP)]
--===================================================================================--
RunService.Stepped:Connect(function()
    if (_G.NoClip or _G.Fly) and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if _G.Fly and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        local cf = Cam.CFrame
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cf.RightVector end
        hrp.Velocity = move * _G.FlySpeed
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if _G.BHop and input.KeyCode == Enum.KeyCode.Space then
        while UserInputService:IsKeyDown(Enum.KeyCode.Space) and _G.BHop do
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                local hum = LocalPlayer.Character.Humanoid
                if hum.FloorMaterial ~= Enum.Material.Air then
                    LocalPlayer.Character.HumanoidRootPart.Velocity = Vector3.new(LocalPlayer.Character.HumanoidRootPart.Velocity.X, _G.BhopJump, LocalPlayer.Character.HumanoidRootPart.Velocity.Z)
                    hum.WalkSpeed = _G.BhopSpeed
                end
            end
            task.wait(0.02)
        end
    end
end)
--===================================================================================--
--                             JYPX // V1.1 - BUILD A BOAT FOR TREASURE               --
--===================================================================================--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")

-- Проверка и создание папки для сохранений в файловой системе эксплоита
if not isfolder("jypxBuild") then
    makefolder("jypxBuild")
end

--===================================================================================--
-- [ГЛОБАЛЬНЫЕ НАСТРОЙКИ И ФЛАГИ СОСТОЯНИЯ ЧИТА]
--===================================================================================--
_G.Building = false
_G.BuildDelay = 0.05
_G.AutoFarm = false
_G.FarmDuration = 25 -- Оптимальное время пролета стадий в секундах
_G.NoClip = false
_G.Fly = false
_G.FlySpeed = 50
_G.BHop = false
_G.BhopSpeed = 25
_G.BhopJump = 40
_G.ESP_Enabled = false

local Cam = Workspace.CurrentCamera
local PreviewModel = nil

--===================================================================================--
-- [МОДУЛЬ 1: АВТО-БИЛД (ЛОГИКА И СЕРИАЛИЗАЦИЯ ДАННЫХ)]
--===================================================================================--

local function sanitizeCFrame(cf) return {cf:GetComponents()} end
local function toCFrame(tbl) return CFrame.new(unpack(tbl)) end
local function sanitizeColor(color) return {color.R, color.G, color.B} end

-- Функция экспорта (Safe Build)
local function safeBuild(fileName)
    local targetFolder = Workspace:FindFirstChild("jypxBuild") or Workspace.Plots:FindFirstChild(LocalPlayer.Name)
    if not targetFolder then return end
    local blocksData = {}
    for _, block in ipairs(targetFolder:GetDescendants()) do
        if block:IsA("BasePart") then
            pcall(function()
                table.insert(blocksData, {
                    ID = block:GetAttribute("BlockID") or block.Name,
                    Name = block.Name,
                    Position = sanitizeCFrame(block.CFrame),
                    Size = {block.Size.X, block.Size.Y, block.Size.Z},
                    Color = sanitizeColor(block.Color),
                    Transparency = block.Transparency,
                    Anchored = block.Anchored,
                    CanCollide = block.CanCollide
                })
            end)
        end
    end
    writefile("jypxBuild/" .. fileName .. ".build", HttpService:JSONEncode(blocksData))
end

-- Удаление старого превью
local function clearPreview()
    if PreviewModel then PreviewModel:Destroy() PreviewModel = nil end
end

-- Функция предпросмотра (Preview)
local function previewBuild(fileName)
    clearPreview()
    local success, content = pcall(function() return readfile("jypxBuild/" .. fileName .. ".build") end)
    if not success then return end
    local blocksData = HttpService:JSONDecode(content)
    PreviewModel = Instance.new("Model")
    PreviewModel.Name = "JYPX_Preview"
    PreviewModel.Parent = Workspace

    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(0, 255, 255)
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0.2
    hl.Parent = PreviewModel

    for _, data in ipairs(blocksData) do
        local part = Instance.new("Part")
        part.Size = Vector3.new(unpack(data.Size))
        part.CFrame = toCFrame(data.Position)
        part.Color = Color3.new(unpack(data.Color))
        part.Transparency = 0.5
        part.CanCollide = false
        part.Anchored = true
        part.Parent = PreviewModel
    end
end

-- Функция постройки (Build)
local function startBuild(fileName)
    _G.Building = true
    local success, content = pcall(function() return readfile("jypxBuild/" .. fileName .. ".build") end)
    if not success then _G.Building = false return end
    local blocksData = HttpService:JSONDecode(content)
    for _, data in ipairs(blocksData) do
        if not _G.Building then break end
        pcall(function()
            local part = Instance.new("Part")
            part.Name = data.Name
            part.Size = Vector3.new(unpack(data.Size))
            part.CFrame = toCFrame(data.Position)
            part.Color = Color3.new(unpack(data.Color))
            part.Transparency = data.Transparency
            part.CanCollide = data.CanCollide
            part.Anchored = data.Anchored
            part.Parent = Workspace.Plots:FindFirstChild(LocalPlayer.Name) or Workspace
        end)
        task.wait(_G.BuildDelay)
    end
    _G.Building = false
end

--===================================================================================--
-- [МОДУЛЬ 2: АВТОФАРМ С АВТО-СПУСКОМ ПОД ВОДОПАД]
--===================================================================================--
local FarmStages = {
    Vector3.new(-50, 55, 200),
    Vector3.new(-50, 55, 1000),
    Vector3.new(-50, 55, 2000),
    Vector3.new(-50, 55, 3000),
    Vector3.new(-50, 55, 4000),
    Vector3.new(-50, 55, 5000),
    Vector3.new(-50, 55, 6000),
    Vector3.new(-50, 55, 7500),  -- Финал верхней стадии перед обрывом
    Vector3.new(-50, -10, 8500), -- КРИТИЧЕСКИЙ СПУСК: Уходим по высоте Y вниз под водопад
    Vector3.new(-60, -15, 9400), -- Залет прямо к сундуку в пещеру
}

task.spawn(function()
    while true do
        task.wait(1)
        if _G.AutoFarm and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = LocalPlayer.Character.HumanoidRootPart
            
            for _, stagePos in ipairs(FarmStages) do
                if not _G.AutoFarm then break end
                
                local distance = (hrp.Position - stagePos).Magnitude
                local speed = distance / (_G.FarmDuration / #FarmStages)
                
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                bv.Velocity = (stagePos - hrp.Position).Unit * speed
                bv.Parent = hrp
                
                while (hrp.Position - stagePos).Magnitude > 12 and _G.AutoFarm do
                    pcall(function()
                        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                            if part:IsA("BasePart") then part.CanCollide = false end
                        end
                    end)
                    task.wait(0.05)
                end
                bv:Destroy()
            end
            
            if _G.AutoFarm then
                task.wait(2.5) -- Тайм-аут на сбор награды из сундука
                if LocalPlayer.Character:FindFirstChild("Humanoid") then
                    LocalPlayer.Character.Humanoid:BreakJoints()
                end
                LocalPlayer.CharacterAdded:Wait()
                task.wait(1.2)
            end
        end
    end
end)

--===================================================================================--
-- [МОДУЛЬ 3: ДВИЖЕНИЯ И ЧИТЫ (FLY, NO-CLIP, BHOP)]
--===================================================================================--
RunService.Stepped:Connect(function()
    if (_G.NoClip or _G.Fly) and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if _G.Fly and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        local cf = Cam.CFrame
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cf.RightVector end
        hrp.Velocity = move * _G.FlySpeed
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if _G.BHop and input.KeyCode == Enum.KeyCode.Space then
        while UserInputService:IsKeyDown(Enum.KeyCode.Space) and _G.BHop do
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                local hum = LocalPlayer.Character.Humanoid
                if hum.FloorMaterial ~= Enum.Material.Air then
                    LocalPlayer.Character.HumanoidRootPart.Velocity = Vector3.new(LocalPlayer.Character.HumanoidRootPart.Velocity.X, _G.BhopJump, LocalPlayer.Character.HumanoidRootPart.Velocity.Z)
                    hum.WalkSpeed = _G.BhopSpeed
                end
            end
            task.wait(0.02)
        end
    end
end)
--===================================================================================--
--                             JYPX // V1.1 - BUILD A BOAT FOR TREASURE               --
--===================================================================================--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")

-- Проверка и создание папки для сохранений в файловой системе эксплоита
if not isfolder("jypxBuild") then
    makefolder("jypxBuild")
end

--===================================================================================--
-- [ГЛОБАЛЬНЫЕ НАСТРОЙКИ И ФЛАГИ СОСТОЯНИЯ ЧИТА]
--===================================================================================--
_G.Building = false
_G.BuildDelay = 0.05
_G.AutoFarm = false
_G.FarmDuration = 25 -- Оптимальное время пролета стадий в секундах
_G.NoClip = false
_G.Fly = false
_G.FlySpeed = 50
_G.BHop = false
_G.BhopSpeed = 25
_G.BhopJump = 40
_G.ESP_Enabled = false

local Cam = Workspace.CurrentCamera
local PreviewModel = nil

--===================================================================================--
-- [МОДУЛЬ 1: АВТО-БИЛД (ЛОГИКА И СЕРИАЛИЗАЦИЯ ДАННЫХ)]
--===================================================================================--

local function sanitizeCFrame(cf) return {cf:GetComponents()} end
local function toCFrame(tbl) return CFrame.new(unpack(tbl)) end
local function sanitizeColor(color) return {color.R, color.G, color.B} end

-- Функция экспорта (Safe Build)
local function safeBuild(fileName)
    local targetFolder = Workspace:FindFirstChild("jypxBuild") or Workspace.Plots:FindFirstChild(LocalPlayer.Name)
    if not targetFolder then return end
    local blocksData = {}
    for _, block in ipairs(targetFolder:GetDescendants()) do
        if block:IsA("BasePart") then
            pcall(function()
                table.insert(blocksData, {
                    ID = block:GetAttribute("BlockID") or block.Name,
                    Name = block.Name,
                    Position = sanitizeCFrame(block.CFrame),
                    Size = {block.Size.X, block.Size.Y, block.Size.Z},
                    Color = sanitizeColor(block.Color),
                    Transparency = block.Transparency,
                    Anchored = block.Anchored,
                    CanCollide = block.CanCollide
                })
            end)
        end
    end
    writefile("jypxBuild/" .. fileName .. ".build", HttpService:JSONEncode(blocksData))
end

-- Удаление старого превью
local function clearPreview()
    if PreviewModel then PreviewModel:Destroy() PreviewModel = nil end
end

-- Функция предпросмотра (Preview)
local function previewBuild(fileName)
    clearPreview()
    local success, content = pcall(function() return readfile("jypxBuild/" .. fileName .. ".build") end)
    if not success then return end
    local blocksData = HttpService:JSONDecode(content)
    PreviewModel = Instance.new("Model")
    PreviewModel.Name = "JYPX_Preview"
    PreviewModel.Parent = Workspace

    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(0, 255, 255)
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0.2
    hl.Parent = PreviewModel

    for _, data in ipairs(blocksData) do
        local part = Instance.new("Part")
        part.Size = Vector3.new(unpack(data.Size))
        part.CFrame = toCFrame(data.Position)
        part.Color = Color3.new(unpack(data.Color))
        part.Transparency = 0.5
        part.CanCollide = false
        part.Anchored = true
        part.Parent = PreviewModel
    end
end

-- Функция постройки (Build)
local function startBuild(fileName)
    _G.Building = true
    local success, content = pcall(function() return readfile("jypxBuild/" .. fileName .. ".build") end)
    if not success then _G.Building = false return end
    local blocksData = HttpService:JSONDecode(content)
    for _, data in ipairs(blocksData) do
        if not _G.Building then break end
        pcall(function()
            local part = Instance.new("Part")
            part.Name = data.Name
            part.Size = Vector3.new(unpack(data.Size))
            part.CFrame = toCFrame(data.Position)
            part.Color = Color3.new(unpack(data.Color))
            part.Transparency = data.Transparency
            part.CanCollide = data.CanCollide
            part.Anchored = data.Anchored
            part.Parent = Workspace.Plots:FindFirstChild(LocalPlayer.Name) or Workspace
        end)
        task.wait(_G.BuildDelay)
    end
    _G.Building = false
end

--===================================================================================--
-- [МОДУЛЬ 2: АВТОФАРМ С АВТО-СПУСКОМ ПОД ВОДОПАД]
--===================================================================================--
local FarmStages = {
    Vector3.new(-50, 55, 200),
    Vector3.new(-50, 55, 1000),
    Vector3.new(-50, 55, 2000),
    Vector3.new(-50, 55, 3000),
    Vector3.new(-50, 55, 4000),
    Vector3.new(-50, 55, 5000),
    Vector3.new(-50, 55, 6000),
    Vector3.new(-50, 55, 7500),  -- Финал верхней стадии перед обрывом
    Vector3.new(-50, -10, 8500), -- КРИТИЧЕСКИЙ СПУСК: Уходим по высоте Y вниз под водопад
    Vector3.new(-60, -15, 9400), -- Залет прямо к сундуку в пещеру
}

task.spawn(function()
    while true do
        task.wait(1)
        if _G.AutoFarm and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = LocalPlayer.Character.HumanoidRootPart
            
            for _, stagePos in ipairs(FarmStages) do
                if not _G.AutoFarm then break end
                
                local distance = (hrp.Position - stagePos).Magnitude
                local speed = distance / (_G.FarmDuration / #FarmStages)
                
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                bv.Velocity = (stagePos - hrp.Position).Unit * speed
                bv.Parent = hrp
                
                while (hrp.Position - stagePos).Magnitude > 12 and _G.AutoFarm do
                    pcall(function()
                        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                            if part:IsA("BasePart") then part.CanCollide = false end
                        end
                    end)
                    task.wait(0.05)
                end
                bv:Destroy()
            end
            
            if _G.AutoFarm then
                task.wait(2.5) -- Тайм-аут на сбор награды из сундука
                if LocalPlayer.Character:FindFirstChild("Humanoid") then
                    LocalPlayer.Character.Humanoid:BreakJoints()
                end
                LocalPlayer.CharacterAdded:Wait()
                task.wait(1.2)
            end
        end
    end
end)

--===================================================================================--
-- [МОДУЛЬ 3: ДВИЖЕНИЯ И ЧИТЫ (FLY, NO-CLIP, BHOP)]
--===================================================================================--
RunService.Stepped:Connect(function()
    if (_G.NoClip or _G.Fly) and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if _G.Fly and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        local cf = Cam.CFrame
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cf.RightVector end
        hrp.Velocity = move * _G.FlySpeed
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if _G.BHop and input.KeyCode == Enum.KeyCode.Space then
        while UserInputService:IsKeyDown(Enum.KeyCode.Space) and _G.BHop do
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                local hum = LocalPlayer.Character.Humanoid
                if hum.FloorMaterial ~= Enum.Material.Air then
                    LocalPlayer.Character.HumanoidRootPart.Velocity = Vector3.new(LocalPlayer.Character.HumanoidRootPart.Velocity.X, _G.BhopJump, LocalPlayer.Character.HumanoidRootPart.Velocity.Z)
                    hum.WalkSpeed = _G.BhopSpeed
                end
            end
            task.wait(0.02)
        end
    end
end)
--===================================================================================--
--                             JYPX // V1.1 - BUILD A BOAT FOR TREASURE               --
--===================================================================================--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")

-- Проверка и создание папки для сохранений в файловой системе эксплоита
if not isfolder("jypxBuild") then
    makefolder("jypxBuild")
end

--===================================================================================--
-- [ГЛОБАЛЬНЫЕ НАСТРОЙКИ И ФЛАГИ СОСТОЯНИЯ ЧИТА]
--===================================================================================--
_G.Building = false
_G.BuildDelay = 0.05
_G.AutoFarm = false
_G.FarmDuration = 25 -- Оптимальное время пролета стадий в секундах
_G.NoClip = false
_G.Fly = false
_G.FlySpeed = 50
_G.BHop = false
_G.BhopSpeed = 25
_G.BhopJump = 40
_G.ESP_Enabled = false

local Cam = Workspace.CurrentCamera
local PreviewModel = nil

--===================================================================================--
-- [МОДУЛЬ 1: АВТО-БИЛД (ЛОГИКА И СЕРИАЛИЗАЦИЯ ДАННЫХ)]
--===================================================================================--

local function sanitizeCFrame(cf) return {cf:GetComponents()} end
local function toCFrame(tbl) return CFrame.new(unpack(tbl)) end
local function sanitizeColor(color) return {color.R, color.G, color.B} end

-- Функция экспорта (Safe Build)
local function safeBuild(fileName)
    local targetFolder = Workspace:FindFirstChild("jypxBuild") or Workspace.Plots:FindFirstChild(LocalPlayer.Name)
    if not targetFolder then return end
    local blocksData = {}
    for _, block in ipairs(targetFolder:GetDescendants()) do
        if block:IsA("BasePart") then
            pcall(function()
                table.insert(blocksData, {
                    ID = block:GetAttribute("BlockID") or block.Name,
                    Name = block.Name,
                    Position = sanitizeCFrame(block.CFrame),
                    Size = {block.Size.X, block.Size.Y, block.Size.Z},
                    Color = sanitizeColor(block.Color),
                    Transparency = block.Transparency,
                    Anchored = block.Anchored,
                    CanCollide = block.CanCollide
                })
            end)
        end
    end
    writefile("jypxBuild/" .. fileName .. ".build", HttpService:JSONEncode(blocksData))
end

-- Удаление старого превью
local function clearPreview()
    if PreviewModel then PreviewModel:Destroy() PreviewModel = nil end
end

-- Функция предпросмотра (Preview)
local function previewBuild(fileName)
    clearPreview()
    local success, content = pcall(function() return readfile("jypxBuild/" .. fileName .. ".build") end)
    if not success then return end
    local blocksData = HttpService:JSONDecode(content)
    PreviewModel = Instance.new("Model")
    PreviewModel.Name = "JYPX_Preview"
    PreviewModel.Parent = Workspace

    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(0, 255, 255)
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0.2
    hl.Parent = PreviewModel

    for _, data in ipairs(blocksData) do
        local part = Instance.new("Part")
        part.Size = Vector3.new(unpack(data.Size))
        part.CFrame = toCFrame(data.Position)
        part.Color = Color3.new(unpack(data.Color))
        part.Transparency = 0.5
        part.CanCollide = false
        part.Anchored = true
        part.Parent = PreviewModel
    end
end

-- Функция постройки (Build)
local function startBuild(fileName)
    _G.Building = true
    local success, content = pcall(function() return readfile("jypxBuild/" .. fileName .. ".build") end)
    if not success then _G.Building = false return end
    local blocksData = HttpService:JSONDecode(content)
    for _, data in ipairs(blocksData) do
        if not _G.Building then break end
        pcall(function()
            local part = Instance.new("Part")
            part.Name = data.Name
            part.Size = Vector3.new(unpack(data.Size))
            part.CFrame = toCFrame(data.Position)
            part.Color = Color3.new(unpack(data.Color))
            part.Transparency = data.Transparency
            part.CanCollide = data.CanCollide
            part.Anchored = data.Anchored
            part.Parent = Workspace.Plots:FindFirstChild(LocalPlayer.Name) or Workspace
        end)
        task.wait(_G.BuildDelay)
    end
    _G.Building = false
end

--===================================================================================--
-- [МОДУЛЬ 2: АВТОФАРМ С АВТО-СПУСКОМ ПОД ВОДОПАД]
--===================================================================================--
local FarmStages = {
    Vector3.new(-50, 55, 200),
    Vector3.new(-50, 55, 1000),
    Vector3.new(-50, 55, 2000),
    Vector3.new(-50, 55, 3000),
    Vector3.new(-50, 55, 4000),
    Vector3.new(-50, 55, 5000),
    Vector3.new(-50, 55, 6000),
    Vector3.new(-50, 55, 7500),  -- Финал верхней стадии перед обрывом
    Vector3.new(-50, -10, 8500), -- КРИТИЧЕСКИЙ СПУСК: Уходим по высоте Y вниз под водопад
    Vector3.new(-60, -15, 9400), -- Залет прямо к сундуку в пещеру
}

task.spawn(function()
    while true do
        task.wait(1)
        if _G.AutoFarm and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = LocalPlayer.Character.HumanoidRootPart
            
            for _, stagePos in ipairs(FarmStages) do
                if not _G.AutoFarm then break end
                
                local distance = (hrp.Position - stagePos).Magnitude
                local speed = distance / (_G.FarmDuration / #FarmStages)
                
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                bv.Velocity = (stagePos - hrp.Position).Unit * speed
                bv.Parent = hrp
                
                while (hrp.Position - stagePos).Magnitude > 12 and _G.AutoFarm do
                    pcall(function()
                        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                            if part:IsA("BasePart") then part.CanCollide = false end
                        end
                    end)
                    task.wait(0.05)
                end
                bv:Destroy()
            end
            
            if _G.AutoFarm then
                task.wait(2.5) -- Тайм-аут на сбор награды из сундука
                if LocalPlayer.Character:FindFirstChild("Humanoid") then
                    LocalPlayer.Character.Humanoid:BreakJoints()
                end
                LocalPlayer.CharacterAdded:Wait()
                task.wait(1.2)
            end
        end
    end
end)

--===================================================================================--
-- [МОДУЛЬ 3: ДВИЖЕНИЯ И ЧИТЫ (FLY, NO-CLIP, BHOP)]
--===================================================================================--
RunService.Stepped:Connect(function()
    if (_G.NoClip or _G.Fly) and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if _G.Fly and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        local cf = Cam.CFrame
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cf.RightVector end
        hrp.Velocity = move * _G.FlySpeed
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if _G.BHop and input.KeyCode == Enum.KeyCode.Space then
        while UserInputService:IsKeyDown(Enum.KeyCode.Space) and _G.BHop do
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                local hum = LocalPlayer.Character.Humanoid
                if hum.FloorMaterial ~= Enum.Material.Air then
                    LocalPlayer.Character.HumanoidRootPart.Velocity = Vector3.new(LocalPlayer.Character.HumanoidRootPart.Velocity.X, _G.BhopJump, LocalPlayer.Character.HumanoidRootPart.Velocity.Z)
                    hum.WalkSpeed = _G.BhopSpeed
                end
            end
            task.wait(0.02)
        end
    end
end)
--===================================================================================--
-- [ЧАСТЬ 2: ГРАФИЧЕСКИЙ ИНТЕРФЕЙС JYPX // V1.1 С РЕЗАЙЗОМ И КНОПКОЙ СВЕРНУТЬ]
--===================================================================================--

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "JYPX_Hub_V11"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Главный фрейм
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 550, 0, 400)
MainFrame.Position = UDim2.new(0.3, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

-- Шапка панели
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text = "JYPX // V1.1"
TitleLabel.Size = UDim2.new(1, -80, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.BackgroundTransparency = 1
TitleLabel.Parent = TitleBar

-- Кнопка закрытия (X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "X"
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 2)
CloseBtn.TextColor3 = Color3.fromRGB(220, 60, 60)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 15
CloseBtn.Parent = TitleBar
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- Кнопка Свернуть/Развернуть (-)
local CollapseBtn = Instance.new("TextButton")
CollapseBtn.Text = "-"
CollapseBtn.Size = UDim2.new(0, 30, 0, 30)
CollapseBtn.Position = UDim2.new(1, -65, 0, 2)
CollapseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
CollapseBtn.BackgroundTransparency = 1
CollapseBtn.Font = Enum.Font.GothamBold
CollapseBtn.TextSize = 18
CollapseBtn.Parent = TitleBar

-- Левая панель вкладок (SideBar)
local SideBar = Instance.new("Frame")
SideBar.Size = UDim2.new(0, 120, 1, -35)
SideBar.Position = UDim2.new(0, 0, 0, 35)
SideBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
SideBar.BorderSizePixel = 0
SideBar.Parent = MainFrame

local SideCorner = Instance.new("UICorner")
SideCorner.CornerRadius = UDim.new(0, 6)
SideCorner.Parent = SideBar

local SideLayout = Instance.new("UIListLayout")
SideLayout.Padding = UDim.new(0, 5)
SideLayout.Parent = SideBar

-- Контейнер для отображения контента страниц
local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -125, 1, -45)
ContentFrame.Position = UDim2.new(0, 125, 0, 40)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

-- Уголок изменения размера (ResizeHandle)
local ResizeHandle = Instance.new("ImageLabel")
ResizeHandle.Size = UDim2.new(0, 15, 0, 15)
ResizeHandle.Position = UDim2.new(1, -15, 1, -15)
ResizeHandle.BackgroundTransparency = 1
ResizeHandle.Image = "rbxassetid://6031302941"
ResizeHandle.ImageColor3 = Color3.fromRGB(80, 80, 80)
ResizeHandle.ZIndex = 10
ResizeHandle.Active = true
ResizeHandle.Parent = MainFrame

-- Логика кнопки СВЕРНУТЬ (-) / РАЗВЕРНУТЬ (+)
local isCollapsed = false
local originalHeight = 400

CollapseBtn.MouseButton1Click:Connect(function()
    isCollapsed = not isCollapsed
    if isCollapsed then
        originalHeight = MainFrame.Size.Y.Offset
        MainFrame:TweenSize(UDim2.new(0, MainFrame.Size.X.Offset, 0, 35), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.25, true)
        SideBar.Visible = false
        ContentFrame.Visible = false
        ResizeHandle.Visible = false
        CollapseBtn.Text = "+"
    else
        MainFrame:TweenSize(UDim2.new(0, MainFrame.Size.X.Offset, 0, originalHeight), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.25, true)
        task.wait(0.1)
        SideBar.Visible = true
        ContentFrame.Visible = true
        ResizeHandle.Visible = true
        CollapseBtn.Text = "-"
    end
end)

-- Логика динамического изменения размера (Resize) за уголок
local isResizing = false
local startMousePos, startSize

ResizeHandle.InputBegan:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not isCollapsed then
        isResizing = true
        startMousePos = input.Position
        startSize = MainFrame.Size
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - startMousePos
        local newWidth = math.clamp(startSize.X.Offset + delta.X, 450, 900)
        local newHeight = math.clamp(startSize.Y.Offset + delta.Y, 300, 700)
        MainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = false
    end
end)

-- Конструктор закругленных кнопок
local function createButton(text, parent, callback)
    local btn = Instance.new("TextButton")
    btn.Text = text
    btn.Size = UDim2.new(1, -10, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    btn.TextColor3 = Color3.fromRGB(230, 230, 230)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.Parent = parent
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 5)
    btnCorner.Parent = btn
    
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- Создание страниц (ScrollingFrames)
local BuildPage = Instance.new("ScrollingFrame")
BuildPage.Size = UDim2.new(1, 0, 1, 0)
BuildPage.BackgroundTransparency = 1
BuildPage.CanvasSize = UDim2.new(0, 0, 1.2, 0)
BuildPage.Parent = ContentFrame

local BuildLayout = Instance.new("UIListLayout")
BuildLayout.Padding = UDim.new(0, 6)
BuildLayout.Parent = BuildPage

local ExploitsPage = Instance.new("ScrollingFrame")
ExploitsPage.Size = UDim2.new(1, 0, 1, 0)
ExploitsPage.BackgroundTransparency = 1
ExploitsPage.Visible = false
ExploitsPage.Parent = ContentFrame

local ExploitLayout = Instance.new("UIListLayout")
ExploitLayout.Padding = UDim.new(0, 6)
ExploitLayout.Parent = ExploitsPage

-- Наполнение элементами вкладки BUILD
createButton("Safe Build (Сохранить)", BuildPage, function() safeBuild("myship") end)
createButton("Preview (Предпросмотр)", BuildPage, function() previewBuild("myship") end)
createButton("Build (Начать постройку)", BuildPage, function() startBuild("myship") end)
createButton("Stop Build (Остановить)", BuildPage, function() _G.Building = false clearPreview() end)

-- Наполнение элементами вкладки EXPLOITS
createButton("Auto Farm: Переключить", ExploitsPage, function() _G.AutoFarm = not _G.AutoFarm end)
createButton("Fly & NoClip: Переключить", ExploitsPage, function() _G.Fly = not _G.Fly _G.NoClip = _G.Fly end)
createButton("BunnyHop: Переключить", ExploitsPage, function() _G.BHop = not _G.BHop end)

-- Логика переключения между главными вкладками меню
createButton("BUILD", SideBar, function() BuildPage.Visible = true ExploitsPage.Visible = false end)
createButton("EXPLOITS", SideBar, function() BuildPage.Visible = false ExploitsPage.Visible = true end)
