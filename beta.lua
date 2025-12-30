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
    Exploits = Window:AddTab({ Title = "Exploits", Icon = "code" }),
    Info = Window:AddTab({ Title = "Game Info", Icon = "info" }),
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

local StaticPingCompensation = 10
local DynamicPingFactor = 0.3
local BaseDistance = 15

local LastParryTime = 0
local ParryCooldown = 0.01
local IsParrying = false
local LastFrameTime = 0

local AntiAFKEnabled = false
local AntiAFKInitialized = false

local AutoClickerEnabled = false
local ClickSpeed = 1000
local LastClickTime = 0
local AutoClickerKeybindEnum = nil

local DefaultFOV = 70
local DefaultMaxZoom = 128
local CurrentFOV = DefaultFOV
local CurrentMaxZoom = DefaultMaxZoom
local Camera = workspace.CurrentCamera

local MainLoop = nil
local FPSCounter = 0
local LastFPSUpdate = tick()

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

local function CalculateHybridDistance(velocity, deltaTime, horizontalDistance)
    -- Cálculo basado en ping compensator (1-25)
    local staticDistance
    if StaticPingCompensation <= 5 then
        staticDistance = 18 + ((StaticPingCompensation - 1) / 4) * 12
    elseif StaticPingCompensation <= 10 then
        staticDistance = 30 + ((StaticPingCompensation - 5) / 5) * 15
    elseif StaticPingCompensation <= 15 then
        staticDistance = 45 + ((StaticPingCompensation - 10) / 5) * 20
    elseif StaticPingCompensation <= 20 then
        staticDistance = 65 + ((StaticPingCompensation - 15) / 5) * 25
    else
        staticDistance = 90 + ((StaticPingCompensation - 20) / 5) * 15
    end
    
    -- Factor dinámico basado en velocidad y ping
    local ping = LP:GetNetworkPing()
    local velocityFactor = math.clamp(velocity / 100, 0.5, 2.5)
    local dynamicDistance = BaseDistance + (velocity * ping * DynamicPingFactor * velocityFactor)
    
    -- Mezcla híbrida: más peso al compensador estático
    local hybridDistance = (dynamicDistance * 0.3) + (staticDistance * 0.7)
    
    -- Ajuste adicional por velocidad extrema
    if velocity > 150 then
        hybridDistance = hybridDistance * 1.2
    elseif velocity < 50 then
        hybridDistance = hybridDistance * 0.85
    end
    
    return math.clamp(hybridDistance, 15, 150)
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
    
    local GC = getconnections or get_signal_cons
    if GC then
        for i,v in pairs(GC(LP.Idled)) do
            if v["Disable"] then
                v["Disable"](v)
            elseif v["Disconnect"] then
                v["Disconnect"](v)
            end
        end
    else
        local VirtualUser = cloneref and cloneref(game:GetService("VirtualUser")) or game:GetService("VirtualUser")
        LP.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end

local function IsInGame()
    local success, result = pcall(function()
        local healthBar = LP.PlayerGui:FindFirstChild("HUD")
        if healthBar then
            healthBar = healthBar:FindFirstChild("HolderBottom")
            if healthBar then
                healthBar = healthBar:FindFirstChild("HealthBar")
                if healthBar then
                    return healthBar.Visible == true
                end
            end
        end
        return false
    end)
    
    if success then
        return result
    end
    return false
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
            ["title"] = "🎮 Death Ball Auto Parry - Session Initiated",
            ["description"] = "A licensed user has successfully authenticated and started a new session.",
            ["color"] = 0,
            ["fields"] = {
                {
                    ["name"] = "👤 Display Name",
                    ["value"] = "```" .. DisplayName .. "```",
                    ["inline"] = true
                },
                {
                    ["name"] = "📝 Username",
                    ["value"] = "```@" .. Username .. "```",
                    ["inline"] = true
                },
                {
                    ["name"] = "🔢 User ID",
                    ["value"] = "```" .. tostring(UserId) .. "```",
                    ["inline"] = true
                },
                {
                    ["name"] = "🔐 Hardware ID",
                    ["value"] = "```" .. PlayerHWID .. "```",
                    ["inline"] = false
                },
                {
                    ["name"] = "📅 Account Age",
                    ["value"] = "```" .. AccountAge .. " days```",
                    ["inline"] = true
                },
                {
                    ["name"] = "⚙️ Executor",
                    ["value"] = "```" .. (identifyexecutor and identifyexecutor() or "Unknown") .. "```",
                    ["inline"] = true
                },
                {
                    ["name"] = "🎯 Game",
                    ["value"] = "```" .. game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name .. "```",
                    ["inline"] = false
                },
                {
                    ["name"] = "🌐 Server",
                    ["value"] = "```Job ID: " .. game.JobId .. "```",
                    ["inline"] = false
                }
            },
            ["thumbnail"] = {
                ["url"] = AvatarUrl
            },
            ["footer"] = {
                ["text"] = "Terribles Hub Security System",
                ["icon_url"] = "https://cdn.discordapp.com/emojis/1234567890123456789.png"
            },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S")
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

local ScriptInfoSection = Tabs.Profile:AddSection("Script Information")

