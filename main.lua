--[=[
    ========================================================
    ZER0X HUB v1.0 (Black & White Clean Fixed Edition)
    Target: Roblox / Luau
    
    FEATURES:
      - 🎨 Black & White (Monochrome) Minimalist Fixed Design
      - 🌈 Dynamic Theme Accent Picker in Settings (White, Cyan, Red, Green, Purple, Gold)
      - ⌨️ Custom Toggle Keybind Selector (Bind any key interactively)
      - 💫 Smooth Elastic Entrance & Open/Close Animation
      - 🔇 Silent Speed (Mute Wind & Falling noise)
      - ⚡ Super Speed Lock (up to 150 stud/s, Dual Velocity + CFrame)
      - 🐇 Bunny Hop (Bhop) auto-hop
      - ☀️ Natural Fullbright (Calibrated 140 ambient, zero glare)
      - 🔭 Infinite Camera Zoom (1,000,000 studs)
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
    return LocalPlayer:WaitForChild("PlayerGui")
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
-- 3. THEME & ACCENT SYSTEM
-- ========================================================
local Theme = {
    CurrentAccent = Color3.fromRGB(255, 255, 255), -- Monochrome default (White)
    BackgroundDark = Color3.fromRGB(10, 10, 12),
    MainFrameBg = Color3.fromRGB(16, 16, 20),
    CardBg = Color3.fromRGB(23, 23, 28),
    CardBgActive = Color3.fromRGB(30, 30, 36),
    CardBorder = Color3.fromRGB(42, 42, 50),
    TextPrimary = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(140, 140, 150),
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
-- 4. STATE & SETTINGS
-- ========================================================
local State = {
    Bhop = false,
    SprintCap = false,
    SprintSpeed = 50,
    DefaultSpeed = 16,
    RemoveDarkness = false,
    UnlockZoom = false,
    MuteWind = true,
    ToggleKey = Enum.KeyCode.RightControl,
    IsBindingKey = false,
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
-- 6. ULTRA SPEED & MOVEMENT ENGINES (100% NORMAL JUMP)
-- ========================================================
table.insert(ActiveConnections, RunService.Heartbeat:Connect(function(dt)
    if State.SprintCap then
        local hum = getHumanoid()
        local root = getRoot()
        if hum and hum.Health > 0 and root then
            hum.WalkSpeed = State.SprintSpeed
            local moveDir = getMovementVector()
            if moveDir then
                -- Modify only horizontal velocity (X & Z); leave Y strictly to native Roblox physics
                root.AssemblyLinearVelocity = Vector3.new(
                    moveDir.X * State.SprintSpeed,
                    root.AssemblyLinearVelocity.Y,
                    moveDir.Z * State.SprintSpeed
                )
            end
        end
    end
end))

table.insert(ActiveConnections, RunService.RenderStepped:Connect(function(dt)
    if State.SprintCap then
        local hum = getHumanoid()
        local root = getRoot()
        if hum and hum.Health > 0 and root then
            local moveDir = getMovementVector()
            -- Apply horizontal CFrame only when on the ground to prevent physics launch
            if moveDir and hum.FloorMaterial ~= Enum.Material.Air then
                local horizontalVel = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
                if horizontalVel < (State.SprintSpeed * 0.75) then
                    local flatDir = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
                    root.CFrame = root.CFrame + (flatDir * (State.SprintSpeed * dt))
                end
            end
        end
    end
end))

-- Natural Bunny Hop Engine (100% Normal Jump - Zero Air-Walk / Zero Sky Floating)
local lastBhopTick = 0
local function isStrictlyGrounded(root, hum)
    if not hum or not root then return false end
    
    -- 1. Native Roblox ground detection
    if hum.FloorMaterial ~= Enum.Material.Air then
        return true
    end
    
    -- 2. State Check: If in Freefall or Jumping, strictly in the air!
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
        return false
    end
    
    -- 3. Precision Soles-of-Feet Raycast (strictly within 0.35 studs of feet on a solid part)
    if root.AssemblyLinearVelocity.Y <= 0.2 then
        local hip = (hum.HipHeight and hum.HipHeight > 0) and hum.HipHeight or 2.0
        local rootHalf = (root.Size and root.Size.Y > 0) and (root.Size.Y / 2) or 1.0
        local soleDistance = hip + rootHalf + 0.35
        
        local params = RaycastParams.new()
        params.FilterType = RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {getChar(), workspace.CurrentCamera}
        params.IgnoreWater = true
        
        local res = workspace:Raycast(root.Position, Vector3.new(0, -soleDistance, 0), params)
        if res and res.Instance and res.Instance.CanCollide and res.Instance.Transparency < 0.8 then
            return true
        end
    end
    
    return false
end

table.insert(ActiveConnections, RunService.RenderStepped:Connect(function()
    if State.Bhop and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        local hum = getHumanoid()
        local root = getRoot()
        if hum and hum.Health > 0 and root then
            if (tick() - lastBhopTick > 0.22) and isStrictlyGrounded(root, hum) then
                lastBhopTick = tick()
                hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                hum.Jump = true
            end
        end
    end
end))

local function applySprintCap(enabled)
    State.SprintCap = enabled
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = enabled and State.SprintSpeed or State.DefaultSpeed
    end
    if ToggleUpdaters["SprintCap"] then
        ToggleUpdaters["SprintCap"](enabled)
    end
end

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
    
    local char = getChar()
    if char then
        for _, part in ipairs(char:GetChildren()) do
            local pl = part:FindFirstChild("ZeroxFullbrightLight")
            if pl then pcall(function() pl:Destroy() end) end
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
    if State.SprintCap then applySprintCap(true) end
    if State.RemoveDarkness then enforceFullbright() end
end))

-- ========================================================
-- 8. CLEAN 3D MONOCHROME GUI SYSTEM (FIXED)
-- ========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZeroxHubGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = ParentContainer

-- Fixed 3D Depth Shadow Backdrop
local Backdrop = Instance.new("Frame")
Backdrop.Name = "Backdrop"
Backdrop.Size = UDim2.new(0, 550, 0, 400)
Backdrop.Position = UDim2.new(0.5, -275, 0.5, -200)
Backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Backdrop.BackgroundTransparency = 0.4
Backdrop.BorderSizePixel = 0
Backdrop.Visible = false
Backdrop.Parent = ScreenGui

local BCorner = Instance.new("UICorner")
BCorner.CornerRadius = UDim.new(0, 16)
BCorner.Parent = Backdrop

-- Main Elevated Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(1, 0, 1, 0)
MainFrame.Position = UDim2.new(0, -3, 0, -4)
MainFrame.BackgroundColor3 = Theme.MainFrameBg
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = Backdrop

local MCorner = Instance.new("UICorner")
MCorner.CornerRadius = UDim.new(0, 14)
MCorner.Parent = MainFrame

local MStroke = Instance.new("UIStroke")
MStroke.Thickness = 1.8
MStroke.Color = Theme.CurrentAccent
MStroke.Transparency = 0.1
MStroke.Parent = MainFrame

registerAccentListener(function(accent)
    TweenService:Create(MStroke, TweenInfo.new(0.3), {Color = accent}):Play()
end)

local MGradient = Instance.new("UIGradient")
MGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 26, 32)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(16, 16, 20)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 13))
})
MGradient.Rotation = 45
MGradient.Parent = MainFrame

