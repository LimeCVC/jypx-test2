--[[
    JYPX // V1.0
    Полная версия с рабочими вкладками
]]

-- ==================== ЧАСТЬ 1: ОКРУЖЕНИЕ И СЕРВИСЫ ====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ==================== ЧАСТЬ 2: РАБОТА С ФАЙЛАМИ ====================
local FOLDER_PATH = "jypxBuild"
local SETTINGS_PATH = FOLDER_PATH .. "/Settings.json"
local BUILD_SEARCH_PATHS = {
    FOLDER_PATH .. "/",
    "BABFT/",
    "BABFT/Build/",
    "Build/",
}

local function ensureFolder()
    if not isfolder(FOLDER_PATH) then
        makefolder(FOLDER_PATH)
    end
end
ensureFolder()

-- Настройки
local Settings = {
    previewTransparency = 0.5,
    guiTransparency = 0.15,
    autoPreview = true,
    showBlockCounts = true,
    uiScale = isMobile and 0.72 or 1.0,
    mobileMode = isMobile,
    buildScale = 1.0,
    buildOffsetX = 0,
    buildOffsetY = 0,
    buildOffsetZ = 0,
    infBlockEnabled = false,
    infBlockSlot1 = 2,
    infBlockSlot2 = 3,
    skyHeight = 500,
    saveFormat = "ASU",
    primaryColor = Color3.fromRGB(255, 255, 255),
    secondaryColor = Color3.fromRGB(120, 120, 120),
    uiMinimized = false,
    windowPosX = -1,
    windowPosY = -1,
    windowWidth = -1,
    windowHeight = -1,
    flySpeed = 50,
    bhopSpeed = 32,
    farmDuration = 30,
}

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

-- ==================== ЧАСТЬ 3: ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================
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

