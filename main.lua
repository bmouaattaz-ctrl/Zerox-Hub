--[=[
    ========================================================
    ZER0X HUB v1.0 (Evade / Rayfield Obsidian Dark UI Edition)
    Target: Roblox / Luau
    
    EXACT MATCH TO USER DESIGN:
      - 🖤 Sleek Obsidian Dark Theme & Layout
      - 📑 Left Sidebar: Title, "Free" badge, clean tab list
      - 🔍 Top Search Bar with live element filtering
      - 🏃 Full Evade Movement Controls:
          • Speed (Editable Textbox, default 1500)
          • Friction (Editable Textbox, default 5)
          • Run Accel (Editable Textbox, default 1)
          • Run Deaccel (Editable Textbox, default 700)
          • Sprint Accel (Editable Textbox, default 1)
          • Sprint Cap (Editable Textbox, default 2)
          • Jump Height (Editable Textbox, default 3)
          • Jump Cap (Editable Textbox, default 1)
          • Bunny Hop (Bhop) Toggle (Natural jump height, zero air-floating)
          • Mute Wind / Falling Sound Toggle
      - ☀️ Visuals: Fullbright (No glare), Infinite Zoom (1M studs)
      - ⚙️ Settings: Accent Color Customizer, Custom Keybind, Total Kill Exit
      - 💫 Animated Splash Loader on Launch
    ========================================================
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer

-- ========================================================
-- 1. CRASH-PROOF UI PARENT RESOLVER
-- ========================================================
local function getSafeParent()
    if gethui then
        local ok, res = pcall(gethui)
        if ok and res then return res end
    end
    local okCore = pcall(function()
        local test = Instance.new("Folder")
        test.Parent = CoreGui
        test:Destroy()
    end)
    if okCore then
        return CoreGui
    end
    return LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
end

local ParentContainer = getSafeParent()

if ParentContainer:FindFirstChild("ZeroxHubGui") then
    pcall(function() ParentContainer.ZeroxHubGui:Destroy() end)
end

-- ========================================================
-- 2. DYNAMIC CHARACTER RESOLVERS
-- ========================================================
local function getChar()
    return LocalPlayer.Character
end

local function getHumanoid()
    local char = getChar()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local char = getChar()
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
end

local function getMovementVector()
    local hum = getHumanoid()
    if hum and hum.MoveDirection.Magnitude > 0.05 then
        local flat = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
        if flat.Magnitude > 0.05 then
            return flat.Unit
        end
    end
    
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    
    local dir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
    
    local horizontal = Vector3.new(dir.X, 0, dir.Z)
    if horizontal.Magnitude > 0.05 then
        return horizontal.Unit
    end
    return nil
end

-- ========================================================
-- 3. THEME SYSTEM (Obsidian & Royal Blue)
-- ========================================================
local Theme = {
    CurrentAccent = Color3.fromRGB(37, 84, 245), -- Default Royal Blue (from user screenshot)
    BackgroundDark = Color3.fromRGB(9, 9, 12),
    SidebarBg = Color3.fromRGB(8, 8, 11),
    MainFrameBg = Color3.fromRGB(12, 12, 16),
    CardBg = Color3.fromRGB(17, 17, 22),
    InputBoxBg = Color3.fromRGB(20, 20, 26),
    InputBorder = Color3.fromRGB(36, 36, 46),
    TextPrimary = Color3.fromRGB(245, 245, 250),
    TextSecondary = Color3.fromRGB(145, 145, 160),
    TextMuted = Color3.fromRGB(100, 100, 115)
}

local AccentListeners = {}
local function registerAccentListener(callback)
    table.insert(AccentListeners, callback)
    callback(Theme.CurrentAccent)
end

local function setAccentColor(newColor)
    Theme.CurrentAccent = newColor
    for _, cb in ipairs(AccentListeners) do
        pcall(cb, newColor)
    end
end

-- ========================================================
-- 4. STATE & SETTINGS (Full Evade Movement Matrix)
-- ========================================================
local State = {
    -- Movement Parameters
    Speed = 1500,
    Friction = 5,
    RunAccel = 1,
    RunDeaccel = 700,
    SprintAccel = 1,
    SprintCap = 2,
    JumpHeight = 1.2,
    JumpCap = 1,
    JumpSpeedMultiplier = 1,
    
    -- Toggles
    SpeedEnabled = true,
    Bhop = true,
    MuteWind = true,
    RemoveDarkness = false,
    UnlockZoom = false,
    
    -- System
    ToggleKey = Enum.KeyCode.RightControl,
    IsBindingKey = false,
    DefaultSpeed = 16,
    OriginalLighting = {
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        ClockTime = Lighting.ClockTime,
        GlobalShadows = Lighting.GlobalShadows
    }
}

local ToggleUpdaters = {}
local ActiveConnections = {}

-- ========================================================
-- 5. WIND & FALLING SOUND SUPPRESSOR ENGINE
-- ========================================================
local function processSound(sound)
    if sound:IsA("Sound") then
        local name = sound.Name:lower()
        if name:find("wind") or name:find("fall") or name:find("whoosh") or name:find("air") or name:find("speed") then
            if State.MuteWind then
                sound.Volume = 0
                if sound.IsPlaying then pcall(function() sound:Stop() end) end
            end
        end
    end
end

local function scanAllSounds()
    local char = getChar()
    if char then
        for _, s in ipairs(char:GetDescendants()) do processSound(s) end
    end
    local cam = workspace.CurrentCamera
    if cam then
        for _, s in ipairs(cam:GetDescendants()) do processSound(s) end
    end
    for _, s in ipairs(SoundService:GetDescendants()) do processSound(s) end
end

table.insert(ActiveConnections, workspace.DescendantAdded:Connect(function(desc)
    if State.MuteWind and desc:IsA("Sound") then
        processSound(desc)
    end
end))

table.insert(ActiveConnections, RunService.Heartbeat:Connect(function()
    if State.MuteWind then
        local root = getRoot()
        if root then
            local ff = root:FindFirstChild("FreeFalling")
            if ff and ff:IsA("Sound") then
                ff.Volume = 0
                if ff.IsPlaying then ff:Stop() end
            end
        end
        local cam = workspace.CurrentCamera
        if cam then
            for _, child in ipairs(cam:GetChildren()) do
                if child:IsA("Sound") then
                    local n = child.Name:lower()
                    if n:find("wind") or n:find("whoosh") or n:find("fall") or n:find("speed") then
                        child.Volume = 0
                        if child.IsPlaying then child:Stop() end
                    end
                end
            end
        end
    end
end))

scanAllSounds()

-- ========================================================
-- 6. EVADE PHYSICS & MOVEMENT ENGINE
-- ========================================================
local EvadeTables = {}

local function scanForEvadeTables()
    local found = {}
    
    -- Safe getgc memory scan (Instant, zero yields, zero module execution)
    if getgc then
        pcall(function()
            local gc = getgc(true)
            for _, v in pairs(gc) do
                if type(v) == "table" then
                    local s = rawget(v, "Speed") or rawget(v, "speed")
                    local f = rawget(v, "Friction") or rawget(v, "friction")
                    local a = rawget(v, "RunAccel") or rawget(v, "RunDeaccel") or rawget(v, "SprintCap")
                    if (s and f) or (s and a) or (f and a) then
                        table.insert(found, v)
                    end
                end
            end
        end)
    end
    
    return found
end

local function applyToEvadeTables()
    if #EvadeTables == 0 then
        EvadeTables = scanForEvadeTables()
    end
    
    for _, tbl in ipairs(EvadeTables) do
        pcall(function()
            if table.isfrozen and table.isfrozen(tbl) and setreadonly then
                setreadonly(tbl, false)
            end
            
            -- Speed
            if rawget(tbl, "Speed") ~= nil then tbl.Speed = State.Speed end
            if rawget(tbl, "speed") ~= nil then tbl.speed = State.Speed end
            
            -- Friction
            if rawget(tbl, "Friction") ~= nil then tbl.Friction = State.Friction end
            if rawget(tbl, "friction") ~= nil then tbl.friction = State.Friction end
            
            -- Run Accel
            if rawget(tbl, "RunAccel") ~= nil then tbl.RunAccel = State.RunAccel end
            if rawget(tbl, "runAccel") ~= nil then tbl.runAccel = State.RunAccel end
            if rawget(tbl, "RunAcceleration") ~= nil then tbl.RunAcceleration = State.RunAccel end
            
            -- Run Deaccel
            if rawget(tbl, "RunDeaccel") ~= nil then tbl.RunDeaccel = State.RunDeaccel end
            if rawget(tbl, "RunDeccel") ~= nil then tbl.RunDeccel = State.RunDeaccel end
            if rawget(tbl, "runDeaccel") ~= nil then tbl.runDeaccel = State.RunDeaccel end
            if rawget(tbl, "runDeccel") ~= nil then tbl.runDeccel = State.RunDeaccel end
            if rawget(tbl, "Deaccel") ~= nil then tbl.Deaccel = State.RunDeaccel end
            
            -- Sprint Accel
            if rawget(tbl, "SprintAccel") ~= nil then tbl.SprintAccel = State.SprintAccel end
            if rawget(tbl, "sprintAccel") ~= nil then tbl.sprintAccel = State.SprintAccel end
            if rawget(tbl, "SprintAcceleration") ~= nil then tbl.SprintAcceleration = State.SprintAccel end
            
            -- Sprint Cap
            if rawget(tbl, "SprintCap") ~= nil then tbl.SprintCap = State.SprintCap end
            if rawget(tbl, "sprintCap") ~= nil then tbl.sprintCap = State.SprintCap end
            if rawget(tbl, "SprintSpeedCap") ~= nil then tbl.SprintSpeedCap = State.SprintCap end
            
            -- Jump parameters (Preserve Evade native jump unless explicitly changed)
            if State.JumpHeight and State.JumpHeight > 1 then
                if rawget(tbl, "JumpHeight") ~= nil then tbl.JumpHeight = State.JumpHeight end
                if rawget(tbl, "jumpHeight") ~= nil then tbl.jumpHeight = State.JumpHeight end
            end
            if State.JumpCap and State.JumpCap > 1 then
                if rawget(tbl, "JumpCap") ~= nil then tbl.JumpCap = State.JumpCap end
                if rawget(tbl, "jumpCap") ~= nil then tbl.jumpCap = State.JumpCap end
            end
            if State.JumpSpeedMultiplier and State.JumpSpeedMultiplier > 1 then
                if rawget(tbl, "JumpSpeedMultiplier") ~= nil then tbl.JumpSpeedMultiplier = State.JumpSpeedMultiplier end
                if rawget(tbl, "jumpSpeedMultiplier") ~= nil then tbl.jumpSpeedMultiplier = State.JumpSpeedMultiplier end
            end
        end)
    end
end

-- Asynchronous non-blocking initialization
task.spawn(function()
    EvadeTables = scanForEvadeTables()
    applyToEvadeTables()
end)

local function syncEvadePhysics()
    local root = getRoot()
    local hum = getHumanoid()
    
    if root then
        pcall(function()
            local frictionVal = math.clamp(State.Friction / 10, 0.0, 5)
            root.CustomPhysicalProperties = PhysicalProperties.new(0.7, frictionVal, 0, 1, 0)
        end)
    end
    
    if hum then
        pcall(function()
            if State.JumpHeight and State.JumpHeight > 1 then
                hum.JumpHeight = math.clamp(State.JumpHeight * 7.2, 7.2, 100)
                hum.JumpPower = math.clamp(State.JumpHeight * 50, 50, 200)
            end
        end)
    end
end

local simulatedSpeed = 0
local lastScanTick = 0

-- Physics & Velocity Execution Loop
table.insert(ActiveConnections, RunService.Heartbeat:Connect(function(dt)
    if (tick() - lastScanTick) > 2 then
        lastScanTick = tick()
        if #EvadeTables == 0 then
            EvadeTables = scanForEvadeTables()
        end
    end
    
    applyToEvadeTables()
    
    local hum = getHumanoid()
    local root = getRoot()
    if not hum or hum.Health <= 0 or not root then return end
    
    -- Anti-Launch Safety Cap: Allows natural ramp surf & punchy jumps up to 65 velocity,
    -- while strictly preventing extreme 100+ sky glitches
    if root.AssemblyLinearVelocity.Y > 65 then
        root.AssemblyLinearVelocity = Vector3.new(
            root.AssemblyLinearVelocity.X,
            65,
            root.AssemblyLinearVelocity.Z
        )
    end
    
    -- If Speed is set to 0, stop movement completely
    if State.Speed <= 0 then
        simulatedSpeed = 0
        hum.WalkSpeed = 0
        root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
        return
    end
    
    -- Fallback / Direct Assist Physics Engine (When Evade internal table is not present)
    if #EvadeTables == 0 and State.SpeedEnabled then
        local moveDir = getMovementVector()
        local isSprinting = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
        local mult = (State.JumpSpeedMultiplier and hum.FloorMaterial == Enum.Material.Air) and State.JumpSpeedMultiplier or 1.0
        
        local targetCap = isSprinting and (State.SprintCap or 2) or 1
        local maxSpeed = (State.Speed / 60) * targetCap * mult
        local accelRate = isSprinting and (State.SprintAccel * 50) or (State.RunAccel * 40)
        local deaccelRate = (State.RunDeaccel / 10) * math.clamp(State.Friction / 5, 0.1, 5)
        
        if moveDir and moveDir.Magnitude > 0 then
            simulatedSpeed = math.min(maxSpeed, simulatedSpeed + (accelRate * dt))
            local vel = moveDir * simulatedSpeed
            root.AssemblyLinearVelocity = Vector3.new(vel.X, root.AssemblyLinearVelocity.Y, vel.Z)
            hum.WalkSpeed = math.max(1, simulatedSpeed)
        else
            simulatedSpeed = math.max(0, simulatedSpeed - (deaccelRate * dt))
            if simulatedSpeed > 0 then
                local currentFlat = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
                if currentFlat.Magnitude > 0.1 then
                    local dir = currentFlat.Unit
                    local newFlat = dir * simulatedSpeed
                    root.AssemblyLinearVelocity = Vector3.new(newFlat.X, root.AssemblyLinearVelocity.Y, newFlat.Z)
                end
            end
            hum.WalkSpeed = math.max(0, simulatedSpeed)
        end
    end
end))

-- Re-hook on character respawn
table.insert(ActiveConnections, LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.3)
    EvadeTables = scanForEvadeTables()
    applyToEvadeTables()
    syncEvadePhysics()
    if State.MuteWind then scanAllSounds() end
end))