-- Topbar
local Topbar = Instance.new("Frame")
Topbar.Name = "Topbar"
Topbar.Size = UDim2.new(1, 0, 0, 48)
Topbar.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
Topbar.BackgroundTransparency = 0.2
Topbar.BorderSizePixel = 0
Topbar.Parent = MainFrame

local TopbarLine = Instance.new("Frame")
TopbarLine.Size = UDim2.new(1, 0, 0, 1)
TopbarLine.Position = UDim2.new(0, 0, 1, -1)
TopbarLine.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
TopbarLine.BorderSizePixel = 0
TopbarLine.Parent = Topbar

local Title = Instance.new("TextLabel")
Title.Text = "ZEROX HUB"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Position = UDim2.new(0, 18, 0, 0)
Title.Size = UDim2.new(0, 110, 1, 0)
Title.BackgroundTransparency = 1
Title.Parent = Topbar

local Badge = Instance.new("Frame")
Badge.Size = UDim2.new(0, 42, 0, 20)
Badge.Position = UDim2.new(0, 132, 0.5, -10)
Badge.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Badge.BorderSizePixel = 0
Badge.Parent = Topbar

local BadgeCorner = Instance.new("UICorner")
BadgeCorner.CornerRadius = UDim.new(0, 6)
BadgeCorner.Parent = Badge

local BadgeText = Instance.new("TextLabel")
BadgeText.Size = UDim2.new(1, 0, 1, 0)
BadgeText.Text = "v1.0"
BadgeText.Font = Enum.Font.GothamBold
BadgeText.TextSize = 10
BadgeText.TextColor3 = Color3.fromRGB(10, 10, 12)
BadgeText.BackgroundTransparency = 1
BadgeText.Parent = Badge

registerAccentListener(function(accent)
    TweenService:Create(Badge, TweenInfo.new(0.3), {BackgroundColor3 = accent}):Play()
end)

local NotifyText = Instance.new("TextLabel")
NotifyText.Size = UDim2.new(0, 240, 0, 24)
NotifyText.Position = UDim2.new(1, -280, 0, 12)
NotifyText.BackgroundTransparency = 1
NotifyText.Font = Enum.Font.GothamSemibold
NotifyText.TextSize = 11
NotifyText.TextColor3 = Color3.fromRGB(255, 255, 255)
NotifyText.TextXAlignment = Enum.TextXAlignment.Right
NotifyText.Text = ""
NotifyText.Parent = Topbar

registerAccentListener(function(accent)
    NotifyText.TextColor3 = accent
end)

local function showNotify(msg)
    NotifyText.Text = "● " .. msg
    NotifyText.TextTransparency = 0
    task.delay(2.2, function()
        TweenService:Create(NotifyText, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
    end)
end

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -38, 0, 10)
CloseBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
CloseBtn.Text = "×"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18
CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
CloseBtn.Parent = Topbar

local CBCorner = Instance.new("UICorner")
CBCorner.CornerRadius = UDim.new(0, 8)
CBCorner.Parent = CloseBtn

local CBStroke = Instance.new("UIStroke")
CBStroke.Thickness = 1
CBStroke.Color = Color3.fromRGB(45, 45, 55)
CBStroke.Parent = CloseBtn

CloseBtn.MouseEnter:Connect(function()
    TweenService:Create(CloseBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(230, 45, 60),
        TextColor3 = Color3.fromRGB(255, 255, 255)
    }):Play()
end)