local function getBuildSearchPaths()
    local paths, seen = {}, {}
    for _, path in ipairs(BUILD_SEARCH_PATHS) do
        if not seen[path] then
            paths[#paths + 1] = path
            seen[path] = true
        end
    end
    if not seen[FOLDER_PATH .. "/"] then
        paths[#paths + 1] = FOLDER_PATH .. "/"
    end
    return paths
end

local function getBlockID(blockName)
    local data = LocalPlayer:FindFirstChild("Data")
    if data then
        local c = data:FindFirstChild(blockName)
        return c and c.Value or 0
    end
    return 0
end

local function getRealBlockCount(blockName)
    pcall(function()
        local bg = LocalPlayer.PlayerGui:FindFirstChild("BuildGui")
        if bg then
            local inv = bg:FindFirstChild("InventoryFrame")
            if inv then
                local sf = inv:FindFirstChild("ScrollingFrame")
                if sf then
                    local bf = sf:FindFirstChild(blockName)
                    if bf then
                        local at = bf:FindFirstChild("AmountText")
                        if at and at.Text then
                            return tonumber(at.Text) or 0
                        end
                    end
                end
            end
        end
    end)
    return getBlockID(blockName)
end

local function getPlayerZone(player)
    for _, zone in pairs(Workspace:GetChildren()) do
        if zone:FindFirstChild("TeamColor") and zone.TeamColor.Value == player.TeamColor then
            return zone
        end
    end
end

local function getPlayerList()
    local list = {}
    for _, p in pairs(Players:GetPlayers()) do
        local d = p.Name
        if p.DisplayName ~= p.Name then d = p.DisplayName .. " (" .. p.Name .. ")" end
        if p == LocalPlayer then d = d .. " [ME]" end
        table.insert(list, {name = p.Name, display = d})
    end
    return list
end

local function getSavedBuilds()
    ensureFolder()
    local builds, seen = {}, {}
    for _, root in ipairs(getBuildSearchPaths()) do
        if isfolder(root) then
            for _, fp in pairs(listfiles(root)) do
                local n = fp:match("([^/\\]+)%.Build$") or fp:match("([^/\\]+)%.build$")
                if n and not seen[n] then
                    table.insert(builds, n)
                    seen[n] = true
                end
            end
        end
    end
    table.sort(builds, function(a, b) return a:lower() < b:lower() end)
    return builds
end

local function trimStr(s)
    return tostring(s or ""):gsub("^%s*(.-)%s*$", "%1")
end

-- ==================== ЧАСТЬ 4: РАБОТА С ПОСТРОЙКАМИ ====================
local isBuilding = false
local stopBuild = false
local previewActive = false
local currentBuild = {}
local selectedObjectName = nil
local selectionBoxes = {}
local previewParts = {}

local PreviewFolder = Workspace:FindFirstChild("JYPX_Preview") or Instance.new("Folder")
PreviewFolder.Name = "JYPX_Preview"
PreviewFolder.Parent = Workspace

local StatusLabelRef = nil
local DupeInfoLabelRef = nil
local DupePercentLabelRef = nil
local ProgressBarFillRef = nil

local function clearPreview()
    for _, obj in pairs(PreviewFolder:GetChildren()) do
        obj:Destroy()
    end
    for _, b in pairs(selectionBoxes) do
        if b then pcall(function() b:Destroy() end) end
    end
    previewParts = {}
    selectionBoxes = {}
    previewActive = false
    if updatePreviewButtonGlobal then updatePreviewButtonGlobal() end
end

local function createPreview(buildData)
    clearPreview()
    if not buildData or #buildData == 0 then return false end

    local myZone = getPlayerZone(LocalPlayer)
    if not myZone then return false end

    local sc = Settings.buildScale
    local off = Vector3.new(Settings.buildOffsetX, Settings.buildOffsetY, Settings.buildOffsetZ)

    for _, blockData in ipairs(buildData) do
        local template = ReplicatedStorage:FindFirstChild("BuildingParts") and ReplicatedStorage.BuildingParts:FindFirstChild(blockData.Name)
        if not template then continue end

        local pb = template:Clone()
        local ppart = pb:FindFirstChild("PPart")
        if not ppart then continue end

        local cf
        if blockData.CFrame then
            cf = strCF(blockData.CFrame)
        elseif blockData.Position then
            local pos = strV3(blockData.Position)
            cf = CFrame.new(pos)
            if blockData.Rotation then
                local rot = strV3(blockData.Rotation)
                cf = cf * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
            end
        end

        if cf then
            local pos = (cf.Position * sc) + off
            local scaledCF = CFrame.new(pos) * (cf - cf.Position)
            ppart.CFrame = myZone.CFrame:ToWorldSpace(scaledCF)
        end

        if blockData.Size then ppart.Size = strV3(blockData.Size) * sc end
        if blockData.Color then ppart.Color = strCol(blockData.Color) end

        ppart.Transparency = Settings.previewTransparency
        ppart.CanCollide = false
        ppart.Anchored = true

        for _, d in pairs(pb:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("UnionOperation") then
                d.Transparency = Settings.previewTransparency
                d.CanCollide = false
                d.Anchored = true
            end
        end

        pb.Name = blockData.Name
        pb.Parent = PreviewFolder
        table.insert(previewParts, pb)
    end

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
    if updatePreviewButtonGlobal then updatePreviewButtonGlobal() end
    return true
end

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
            local ppart = block.PPart
            table.insert(buildData, {
                Name = block.Name,
                Position = v3Str(ppart.Position),
                Rotation = v3Str(ppart.Rotation),
                Size = v3Str(ppart.Size),
                Color = colStr(ppart.Color),
                Transparency = ppart.Transparency,
                Anchored = ppart.Anchored,
                CanCollide = ppart.CanCollide,
                CFrame = cfStr(ppart.CFrame),
            })
        end
    end

    if #buildData == 0 then return false, "No blocks found" end

    local json = HttpService:JSONEncode(buildData)
    pcall(function() writefile(FOLDER_PATH .. "/" .. fileName .. ".build", json) end)
    return true, "Build saved: " .. fileName
end

local function loadBuildFromFile(fileName)
    local json
    for _, root in ipairs(getBuildSearchPaths()) do
        local paths = {
            root .. fileName .. ".Build",
            root .. fileName .. ".build",
            root .. fileName,
        }
        for _, p in ipairs(paths) do
            if isfile(p) then
                json = readfile(p)
                break
            end
        end
        if json then break end
    end
    if not json then return nil, "File not found" end

    local data = pcall(function() return HttpService:JSONDecode(json) end)
    if not data or type(data) ~= "table" then return nil, "Invalid JSON" end

    return data, "Build loaded: " .. fileName
end

local function pasteBuild(buildData, statusCb)
    if isBuilding then return false end
    if not buildData or #buildData == 0 then return false end

    isBuilding = true
    stopBuild = false

    local total = #buildData
    local placed = 0

    local myZone = getPlayerZone(LocalPlayer)
    if not myZone then
        isBuilding = false
        return false, "Zone not found"
    end

    local placeTool = Character:FindFirstChild("BuildingTool")
    local placeRF = placeTool and placeTool:FindFirstChild("RF")
    local scaleTool = Character:FindFirstChild("ScalingTool")
    local scaleRF = scaleTool and scaleTool:FindFirstChild("RF")
    local paintTool = Character:FindFirstChild("PaintingTool")
    local paintRF = paintTool and paintTool:FindFirstChild("RF")
    local deleteTool = Character:FindFirstChild("DeleteTool") or Character:FindFirstChild("DeletingTool")
    local deleteRF = deleteTool and deleteTool:FindFirstChild("RF")
    local propertiesTool = Character:FindFirstChild("PropertiesTool")
    local propertiesRF = propertiesTool and propertiesTool:FindFirstChild("SetPropertieRF")

    if not placeRF then
        isBuilding = false
        return false, "BuildingTool not found"
    end

    local sc = Settings.buildScale
    local off = Vector3.new(Settings.buildOffsetX, Settings.buildOffsetY, Settings.buildOffsetZ)

    for i, blockData in ipairs(buildData) do
        if stopBuild then break end

        local template = ReplicatedStorage:FindFirstChild("BuildingParts") and ReplicatedStorage.BuildingParts:FindFirstChild(blockData.Name)
        if not template then continue end

        local cf
        if blockData.CFrame then
            cf = strCF(blockData.CFrame)
        elseif blockData.Position then
            local pos = strV3(blockData.Position)
            cf = CFrame.new(pos)
            if blockData.Rotation then
                local rot = strV3(blockData.Rotation)
                cf = cf * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
            end
        else
            continue
        end

        local pos = (cf.Position * sc) + off
        local scaledCF = CFrame.new(pos) * (cf - cf.Position)
        local worldCF = myZone.CFrame:ToWorldSpace(scaledCF)

        pcall(function()
            placeRF:InvokeServer(
                blockData.Name,
                getBlockID(blockData.Name),
                myZone,
                myZone.CFrame:ToObjectSpace(worldCF),
                true
            )
        end)

        placed = placed + 1
        if statusCb then
            statusCb("Building " .. placed .. "/" .. total, placed / total * 100)
        end

        task.wait(0.05)
    end

    isBuilding = false
    return true, "Built " .. placed .. " blocks"
end

-- ==================== ЧАСТЬ 5: ЭКСПЛОИТЫ ====================
local noclipActive = false
local flyActive = false
local bhopEnabled = false
local farmActive = false
local espEnabled = false
local noclipConn = nil
local flyConn = nil
local flyBV = nil
local bhopConn = nil
local bhopKeys = {W = 0, S = 0, D = 0, A = 0, Space = 0}

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

local function initBhop()
    if bhopConn then return end

    UserInputService.InputBegan:Connect(function(inp)
        if inp.KeyCode and bhopKeys[inp.KeyCode.Name] ~= nil then
            bhopKeys[inp.KeyCode.Name] = 1
        end
    end)

    UserInputService.InputEnded:Connect(function(inp)
        if inp.KeyCode and bhopKeys[inp.KeyCode.Name] ~= nil then
            bhopKeys[inp.KeyCode.Name] = 0
        end
    end)

    bhopConn = RunService.RenderStepped:Connect(function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end

        if bhopKeys.Space > 0 and humanoid:GetState() == Enum.HumanoidStateType.Landed then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end

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

-- ==================== ЧАСТЬ 6: UI ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "JYPX_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

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

local function stylizeObject(obj, bgColor)
    obj.BackgroundColor3 = bgColor or Colors.Panel
    obj.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = obj
    return obj
end

-- ==================== ГЛАВНОЕ ОКНО ====================
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
local baseWidth = 640
local baseHeight = 420
local currentScale = Settings.uiScale
MainFrame.Size = UDim2.new(0, baseWidth * currentScale, 0, baseHeight * currentScale)
MainFrame.Position = UDim2.new(0.5, -(baseWidth * currentScale) / 2, 0.5, -(baseHeight * currentScale) / 2)
MainFrame.BackgroundColor3 = Colors.BG
MainFrame.BackgroundTransparency = Settings.guiTransparency
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Parent = ScreenGui
stylizeObject(MainFrame, Colors.BG)

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Colors.Border
mainStroke.Transparency = 0.4
mainStroke.Thickness = 1
mainStroke.Parent = MainFrame

-- ==================== ШАПКА ====================
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 44)
Header.BackgroundColor3 = Colors.PanelElevated
Header.BackgroundTransparency = 0.1
Header.BorderSizePixel = 0
Header.ZIndex = 2
Header.Parent = MainFrame
stylizeObject(Header, Colors.PanelElevated)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.6, 0, 0, 24)
Title.Position = UDim2.new(0, 14, 0, 10)
Title.BackgroundTransparency = 1
Title.Text = "JYPX // V1.0"
Title.TextColor3 = Colors.Text
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 3
Title.Parent = Header

-- Кнопка свернуть
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -68, 0.5, -14)
MinBtn.BackgroundColor3 = Colors.Panel
MinBtn.BorderSizePixel = 0
MinBtn.Text = "-"
MinBtn.TextColor3 = Colors.Text
MinBtn.TextSize = 16
MinBtn.Font = Enum.Font.GothamBold
MinBtn.ZIndex = 4
MinBtn.Parent = Header
stylizeObject(MinBtn, Colors.Panel)

-- Кнопка закрытия
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -14)
CloseBtn.BackgroundColor3 = Colors.Panel
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Colors.Text
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.ZIndex = 4
CloseBtn.Parent = Header
stylizeObject(CloseBtn, Colors.Panel)