-- Natural Bunny Hop Engine (100% Normal Jump - Zero Super Jump)
local lastBhopTick = 0
local function isGrounded(root, hum)
    if hum and hum.FloorMaterial ~= Enum.Material.Air then
        return true
    end
    -- Detect ground/slopes when descending or climbing ramps
    if root and root.AssemblyLinearVelocity.Y <= 1.0 then
        local char = getChar()
        local ray = Ray.new(root.Position, Vector3.new(0, -3.8, 0))
        local hit = workspace:FindPartOnRayWithIgnoreList(ray, {char})
        return hit ~= nil
    end
    return false
end

table.insert(ActiveConnections, RunService.RenderStepped:Connect(function()
    if State.Bhop and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        local hum = getHumanoid()
        local root = getRoot()
        if hum and hum.Health > 0 and root then
            if (tick() - lastBhopTick > 0.25) and isGrounded(root, hum) then
                lastBhopTick = tick()
                hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                hum.Jump = true
            end
        end
    end
end))

-- ========================================================
-- 7. VISUALS ENGINES (FULLBRIGHT & ZOOM)
-- ========================================================
local lightingChangedConn = nil

local function enforceFullbright()
    pcall(function()
        Lighting.Ambient = Color3.fromRGB(140, 140, 140)
        Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 140)
        Lighting.Brightness = 1
        Lighting.FogEnd = 1000000
        Lighting.FogStart = 0
        Lighting.GlobalShadows = false
        Lighting.ClockTime = 14
    end)
    
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then
            pcall(function() obj.Density = 0; obj.Haze = 0 end)
        elseif obj:IsA("ColorCorrectionEffect") then
            pcall(function()
                obj.Brightness = 0
                obj.Contrast = 0
                obj.TintColor = Color3.fromRGB(255, 255, 255)
            end)
        elseif obj:IsA("BloomEffect") then
            pcall(function() obj.Intensity = 0.15 end)
        end
    end
