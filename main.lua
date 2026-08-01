Я создам обновленную версию скрипта с заменой всех упоминаний SoPeRa_Builds на JYPX Builds и версией 2.1.

```lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local bit = bit32

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local BlocksFolder = Workspace:WaitForChild("Blocks")
local BlockData = LocalPlayer:WaitForChild("Data")
local BuildingParts = ReplicatedStorage:WaitForChild("BuildingParts")

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local FOLDER_PATH = "JYPX Builds"
local FOLDER_PREFIX = FOLDER_PATH .. "/"
local SETTINGS_PATH = "JYPX_Settings.json"
local CUSTOM_SCRIPTS_PATH = "JYPX_CustomScripts.json"
local BUILD_SEARCH_PATHS = {
    FOLDER_PREFIX,
    "JYPX Builds/",
}

local PreviewFolder = Workspace:FindFirstChild("JYPX_Preview") or Instance.new("Folder")
PreviewFolder.Name = "JYPX_Preview"
PreviewFolder.Parent = Workspace

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
}

local selectedPlayer = nil
local currentBuild = {}
local isBuilding = false
local stopBuild = false
local previewActive = false
local selectedObjectName = nil
local previewParts = {}
local selectionBoxes = {}

local updatePreviewButtonGlobal = nil
local updateBlocksDisplayGlobal = nil
local StatusLabelRef = nil
local MiscStatusLabelRef = nil
local InfProgressLabelRef = nil
local InfProgressFillRef = nil
local ProgressBarFillRef = nil
local DupeInfoLabelRef = nil
local DupePercentLabelRef = nil

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
    AccentSoft = Color3.fromRGB(180, 180, 180),
    AccentGlow = Color3.fromRGB(235, 235, 235),
}

local UISoundConfig = {
    volume = 0.45,
    click = "rbxassetid://6026984224",
    open = "rbxassetid://6026984224",
    close = "rbxassetid://6026984255",
}

local function syncColors()
    Colors.Border = Settings.secondaryColor
    Colors.Text = Settings.primaryColor
    Colors.ActiveBG = Settings.primaryColor
    Colors.ActiveText = Color3.new(
        1 - Settings.primaryColor.R * 0.92,
        1 - Settings.primaryColor.G * 0.92,
        1 - Settings.primaryColor.B * 0.92
    )
    Colors.Muted = Settings.secondaryColor:Lerp(Color3.fromRGB(255, 255, 255), 0.18)
    Colors.AccentSoft = Settings.secondaryColor:Lerp(Settings.primaryColor, 0.4)
    Colors.AccentGlow = Settings.primaryColor:Lerp(Color3.fromRGB(255, 255, 255), 0.28)
end

local function playUISound(soundId)
    if not soundId or soundId == "" then return end
    task.spawn(function()
        local s = Instance.new("Sound")
        s.SoundId = soundId
        s.Volume = UISoundConfig.volume
        s.Parent = SoundService
        s.Ended:Connect(function()
            s:Destroy()
        end)
        pcall(function() s:Play() end)
        task.delay(2, function()
            if s and s.Parent then s:Destroy() end
        end)
    end)
end

local function ensureFolder()
    if isfolder(FOLDER_PATH) then
        return
    end
    makefolder(FOLDER_PATH)
end

local function getBuildSearchPaths()
    local paths, seen = {}, {}
    for _, path in ipairs(BUILD_SEARCH_PATHS) do
        if not seen[path] then
            paths[#paths + 1] = path
            seen[path] = true
        end
    end
    if not seen[FOLDER_PREFIX] then
        paths[#paths + 1] = FOLDER_PREFIX
    end
    return paths
end

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

local function saveSettings()
    local d = {}
    for k, v in pairs(Settings) do
        if type(v) == "userdata" then
            d[k] = {R=v.R, G=v.G, B=v.B}
        else
            d[k] = v
        end
    end
    writefile(SETTINGS_PATH, HttpService:JSONEncode(d))
end

local function loadCustomScripts()
    if not isfile(CUSTOM_SCRIPTS_PATH) then return {windows={}} end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CUSTOM_SCRIPTS_PATH)) end)
    return (ok and data and data.windows) and data or {windows={}}
end

local function saveCustomScripts(data)
    writefile(CUSTOM_SCRIPTS_PATH, HttpService:JSONEncode(data or {windows={}}))
end

local function getBlockID(blockName)
    local c = BlockData:FindFirstChild(blockName)
    return c and c.Value or 0
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
        table.insert(list, {name=p.Name, display=d})
    end
    return list
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

local function v3Str(v) return string.format("%.4f,%.4f,%.4f", v.X, v.Y, v.Z) end
local function strV3(s)
    local c = {}
    for v in s:gmatch("[^,]+") do table.insert(c, tonumber(v) or 0) end
    return #c >= 3 and Vector3.new(c[1],c[2],c[3]) or Vector3.new(0,0,0)
end

local function colStr(c) return string.format("%.4f,%.4f,%.4f", c.R, c.G, c.B) end
local function strCol(s)
    local c = {}
    for v in s:gmatch("[^,]+") do table.insert(c, tonumber(v) or 1) end
    return #c >= 3 and Color3.new(math.clamp(c[1],0,1), math.clamp(c[2],0,1), math.clamp(c[3],0,1)) or Color3.new(1,1,1)
end

local function parseNums(s)
    if type(s) ~= "string" then return {} end
    local r = {}
    for p in s:gmatch("[^,%s]+") do
        local n = tonumber(p)
        if n then table.insert(r, n) end
    end
    return r
end

local function parseColorRGBA(rgba)
    if type(rgba) ~= "table" then return "1.000000, 1.000000, 1.000000" end
    local r = (tonumber(rgba[1]) or 255) / 255
    local g = (tonumber(rgba[2]) or 255) / 255
    local b = (tonumber(rgba[3]) or 255) / 255
    return string.format("%.6f, %.6f, %.6f", math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
end

local function geomGetAABB(shape)
    if type(shape) ~= "table" then return nil end
    local t = tonumber(shape.type) or -1
    local d = shape.data
    if type(d) ~= "table" then return nil end
    local function min(a, b) return (a < b) and a or b end
    local function max(a, b) return (a > b) and a or b end
    if (t == 0 or t == 2) and #d >= 4 then
        local x0, y0, x1, y1 = d[1], d[2], d[3], d[4]
        return {min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)}
    elseif t == 1 and #d >= 5 then
        local x0, y0, x1, y1, ang = d[1], d[2], d[3], d[4], d[5]
        local cx = (x0 + x1) / 2
        local cy = (y0 + y1) / 2
        local rx = math.abs(x1 - x0) / 2
        local ry = math.abs(y1 - y0) / 2
        local rad = math.rad(ang)
        local hw = math.sqrt((rx * math.cos(rad)) ^ 2 + (ry * math.sin(rad)) ^ 2)
        local hh = math.sqrt((rx * math.sin(rad)) ^ 2 + (ry * math.cos(rad)) ^ 2)
        return {cx - hw, cy - hh, cx + hw, cy + hh}
    elseif t == 3 and #d >= 3 then
        local cx, cy, r = d[1], d[2], d[3]
        return {cx - r, cy - r, cx + r, cy + r}
    elseif t == 4 and #d >= 6 then
        local xs = {d[1], d[3], d[5]}
        local ys = {d[2], d[4], d[6]}
        local xMin, xMax = xs[1], xs[1]
        local yMin, yMax = ys[1], ys[1]
        for i = 2, 3 do
            xMin = min(xMin, xs[i]); xMax = max(xMax, xs[i])
            yMin = min(yMin, ys[i]); yMax = max(yMax, ys[i])
        end
        return {xMin, yMin, xMax, yMax}
    elseif t == 5 and #d >= 4 then
        local x0, y0, x1, y1 = d[1], d[2], d[3], d[4]
        local lw = tonumber(d[5]) or 1
        local half = lw / 2
        return {min(x0, x1) - half, min(y0, y1) - half, max(x0, x1) + half, max(y0, y1) + half}
    end
    return nil
end

local function geomAABBIntersects(a, b)
    return not (a[3] <= b[1] or b[3] <= a[1] or a[4] <= b[2] or b[4] <= a[2])
end

local function geomComputeZPositions(shapes, thickness)
    local step = thickness
    local placed = {}
    local results = {}
    for i, shape in ipairs(shapes) do
        local aabb = geomGetAABB(shape)
        if not aabb then
            results[i] = 0
        else
            local maxZ = -step
            for _, prev in ipairs(placed) do
                local prevAABB, prevZ = prev[1], prev[2]
                if geomAABBIntersects(aabb, prevAABB) then
                    if prevZ > maxZ then maxZ = prevZ end
                end
            end
            local z = maxZ + step
            results[i] = z
            placed[#placed + 1] = {aabb, z}
        end
    end
    return results
end

local function geomMakeBlock(cx, cy, zPos, w, h, thickness, rotZ, colorStr, transparency, blockId)
    return {
        ShowShadow = true,
        CanCollide = true,
        Color = colorStr,
        Anchored = true,
        BoolValues = {},
        Rotation = string.format("0.000, 0.000, %.3f", -rotZ),
        Transparency = transparency,
        Position = string.format("%.6f, %.6f, %.6f", cx, -cy, zPos + thickness / 2),
        ID = blockId,
        NumberValues = {},
        Size = string.format("%.6f, %.6f, %.6f", w, h, thickness),
    }
end

local function geomGetBounds(shapes)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local function addPoint(x, y)
        x, y = tonumber(x), tonumber(y)
        if not x or not y then return end
        minX = math.min(minX, x)
        minY = math.min(minY, y)
        maxX = math.max(maxX, x)
        maxY = math.max(maxY, y)
    end

    for _, shape in ipairs(shapes) do
        if type(shape) == "table" and type(shape.data) == "table" then
            local stype = tonumber(shape.type) or -1
            local data = shape.data
            if (stype == 0 or stype == 1 or stype == 2) and #data >= 4 then
                addPoint(data[1], data[2])
                addPoint(data[3], data[4])
            elseif stype == 3 and #data >= 3 then
                local x, y, r = tonumber(data[1]), tonumber(data[2]), tonumber(data[3]) or 0
                if x and y then
                    addPoint(x - r, y - r)
                    addPoint(x + r, y + r)
                end
            elseif stype == 4 and #data >= 6 then
                addPoint(data[1], data[2])
                addPoint(data[3], data[4])
                addPoint(data[5], data[6])
            elseif stype == 5 and #data >= 4 then
                addPoint(data[1], data[2])
                addPoint(data[3], data[4])
            end
        end
    end

    if minX == math.huge then return nil end
    return minX, minY, maxX, maxY
end

local function convertGeometrizeJsonToBlocks(jsonText, scale, thickness, material, targetWidth, targetLength)
    local shapes = HttpService:JSONDecode(jsonText)
    if type(shapes) ~= "table" then return nil, nil, "Invalid JSON" end
    scale = tonumber(scale) or 0.035
    thickness = tonumber(thickness) or 0.001
    if scale <= 0 or thickness <= 0 then return nil, nil, "Scale/thickness must be > 0" end
    material = tostring(material or "PlasticBlock")
    targetWidth = tonumber(targetWidth) or 0
    targetLength = tonumber(targetLength) or 0

    local scaleX, scaleY = scale, scale
    if targetWidth > 0 or targetLength > 0 then
        local minX, minY, maxX, maxY = geomGetBounds(shapes)
        if minX then
            local rawW = math.max(0.001, maxX - minX)
            local rawH = math.max(0.001, maxY - minY)
            if targetWidth > 0 then scaleX = targetWidth / rawW end
            if targetLength > 0 then scaleY = targetLength / rawH end
        end
    end

    local zPositions = geomComputeZPositions(shapes, thickness)
    local blocks = {}
    local currentId = 1

    for i, shape in ipairs(shapes) do
        if type(shape) ~= "table" then continue end
        local stype = tonumber(shape.type) or -1
        local data = shape.data
        local color = shape.color
        if type(data) ~= "table" then continue end

        local transparency = 0
        local colorStr = parseColorRGBA(color)
        local layerZ = zPositions[i] or 0

        if stype == 1 and #data >= 5 then
            local x0, y0, x1, y1, angle = data[1], data[2], data[3], data[4], data[5]
            local cx = (x0 + x1) / 2 * scaleX
            local cy = (y0 + y1) / 2 * scaleY
            local w = math.abs(x1 - x0) * scaleX
            local h = math.abs(y1 - y0) * scaleY
            blocks[#blocks + 1] = geomMakeBlock(cx, cy, layerZ, w, h, thickness, tonumber(angle) or 0, colorStr, transparency, currentId)
            currentId = currentId + 1
        elseif (stype == 0 or stype == 2) and #data >= 4 then
            local x0, y0, x1, y1 = data[1], data[2], data[3], data[4]
            local cx = (x0 + x1) / 2 * scaleX
            local cy = (y0 + y1) / 2 * scaleY
            local w = math.abs(x1 - x0) * scaleX
            local h = math.abs(y1 - y0) * scaleY
            blocks[#blocks + 1] = geomMakeBlock(cx, cy, layerZ, w, h, thickness, 0, colorStr, transparency, currentId)
            currentId = currentId + 1
        elseif stype == 3 and #data >= 3 then
            local cxRaw, cyRaw, r = data[1], data[2], data[3]
            local w = r * 2 * scaleX
            local h = r * 2 * scaleY
            blocks[#blocks + 1] = geomMakeBlock(cxRaw * scaleX, cyRaw * scaleY, layerZ, w, h, thickness, 0, colorStr, transparency, currentId)
            currentId = currentId + 1
        elseif stype == 4 and #data >= 6 then
            local ptsX = {data[1], data[3], data[5]}
            local ptsY = {data[2], data[4], data[6]}
            local cx = (ptsX[1] + ptsX[2] + ptsX[3]) / 3 * scaleX
            local cy = (ptsY[1] + ptsY[2] + ptsY[3]) / 3 * scaleY
            local xMin, xMax = math.min(ptsX[1], ptsX[2], ptsX[3]), math.max(ptsX[1], ptsX[2], ptsX[3])
            local yMin, yMax = math.min(ptsY[1], ptsY[2], ptsY[3]), math.max(ptsY[1], ptsY[2], ptsY[3])
            local w = (xMax - xMin) * scaleX
            local h = (yMax - yMin) * scaleY
            blocks[#blocks + 1] = geomMakeBlock(cx, cy, layerZ, w, h, thickness, 0, colorStr, transparency, currentId)
            currentId = currentId + 1
        elseif stype == 5 and #data >= 4 then
            local x0, y0, x1, y1 = data[1], data[2], data[3], data[4]
            local lw = tonumber(data[5]) or 1
            local dx = (x1 - x0) * scaleX
            local dy = (y1 - y0) * scaleY
            local cx = (x0 + x1) / 2 * scaleX
            local cy = (y0 + y1) / 2 * scaleY
            local length = math.sqrt(dx ^ 2 + dy ^ 2)
            local angleZ = math.deg(math.atan2(-dy, dx))
            blocks[#blocks + 1] = geomMakeBlock(cx, cy, layerZ, length, lw * math.min(scaleX, scaleY), thickness, -angleZ, colorStr, transparency, currentId)
            currentId = currentId + 1
        end
    end

    if #blocks == 0 then
        return nil, nil, "Image produced no blocks"
    end
    return material, blocks, nil
end

local function convertGeometrizeJsonToBuild(jsonText, buildName, scale, thickness, material, targetWidth, targetLength)
    local outMaterial, blocks, err = convertGeometrizeJsonToBlocks(jsonText, scale, thickness, material, targetWidth, targetLength)
    if not outMaterial then
        return nil, err
    end
    local safeName = tostring(buildName or ""):gsub("^%s*(.-)%s*$", "%1")
    if safeName == "" then
        return nil, "Output name is empty"
    end
    ensureFolder()
    local outPath = FOLDER_PREFIX .. safeName .. ".Build"
    writefile(outPath, HttpService:JSONEncode({{outMaterial}, {[outMaterial] = blocks}}))
    return outPath, nil
end

local function trimStr(s)
    return tostring(s or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function startsWithDrivePath(s)
    return s:match("^%a:[/\\]") ~= nil or s:sub(1, 2) == "\\\\"
end

local function isAbsolutePath(s)
    s = trimStr(s)
    return s:sub(1, 1) == "/" or startsWithDrivePath(s)
end

local function getFileStem(path)
    local name = tostring(path or ""):match("([^/\\]+)$") or tostring(path or "")
    return (name:gsub("%.[^%.]+$", ""))
end

local function joinPath(dir, name)
    if dir == "" then return name end
    local sep = dir:match("[/\\]$") and "" or "/"
    return dir .. sep .. name
end

local function resolveConverterPath(rawPath)
    local candidate = trimStr(rawPath)
    if candidate == "" then
        return nil, "Select a converter file"
    end
    candidate = candidate:gsub('^"(.*)"$', "%1")
    if isfile(candidate) then
        return candidate
    end
    local probes = {}
    if isAbsolutePath(candidate) then
        probes[#probes + 1] = candidate
    else
        probes[#probes + 1] = FOLDER_PREFIX .. candidate
        probes[#probes + 1] = candidate
    end
    for _, probe in ipairs(probes) do
        if isfile(probe) then
            return probe
        end
    end
    return nil, "File not found: " .. candidate
end

local function getParentDir(path)
    local cleaned = trimStr(path)
    if cleaned == "" then
        return nil
    end
    if isfolder(cleaned) then
        return cleaned
    end
    return cleaned:match("^(.*)[/\\][^/\\]+$")
end

local function rgbStr(r, g, b)
    if r > 1 or g > 1 or b > 1 then
        r, g, b = r / 255, g / 255, b / 255
    end
    return string.format("%.4f,%.4f,%.4f", math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
end

local function cfToAsuBlock(cf, sizeVec, colorStr, blockId, transparency)
    local rx, ry, rz = cf:ToEulerAnglesXYZ()
    local pos = cf.Position
    return {
        ShowShadow = true,
        CanCollide = true,
        Color = colorStr or rgbStr(1, 1, 1),
        Anchored = true,
        BoolValues = {},
        Rotation = string.format("%.6f, %.6f, %.6f", math.deg(rx), math.deg(ry), math.deg(rz)),
        Transparency = transparency or 0,
        Position = string.format("%.6f, %.6f, %.6f", pos.X, pos.Y, pos.Z),
        ID = blockId or 0,
        NumberValues = {},
        Size = string.format("%.6f, %.6f, %.6f", sizeVec.X, sizeVec.Y, sizeVec.Z),
    }
end

local function cloneJsonValue(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = cloneJsonValue(v)
    end
    return out
end

local ASU_MAPPED_KEYS = {
    Position = true, position = true, Pos = true, pos = true,
    Rotation = true, rotation = true, Rot = true, rot = true,
    Size = true, size = true,
    Color = true, color = true, Col = true, col = true,
    Transparency = true,
    Anchored = true,
    CanCollide = true,
    ShowShadow = true,
    BoolValues = true,
    NumberValues = true,
    BindTable = true,
    ID = true,
    SecondaryPartPosition = true,
    SecondaryPartRotation = true,
    Stiffness = true,
    Damping = true,
    TargetLength = true,
    MaxLength = true,
    MinLength = true,
    Length = true,
    AngleLimit = true,
    MatchRotation = true,
    ShowConstraint = true,
}

local function collectAsuExtras(block)
    local extras = {}
    for k, v in pairs(block) do
        if not ASU_MAPPED_KEYS[k] then
            extras[k] = cloneJsonValue(v)
        end
    end
    if next(extras) then
        return extras
    end
    return nil
end

local function mergePropertyMaps(boolValues, numberValues, extras)
    local outBool = {}
    local outNum = {}

    if type(boolValues) == "table" then
        for k, v in pairs(boolValues) do
            outBool[k] = v
        end
    end
    if type(numberValues) == "table" then
        for k, v in pairs(numberValues) do
            outNum[k] = v
        end
    end
    if type(extras) == "table" then
        for k, v in pairs(extras) do
            local vt = type(v)
            if vt == "boolean" then
                if outBool[k] == nil then
                    outBool[k] = v
                end
            elseif vt == "number" then
                if outNum[k] == nil then
                    outNum[k] = v
                end
            elseif vt == "string" then
                local lower = string.lower(v)
                if outBool[k] == nil and (lower == "true" or lower == "false") then
                    outBool[k] = lower == "true"
                elseif outNum[k] == nil then
                    local n = tonumber(v)
                    if n ~= nil then
                        outNum[k] = n
                    end
                end
            end
        end
    end

    return outBool, outNum
end

local function currentExecutorName()
    local ok, name = pcall(function()
        if identifyexecutor then
            return identifyexecutor()
        end
        if getexecutorname then
            return getexecutorname()
        end
        return ""
    end)
    if ok and name then
        return tostring(name)
    end
    return ""
end

local function pointInsideAnyButton(container, x, y)
    for _, child in pairs(container:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("ImageButton") then
            local pos = child.AbsolutePosition
            local size = child.AbsoluteSize
            if x >= pos.X and x <= pos.X + size.X and y >= pos.Y and y <= pos.Y + size.Y then
                return true
            end
        end
    end
    return false
end

local function writeConvertedBuild(buildName, material, blocks)
    local safeName = trimStr(buildName)
    if safeName == "" then
        return nil, "Output name is empty"
    end
    if type(blocks) ~= "table" or #blocks == 0 then
        return nil, "Nothing to convert"
    end
    local cleanBlocks = {}
    local seen = {}
    for _, block in ipairs(blocks) do
        if type(block) == "table" then
            local key = table.concat({
                tostring(block.Position or ""),
                tostring(block.Rotation or ""),
                tostring(block.Size or ""),
                tostring(block.Color or ""),
                tostring(block.Transparency or 0),
            }, "|")
            if not seen[key] then
                seen[key] = true
                cleanBlocks[#cleanBlocks + 1] = block
            end
        end
    end
    if #cleanBlocks == 0 then
        return nil, "Nothing to convert"
    end
    ensureFolder()
    local outPath = FOLDER_PREFIX .. safeName .. ".Build"
    writefile(outPath, HttpService:JSONEncode({{material}, {[material] = cleanBlocks}}))
    return outPath, nil
end

local function bytesToString(bytes)
    local chunks = {}
    for i = 1, #bytes, 4096 do
        local chars = {}
        for j = i, math.min(i + 4095, #bytes) do
            chars[#chars + 1] = string.char(bytes[j])
        end
        chunks[#chunks + 1] = table.concat(chars)
    end
    return table.concat(chunks)
end

local function gzNoEof(value)
    if value == nil then
        error("Unexpected end of gzip stream", 0)
    end
    return value
end

local function gzHasBit(bits, mask)
    return bits % (mask + mask) >= mask
end

local function gzMakeOutputState(writer)
    return {
        outbs = writer,
        window = {},
        windowPos = 1,
    }
end

local function gzOutput(outState, byte)
    outState.outbs(byte)
    outState.window[outState.windowPos] = byte
    outState.windowPos = outState.windowPos % 32768 + 1
end

local function gzBitstreamFromString(data)
    local index = 1
    local bufByte = 0
    local bufBits = 0
    local stream = {}

    function stream:nbitsLeftInByte()
        return bufBits
    end

    function stream:read(nbits)
        nbits = nbits or 1
        while bufBits < nbits do
            if index > #data then
                return nil
            end
            local byte = string.byte(data, index)
            index = index + 1
            bufByte = bufByte + bit.lshift(byte, bufBits)
            bufBits = bufBits + 8
        end
        local bitsOut
        if nbits == 0 then
            bitsOut = 0
        elseif nbits == 32 then
            bitsOut = bufByte
            bufByte = 0
        else