local isMinimized = Settings.uiMinimized or false

MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    Settings.uiMinimized = isMinimized
    MinBtn.Text = isMinimized and "+" or "-"

    local targetH = isMinimized and 44 or baseHeight * currentScale
    TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, baseWidth * currentScale, 0, targetH)
    }):Play()

    for _, child in pairs(MainFrame:GetChildren()) do
        if child ~= Header and child ~= mainStroke then
            child.Visible = not isMinimized
        end
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- ==================== РЕСАЙЗ ====================
local ResizeHandle = Instance.new("TextButton")
ResizeHandle.Name = "ResizeHandle"
ResizeHandle.Size = UDim2.new(0, 20, 0, 20)
ResizeHandle.Position = UDim2.new(1, -22, 1, -22)
ResizeHandle.BackgroundTransparency = 1
ResizeHandle.Text = ""
ResizeHandle.ZIndex = 100
ResizeHandle.Parent = MainFrame

local resizeIcon = Instance.new("Frame")
resizeIcon.Size = UDim2.new(0, 12, 0, 12)
resizeIcon.Position = UDim2.new(0, 2, 0, 2)
resizeIcon.BackgroundTransparency = 1
resizeIcon.Parent = ResizeHandle

for i = 1, 3 do
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0, 8 - (i - 1) * 2, 0, 1)
    line.Position = UDim2.new(0, (i - 1) * 2, 0, 8 - (i - 1) * 3)
    line.Rotation = -45
    line.BackgroundColor3 = Colors.Muted
    line.BackgroundTransparency = 0.5
    line.BorderSizePixel = 0
    line.Parent = resizeIcon