end

local function restoreLighting()
    if lightingChangedConn then
        lightingChangedConn:Disconnect()
        lightingChangedConn = nil
    end
    pcall(function()
        Lighting.Ambient = State.OriginalLighting.Ambient
        Lighting.OutdoorAmbient = State.OriginalLighting.OutdoorAmbient
        Lighting.Brightness = State.OriginalLighting.Brightness
        Lighting.FogEnd = State.OriginalLighting.FogEnd
        Lighting.FogStart = State.OriginalLighting.FogStart
        Lighting.ClockTime = State.OriginalLighting.ClockTime
        Lighting.GlobalShadows = State.OriginalLighting.GlobalShadows
    end)
end

local function applyRemoveDarkness(enabled)
    State.RemoveDarkness = enabled
    if enabled then
        enforceFullbright()
        if not lightingChangedConn then
            lightingChangedConn = Lighting.Changed:Connect(function()
                if State.RemoveDarkness then enforceFullbright() end
            end)
        end
    else
        restoreLighting()
    end
end

local function applyUnlockZoom(enabled)
    State.UnlockZoom = enabled
    pcall(function()
        LocalPlayer.CameraMaxZoomDistance = enabled and 1000000 or 128
        LocalPlayer.CameraMinZoomDistance = 0.5
    end)
end

table.insert(ActiveConnections, RunService.RenderStepped:Connect(function()
    if State.UnlockZoom and LocalPlayer.CameraMaxZoomDistance < 1000000 then
        LocalPlayer.CameraMaxZoomDistance = 1000000
    end
end))

table.insert(ActiveConnections, LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    scanAllSounds()
    syncEvadePhysics()
    if State.RemoveDarkness then enforceFullbright() end
end))

-- ========================================================
-- 8. OBSIDIAN RAYFIELD-STYLE UI (EXACT MATCH TO SCREENSHOT)
-- ========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZeroxHubGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = ParentContainer

-- Backdrop Container (Main Window)
local Backdrop = Instance.new("Frame")
Backdrop.Name = "Backdrop"
Backdrop.Size = UDim2.new(0, 560, 0, 420)
Backdrop.Position = UDim2.new(0.5, -280, 0.5, -210)
Backdrop.BackgroundColor3 = Theme.BackgroundDark
Backdrop.BorderSizePixel = 0
Backdrop.Visible = false
Backdrop.ClipsDescendants = true
Backdrop.Parent = ScreenGui

local BCorner = Instance.new("UICorner")
BCorner.CornerRadius = UDim.new(0, 8)
BCorner.Parent = Backdrop

local BStroke = Instance.new("UIStroke")
BStroke.Thickness = 1.2
BStroke.Color = Color3.fromRGB(30, 30, 40)
BStroke.Parent = Backdrop