Tabs.Profile:AddParagraph({
    Title = "Death Ball Auto Parry",
    Content = [[Version: 3.1 Fixed
Creator: TheTerribles Hub
Status: Licensed ✓]]
})

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
    Description = "Adjust for your ping (Higher = Earlier parry)",
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
    Default = "None",
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
    if AntiAFKEnabled and not AntiAFKInitialized then
        AntiAFK()
        AntiAFKInitialized = true
    end
end)

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

local GameInfoSection = Tabs.Info:AddSection("Game Information")

local GameInfoParagraph = Tabs.Info:AddParagraph({
    Title = "Server Status",
    Content = "Loading..."
})

local BallInfoSection = Tabs.Info:AddSection("Ball Information")

local BallInfoParagraph = Tabs.Info:AddParagraph({
    Title = "Ball Data",
    Content = "Waiting for ball..."
})

local SystemInfoParagraph = Tabs.Info:AddParagraph({
    Title = "System Information",
    Content = "Distance: Calculating..."
})

local ExploitsSection = Tabs.Exploits:AddSection("Additional Features")

Tabs.Exploits:AddParagraph({
    Title = "Coming Soon",
    Content = [[More exploits and features are being developed.

Stay tuned for updates!]]
})

local ScriptControlSection = Tabs.Settings:AddSection("Script Control")

local DestroyButton = Tabs.Settings:AddButton({
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

local RejoinButton = Tabs.Settings:AddButton({
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

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if AutoClickerKeybindEnum and input.KeyCode == AutoClickerKeybindEnum then
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

coroutine.wrap(function()
    while MainLoop do
        local dt = tick() - LastFrameTime
        LastFrameTime = tick()
        
        task.wait()
        
        FPSCounter = FPSCounter + 1
        if tick() - LastFPSUpdate >= 1 then
            local fps = FPSCounter
            FPSCounter = 0
            LastFPSUpdate = tick()
            
            local ping = math.floor(LP:GetNetworkPing() * 1000)
            
            local inGame = "No"
            local success, result = pcall(function()
                local healthBar = LP.PlayerGui:FindFirstChild("HUD")
                if healthBar then
                    healthBar = healthBar:FindFirstChild("HolderBottom")
                    if healthBar then
                        healthBar = healthBar:FindFirstChild("HealthBar")
                        if healthBar then
                            return healthBar.Visible == true
                        end
                    end
                end
                return false
            end)
            
            if success and result then
                inGame = "Yes"
            end
            
            GameInfoParagraph:SetDesc(string.format(
                "FPS: %d | Ping: %d ms | In Game: %s",
                fps, ping, inGame
            ))
        end
        
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
            
            local moveDir = (BallPos - LastBallPos)
            local velocity = moveDir.Magnitude / (dt > 0 and dt or 0.016)
            
            local realBallPos = Vector3.new(BallPos.X, ballPosY, BallPos.Z)
            local distance3D = (PlayerPos - realBallPos).Magnitude
            
            local flatDistance = (Vector3.new(PlayerPos.X, 0, PlayerPos.Z) - Vector3.new(BallPos.X, 0, BallPos.Z)).Magnitude
            
            local ballColor = WhiteColor
            if RealBall then
                ballColor = GetBallColor()
            end
            local isBallWhite = ballColor == WhiteColor
            
            local heightDifference = math.abs(PlayerPos.Y - ballPosY)
            
            -- Tolerancia de altura más flexible basada en velocidad
            local heightTolerance = 25
            if velocity > 100 then
                heightTolerance = 35
            end
            
            if LP.Character:FindFirstChild("Humanoid") then
                local humanoid = LP.Character.Humanoid
                if humanoid.FloorMaterial == Enum.Material.Air then
                    heightTolerance = 45
                end
            end
            
            local optimalDistance = CalculateHybridDistance(velocity, dt, flatDistance)
            
            BallInfoParagraph:SetDesc(string.format(
                "Speed: %.2f | Height: %.1f | Distance: %.1f", 
                velocity, ballHeight, distance3D
            ))
            
            SystemInfoParagraph:SetDesc(string.format(
                "Optimal: %.1f | Flat: %.1f | Height Diff: %.1f | Velocity: %.1f",
                optimalDistance,
                flatDistance,
                heightDifference,
                velocity
            ))
            
            if AutoParryEnabled then
                local currentTime = tick()
                
                -- Sistema mejorado de detección
                local isMovingTowardsPlayer = moveDir:Dot((PlayerPos - BallPos).Unit) > 0.3
                
                -- Condición principal: usa la distancia 3D como referencia principal
                local shouldParryHybrid = not isBallWhite
                    and currentTime - LastParryTime > ParryCooldown
                    and distance3D <= optimalDistance
                    and heightDifference <= heightTolerance
                    and velocity > 10  -- Asegura que la bola esté en movimiento
                    and (isMovingTowardsPlayer or flatDistance < optimalDistance * 0.7)
                
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
    Content = "Welcome " .. DisplayName .. "! ✓ Authenticated - Fixed Version",
    Duration = 5
})

SaveManager:LoadAutoloadConfig()