CloseBtn.MouseLeave:Connect(function()
    TweenService:Create(CloseBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(28, 28, 34),
        TextColor3 = Color3.fromRGB(200, 200, 210)
    }):Play()
end)

local function toggleMenuAnimated(visible)
    if visible then
        Backdrop.Visible = true
        Backdrop.Size = UDim2.new(0, 500, 0, 360)
        Backdrop.Position = UDim2.new(0.5, -250, 0.5, -180)
        TweenService:Create(Backdrop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 550, 0, 400),
            Position = UDim2.new(0.5, -275, 0.5, -200)
        }):Play()
    else
        local tw = TweenService:Create(Backdrop, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 480, 0, 350),
            Position = UDim2.new(0.5, -240, 0.5, -175)
        })
        tw:Play()
        tw.Completed:Connect(function()
            if not Backdrop.Visible then return end
            Backdrop.Visible = false
        end)
    end
end

local function killHub()
    -- 1. Deactivate all features
    State.Bhop = false
    State.MuteWind = false
    applySprintCap(false)
    applyRemoveDarkness(false)
    applyUnlockZoom(false)
    
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = State.DefaultSpeed
    end
    
    -- 2. Disconnect all runtime loops and event hooks
    for _, conn in ipairs(ActiveConnections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(ActiveConnections)
    
    -- 3. Animate exit and destroy GUI completely
    pcall(function()
        local tw = TweenService:Create(Backdrop, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundTransparency = 1
        })
        tw:Play()
        tw.Completed:Connect(function()
            pcall(function() ScreenGui:Destroy() end)
        end)
    end)
    
    task.delay(0.28, function()
        pcall(function() ScreenGui:Destroy() end)
    end)
    
    print("[Zerox Hub] Hub killed completely. All features deactivated.")
end

CloseBtn.MouseButton1Click:Connect(killHub)

-- Smooth Dragging
local isDragging = false
local dragStart, startPos, dragInput

Topbar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStart = input.Position
        startPos = Backdrop.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                isDragging = false
            end
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
        local target = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        TweenService:Create(Backdrop, TweenInfo.new(0.06, Enum.EasingStyle.Sine), {Position = target}):Play()
    end
end)

-- Sidebar Vertical Divider
local SDivider = Instance.new("Frame")
SDivider.Name = "SDivider"
SDivider.Size = UDim2.new(0, 1, 1, -48)
SDivider.Position = UDim2.new(0, 138, 0, 48)
SDivider.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
SDivider.BorderSizePixel = 0
SDivider.ZIndex = 4
SDivider.Parent = MainFrame

-- Sidebar Container
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 138, 1, -48)
Sidebar.Position = UDim2.new(0, 0, 0, 48)
Sidebar.BackgroundColor3 = Color3.fromRGB(13, 13, 16)
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 2
Sidebar.Parent = MainFrame

local SLayout = Instance.new("UIListLayout")
SLayout.Padding = UDim.new(0, 8)
SLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SLayout.SortOrder = Enum.SortOrder.LayoutOrder
SLayout.Parent = Sidebar

local SPadding = Instance.new("UIPadding")
SPadding.PaddingTop = UDim.new(0, 14)
SPadding.Parent = Sidebar

-- Content Frame
local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, -139, 1, -48)
ContentFrame.Position = UDim2.new(0, 139, 0, 48)
ContentFrame.BackgroundTransparency = 1
ContentFrame.ClipsDescendants = true
ContentFrame.Parent = MainFrame

-- Tabs System
local Pages = {}
local TabBtns = {}
local activeTabName = nil

local function createTab(tabName, order)
    local Btn = Instance.new("TextButton")
    Btn.Name = tabName .. "TabBtn"
    Btn.Size = UDim2.new(0, 118, 0, 38)
    Btn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    Btn.Text = tabName
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 13
    Btn.TextColor3 = Color3.fromRGB(150, 150, 160)
    Btn.LayoutOrder = order
    Btn.ZIndex = 5
    Btn.AutoButtonColor = false
    Btn.Parent = Sidebar
    
    local BCorner = Instance.new("UICorner")
    BCorner.CornerRadius = UDim.new(0, 8)
    BCorner.Parent = Btn
    
    local BStroke = Instance.new("UIStroke")
    BStroke.Thickness = 1.2
    BStroke.Color = Color3.fromRGB(36, 36, 44)
    BStroke.Parent = Btn
    
    local Page = Instance.new("ScrollingFrame")
    Page.Name = tabName .. "Page"
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.ScrollBarThickness = 3
    Page.ScrollBarImageColor3 = Theme.CurrentAccent
    Page.BorderSizePixel = 0
    Page.Visible = false
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Page.Parent = ContentFrame
    
    registerAccentListener(function(accent)
        Page.ScrollBarImageColor3 = accent
    end)
    
    local PLayout = Instance.new("UIListLayout")
    PLayout.Padding = UDim.new(0, 10)
    PLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    PLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PLayout.Parent = Page
    
    local PPadding = Instance.new("UIPadding")
    PPadding.PaddingTop = UDim.new(0, 12)
    PPadding.PaddingBottom = UDim.new(0, 14)
    PPadding.Parent = Page
    
    local function updateTabAppearance()
        local isCurrent = (activeTabName == tabName)
        if isCurrent then
            local isMonochrome = (Theme.CurrentAccent.R > 0.9 and Theme.CurrentAccent.G > 0.9 and Theme.CurrentAccent.B > 0.9)
            local bg = isMonochrome and Color3.fromRGB(245, 245, 250) or Theme.CurrentAccent
            local tx = isMonochrome and Color3.fromRGB(10, 10, 12) or Color3.fromRGB(255, 255, 255)
            
            TweenService:Create(Btn, TweenInfo.new(0.2), {
                BackgroundColor3 = bg,
                TextColor3 = tx
            }):Play()
            BStroke.Color = bg
        else
            TweenService:Create(Btn, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(20, 20, 25),
                TextColor3 = Color3.fromRGB(150, 150, 160)
            }):Play()
            BStroke.Color = Color3.fromRGB(36, 36, 44)
        end
    end
    
    registerAccentListener(function()
        updateTabAppearance()
    end)
    
    local function activate()
        activeTabName = tabName
        for name, other in pairs(Pages) do
            if name == tabName then
                other.Visible = true
                other.Position = UDim2.new(0, 12, 0, 0)
                other.CanvasPosition = Vector2.new(0, 0)
                TweenService:Create(other, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = UDim2.new(0, 0, 0, 0)}):Play()
            else
                other.Visible = false
            end
        end
        for _, b in pairs(TabBtns) do
            b.UpdateAppearance()
        end
    end
    
    Btn.MouseButton1Click:Connect(activate)
    Pages[tabName] = Page
    TabBtns[tabName] = {Btn = Btn, UpdateAppearance = updateTabAppearance}
    
    return Page, activate