-- Left Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 140, 1, 0)
Sidebar.Position = UDim2.new(0, 0, 0, 0)
Sidebar.BackgroundColor3 = Theme.SidebarBg
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Backdrop

local SCorner = Instance.new("UICorner")
SCorner.CornerRadius = UDim.new(0, 8)
SCorner.Parent = Sidebar

local SDivider = Instance.new("Frame")
SDivider.Name = "SDivider"
SDivider.Size = UDim2.new(0, 1, 1, 0)
SDivider.Position = UDim2.new(0, 140, 0, 0)
SDivider.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
SDivider.BorderSizePixel = 0
SDivider.ZIndex = 3
SDivider.Parent = Backdrop

-- Sidebar Header (Title + "Free" label from screenshot)
local BrandTitle = Instance.new("TextLabel")
BrandTitle.Text = "Zerox"
BrandTitle.Font = Enum.Font.GothamBold
BrandTitle.TextSize = 20
BrandTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
BrandTitle.TextXAlignment = Enum.TextXAlignment.Left
BrandTitle.Position = UDim2.new(0, 14, 0, 14)
BrandTitle.Size = UDim2.new(1, -20, 0, 24)
BrandTitle.BackgroundTransparency = 1
BrandTitle.Parent = Sidebar

local SubBadge = Instance.new("TextLabel")
SubBadge.Text = "Free"
SubBadge.Font = Enum.Font.GothamBold
SubBadge.TextSize = 16
SubBadge.TextColor3 = Theme.CurrentAccent
SubBadge.TextXAlignment = Enum.TextXAlignment.Left
SubBadge.Position = UDim2.new(0, 14, 0, 36)
SubBadge.Size = UDim2.new(1, -20, 0, 20)
SubBadge.BackgroundTransparency = 1
SubBadge.Parent = Sidebar

registerAccentListener(function(accent)
    SubBadge.TextColor3 = accent
end)

-- Sidebar Tabs Container
local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, 0, 1, -70)
TabContainer.Position = UDim2.new(0, 0, 0, 68)
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = Sidebar

local TLayout = Instance.new("UIListLayout")
TLayout.Padding = UDim.new(0, 4)
TLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TLayout.SortOrder = Enum.SortOrder.LayoutOrder
TLayout.Parent = TabContainer

-- Content Container (Right Side)
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -141, 1, 0)
ContentArea.Position = UDim2.new(0, 141, 0, 0)
ContentArea.BackgroundColor3 = Theme.MainFrameBg
ContentArea.BorderSizePixel = 0
ContentArea.Parent = Backdrop

-- Topbar in Content Area (Search Bar + Close Button)
local Topbar = Instance.new("Frame")
Topbar.Name = "Topbar"
Topbar.Size = UDim2.new(1, 0, 0, 44)
Topbar.BackgroundTransparency = 1
Topbar.BorderSizePixel = 0
Topbar.Parent = ContentArea

-- Search Bar (Exact Match to Screenshot)
local SearchFrame = Instance.new("Frame")
SearchFrame.Size = UDim2.new(1, -74, 0, 30)
SearchFrame.Position = UDim2.new(0, 10, 0, 7)
SearchFrame.BackgroundColor3 = Theme.InputBoxBg
SearchFrame.BorderSizePixel = 0
SearchFrame.Parent = Topbar

local SFCorner = Instance.new("UICorner")
SFCorner.CornerRadius = UDim.new(0, 6)
SFCorner.Parent = SearchFrame

local SFStroke = Instance.new("UIStroke")
SFStroke.Thickness = 1
SFStroke.Color = Theme.InputBorder
SFStroke.Parent = SearchFrame

local SearchIcon = Instance.new("TextLabel")
SearchIcon.Text = "🔍"
SearchIcon.TextSize = 11
SearchIcon.Position = UDim2.new(0, 8, 0, 0)
SearchIcon.Size = UDim2.new(0, 18, 1, 0)
SearchIcon.BackgroundTransparency = 1
SearchIcon.Parent = SearchFrame

local SearchInput = Instance.new("TextBox")
SearchInput.Size = UDim2.new(1, -32, 1, 0)
SearchInput.Position = UDim2.new(0, 28, 0, 0)
SearchInput.BackgroundTransparency = 1
SearchInput.PlaceholderText = "Search..."
SearchInput.PlaceholderColor3 = Theme.TextMuted
SearchInput.Text = ""
SearchInput.TextColor3 = Theme.TextPrimary
SearchInput.Font = Enum.Font.GothamMedium
SearchInput.TextSize = 12
SearchInput.TextXAlignment = Enum.TextXAlignment.Left
SearchInput.ClearTextOnFocus = false
SearchInput.Parent = SearchFrame

-- Close Button (Kills Hub)
-- Close Button (Kills Hub)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -34, 0, 9)
CloseBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
CloseBtn.Text = "×"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
CloseBtn.ZIndex = 25
CloseBtn.Active = true
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Topbar

local CBCorner = Instance.new("UICorner")
CBCorner.CornerRadius = UDim.new(0, 6)
CBCorner.Parent = CloseBtn

CloseBtn.MouseEnter:Connect(function()
    TweenService:Create(CloseBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(220, 45, 55), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
end)

CloseBtn.MouseLeave:Connect(function()
    TweenService:Create(CloseBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(24, 24, 30), TextColor3 = Color3.fromRGB(180, 180, 190)}):Play()
end)

-- Tab Viewport & Dragging
local isDragging = false
local dragStart, startPos, dragInput

Topbar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        -- Don't start dragging if clicking CloseBtn
        local mousePos = input.Position
        local cbPos = CloseBtn.AbsolutePosition
        local cbSize = CloseBtn.AbsoluteSize
        if mousePos.X >= cbPos.X and mousePos.X <= (cbPos.X + cbSize.X) and
           mousePos.Y >= cbPos.Y and mousePos.Y <= (cbPos.Y + cbSize.Y) then
            return
        end
        
        isDragging = true
        dragStart = input.Position
        startPos = Backdrop.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then isDragging = false end
        end)
    end
end)

Topbar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and isDragging then
        local delta = input.Position - dragStart
        Backdrop.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Main Pages System
local Pages = {}
local TabButtons = {}
local CurrentTab = nil
local AllSearchableItems = {}

