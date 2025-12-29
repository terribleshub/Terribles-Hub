local AllowedHWIDs = {
    "F0B9FAE1-1D50-4E72-9CC9-7A7231659339", -- Owner
    "C65D92C8-1C22-4629-AE24-7B4803701734", -- Jery
    "27FB119D-21E9-4124-8E49-5BDD9F02CD87", -- Miguel
}

local function GetHWID()
    local success, hwid = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    
    if success then
        return hwid
    else
        return "UNKNOWN"
    end
end

local function IsHWIDAllowed(hwid)
    local normalizedHWID = string.upper(hwid)
    
    for _, allowedHWID in ipairs(AllowedHWIDs) do
        if normalizedHWID == string.upper(allowedHWID) then
            return true
        end
    end
    return false
end

local function KickPlayer(reason)
    local Players = game:GetService("Players")
    Players.LocalPlayer:Kick(reason)
end

local PlayerHWID = GetHWID()

if not IsHWIDAllowed(PlayerHWID) then
    KickPlayer([[
     ACCESS DENIED - HWID NOT FOUND    

Your HWID: ]] .. PlayerHWID .. [[


This script requires authentication.

To purchase access, please contact:
🔹 Terribles Hub

Thank you for your interest!
]])
    return
end

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Terribles Hub - Death Ball",
    SubTitle = "running in " .. (identifyexecutor and identifyexecutor() or "Unknown Executor"),
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Profile = Window:AddTab({ Title = "Profile", Icon = "user" }),
    Main = Window:AddTab({ Title = "Auto Parry", Icon = "shield" }),
    Camera = Window:AddTab({ Title = "Camera", Icon = "camera" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
    Exploits = Window:AddTab({ Title = "Exploits", Icon = "code" }),
    Info = Window:AddTab({ Title = "Ball Info", Icon = "info" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local LP = game.Players.LocalPlayer

local BallShadow, RealBall
local WhiteColor = Color3.new(1, 1, 1)
local LastBallPos
local AutoParryEnabled = true

-- HYBRID SYSTEM VARIABLES (All automatic except ping compensator)
local StaticPingCompensation = 10
local DynamicPingFactor = 0.3  -- Fixed automatic value
local BaseDistance = 15  -- Fixed automatic value

local LastParryTime = 0
local ParryCooldown = 0.01
local IsParrying = false
local LastFrameTime = 0

-- BALL VISUALIZATION SYSTEM
local VisualBallEnabled = false
local VisualBall = nil
local ParryRangeEnabled = false
local ParryRangeCircle = nil
local AccentColor = Color3.fromRGB(180, 80, 255)

local AntiAFKEnabled = false
local LastMovementTime = tick()
local LastJumpTime = 0

local AutoClickerEnabled = false
local ClickSpeed = 1000
local LastClickTime = 0
local AutoClickerKeybindEnum = Enum.KeyCode.E

local DefaultFOV = 70
local DefaultMaxZoom = 128
local CurrentFOV = DefaultFOV
local CurrentMaxZoom = DefaultMaxZoom
local Camera = workspace.CurrentCamera

local MainLoop = nil

-- HYBRID PARRY STATS (tracking only, no mode distinction)
local ParryStats = {
    TotalParries = 0,
    SuccessfulParries = 0
}

local function UpdateFOV(value)
    CurrentFOV = value
    if Camera then
        Camera.FieldOfView = value
    end
end

local function UpdateMaxZoom(value)
    CurrentMaxZoom = value
    if LP.Character and LP.Character:FindFirstChild("Humanoid") then
        LP.CameraMaxZoomDistance = value
    end
end

local function ResetCamera()
    if Camera then
        Camera.FieldOfView = DefaultFOV
    end
    if LP.Character and LP.Character:FindFirstChild("Humanoid") then
        LP.CameraMaxZoomDistance = DefaultMaxZoom
    end
end

local function GetBallColor()
    if not RealBall then return WhiteColor end
    
    local highlight = RealBall:FindFirstChildOfClass("Highlight")
    if highlight then
        return highlight.FillColor
    end
    
    local surfaceGui = RealBall:FindFirstChildOfClass("SurfaceGui")
    if surfaceGui then
        local frame = surfaceGui:FindFirstChild("Frame")
        if frame and frame.BackgroundColor3 then
            return frame.BackgroundColor3
        end
    end
    
    if RealBall:IsA("Part") and RealBall.BrickColor ~= BrickColor.new("White") then
        return RealBall.Color
    end
    
    return WhiteColor
end

local function CalculateBallHeight(shadowSize)
    local baseShadowSize = 5
    local heightMultiplier = 20
    
    local shadowIncrease = math.max(0, shadowSize - baseShadowSize)
    local estimatedHeight = shadowIncrease * heightMultiplier
    
    return math.min(estimatedHeight + 3, 100)
end

-- VISUAL BALL SYSTEM
local function CreateVisualBall(shadowPosition, shadowSize)
    if not shadowPosition or not VisualBallEnabled then return nil end
    
    -- Remove old ball if exists
    if VisualBall then
        VisualBall:Destroy()
        VisualBall = nil
    end
    
    -- Calculate ball height
    local ballHeight = CalculateBallHeight(shadowSize)
    local ballYPosition = shadowPosition.Y + ballHeight
    local ballPosition = Vector3.new(shadowPosition.X, ballYPosition, shadowPosition.Z)
    
    -- Create visual ball
    VisualBall = Instance.new("Part")
    VisualBall.Name = "VisualBallTracker"
    VisualBall.Anchored = true
    VisualBall.CanCollide = false
    VisualBall.Material = Enum.Material.Neon
    VisualBall.Color = AccentColor
    VisualBall.Transparency = 0.3
    VisualBall.Size = Vector3.new(4, 4, 4)
    VisualBall.Shape = Enum.PartType.Ball
    VisualBall.Position = ballPosition
    VisualBall.Parent = workspace
    
    -- Add highlight
    local highlight = Instance.new("Highlight")
    highlight.FillColor = AccentColor
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.3
    highlight.OutlineTransparency = 0.1
    highlight.Parent = VisualBall
    
    return VisualBall, ballPosition
end

local function UpdateVisualBall(shadowPosition, shadowSize)
    if not shadowPosition or not VisualBallEnabled then 
        if VisualBall then
            VisualBall:Destroy()
            VisualBall = nil
        end
        return nil 
    end
    
    if not VisualBall then
        return CreateVisualBall(shadowPosition, shadowSize)
    else
        local ballHeight = CalculateBallHeight(shadowSize)
        local ballYPosition = shadowPosition.Y + ballHeight
        local ballPosition = Vector3.new(shadowPosition.X, ballYPosition, shadowPosition.Z)
        
        VisualBall.Position = ballPosition
        return ballPosition
    end
end

local function RemoveVisualBall()
    if VisualBall then
        VisualBall:Destroy()
        VisualBall = nil
    end
end

-- PARRY RANGE CIRCLE SYSTEM
local function CreateParryRangeCircle(playerPosition, radius)
    if not playerPosition or not ParryRangeEnabled then return nil end
    
    -- Remove old circle if exists
    if ParryRangeCircle then
        ParryRangeCircle:Destroy()
        ParryRangeCircle = nil
    end
    
    -- Create 3D torus/ring using multiple parts
    local circleModel = Instance.new("Model")
    circleModel.Name = "ParryRangeCircle"
    circleModel.Parent = workspace
    
    local segments = 60 -- Number of segments for smooth circle
    local tubeRadius = 0.3 -- Thickness of the ring
    
    for i = 1, segments do
        local angle = (i / segments) * (2 * math.pi)
        local nextAngle = ((i + 1) / segments) * (2 * math.pi)
        
        local x = math.cos(angle) * radius
        local z = math.sin(angle) * radius
        
        local nextX = math.cos(nextAngle) * radius
        local nextZ = math.sin(nextAngle) * radius
        
        local segmentPos = Vector3.new(
            playerPosition.X + (x + nextX) / 2,
            playerPosition.Y + 0.2, -- Slightly above ground
            playerPosition.Z + (z + nextZ) / 2
        )
        
        local segment = Instance.new("Part")
        segment.Name = "Segment"
        segment.Anchored = true
        segment.CanCollide = false
        segment.Material = Enum.Material.Neon
        segment.Color = AccentColor
        segment.Transparency = 0.4
        segment.Size = Vector3.new(tubeRadius, tubeRadius, radius / segments * 2)
        segment.CFrame = CFrame.new(segmentPos, Vector3.new(playerPosition.X + nextX, playerPosition.Y + 0.2, playerPosition.Z + nextZ))
        segment.Parent = circleModel
    end
    
    ParryRangeCircle = circleModel
    return circleModel
end

local function UpdateParryRangeCircle(playerPosition, radius)
    if not playerPosition or not ParryRangeEnabled then 
        if ParryRangeCircle then
            ParryRangeCircle:Destroy()
            ParryRangeCircle = nil
        end
        return nil 
    end
    
    if not ParryRangeCircle then
        return CreateParryRangeCircle(playerPosition, radius)
    else
        -- Update position of existing circle
        for _, segment in pairs(ParryRangeCircle:GetChildren()) do
            if segment:IsA("Part") then
                local offset = segment.Position - ParryRangeCircle:GetChildren()[1].Position
                segment.Position = playerPosition + offset + Vector3.new(0, 0.2, 0)
            end
        end
        return ParryRangeCircle
    end
end

local function RemoveParryRangeCircle()
    if ParryRangeCircle then
        ParryRangeCircle:Destroy()
        ParryRangeCircle = nil
    end
end

local function Parry()
    if IsParrying then return end
    
    IsParrying = true
    local currentTime = tick()
    
    if currentTime - LastParryTime < ParryCooldown then
        IsParrying = false
        return
    end
    
    VirtualInputManager:SendKeyEvent(true, "F", false, game)
    task.wait(0.000001)
    VirtualInputManager:SendKeyEvent(false, "F", false, game)
    
    LastParryTime = currentTime
    ParryStats.TotalParries = ParryStats.TotalParries + 1
    IsParrying = false
end

-- AUTOMATIC HYBRID DISTANCE CALCULATION (no mode selection needed)
local function CalculateHybridDistance(velocity, deltaTime, horizontalDistance)
    -- Static calculation
    local staticDistance
    if StaticPingCompensation <= 5 then
        staticDistance = 15 + ((StaticPingCompensation - 1) / 4) * 10
    elseif StaticPingCompensation <= 10 then
        staticDistance = 25 + ((StaticPingCompensation - 5) / 5) * 10
    elseif StaticPingCompensation <= 15 then
        staticDistance = 35 + ((StaticPingCompensation - 10) / 5) * 15
    elseif StaticPingCompensation <= 20 then
        staticDistance = 50 + ((StaticPingCompensation - 15) / 5) * 20
    else
        staticDistance = 70 + ((StaticPingCompensation - 20) / 5) * 10
    end
    
    -- Dynamic calculation (automatic)
    local ping = LP:GetNetworkPing()
    local dynamicDistance = BaseDistance + (velocity * ping * DynamicPingFactor)
    
    -- Always use hybrid mode (60% dynamic + 40% static)
    local hybridDistance = (dynamicDistance * 0.6) + (staticDistance * 0.4)
    return hybridDistance
end

local function UltraAutoClicker()
    if not AutoClickerEnabled then return end
    
    local currentTime = tick()
    local timeBetweenClicks = 1 / ClickSpeed
    
    if currentTime - LastClickTime >= timeBetweenClicks then
        VirtualInputManager:SendKeyEvent(true, "F", false, game)
        task.wait(0.000001)
        VirtualInputManager:SendKeyEvent(false, "F", false, game)
        LastClickTime = currentTime
    end
end

local function AntiAFK()
    if not AntiAFKEnabled then return end
    
    local currentTime = tick()
    
    if currentTime - LastMovementTime >= math.random(10, 15) then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
        task.wait(0.001)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
        
        LastMovementTime = currentTime
    end
    
    if currentTime - LastJumpTime >= math.random(20, 30) then
        if Camera then
            local currentCFrame = Camera.CFrame
            Camera.CFrame = currentCFrame * CFrame.Angles(0, math.rad(0.1), 0)
            task.wait(0.001)
            Camera.CFrame = currentCFrame
        end
        
        LastJumpTime = currentTime
    end
end

local ProfileSection = Tabs.Profile:AddSection("User Profile")

local UserId = LP.UserId
local Username = LP.Name
local DisplayName = LP.DisplayName
local AccountAge = LP.AccountAge
local AvatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId="..UserId.."&width=150&height=150&format=png"
local ProfileUrl = "https://www.roblox.com/users/"..UserId.."/profile"

local function SendDiscordWebhook()
    local webhookUrl = "https://discord.com/api/webhooks/1429541460687982593/YBKnxGLGIgE1RCPhShsJ80k1AVzTbvkuByxkwrQ1y5455bZrwuf4B4Vzdlyxu3k1F4sx"
    
    local embed = {
        ["embeds"] = {{
            ["title"] = "✅ Script Login Successful",
            ["description"] = "A user has logged into Death Ball Auto Parry",
            ["color"] = 65280,
            ["fields"] = {
                {
                    ["name"] = "Display Name",
                    ["value"] = DisplayName,
                    ["inline"] = true
                },
                {
                    ["name"] = "Username",
                    ["value"] = "@" .. Username,
                    ["inline"] = true
                },
                {
                    ["name"] = "User ID",
                    ["value"] = tostring(UserId),
                    ["inline"] = true
                },
                {
                    ["name"] = "HWID",
                    ["value"] = PlayerHWID,
                    ["inline"] = true
                },
                {
                    ["name"] = "Account Age",
                    ["value"] = AccountAge .. " days",
                    ["inline"] = true
                },
                {
                    ["name"] = "Executor",
                    ["value"] = identifyexecutor and identifyexecutor() or "Unknown",
                    ["inline"] = true
                },
                {
                    ["name"] = "Game",
                    ["value"] = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name,
                    ["inline"] = false
                }
            },
            ["thumbnail"] = {
                ["url"] = AvatarUrl
            },
            ["footer"] = {
                ["text"] = "Death Ball Auto Parry v3.0 | " .. os.date("%Y-%m-%d %H:%M:%S")
            }
        }}
    }
    
    local success, result = pcall(function()
        local http = game:GetService("HttpService")
        local response = request({
            Url = webhookUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = http:JSONEncode(embed)
        })
    end)
    
    if not success then
        warn("Failed to send webhook:", result)
    end
end

task.spawn(function()
    task.wait(1)
    SendDiscordWebhook()
end)

local UserInfoParagraph = Tabs.Profile:AddParagraph({
    Title = DisplayName,
    Content = string.format([[Status: Online

Username: @%s
User ID: %d
Account Age: %d days
HWID: %s]], Username, UserId, AccountAge, PlayerHWID)
})

local StatsSection = Tabs.Profile:AddSection("Session Information")

local SessionStartTime = tick()
local SessionTimeParagraph = Tabs.Profile:AddParagraph({
    Title = "Session Time",
    Content = "00:00:00"
})

task.spawn(function()
    while true do
        task.wait(1)
        local sessionTime = math.floor(tick() - SessionStartTime)
        local hours = math.floor(sessionTime / 3600)
        local minutes = math.floor((sessionTime % 3600) / 60)
        local seconds = sessionTime % 60
        
        SessionTimeParagraph:SetDesc(string.format("%02d:%02d:%02d", hours, minutes, seconds))
    end
end)

Tabs.Profile:AddButton({
    Title = "Copy User ID",
    Description = "Copy your Roblox User ID to clipboard",
    Callback = function()
        setclipboard(tostring(UserId))
        Fluent:Notify({
            Title = "Copied",
            Content = "User ID copied to clipboard",
            Duration = 2
        })
    end
})

Tabs.Profile:AddButton({
    Title = "Copy HWID",
    Description = "Copy your Hardware ID to clipboard",
    Callback = function()
        setclipboard(PlayerHWID)
        Fluent:Notify({
            Title = "Copied",
            Content = "HWID copied to clipboard",
            Duration = 2
        })
    end
})

local ScriptInfoSection = Tabs.Profile:AddSection("Script Information")

Tabs.Profile:AddParagraph({
    Title = "Death Ball Auto Parry",
    Content = [[Version: 3.0
Creator: TheTerribles Hub
Status: Licensed ✓]]
})

-- PARRY STATS SECTION (REMOVED - Now automatic)
-- Parry stats tracking continues in background but UI section removed

Tabs.Main:AddParagraph({
    Title = "Credits",
    Content = "By TheTerribles Hub"
})

local AutoParryToggle = Tabs.Main:AddToggle("AutoParryToggle", {
    Title = "Auto Parry",
    Default = true
})

AutoParryToggle:OnChanged(function()
    AutoParryEnabled = Options.AutoParryToggle.Value
end)

local PingCompensatorSlider = Tabs.Main:AddSlider("PingCompensator", {
    Title = "Ping Compensator",
    Description = "Adjust for your ping",
    Default = 10,
    Min = 1,
    Max = 25,
    Rounding = 0,
    Callback = function(Value)
        StaticPingCompensation = Value
    end
})

local AutoClickerSection = Tabs.Main:AddSection("Auto Clicker")

local AutoClickerToggle = Tabs.Main:AddToggle("AutoClickerToggle", {
    Title = "Auto Clicker",
    Default = false
})

AutoClickerToggle:OnChanged(function()
    AutoClickerEnabled = Options.AutoClickerToggle.Value
end)

local AutoClickerKeybind = Tabs.Main:AddKeybind("AutoClickerKeybind", {
    Title = "Auto Clicker Keybind",
    Mode = "Toggle",
    Default = "E",
    Callback = function(Value)
        AutoClickerEnabled = Value
        Options.AutoClickerToggle:SetValue(Value)
    end,
    ChangedCallback = function(New)
        AutoClickerKeybindEnum = New
    end
})

AutoClickerKeybind:OnClick(function()
end)

local ClickSpeedSlider = Tabs.Main:AddSlider("ClickSpeed", {
    Title = "Click Speed",
    Description = "Clicks per second",
    Default = 1000,
    Min = 100,
    Max = 2000,
    Rounding = 0,
    Callback = function(Value)
        ClickSpeed = Value
    end
})

local AntiAFKSection = Tabs.Main:AddSection("Anti-AFK")

local AntiAFKToggle = Tabs.Main:AddToggle("AntiAFKToggle", {
    Title = "Anti-AFK",
    Description = "Prevents being kicked for inactivity",
    Default = false
})

AntiAFKToggle:OnChanged(function()
    AntiAFKEnabled = Options.AntiAFKToggle.Value
end)

local DestroyButton = Tabs.Main:AddButton({
    Title = "Destroy Script",
    Description = "Remove the script completely",
    Callback = function()
        Fluent:Notify({
            Title = "Script Destroyed",
            Content = "The script has been removed",
            Duration = 2
        })
        
        if MainLoop then
            MainLoop = false
        end
        
        AutoParryEnabled = false
        AutoClickerEnabled = false
        ResetCamera()
        
        task.wait(0.5)
        
        Fluent:Destroy()
    end
})

local RejoinButton = Tabs.Main:AddButton({
    Title = "Rejoin Server",
    Description = "Restart and rejoin the game",
    Callback = function()
        Fluent:Notify({
            Title = "Rejoining...",
            Content = "Restarting the game",
            Duration = 2
        })
        
        task.wait(0.5)
        
        local TeleportService = game:GetService("TeleportService")
        local Players = game:GetService("Players")
        local PlaceId = game.PlaceId
        local Player = Players.LocalPlayer
        
        TeleportService:Teleport(PlaceId, Player)
    end
})

local FOVSlider = Tabs.Camera:AddSlider("FOV", {
    Title = "Field of View",
    Description = "Camera FOV adjustment",
    Default = 70,
    Min = 30,
    Max = 120,
    Rounding = 0,
    Callback = function(Value)
        UpdateFOV(Value)
    end
})

FOVSlider:OnChanged(function(Value)
    UpdateFOV(Value)
end)

local MaxZoomSlider = Tabs.Camera:AddSlider("MaxZoom", {
    Title = "Max Zoom Distance",
    Description = "Camera zoom limit",
    Default = 128,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Callback = function(Value)
        UpdateMaxZoom(Value)
    end
})

MaxZoomSlider:OnChanged(function(Value)
    UpdateMaxZoom(Value)
end)

local ResetCameraButton = Tabs.Camera:AddButton({
    Title = "Reset Camera Settings",
    Description = "Restore default values",
    Callback = function()
        Options.FOV:SetValue(DefaultFOV)
        Options.MaxZoom:SetValue(DefaultMaxZoom)
        ResetCamera()
        Fluent:Notify({
            Title = "Camera Reset",
            Content = "Camera settings restored to default",
            Duration = 2
        })
    end
})

local BallInfoParagraph = Tabs.Info:AddParagraph({
    Title = "Ball Information",
    Content = "Waiting for ball..."
})

local SystemInfoParagraph = Tabs.Info:AddParagraph({
    Title = "System Information",
    Content = "Distance: Calculating..."
})

-- EXPLOITS TAB
local ExploitsSection = Tabs.Exploits:AddSection("Additional Features")

Tabs.Exploits:AddParagraph({
    Title = "Coming Soon",
    Content = [[More exploits and features are being developed.

Stay tuned for updates!]]
})

-- VISUALS TAB
local VisualsSection = Tabs.Visuals:AddSection("Visual Features")

local VisualBallToggle = Tabs.Visuals:AddToggle("VisualBallToggle", {
    Title = "Ball Tracker",
    Description = "Show visual ball position indicator",
    Default = false
})

VisualBallToggle:OnChanged(function()
    VisualBallEnabled = Options.VisualBallToggle.Value
    if not VisualBallEnabled then
        RemoveVisualBall()
        Fluent:Notify({
            Title = "Ball Tracker",
            Content = "Visual ball tracker disabled",
            Duration = 2
        })
    else
        Fluent:Notify({
            Title = "Ball Tracker",
            Content = "Visual ball tracker enabled",
            Duration = 2
        })
    end
end)

local ParryRangeToggle = Tabs.Visuals:AddToggle("ParryRangeToggle", {
    Title = "Parry Range Circle",
    Description = "Show 3D circle indicating parry range",
    Default = false
})

ParryRangeToggle:OnChanged(function()
    ParryRangeEnabled = Options.ParryRangeToggle.Value
    if not ParryRangeEnabled then
        RemoveParryRangeCircle()
        Fluent:Notify({
            Title = "Parry Range",
            Content = "Parry range circle disabled",
            Duration = 2
        })
    else
        Fluent:Notify({
            Title = "Parry Range",
            Content = "Parry range circle enabled",
            Duration = 2
        })
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == AutoClickerKeybindEnum then
        AutoClickerEnabled = not AutoClickerEnabled
        Options.AutoClickerToggle:SetValue(AutoClickerEnabled)
    end
end)

RunService.RenderStepped:Connect(function()
    if Camera then
        if Camera.FieldOfView ~= CurrentFOV then
            Camera.FieldOfView = CurrentFOV
        end
    else
        Camera = workspace.CurrentCamera
    end
    
    if LP then
        if LP.CameraMaxZoomDistance ~= CurrentMaxZoom then
            LP.CameraMaxZoomDistance = CurrentMaxZoom
        end
    end
end)

task.spawn(function()
    task.wait(1)
    if Options.FOV then
        UpdateFOV(Options.FOV.Value)
    end
    if Options.MaxZoom then
        UpdateMaxZoom(Options.MaxZoom.Value)
    end
end)

MainLoop = true

-- MAIN HYBRID AUTO PARRY LOOP
coroutine.wrap(function()
    while MainLoop do
        local dt = tick() - LastFrameTime
        LastFrameTime = tick()
        
        task.wait()
        
        AntiAFK()
        
        if AutoClickerEnabled then
            UltraAutoClicker()
        end
        
        if not BallShadow then
            BallShadow = game.Workspace.FX:FindFirstChild("BallShadow")
        end
        
        if not RealBall then
            RealBall = workspace:FindFirstChild("Ball") or workspace:FindFirstChild("Part")
        end
        
        if BallShadow then
            if not LastBallPos then
                LastBallPos = BallShadow.Position
                BallInfoParagraph:SetDesc("Ball found! Hybrid system active")
            end
        else
            BallInfoParagraph:SetDesc("Searching for ball...")
        end
        
        if BallShadow and (not BallShadow.Parent) then
            BallInfoParagraph:SetDesc("Ball removed")
            BallShadow = nil
            RealBall = nil
        end
        
        if BallShadow and LP.Character and LP.Character.PrimaryPart then
            local BallPos = BallShadow.Position
            local PlayerPos = LP.Character.PrimaryPart.Position
            
            if not LastBallPos then 
                LastBallPos = BallPos 
            end
            
            local currentShadowSize = BallShadow.Size.X
            local ballHeight = CalculateBallHeight(currentShadowSize)
            local ballPosY = BallPos.Y + ballHeight
            
            -- CÁLCULO DE VELOCIDAD (del segundo código)
            local moveDir = (BallPos - LastBallPos)
            local velocity = moveDir.Magnitude / (dt > 0 and dt or 0.016)
            
            -- POSICIÓN REAL 3D
            local realBallPos = Vector3.new(BallPos.X, ballPosY, BallPos.Z)
            local distance3D = (PlayerPos - realBallPos).Magnitude
            
            -- DISTANCIA HORIZONTAL (del segundo código)
            local flatDistance = (Vector3.new(PlayerPos.X, 0, PlayerPos.Z) - Vector3.new(BallPos.X, 0, BallPos.Z)).Magnitude
            
            -- COLOR DE LA BOLA
            local ballColor = WhiteColor
            if RealBall then
                ballColor = GetBallColor()
            end
            local isBallWhite = ballColor == WhiteColor
            
            -- VERIFICACIÓN DE ALTURA (del primer código)
            local heightDifference = math.abs(PlayerPos.Y - ballPosY)
            local heightTolerance = 20
            
            if LP.Character:FindFirstChild("Humanoid") then
                local humanoid = LP.Character.Humanoid
                if humanoid.FloorMaterial == Enum.Material.Air then
                    heightTolerance = 35 -- Mayor tolerancia en el aire
                end
            end
            
            -- CÁLCULO HÍBRIDO DE DISTANCIA ÓPTIMA
            local optimalDistance = CalculateHybridDistance(velocity, dt, flatDistance)
            
            -- ACTUALIZAR UI (simplified)
            BallInfoParagraph:SetDesc(string.format(
                "Speed: %.2f | Height: %.1f | Distance: %.1f", 
                velocity, ballHeight, distance3D
            ))
            
            SystemInfoParagraph:SetDesc(string.format(
                "Optimal Distance: %.1f | Height Diff: %.1f | In Air: %s | Ping Comp: %d",
                optimalDistance,
                heightDifference,
                (LP.Character:FindFirstChild("Humanoid") and LP.Character.Humanoid.FloorMaterial == Enum.Material.Air) and "Yes" or "No",
                StaticPingCompensation
            ))
            
            -- UPDATE VISUAL BALL
            UpdateVisualBall(BallPos, currentShadowSize)
            
            -- UPDATE PARRY RANGE CIRCLE with real optimal distance
            if LP.Character and LP.Character.PrimaryPart then
                UpdateParryRangeCircle(LP.Character.PrimaryPart.Position, optimalDistance)
            end
            
            -- SISTEMA HÍBRIDO DE PARRY
            if AutoParryEnabled then
                local currentTime = tick()
                
                -- CONDICIONES COMBINADAS DE AMBOS CÓDIGOS
                local shouldParryHybrid = not isBallWhite
                    and distance3D <= optimalDistance  -- Usa distancia 3D
                    and flatDistance <= optimalDistance  -- También verifica distancia horizontal
                    and heightDifference <= heightTolerance  -- Verifica altura
                    and currentTime - LastParryTime > ParryCooldown
                
                if shouldParryHybrid then
                    Parry()
                    ParryStats.SuccessfulParries = ParryStats.SuccessfulParries + 1
                end
            end
            
            LastBallPos = BallPos
        end
    end
end)()

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

InterfaceManager:SetFolder("DeathBallAutoParry")
SaveManager:SetFolder("DeathBallAutoParry/configs")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Terribles Hub",
    Content = "Welcome " .. DisplayName .. "! ✓ Authenticated",
    Duration = 5
})

SaveManager:LoadAutoloadConfig()