end

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
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = false
    end
end)

-- ==================== ЛЕВАЯ ПАНЕЛЬ ====================
local TabsBar = Instance.new("Frame")
TabsBar.Size = UDim2.new(0, 100, 1, -60)
TabsBar.Position = UDim2.new(0, 10, 0, 54)
TabsBar.BackgroundColor3 = Colors.PanelSoft
TabsBar.BackgroundTransparency = 0.1
TabsBar.BorderSizePixel = 0
TabsBar.ClipsDescendants = true
TabsBar.Parent = MainFrame
stylizeObject(TabsBar, Colors.PanelSoft)

local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Vertical
tabsLayout.Padding = UDim.new(0, 4)
tabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabsLayout.Parent = TabsBar

local tabsPad = Instance.new("UIPadding")
tabsPad.PaddingTop = UDim.new(0, 6)
tabsPad.PaddingBottom = UDim.new(0, 6)
tabsPad.Parent = TabsBar

-- ==================== КОНТЕНТ ====================
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -120, 1, -60)
ContentArea.Position = UDim2.new(0, 114, 0, 54)
ContentArea.BackgroundTransparency = 1
ContentArea.ClipsDescendants = true
ContentArea.Parent = MainFrame

-- ==================== СОЗДАНИЕ ВКЛАДОК ====================
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
    stylizeObject(btn, Colors.PanelElevated)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Colors.Border
    stroke.Transparency = 0.4
    stroke.Thickness = 1
    stroke.Parent = btn

    local frame = Instance.new("ScrollingFrame")
    frame.Name = name .. "Frame"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.ClipsDescendants = true
    frame.ScrollBarThickness = 4
    frame.ScrollBarImageColor3 = Colors.Muted
    frame.CanvasSize = UDim2.new(0, 0, 0, 0)
    frame.Visible = false
    frame.Parent = ContentArea

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        frame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)

    btn.MouseButton1Click:Connect(function()
        for _, child in pairs(ContentArea:GetChildren()) do
            if child:IsA("ScrollingFrame") then
                child.Visible = false
            end
        end
        for _, child in pairs(TabsBar:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = Colors.PanelElevated
                child.BackgroundTransparency = 0.1
                child.TextColor3 = Colors.Muted
            end
        end
        frame.Visible = true
        btn.BackgroundColor3 = Colors.ActiveBG
        btn.BackgroundTransparency = 0
        btn.TextColor3 = Colors.ActiveText
    end)

    return btn, frame, layout
end

-- Создаем вкладки (только BUILD, EXPLOITS, SETTINGS)
local buildBtn, buildFrame, buildLayout = createTab("Build", "BUILD")
local exploitsBtn, exploitsFrame, exploitsLayout = createTab("Exploits", "EXPLOITS")
local settingsBtn, settingsFrame, settingsLayout = createTab("Settings", "SETTINGS")

-- ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ДЛЯ UI ====================
local function createLabel(text, parent)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 24)
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
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Colors.PanelElevated
    btn.BackgroundTransparency = 0
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Colors.Text
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = parent
    stylizeObject(btn, Colors.PanelElevated)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Colors.Border
    stroke.Transparency = 0.4
    stroke.Thickness = 1
    stroke.Parent = btn

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
    stylizeObject(inp, Colors.PanelSoft)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Colors.Border
    stroke.Transparency = 0.4
    stroke.Thickness = 1
    stroke.Parent = inp

    inp.FocusLost:Connect(function()
        if callback then callback(inp.Text) end
    end)

    return inp