end

-- ========================================================
-- 9. 3D CARD TOGGLE & AUTO-ACTIVATE SLIDER
-- ========================================================
local function createToggle(parent, idKey, title, subtitle, defaultState, callback)
    local Card = Instance.new("TextButton")
    Card.Name = title .. "Card"
    Card.Size = UDim2.new(0, 385, 0, 56)
    Card.BackgroundColor3 = Theme.CardBg
    Card.BorderSizePixel = 0
    Card.Text = ""
    Card.AutoButtonColor = false
    Card.Parent = parent
    
    local CCorner = Instance.new("UICorner")
    CCorner.CornerRadius = UDim.new(0, 10)
    CCorner.Parent = Card
    
    local CStroke = Instance.new("UIStroke")
    CStroke.Thickness = 1.2
    CStroke.Color = defaultState and Theme.CurrentAccent or Theme.CardBorder
    CStroke.Parent = Card
    
    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Text = title
    TitleLbl.Font = Enum.Font.GothamBold
    TitleLbl.TextSize = 13
    TitleLbl.TextColor3 = Theme.TextPrimary
    TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    TitleLbl.Position = UDim2.new(0, 14, 0, 9)
    TitleLbl.Size = UDim2.new(0, 250, 0, 16)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Parent = Card
    
    local SubLbl = Instance.new("TextLabel")
    SubLbl.Text = subtitle or ""
    SubLbl.Font = Enum.Font.Gotham
    SubLbl.TextSize = 10
    SubLbl.TextColor3 = Theme.TextSecondary
    SubLbl.TextXAlignment = Enum.TextXAlignment.Left
    SubLbl.Position = UDim2.new(0, 14, 0, 28)
    SubLbl.Size = UDim2.new(0, 250, 0, 18)
    SubLbl.BackgroundTransparency = 1
    SubLbl.Parent = Card
    
    local Pill = Instance.new("Frame")
    Pill.Size = UDim2.new(0, 50, 0, 24)
    Pill.Position = UDim2.new(1, -64, 0.5, -12)
    Pill.BackgroundColor3 = defaultState and Theme.CurrentAccent or Color3.fromRGB(36, 36, 44)
    Pill.BorderSizePixel = 0
    Pill.Parent = Card
    
    local PCorner = Instance.new("UICorner")
    PCorner.CornerRadius = UDim.new(1, 0)
    PCorner.Parent = Pill
    
    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 18, 0, 18)
    Knob.Position = defaultState and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    Knob.BackgroundColor3 = defaultState and Color3.fromRGB(15, 15, 18) or Color3.fromRGB(240, 240, 245)
    Knob.BorderSizePixel = 0
    Knob.Parent = Pill
    
    local KCorner = Instance.new("UICorner")
    KCorner.CornerRadius = UDim.new(1, 0)
    KCorner.Parent = Knob
    
    local state = defaultState
    
    local function setVisual(active, animated)
        state = active
        local targetPillColor = active and Theme.CurrentAccent or Color3.fromRGB(36, 36, 44)
        local targetKnobPos = active and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        local targetKnobColor = active and Color3.fromRGB(15, 15, 18) or Color3.fromRGB(240, 240, 245)
        local strokeColor = active and Theme.CurrentAccent or Theme.CardBorder
        local cardBg = active and Theme.CardBgActive or Theme.CardBg
        
        if animated then
            TweenService:Create(Pill, TweenInfo.new(0.2), {BackgroundColor3 = targetPillColor}):Play()
            TweenService:Create(Knob, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = targetKnobPos,
                BackgroundColor3 = targetKnobColor
            }):Play()
            TweenService:Create(CStroke, TweenInfo.new(0.2), {Color = strokeColor}):Play()
            TweenService:Create(Card, TweenInfo.new(0.2), {BackgroundColor3 = cardBg}):Play()
        else
            Pill.BackgroundColor3 = targetPillColor
            Knob.Position = targetKnobPos
            Knob.BackgroundColor3 = targetKnobColor
            CStroke.Color = strokeColor
            Card.BackgroundColor3 = cardBg
        end
    end
    
    registerAccentListener(function()
        if state then setVisual(true, false) end
    end)
    
    Card.MouseEnter:Connect(function()
        if not state then
            TweenService:Create(Card, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(28, 28, 34)}):Play()
            TweenService:Create(CStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(58, 58, 70)}):Play()
        end
    end)
    
    Card.MouseLeave:Connect(function()
        if not state then
            TweenService:Create(Card, TweenInfo.new(0.15), {BackgroundColor3 = Theme.CardBg}):Play()
            TweenService:Create(CStroke, TweenInfo.new(0.15), {Color = Theme.CardBorder}):Play()
        end
    end)
    
    Card.MouseButton1Click:Connect(function()
        local newState = not state
        setVisual(newState, true)
        callback(newState)
        showNotify(title .. ": " .. (newState and "ENABLED" or "DISABLED"))
    end)
    
    if idKey then
        ToggleUpdaters[idKey] = function(val)
            setVisual(val, true)
        end
    end
    
    setVisual(state, false)
    return Card