local function createTab(tabName, order)
    local Btn = Instance.new("TextButton")
    Btn.Name = tabName .. "Tab"
    Btn.Size = UDim2.new(0, 126, 0, 32)
    Btn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    Btn.BackgroundTransparency = 1
    Btn.Text = "    " .. tabName
    Btn.Font = Enum.Font.GothamMedium
    Btn.TextSize = 13
    Btn.TextColor3 = Theme.TextSecondary
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.LayoutOrder = order
    Btn.AutoButtonColor = false
    Btn.Parent = TabContainer
    
    local BCorner = Instance.new("UICorner")
    BCorner.CornerRadius = UDim.new(0, 6)
    BCorner.Parent = Btn
    
    -- Page
    local Page = Instance.new("ScrollingFrame")
    Page.Name = tabName .. "Page"
    Page.Size = UDim2.new(1, 0, 1, -44)
    Page.Position = UDim2.new(0, 0, 0, 44)
    Page.BackgroundTransparency = 1
    Page.ScrollBarThickness = 3
    Page.ScrollBarImageColor3 = Theme.CurrentAccent
    Page.BorderSizePixel = 0
    Page.Visible = false
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Page.Parent = ContentArea
    
    registerAccentListener(function(accent)
        Page.ScrollBarImageColor3 = accent
    end)
    
    local PLayout = Instance.new("UIListLayout")
    PLayout.Padding = UDim.new(0, 8)
    PLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    PLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PLayout.Parent = Page
    
    local PPadding = Instance.new("UIPadding")
    PPadding.PaddingTop = UDim.new(0, 6)
    PPadding.PaddingBottom = UDim.new(0, 12)
    PPadding.Parent = Page
    
    -- Section Title Header inside Page (Exact match to screenshot)
    local SecHeader = Instance.new("Frame")
    SecHeader.Size = UDim2.new(0, 395, 0, 26)
    SecHeader.BackgroundTransparency = 1
    SecHeader.LayoutOrder = 0
    SecHeader.Parent = Page
    
    local SecTitle = Instance.new("TextLabel")
    SecTitle.Text = tabName
    SecTitle.Font = Enum.Font.GothamBold
    SecTitle.TextSize = 14
    SecTitle.TextColor3 = Color3.fromRGB(240, 240, 245)
    SecTitle.Position = UDim2.new(0, 0, 0, 0)
    SecTitle.Size = UDim2.new(1, 0, 0, 20)
    SecTitle.TextXAlignment = Enum.TextXAlignment.Center
    SecTitle.BackgroundTransparency = 1
    SecTitle.Parent = SecHeader
    
    local SecDivider = Instance.new("Frame")
    SecDivider.Size = UDim2.new(1, -20, 0, 1)
    SecDivider.Position = UDim2.new(0, 10, 1, -2)
    SecDivider.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    SecDivider.BorderSizePixel = 0
    SecDivider.Parent = SecHeader
    
    local function activate()
        CurrentTab = tabName
        for name, otherPage in pairs(Pages) do
            otherPage.Visible = (name == tabName)
        end
        for name, b in pairs(TabButtons) do
            if name == tabName then
                TweenService:Create(b, TweenInfo.new(0.18), {
                    BackgroundColor3 = Theme.CurrentAccent,
                    BackgroundTransparency = 0,
                    TextColor3 = Color3.fromRGB(255, 255, 255)
                }):Play()
                b.Font = Enum.Font.GothamBold
            else
                TweenService:Create(b, TweenInfo.new(0.18), {
                    BackgroundTransparency = 1,
                    TextColor3 = Theme.TextSecondary
                }):Play()
                b.Font = Enum.Font.GothamMedium
            end
        end
    end
    
    Btn.MouseButton1Click:Connect(activate)
    Pages[tabName] = Page
    TabButtons[tabName] = Btn
    
    return Page, activate
end

-- ========================================================
-- 9. COMPONENT BUILDERS (Exact TextBoxes & Toggles)
-- ========================================================

-- Textbox Parameter Card (Exact Match to Screenshot)
local function createInput(parent, title, defaultValue, callback)
    local Card = Instance.new("Frame")
    Card.Name = title .. "Card"
    Card.Size = UDim2.new(0, 395, 0, 48)
    Card.BackgroundTransparency = 1
    Card.Parent = parent
    
    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Text = title
    TitleLbl.Font = Enum.Font.GothamMedium
    TitleLbl.TextSize = 12
    TitleLbl.TextColor3 = Theme.TextPrimary
    TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    TitleLbl.Position = UDim2.new(0, 4, 0, 0)
    TitleLbl.Size = UDim2.new(1, -8, 0, 16)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Parent = Card
    
    local BoxFrame = Instance.new("Frame")
    BoxFrame.Size = UDim2.new(1, -8, 0, 26)
    BoxFrame.Position = UDim2.new(0, 4, 0, 18)
    BoxFrame.BackgroundColor3 = Theme.InputBoxBg
    BoxFrame.BorderSizePixel = 0
    BoxFrame.Parent = Card
    
    local BCorner = Instance.new("UICorner")
    BCorner.CornerRadius = UDim.new(0, 5)
    BCorner.Parent = BoxFrame
    
    local BStroke = Instance.new("UIStroke")
    BStroke.Thickness = 1
    BStroke.Color = Theme.InputBorder
    BStroke.Parent = BoxFrame
    
    local TBox = Instance.new("TextBox")
    TBox.Size = UDim2.new(1, -16, 1, 0)
    TBox.Position = UDim2.new(0, 8, 0, 0)
    TBox.BackgroundTransparency = 1
    TBox.Text = tostring(defaultValue)
    TBox.TextColor3 = Theme.TextSecondary
    TBox.Font = Enum.Font.Gotham
    TBox.TextSize = 12
    TBox.TextXAlignment = Enum.TextXAlignment.Left
    TBox.ClearTextOnFocus = false
    TBox.Parent = BoxFrame
    
    local function applyVal()
        local num = tonumber(TBox.Text)
        if num ~= nil then
            callback(num)
        end
    end
    
    TBox.Focused:Connect(function()
        TweenService:Create(BStroke, TweenInfo.new(0.15), {Color = Theme.CurrentAccent}):Play()
        TBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)
    
    TBox.FocusLost:Connect(function()
        TweenService:Create(BStroke, TweenInfo.new(0.15), {Color = Theme.InputBorder}):Play()
        TBox.TextColor3 = Theme.TextSecondary
        applyVal()
    end)
    
    TBox:GetPropertyChangedSignal("Text"):Connect(function()
        applyVal()
    end)
    
    table.insert(AllSearchableItems, {Card = Card, Title = title})
    return Card
end