end

local function createSlider(label, minVal, maxVal, defaultVal, parent, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 48)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.45, 0, 0, 22)
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label .. ": " .. tostring(defaultVal)
    lbl.TextColor3 = Colors.Muted
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.15, 0, 0, 22)
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
    slider.Position = UDim2.new(0, 0, 0, 28)
    slider.BackgroundColor3 = Colors.PanelElevated
    slider.BorderSizePixel = 0
    slider.Parent = container
    stylizeObject(slider, Colors.PanelElevated)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = Colors.ActiveBG
    fill.BorderSizePixel = 0
    fill.Parent = slider
    stylizeObject(fill, Colors.ActiveBG)

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

local function createDropdown(name, getOpts, parent, cb)
    local closedH = 34
    local df = Instance.new("Frame")
    df.Name = name .. "DF"
    df.Size = UDim2.new(1, 0, 0, closedH)
    df.BackgroundColor3 = Colors.PanelSoft
    df.BackgroundTransparency = 0
    df.BorderSizePixel = 0
    df.ZIndex = 10
    df.Parent = parent
    stylizeObject(df, Colors.PanelSoft)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Colors.Border
    stroke.Transparency = 0.4
    stroke.Thickness = 1
    stroke.Parent = df

    local dbtn = Instance.new("TextButton")
    dbtn.Name = name
    dbtn.Size = UDim2.new(1, -30, 1, 0)
    dbtn.Position = UDim2.new(0, 8, 0, 0)
    dbtn.BackgroundTransparency = 1
    dbtn.Text = "Select..."
    dbtn.TextColor3 = Colors.Muted
    dbtn.TextSize = 12
    dbtn.Font = Enum.Font.Gotham
    dbtn.TextXAlignment = Enum.TextXAlignment.Left
    dbtn.ZIndex = 203
    dbtn.Parent = df

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 20, 1, 0)
    arrow.Position = UDim2.new(1, -24, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▼"
    arrow.TextColor3 = Colors.Muted
    arrow.TextSize = 12
    arrow.Font = Enum.Font.GothamBold
    arrow.ZIndex = 203
    arrow.Parent = df

    return dbtn, function() end
end

-- ==================== НАПОЛНЕНИЕ ВКЛАДКИ BUILD ====================
createLabel("BUILD CONTROLS", buildFrame)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 30)
statusLabel.BackgroundColor3 = Colors.PanelSoft
statusLabel.BackgroundTransparency = 0
statusLabel.BorderSizePixel = 0
statusLabel.Text = "  Ready"
statusLabel.TextColor3 = Colors.Text
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.GothamSemibold
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = buildFrame
stylizeObject(statusLabel, Colors.PanelSoft)
StatusLabelRef = statusLabel