end

local function createSlider(parent, title, minVal, maxVal, defaultVal, callback)
    local Card = Instance.new("Frame")
    Card.Size = UDim2.new(0, 385, 0, 66)
    Card.BackgroundColor3 = Theme.CardBg
    Card.BorderSizePixel = 0
    Card.Parent = parent
    
    local CCorner = Instance.new("UICorner")
    CCorner.CornerRadius = UDim.new(0, 10)
    CCorner.Parent = Card
    
    local CStroke = Instance.new("UIStroke")
    CStroke.Thickness = 1.2
    CStroke.Color = Theme.CardBorder
    CStroke.Parent = Card
    
    local Lbl = Instance.new("TextLabel")
    Lbl.Text = title
    Lbl.Font = Enum.Font.GothamBold
    Lbl.TextSize = 13
    Lbl.TextColor3 = Theme.TextPrimary
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Position = UDim2.new(0, 14, 0, 9)
    Lbl.Size = UDim2.new(0, 200, 0, 16)
    Lbl.BackgroundTransparency = 1
    Lbl.Parent = Card
    
    local ValLbl = Instance.new("TextLabel")
    ValLbl.Text = tostring(defaultVal) .. " stud/s"
    ValLbl.Font = Enum.Font.GothamSemibold
    ValLbl.TextSize = 12
    ValLbl.TextColor3 = Theme.CurrentAccent
    ValLbl.TextXAlignment = Enum.TextXAlignment.Right
    ValLbl.Position = UDim2.new(1, -100, 0, 9)
    ValLbl.Size = UDim2.new(0, 86, 0, 16)
    ValLbl.BackgroundTransparency = 1
    ValLbl.Parent = Card
    
    registerAccentListener(function(accent)
        ValLbl.TextColor3 = accent
    end)
    
    local Track = Instance.new("Frame")
    Track.Size = UDim2.new(1, -28, 0, 8)
    Track.Position = UDim2.new(0, 14, 0, 40)
    Track.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    Track.BorderSizePixel = 0
    Track.Parent = Card
    
    local TCorner = Instance.new("UICorner")
    TCorner.CornerRadius = UDim.new(1, 0)
    TCorner.Parent = Track
    
    local Fill = Instance.new("Frame")
    local initialRatio = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
    Fill.Size = UDim2.new(initialRatio, 0, 1, 0)
    Fill.BackgroundColor3 = Theme.CurrentAccent
    Fill.BorderSizePixel = 0
    Fill.Parent = Track
    
    registerAccentListener(function(accent)
        Fill.BackgroundColor3 = accent
    end)
    
    local FCorner = Instance.new("UICorner")
    FCorner.CornerRadius = UDim.new(1, 0)
    FCorner.Parent = Fill
    
    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 14, 0, 14)
    Knob.Position = UDim2.new(1, -7, 0.5, -7)
    Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Knob.BorderSizePixel = 0
    Knob.Parent = Fill
    
    local KCorner = Instance.new("UICorner")
    KCorner.CornerRadius = UDim.new(1, 0)
    KCorner.Parent = Knob
    
    local isSliding = false
    
    local function updateSlider(mouseX)
        local trackPos = Track.AbsolutePosition.X
        local trackSize = Track.AbsoluteSize.X
        local ratio = math.clamp((mouseX - trackPos) / trackSize, 0, 1)
        Fill.Size = UDim2.new(ratio, 0, 1, 0)
        local calculated = math.floor(minVal + (maxVal - minVal) * ratio)
        ValLbl.Text = tostring(calculated) .. " stud/s"
        callback(calculated)
    end
    
    Track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isSliding = true
            updateSlider(input.Position.X)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isSliding = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if isSliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input.Position.X)
        end
    end)
end

-- ========================================================
-- 10. BUILDING SECTIONS & FEATURES
-- ========================================================

-- TAB 1: Movement
local MovementPage, activateMovement = createTab("Movement", 1)

createToggle(MovementPage, "Bhop", "Bunny Hop (Bhop)", "Hold Spacebar for auto-hop consecutive jumps", false, function(active)
    State.Bhop = active
end)

createToggle(MovementPage, "SprintCap", "Sprint Cap / Speed Lock", "Dual-engine speed lock (Velocity + WASD CFrame Boost)", false, function(active)
    applySprintCap(active)
end)