-- Toggle Switch Card
local function createToggle(parent, title, defaultState, callback)
    local Card = Instance.new("Frame")
    Card.Name = title .. "Card"
    Card.Size = UDim2.new(0, 395, 0, 40)
    Card.BackgroundColor3 = Theme.CardBg
    Card.BorderSizePixel = 0
    Card.Parent = parent
    
    local CCorner = Instance.new("UICorner")
    CCorner.CornerRadius = UDim.new(0, 6)
    CCorner.Parent = Card
    
    local CStroke = Instance.new("UIStroke")
    CStroke.Thickness = 1
    CStroke.Color = Theme.InputBorder
    CStroke.Parent = Card
    
    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Text = title
    TitleLbl.Font = Enum.Font.GothamMedium
    TitleLbl.TextSize = 13
    TitleLbl.TextColor3 = Theme.TextPrimary
    TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    TitleLbl.Position = UDim2.new(0, 12, 0, 0)
    TitleLbl.Size = UDim2.new(1, -70, 1, 0)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Parent = Card
    
    local Pill = Instance.new("TextButton")
    Pill.Size = UDim2.new(0, 44, 0, 22)
    Pill.Position = UDim2.new(1, -56, 0.5, -11)
    Pill.BackgroundColor3 = defaultState and Theme.CurrentAccent or Color3.fromRGB(30, 30, 40)
    Pill.BorderSizePixel = 0
    Pill.Text = ""
    Pill.AutoButtonColor = false
    Pill.Parent = Card
    
    local PCorner = Instance.new("UICorner")
    PCorner.CornerRadius = UDim.new(1, 0)
    PCorner.Parent = Pill
    
    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 16, 0, 16)
    Knob.Position = defaultState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Knob.BorderSizePixel = 0
    Knob.Parent = Pill
    
    local KCorner = Instance.new("UICorner")
    KCorner.CornerRadius = UDim.new(1, 0)
    KCorner.Parent = Knob
    
    local state = defaultState
    
    local function setVisual(val, anim)
        state = val
        local targetColor = val and Theme.CurrentAccent or Color3.fromRGB(30, 30, 40)
        local targetPos = val and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        if anim then
            TweenService:Create(Pill, TweenInfo.new(0.18), {BackgroundColor3 = targetColor}):Play()
            TweenService:Create(Knob, TweenInfo.new(0.18, Enum.EasingStyle.Sine), {Position = targetPos}):Play()
        else
            Pill.BackgroundColor3 = targetColor
            Knob.Position = targetPos
        end
    end
    
    Pill.MouseButton1Click:Connect(function()
        local newState = not state
        setVisual(newState, true)
        callback(newState)
    end)
    
    table.insert(AllSearchableItems, {Card = Card, Title = title})
    return Card
end

-- Live Search Filtering
SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    local q = SearchInput.Text:lower()
    for _, item in ipairs(AllSearchableItems) do
        if q == "" or item.Title:lower():find(q) then
            item.Card.Visible = true
        else
            item.Card.Visible = false
        end
    end
end)

-- ========================================================
-- 10. CREATING PAGES & CONTROLS (Exact Match to Screenshot)
-- ========================================================

-- TABS (Essential Only: Movements, Visuals, Settings)
local MovPage, activateMov = createTab("Movements", 1)
local VisualsPage, activateVisuals = createTab("Visuals", 2)
local SettingsPage, activateSettings = createTab("Settings", 3)

-- TAB: Movements
createInput(MovPage, "Speed", State.Speed, function(v)
    State.Speed = v
    State.SpeedEnabled = (v > 0)
    applyToEvadeTables()
end)

createInput(MovPage, "Friction", State.Friction, function(v)
    State.Friction = v
    applyToEvadeTables()
    syncEvadePhysics()
end)

createInput(MovPage, "Run Accel", State.RunAccel, function(v)
    State.RunAccel = v
    applyToEvadeTables()
end)

createInput(MovPage, "Run Deaccel", State.RunDeaccel, function(v)
    State.RunDeaccel = v
    applyToEvadeTables()
end)

createInput(MovPage, "Sprint Accel", State.SprintAccel, function(v)
    State.SprintAccel = v
    applyToEvadeTables()
end)

createInput(MovPage, "Sprint Cap", State.SprintCap, function(v)
    State.SprintCap = v
    applyToEvadeTables()
end)

createInput(MovPage, "Jump Height", State.JumpHeight, function(v)
    State.JumpHeight = v
    applyToEvadeTables()
    syncEvadePhysics()
end)

createInput(MovPage, "Jump Cap", State.JumpCap, function(v)
    State.JumpCap = v
    applyToEvadeTables()
end)

createInput(MovPage, "Jump Speed Multiplier", State.JumpSpeedMultiplier, function(v)
    State.JumpSpeedMultiplier = v
    applyToEvadeTables()
end)

createToggle(MovPage, "Bunny Hop (Bhop)", State.Bhop, function(v)
    State.Bhop = v
end)

createToggle(MovPage, "Mute Wind / Falling Sound", State.MuteWind, function(v)
    State.MuteWind = v
    if v then scanAllSounds() end
end)

-- TAB: Visuals
createToggle(VisualsPage, "Remove Darkness (Fullbright)", State.RemoveDarkness, function(v)
    applyRemoveDarkness(v)
end)

createToggle(VisualsPage, "Unlock Camera Zoom (1M studs)", State.UnlockZoom, function(v)
    applyUnlockZoom(v)
end)

-- TAB: Settings
local ColorCard = Instance.new("Frame")
ColorCard.Size = UDim2.new(0, 395, 0, 60)
ColorCard.BackgroundColor3 = Theme.CardBg
ColorCard.BorderSizePixel = 0
ColorCard.Parent = SettingsPage

local CCCorner = Instance.new("UICorner")
CCCorner.CornerRadius = UDim.new(0, 6)
CCCorner.Parent = ColorCard

local CCLabel = Instance.new("TextLabel")
CCLabel.Text = "UI Theme Accent Color"
CCLabel.Font = Enum.Font.GothamMedium
CCLabel.TextSize = 13
CCLabel.TextColor3 = Theme.TextPrimary
CCLabel.TextXAlignment = Enum.TextXAlignment.Left
CCLabel.Position = UDim2.new(0, 12, 0, 8)
CCLabel.Size = UDim2.new(0, 200, 0, 16)
CCLabel.BackgroundTransparency = 1
CCLabel.Parent = ColorCard