createLabel("FILE NAME", buildFrame)
local fileInput = createInput("Enter file name...", buildFrame)

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

createLabel("BUILD SETTINGS", buildFrame)

local bsInput = createInput("Build Scale (1.0)", buildFrame)
bsInput.Text = tostring(Settings.buildScale)
bsInput.FocusLost:Connect(function()
    local v = tonumber(bsInput.Text)
    if v and v >= 0.01 and v <= 20 then
        Settings.buildScale = v
        if previewActive then createPreview(currentBuild) end
    else
        bsInput.Text = tostring(Settings.buildScale)
    end
end)

-- ==================== НАПОЛНЕНИЕ ВКЛАДКИ EXPLOITS ====================
createLabel("EXPLOITS", exploitsFrame)

-- Под-вкладки
local subTabsBar = Instance.new("Frame")
subTabsBar.Name = "subTabsBar"
subTabsBar.Size = UDim2.new(1, 0, 0, 32)
subTabsBar.BackgroundTransparency = 1
subTabsBar.Parent = exploitsFrame

local subTabsLayout = Instance.new("UIListLayout")
subTabsLayout.FillDirection = Enum.FillDirection.Horizontal
subTabsLayout.Padding = UDim.new(0, 2)
subTabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
subTabsLayout.Parent = subTabsBar