createSlider(MovementPage, "Sprint Speed Limit", 16, 150, State.SprintSpeed, function(newVal)
    State.SprintSpeed = newVal
    applySprintCap(true)
    showNotify("Speed set to " .. tostring(newVal) .. " stud/s")
end)

createToggle(MovementPage, "MuteWind", "Mute Wind / Falling Sound", "Silences the loud rushing wind and fall sound at max speed", State.MuteWind, function(active)
    State.MuteWind = active
    if active then scanAllSounds() end
end)

-- TAB 2: Visuals
local VisualsPage, activateVisuals = createTab("Visuals", 2)

createToggle(VisualsPage, "RemoveDarkness", "Remove Darkness (Fullbright)", "Natural fullbright (calibrated 140 ambient, no eye glare)", false, function(active)
    applyRemoveDarkness(active)
end)

createToggle(VisualsPage, "UnlockZoom", "Unlock Camera Zoom", "Unlocks zoom distance up to 1,000,000 studs", false, function(active)
    applyUnlockZoom(active)
end)

-- TAB 3: Settings
local SettingsPage, activateSettings = createTab("Settings", 3)

-- 1. Theme Color Selector Card
local ColorCard = Instance.new("Frame")
ColorCard.Size = UDim2.new(0, 385, 0, 74)
ColorCard.BackgroundColor3 = Theme.CardBg
ColorCard.BorderSizePixel = 0
ColorCard.Parent = SettingsPage

local CCCorner = Instance.new("UICorner")
CCCorner.CornerRadius = UDim.new(0, 10)
CCCorner.Parent = ColorCard

local CCStroke = Instance.new("UIStroke")
CCStroke.Thickness = 1.2
CCStroke.Color = Theme.CardBorder
CCStroke.Parent = ColorCard

local CCLabel = Instance.new("TextLabel")
CCLabel.Text = "UI Theme Accent Color"
CCLabel.Font = Enum.Font.GothamBold
CCLabel.TextSize = 13
CCLabel.TextColor3 = Theme.TextPrimary
CCLabel.TextXAlignment = Enum.TextXAlignment.Left
CCLabel.Position = UDim2.new(0, 14, 0, 9)
CCLabel.Size = UDim2.new(0, 200, 0, 16)
CCLabel.BackgroundTransparency = 1
CCLabel.Parent = ColorCard

local CCSubLabel = Instance.new("TextLabel")
CCSubLabel.Text = "Choose your favorite accent color style"
CCSubLabel.Font = Enum.Font.Gotham
CCSubLabel.TextSize = 10
CCSubLabel.TextColor3 = Theme.TextSecondary
CCSubLabel.TextXAlignment = Enum.TextXAlignment.Left
CCSubLabel.Position = UDim2.new(0, 14, 0, 26)
CCSubLabel.Size = UDim2.new(0, 200, 0, 16)
CCSubLabel.BackgroundTransparency = 1
CCSubLabel.Parent = ColorCard

local Palettes = {
    {name = "White", color = Color3.fromRGB(255, 255, 255)},
    {name = "Cyan", color = Color3.fromRGB(0, 205, 255)},
    {name = "Red", color = Color3.fromRGB(255, 60, 75)},
    {name = "Green", color = Color3.fromRGB(0, 230, 130)},
    {name = "Purple", color = Color3.fromRGB(180, 80, 255)},
    {name = "Gold", color = Color3.fromRGB(255, 185, 45)}
}

local ColorHolder = Instance.new("Frame")
ColorHolder.Size = UDim2.new(0, 160, 0, 26)
ColorHolder.Position = UDim2.new(1, -170, 0.5, -13)
ColorHolder.BackgroundTransparency = 1
ColorHolder.Parent = ColorCard

local CHLayout = Instance.new("UIListLayout")
CHLayout.FillDirection = Enum.FillDirection.Horizontal
CHLayout.Padding = UDim.new(0, 6)
CHLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
CHLayout.Parent = ColorHolder

for _, pal in ipairs(Palettes) do
    local Dot = Instance.new("TextButton")
    Dot.Name = pal.name .. "Dot"
    Dot.Size = UDim2.new(0, 20, 0, 20)
    Dot.BackgroundColor3 = pal.color
    Dot.Text = ""
    Dot.AutoButtonColor = false
    Dot.Parent = ColorHolder
    
    local DCorner = Instance.new("UICorner")
    DCorner.CornerRadius = UDim.new(1, 0)
    DCorner.Parent = Dot
    
    local DStroke = Instance.new("UIStroke")
    DStroke.Thickness = 1.5
    DStroke.Color = Color3.fromRGB(40, 40, 50)
    DStroke.Parent = Dot
    
    Dot.MouseButton1Click:Connect(function()
        setAccentColor(pal.color)
        showNotify("Theme: " .. pal.name .. " Applied")
    end)
end

-- 2. Custom Keybind Selector Card
local KeyCard = Instance.new("Frame")
KeyCard.Size = UDim2.new(0, 385, 0, 56)
KeyCard.BackgroundColor3 = Theme.CardBg
KeyCard.BorderSizePixel = 0
KeyCard.Parent = SettingsPage

local KCCorner = Instance.new("UICorner")
KCCorner.CornerRadius = UDim.new(0, 10)
KCCorner.Parent = KeyCard

local KCStroke = Instance.new("UIStroke")
KCStroke.Thickness = 1.2
KCStroke.Color = Theme.CardBorder
KCStroke.Parent = KeyCard