local Palettes = {
    {name = "Blue", color = Color3.fromRGB(37, 84, 245)},
    {name = "Cyan", color = Color3.fromRGB(0, 205, 255)},
    {name = "White", color = Color3.fromRGB(240, 240, 250)},
    {name = "Red", color = Color3.fromRGB(245, 55, 75)},
    {name = "Green", color = Color3.fromRGB(0, 225, 125)},
    {name = "Purple", color = Color3.fromRGB(175, 75, 255)},
    {name = "Gold", color = Color3.fromRGB(255, 185, 40)}
}

local ColorHolder = Instance.new("Frame")
ColorHolder.Size = UDim2.new(1, -24, 0, 22)
ColorHolder.Position = UDim2.new(0, 12, 0, 30)
ColorHolder.BackgroundTransparency = 1
ColorHolder.Parent = ColorCard

local CHLayout = Instance.new("UIListLayout")
CHLayout.FillDirection = Enum.FillDirection.Horizontal
CHLayout.Padding = UDim.new(0, 8)
CHLayout.Parent = ColorHolder

for _, pal in ipairs(Palettes) do
    local Dot = Instance.new("TextButton")
    Dot.Size = UDim2.new(0, 20, 0, 20)
    Dot.BackgroundColor3 = pal.color
    Dot.Text = ""
    Dot.AutoButtonColor = false
    Dot.Parent = ColorHolder
    
    local DCorner = Instance.new("UICorner")
    DCorner.CornerRadius = UDim.new(1, 0)
    DCorner.Parent = Dot
    
    Dot.MouseButton1Click:Connect(function()
        setAccentColor(pal.color)
        if CurrentTab and TabButtons[CurrentTab] then
            TabButtons[CurrentTab].BackgroundColor3 = pal.color
        end
    end)
end

-- Keybind Card
local KeyCard = Instance.new("Frame")
KeyCard.Size = UDim2.new(0, 395, 0, 46)
KeyCard.BackgroundColor3 = Theme.CardBg
KeyCard.BorderSizePixel = 0
KeyCard.Parent = SettingsPage

local KCorner = Instance.new("UICorner")
KCorner.CornerRadius = UDim.new(0, 6)
KCorner.Parent = KeyCard

local KLabel = Instance.new("TextLabel")
KLabel.Text = "Menu Toggle Keybind"
KLabel.Font = Enum.Font.GothamMedium
KLabel.TextSize = 13
KLabel.TextColor3 = Theme.TextPrimary
KLabel.TextXAlignment = Enum.TextXAlignment.Left
KLabel.Position = UDim2.new(0, 12, 0, 0)
KLabel.Size = UDim2.new(1, -120, 1, 0)
KLabel.BackgroundTransparency = 1
KLabel.Parent = KeyCard

local KeyBtn = Instance.new("TextButton")
KeyBtn.Size = UDim2.new(0, 100, 0, 28)
KeyBtn.Position = UDim2.new(1, -112, 0.5, -14)
KeyBtn.BackgroundColor3 = Theme.InputBoxBg
KeyBtn.Text = "[" .. State.ToggleKey.Name .. "]"
KeyBtn.Font = Enum.Font.GothamBold
KeyBtn.TextSize = 11
KeyBtn.TextColor3 = Color3.fromRGB(240, 240, 250)
KeyBtn.Parent = KeyCard

local KBCorner = Instance.new("UICorner")
KBCorner.CornerRadius = UDim.new(0, 6)
KBCorner.Parent = KeyBtn

KeyBtn.MouseButton1Click:Connect(function()
    if State.IsBindingKey then return end
    State.IsBindingKey = true
    KeyBtn.Text = "[Press Key...]"
    KeyBtn.TextColor3 = Color3.fromRGB(255, 200, 60)
    
    local conn
    conn = UserInputService.InputBegan:Connect(function(input, gpe)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            conn:Disconnect()
            State.ToggleKey = input.KeyCode
            State.IsBindingKey = false
            KeyBtn.Text = "[" .. input.KeyCode.Name .. "]"
            KeyBtn.TextColor3 = Color3.fromRGB(240, 240, 250)
        end
    end)
end)

-- Unload Card
local UnloadBtn = Instance.new("TextButton")
UnloadBtn.Size = UDim2.new(0, 395, 0, 38)
UnloadBtn.BackgroundColor3 = Color3.fromRGB(200, 45, 55)
UnloadBtn.Text = "Unload Zerox Hub"
UnloadBtn.Font = Enum.Font.GothamBold
UnloadBtn.TextSize = 13
UnloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
UnloadBtn.Parent = SettingsPage

local UBCorner = Instance.new("UICorner")
UBCorner.CornerRadius = UDim.new(0, 6)
UBCorner.Parent = UnloadBtn

-- Total Kill / Exit Function (Immediate Destruction & Total Deactivation)
local function killHub()
    -- 1. Disable all state flags
    State.Bhop = false
    State.MuteWind = false
    State.SpeedEnabled = false
    State.Speed = 0
    State.JumpHeight = 1
    
    -- 2. Restore Visuals
    pcall(function() applyRemoveDarkness(false) end)
    pcall(function() applyUnlockZoom(false) end)
    
    -- 3. Reset Evade memory tables to factory defaults
    for _, tbl in ipairs(EvadeTables) do
        pcall(function()
            if rawget(tbl, "Speed") ~= nil then tbl.Speed = 1500 end
            if rawget(tbl, "speed") ~= nil then tbl.speed = 1500 end
            if rawget(tbl, "Friction") ~= nil then tbl.Friction = 5 end
            if rawget(tbl, "friction") ~= nil then tbl.friction = 5 end
            if rawget(tbl, "RunAccel") ~= nil then tbl.RunAccel = 1 end
            if rawget(tbl, "RunDeaccel") ~= nil then tbl.RunDeaccel = 700 end
            if rawget(tbl, "RunDeccel") ~= nil then tbl.RunDeccel = 700 end
            if rawget(tbl, "SprintAccel") ~= nil then tbl.SprintAccel = 1 end
            if rawget(tbl, "SprintCap") ~= nil then tbl.SprintCap = 2 end
            if rawget(tbl, "JumpHeight") ~= nil then tbl.JumpHeight = 1 end
            if rawget(tbl, "JumpCap") ~= nil then tbl.JumpCap = 1 end
            if rawget(tbl, "JumpSpeedMultiplier") ~= nil then tbl.JumpSpeedMultiplier = 1 end
        end)
    end
    table.clear(EvadeTables)
    
    -- 4. Reset Character physics & humanoid
    local hum = getHumanoid()
    if hum then
        pcall(function()
            hum.WalkSpeed = State.DefaultSpeed or 16
            hum.JumpHeight = 7.2
            hum.JumpPower = 50
        end)
    end
    
    local root = getRoot()
    if root then
        pcall(function()
            root.CustomPhysicalProperties = nil
        end)
    end
    
    -- 5. Restore sounds volume
    pcall(function()
        for _, s in ipairs(SoundService:GetDescendants()) do
            if s:IsA("Sound") and s.Volume == 0 then
                s.Volume = 0.5
            end
        end
    end)
    
    -- 6. Disconnect all runtime loops
    for _, conn in ipairs(ActiveConnections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(ActiveConnections)
    
    -- 7. Destroy GUI immediately
    pcall(function()
        Backdrop.Visible = false
        ScreenGui.Enabled = false
        ScreenGui:Destroy()
    end)
    pcall(function()
        if ParentContainer and ParentContainer:FindFirstChild("ZeroxHubGui") then
            ParentContainer.ZeroxHubGui:Destroy()
        end
    end)
    
    print("[Zerox Hub] Total Kill Executed. Everything deactivated & unloaded.")
end

-- Connect across multiple events so it never fails to trigger
CloseBtn.MouseButton1Click:Connect(killHub)
CloseBtn.Activated:Connect(killHub)
CloseBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        killHub()
    end
end)