local subContent = Instance.new("Frame")
subContent.Name = "subContent"
subContent.Size = UDim2.new(1, 0, 1, -38)
subContent.Position = UDim2.new(0, 0, 0, 38)
subContent.BackgroundTransparency = 1
subContent.ClipsDescendants = true
subContent.Parent = exploitsFrame

local function createSubTab(label)
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
    stylizeObject(btn, Colors.PanelSoft)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Colors.Border
    stroke.Transparency = 0.4
    stroke.Thickness = 1
    stroke.Parent = btn

    local container = Instance.new("ScrollingFrame")
    container.Size = UDim2.new(1, 0, 1, 0)
    container.BackgroundTransparency = 1
    container.ClipsDescendants = true
    container.ScrollBarThickness = 4
    container.ScrollBarImageColor3 = Colors.Muted
    container.CanvasSize = UDim2.new(0, 0, 0, 0)
    container.Visible = false
    container.Parent = subContent

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.Parent = container

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = container

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        container.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)

    btn.MouseButton1Click:Connect(function()
        for _, child in pairs(subTabsBar:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = Colors.PanelSoft
                child.TextColor3 = Colors.Muted
            end
        end
        for _, child in pairs(subContent:GetChildren()) do
            if child:IsA("ScrollingFrame") then
                child.Visible = false
            end
        end
        btn.BackgroundColor3 = Colors.ActiveBG
        btn.TextColor3 = Colors.ActiveText
        container.Visible = true
    end)

    return btn, container
end

-- Создаем под-вкладки
local infBtn, infContainer = createSubTab("INF")
local miscBtn, miscContainer = createSubTab("MISC")
local moveBtn, moveContainer = createSubTab("MOVE")
local visualBtn, visualContainer = createSubTab("VISUAL")

-- Активируем первую под-вкладку
infBtn.MouseButton1Click:Fire()

-- INF под-вкладка
createLabel("INF BLOCK", infContainer)
local infToggle = createButton("Inf Block: OFF", infContainer, function()
    Settings.infBlockEnabled = not Settings.infBlockEnabled
    infToggle.Text = "Inf Block: " .. (Settings.infBlockEnabled and "ON" or "OFF")
    infToggle.BackgroundColor3 = Settings.infBlockEnabled and Color3.fromRGB(16, 32, 16) or Colors.PanelElevated
end)
infToggle.BackgroundColor3 = Settings.infBlockEnabled and Color3.fromRGB(16, 32, 16) or Colors.PanelElevated

-- MISC под-вкладка
createLabel("SHOP", miscContainer)
createButton("Buy Pine Tree", miscContainer, function()
    pcall(function() Workspace.ItemBoughtFromShop:InvokeServer("PineTree", 1) end)
end)
createButton("Buy Dragon Harpoon", miscContainer, function()
    pcall(function() Workspace.PromptRobuxEvent:InvokeServer(1109792341, "Product") end)
end)
createButton("Buy Cookie Wheels", miscContainer, function()
    pcall(function() Workspace.PromptRobuxEvent:InvokeServer(1126385328, "Product") end)
end)

createLabel("TELEPORTS", miscContainer)
createButton("Easter Event", miscContainer, function()
    pcall(function() TeleportService:Teleport(1930863474) end)
end)
createButton("Christmas Event", miscContainer, function()
    pcall(function() TeleportService:Teleport(1930866268) end)
end)

createLabel("AUTO FARM", miscContainer)
local farmToggle = createButton("Auto Farm: OFF", miscContainer, function()
    farmActive = not farmActive
    farmToggle.Text = "Auto Farm: " .. (farmActive and "ON" or "OFF")
    farmToggle.BackgroundColor3 = farmActive and Color3.fromRGB(16, 32, 16) or Colors.PanelElevated

    if farmActive then
        task.spawn(function()
            local stages = Workspace:FindFirstChild("BoatStages")
            if not stages then return end
            local normalStages = stages:FindFirstChild("NormalStages")
            if not normalStages then return end
            local theEnd = normalStages:FindFirstChild("TheEnd")
            local trigger = theEnd and theEnd:FindFirstChild("GoldenChest") and theEnd.GoldenChest:FindFirstChild("Trigger")
            if not trigger then return end

            local duration = Settings.farmDuration or 30
            local runs = 0

            while farmActive do
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then task.wait(1) continue end

                local startPos = hrp.Position
                local endPos = trigger.Position + Vector3.new(0, 5, 0)
                local startTime = tick()

                while tick() - startTime < duration and farmActive do
                    local progress = (tick() - startTime) / duration
                    local targetPos = startPos:lerp(endPos, progress)
                    hrp.CFrame = CFrame.new(targetPos)
                    task.wait(0.05)
                end

                hrp.CFrame = trigger.CFrame * CFrame.new(0, 2, 0)
                task.wait(0.5)
                pcall(function() firetouchinterest(hrp, trigger, 0) end)
                task.wait()
                pcall(function() firetouchinterest(hrp, trigger, 1) end)

                local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid.Health = 0 end
                runs = runs + 1
                task.wait(3)
            end
        end)
    end
end)

-- MOVE под-вкладка
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

-- VISUAL под-вкладка
createLabel("VISUAL", visualContainer)

local espBtn = createButton("ESP: OFF", visualContainer, function()
    espEnabled = not espEnabled
    espBtn.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
    espBtn.BackgroundColor3 = espEnabled and Color3.fromRGB(16, 32, 16) or Colors.PanelElevated

    if espEnabled then
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

-- ==================== НАПОЛНЕНИЕ ВКЛАДКИ SETTINGS ====================
createLabel("UI SETTINGS", settingsFrame)

local autoPreviewBtn = createButton("Auto Preview: " .. (Settings.autoPreview and "ON" or "OFF"), settingsFrame, function()
    Settings.autoPreview = not Settings.autoPreview
    autoPreviewBtn.Text = "Auto Preview: " .. (Settings.autoPreview and "ON" or "OFF")
    autoPreviewBtn.BackgroundColor3 = Settings.autoPreview and Color3.fromRGB(16, 32, 16) or Colors.PanelElevated
end)
autoPreviewBtn.BackgroundColor3 = Settings.autoPreview and Color3.fromRGB(16, 32, 16) or Colors.PanelElevated

createSlider("UI Scale", 0.5, 2.0, Settings.uiScale, settingsFrame, function(value)
    Settings.uiScale = value
    currentScale = value
    MainFrame.Size = UDim2.new(0, baseWidth * value, 0, isMinimized and 44 or baseHeight * value)
    MainFrame.Position = UDim2.new(0.5, -(baseWidth * value) / 2, 0.5, -(baseHeight * value) / 2)
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

createSlider("Sky Height", 0, 10000, Settings.skyHeight, settingsFrame, function(value)
    Settings.skyHeight = math.floor(value)
end)

createLabel("SAVE SETTINGS", settingsFrame)
createButton("Save All Settings", settingsFrame, function()
    saveSettings()
    statusLabel.Text = "  Settings saved"
end)

-- ==================== АКТИВАЦИЯ ====================
buildBtn.MouseButton1Click:Fire()

LocalPlayer.CharacterAdded:Connect(function()
    clearPreview()
end)

task.spawn(function()
    while true do
        task.wait(60)
        pcall(saveSettings)
    end
end)

print("JYPX // V1.0 loaded successfully!")