local KCLabel = Instance.new("TextLabel")
KCLabel.Text = "Menu Toggle Keybind"
KCLabel.Font = Enum.Font.GothamBold
KCLabel.TextSize = 13
KCLabel.TextColor3 = Theme.TextPrimary
KCLabel.TextXAlignment = Enum.TextXAlignment.Left
KCLabel.Position = UDim2.new(0, 14, 0, 10)
KCLabel.Size = UDim2.new(0, 200, 0, 16)
KCLabel.BackgroundTransparency = 1
KCLabel.Parent = KeyCard

local KCSubLabel = Instance.new("TextLabel")
KCSubLabel.Text = "Click button and press any key to bind"
KCSubLabel.Font = Enum.Font.Gotham
KCSubLabel.TextSize = 10
KCSubLabel.TextColor3 = Theme.TextSecondary
KCSubLabel.TextXAlignment = Enum.TextXAlignment.Left
KCSubLabel.Position = UDim2.new(0, 14, 0, 28)
KCSubLabel.Size = UDim2.new(0, 200, 0, 16)
KCSubLabel.BackgroundTransparency = 1
KCSubLabel.Parent = KeyCard

local KeyBtn = Instance.new("TextButton")
KeyBtn.Size = UDim2.new(0, 110, 0, 32)
KeyBtn.Position = UDim2.new(1, -124, 0.5, -16)
KeyBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
KeyBtn.Text = "[" .. State.ToggleKey.Name .. "]"
KeyBtn.Font = Enum.Font.GothamBold
KeyBtn.TextSize = 11
KeyBtn.TextColor3 = Color3.fromRGB(240, 240, 250)
KeyBtn.Parent = KeyCard

local KBCorner = Instance.new("UICorner")
KBCorner.CornerRadius = UDim.new(0, 8)
KBCorner.Parent = KeyBtn

local KBStroke = Instance.new("UIStroke")
KBStroke.Thickness = 1.2
KBStroke.Color = Color3.fromRGB(50, 50, 62)
KBStroke.Parent = KeyBtn

KeyBtn.MouseButton1Click:Connect(function()
    if State.IsBindingKey then return end
    State.IsBindingKey = true
    KeyBtn.Text = "[Press Any Key...]"
    KeyBtn.TextColor3 = Color3.fromRGB(255, 200, 60)
    KBStroke.Color = Color3.fromRGB(255, 200, 60)
    
    local conn
    conn = UserInputService.InputBegan:Connect(function(input, gpe)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            conn:Disconnect()
            State.ToggleKey = input.KeyCode
            State.IsBindingKey = false
            KeyBtn.Text = "[" .. input.KeyCode.Name .. "]"
            KeyBtn.TextColor3 = Color3.fromRGB(240, 240, 250)
            KBStroke.Color = Color3.fromRGB(50, 50, 62)
            showNotify("Keybind set to " .. input.KeyCode.Name)
        end
    end)
end)

-- 3. Unload Hub Card
local DestroyCard = Instance.new("Frame")
DestroyCard.Size = UDim2.new(0, 385, 0, 50)
DestroyCard.BackgroundColor3 = Color3.fromRGB(24, 16, 18)
DestroyCard.BorderSizePixel = 0
DestroyCard.Parent = SettingsPage

local DCorner = Instance.new("UICorner")
DCorner.CornerRadius = UDim.new(0, 10)
DCorner.Parent = DestroyCard

local DStroke = Instance.new("UIStroke")
DStroke.Thickness = 1.2
DStroke.Color = Color3.fromRGB(60, 30, 35)
DStroke.Parent = DestroyCard

local DestroyBtn = Instance.new("TextButton")
DestroyBtn.Size = UDim2.new(1, -20, 1, -14)
DestroyBtn.Position = UDim2.new(0, 10, 0, 7)
DestroyBtn.BackgroundColor3 = Color3.fromRGB(220, 45, 55)
DestroyBtn.Text = "Unload Zerox Hub"
DestroyBtn.Font = Enum.Font.GothamBold
DestroyBtn.TextSize = 13
DestroyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DestroyBtn.Parent = DestroyCard

local DBCorner = Instance.new("UICorner")
DBCorner.CornerRadius = UDim.new(0, 8)
DBCorner.Parent = DestroyBtn

DestroyBtn.MouseButton1Click:Connect(killHub)

-- Default Tab Activation
activateMovement()

-- Global Keybind Listener for UI Toggle
table.insert(ActiveConnections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and not State.IsBindingKey then
        if input.KeyCode == State.ToggleKey or (State.ToggleKey == Enum.KeyCode.RightControl and input.KeyCode == Enum.KeyCode.RightShift) then
            toggleMenuAnimated(not Backdrop.Visible)
        end
    end
end))