UnloadBtn.MouseButton1Click:Connect(killHub)
UnloadBtn.Activated:Connect(killHub)

-- Default Tab: Movements (Selected by default)
activateMov()

-- Menu Toggle Keybind
table.insert(ActiveConnections, UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and not State.IsBindingKey then
        if input.KeyCode == State.ToggleKey or (State.ToggleKey == Enum.KeyCode.RightControl and input.KeyCode == Enum.KeyCode.RightShift) then
            Backdrop.Visible = not Backdrop.Visible
        end
    end
end))

-- ========================================================
-- 11. ANIMATED INTRO LOADER & OPENING
-- ========================================================
local function runLoader(onComplete)
    local Splash = Instance.new("Frame")
    Splash.Name = "ZeroxSplash"
    Splash.Size = UDim2.new(0, 0, 0, 0)
    Splash.Position = UDim2.new(0.5, 0, 0.5, 0)
    Splash.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    Splash.BorderSizePixel = 0
    Splash.ClipsDescendants = true
    Splash.Parent = ScreenGui
    
    local SCorner = Instance.new("UICorner")
    SCorner.CornerRadius = UDim.new(0, 10)
    SCorner.Parent = Splash
    
    local SStroke = Instance.new("UIStroke")
    SStroke.Thickness = 1.4
    SStroke.Color = Theme.CurrentAccent
    SStroke.Parent = Splash
    
    local STitle = Instance.new("TextLabel")
    STitle.Text = "ZEROX HUB"
    STitle.Font = Enum.Font.GothamBold
    STitle.TextSize = 18
    STitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    STitle.Position = UDim2.new(0, 20, 0, 16)
    STitle.Size = UDim2.new(0, 130, 0, 22)
    STitle.TextXAlignment = Enum.TextXAlignment.Left
    STitle.BackgroundTransparency = 1
    STitle.Parent = Splash
    
    local SBadge = Instance.new("TextLabel")
    SBadge.Text = "Free"
    SBadge.Font = Enum.Font.GothamBold
    SBadge.TextSize = 14
    SBadge.TextColor3 = Theme.CurrentAccent
    SBadge.Position = UDim2.new(0, 142, 0, 18)
    SBadge.Size = UDim2.new(0, 40, 0, 20)
    SBadge.BackgroundTransparency = 1
    SBadge.Parent = Splash
    
    local SStatus = Instance.new("TextLabel")
    SStatus.Text = "Initializing Evade Movement Matrix..."
    SStatus.Font = Enum.Font.GothamMedium
    SStatus.TextSize = 11
    SStatus.TextColor3 = Theme.TextSecondary
    SStatus.Position = UDim2.new(0, 20, 0, 52)
    SStatus.Size = UDim2.new(1, -40, 0, 16)
    SStatus.TextXAlignment = Enum.TextXAlignment.Left
    SStatus.BackgroundTransparency = 1
    SStatus.Parent = Splash
    
    local STrack = Instance.new("Frame")
    STrack.Size = UDim2.new(1, -40, 0, 6)
    STrack.Position = UDim2.new(0, 20, 0, 78)
    STrack.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    STrack.BorderSizePixel = 0
    STrack.Parent = Splash
    
    local STCorner = Instance.new("UICorner")
    STCorner.CornerRadius = UDim.new(1, 0)
    STCorner.Parent = STrack
    
    local SFill = Instance.new("Frame")
    SFill.Size = UDim2.new(0, 0, 1, 0)
    SFill.BackgroundColor3 = Theme.CurrentAccent
    SFill.BorderSizePixel = 0
    SFill.Parent = STrack
    
    local SFCorner = Instance.new("UICorner")
    SFCorner.CornerRadius = UDim.new(1, 0)
    SFCorner.Parent = SFill
    
    TweenService:Create(Splash, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 320, 0, 110),
        Position = UDim2.new(0.5, -160, 0.5, -55)
    }):Play()
    
    task.spawn(function()
        task.wait(0.3)
        TweenService:Create(SFill, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {Size = UDim2.new(0.4, 0, 1, 0)}):Play()
        SStatus.Text = "Loading Evade physics & bypasses..."
        task.wait(0.35)
        
        TweenService:Create(SFill, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {Size = UDim2.new(0.8, 0, 1, 0)}):Play()
        SStatus.Text = "Hooking bhop & sound suppressor..."
        task.wait(0.35)
        
        TweenService:Create(SFill, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {Size = UDim2.new(1, 0, 1, 0)}):Play()
        SStatus.Text = "Ready! Loading interface..."
        task.wait(0.25)
        
        local tw = TweenService:Create(Splash, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 280, 0, 0),
            Position = UDim2.new(0.5, -140, 0.5, 0),
            BackgroundTransparency = 1
        })
        tw:Play()
        tw.Completed:Connect(function()
            pcall(function() Splash:Destroy() end)
            if onComplete then onComplete() end
        end)
    end)
end

runLoader(function()
    Backdrop.Visible = true
    Backdrop.Size = UDim2.new(0, 0, 0, 0)
    Backdrop.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    TweenService:Create(Backdrop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 560, 0, 420),
        Position = UDim2.new(0.5, -280, 0.5, -210)
    }):Play()
    
    print("[Zerox Hub v1.0] Obsidian Dark UI loaded successfully.")
end)