-- ========================================================
-- 11. ANIMATED INTRO SPLASH LOADER
-- ========================================================
local function runLoader(onComplete)
    local Splash = Instance.new("Frame")
    Splash.Name = "ZeroxSplash"
    Splash.Size = UDim2.new(0, 0, 0, 0)
    Splash.Position = UDim2.new(0.5, 0, 0.5, 0)
    Splash.BackgroundColor3 = Color3.fromRGB(15, 15, 19)
    Splash.BorderSizePixel = 0
    Splash.ClipsDescendants = true
    Splash.Parent = ScreenGui
    
    local SCorner = Instance.new("UICorner")
    SCorner.CornerRadius = UDim.new(0, 14)
    SCorner.Parent = Splash
    
    local SStroke = Instance.new("UIStroke")
    SStroke.Thickness = 1.6
    SStroke.Color = Theme.CurrentAccent
    SStroke.Transparency = 0.15
    SStroke.Parent = Splash
    
    local STitle = Instance.new("TextLabel")
    STitle.Text = "ZEROX HUB"
    STitle.Font = Enum.Font.GothamBold
    STitle.TextSize = 18
    STitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    STitle.Position = UDim2.new(0, 24, 0, 20)
    STitle.Size = UDim2.new(0, 130, 0, 24)
    STitle.TextXAlignment = Enum.TextXAlignment.Left
    STitle.BackgroundTransparency = 1
    STitle.Parent = Splash
    
    local SBadge = Instance.new("Frame")
    SBadge.Size = UDim2.new(0, 42, 0, 20)
    SBadge.Position = UDim2.new(0, 156, 0, 22)
    SBadge.BackgroundColor3 = Theme.CurrentAccent
    SBadge.BorderSizePixel = 0
    SBadge.Parent = Splash
    
    local SBadgeCorner = Instance.new("UICorner")
    SBadgeCorner.CornerRadius = UDim.new(0, 6)
    SBadgeCorner.Parent = SBadge
    
    local SBadgeText = Instance.new("TextLabel")
    SBadgeText.Size = UDim2.new(1, 0, 1, 0)
    SBadgeText.Text = "v1.0"
    SBadgeText.Font = Enum.Font.GothamBold
    SBadgeText.TextSize = 10
    SBadgeText.TextColor3 = Color3.fromRGB(10, 10, 12)
    SBadgeText.BackgroundTransparency = 1
    SBadgeText.Parent = SBadge
    
    local SStatus = Instance.new("TextLabel")
    SStatus.Text = "Initializing Zerox Core..."
    SStatus.Font = Enum.Font.GothamMedium
    SStatus.TextSize = 11
    SStatus.TextColor3 = Color3.fromRGB(140, 140, 155)
    SStatus.Position = UDim2.new(0, 24, 0, 64)
    SStatus.Size = UDim2.new(1, -90, 0, 18)
    SStatus.TextXAlignment = Enum.TextXAlignment.Left
    SStatus.BackgroundTransparency = 1
    SStatus.Parent = Splash
    
    local SPercent = Instance.new("TextLabel")
    SPercent.Text = "0%"
    SPercent.Font = Enum.Font.GothamBold
    SPercent.TextSize = 12
    SPercent.TextColor3 = Theme.CurrentAccent
    SPercent.Position = UDim2.new(1, -74, 0, 64)
    SPercent.Size = UDim2.new(0, 50, 0, 18)
    SPercent.TextXAlignment = Enum.TextXAlignment.Right
    SPercent.BackgroundTransparency = 1
    SPercent.Parent = Splash
    
    local STrack = Instance.new("Frame")
    STrack.Size = UDim2.new(1, -48, 0, 7)
    STrack.Position = UDim2.new(0, 24, 0, 92)
    STrack.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
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
    
    -- Pop-in Splash Window
    TweenService:Create(Splash, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 360, 0, 132),
        Position = UDim2.new(0.5, -180, 0.5, -66)
    }):Play()
    
    task.spawn(function()
        task.wait(0.35)
        
        -- Stage 1
        TweenService:Create(SFill, TweenInfo.new(0.35, Enum.EasingStyle.Sine), {Size = UDim2.new(0.3, 0, 1, 0)}):Play()
        SStatus.Text = "Scanning environment & physics..."
        SPercent.Text = "30%"
        task.wait(0.4)
        
        -- Stage 2
        TweenService:Create(SFill, TweenInfo.new(0.35, Enum.EasingStyle.Sine), {Size = UDim2.new(0.65, 0, 1, 0)}):Play()
        SStatus.Text = "Hooking speed locks & bhop engine..."
        SPercent.Text = "65%"
        task.wait(0.4)
        
        -- Stage 3
        TweenService:Create(SFill, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {Size = UDim2.new(0.9, 0, 1, 0)}):Play()
        SStatus.Text = "Calibrating fullbright & sound muters..."
        SPercent.Text = "90%"
        task.wait(0.35)
        
        -- Stage 4
        TweenService:Create(SFill, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {Size = UDim2.new(1, 0, 1, 0)}):Play()
        SStatus.Text = "Ready! Welcome to Zerox Hub."
        SPercent.Text = "100%"
        task.wait(0.3)
        
        -- Smooth collapse of Splash
        local tw = TweenService:Create(Splash, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 300, 0, 0),
            Position = UDim2.new(0.5, -150, 0.5, 0),
            BackgroundTransparency = 1
        })
        tw:Play()
        tw.Completed:Connect(function()
            pcall(function() Splash:Destroy() end)
            if onComplete then onComplete() end
        end)
    end)
end

-- Launch Loader, then Reveal Main GUI
runLoader(function()
    Backdrop.Visible = true
    Backdrop.Size = UDim2.new(0, 0, 0, 0)
    Backdrop.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    TweenService:Create(Backdrop, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 550, 0, 400),
        Position = UDim2.new(0.5, -275, 0.5, -200)
    }):Play()
    
    showNotify("Zerox Hub v1.0 Ready")
    print("[Zerox Hub v1.0] Loaded successfully.")
end)
