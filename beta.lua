local AllowedHWIDs = {
    "F0B9FAE1-1D50-4E72-9CC9-7A7231659339", -- Owner
    "C65D92C8-1C22-4629-AE24-7B4803701734", -- Jery
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

local ReactionTime = 0.0001
local SafetyMargin = 1.3

local PingCompensation = 10

local LastParryTime = 0
local ParryCooldown = 0.000001
local IsParrying = false

local MinimumSpeedThreshold = 0.3
local BallStillCheckFrames = 2
local BallStillCounter = 0

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

local SpeedHeightThresholds = {
    {speed = 7.5, maxHeight = 22},
    {speed = 10, maxHeight = 27},
    {speed = math.huge, maxHeight = 30}
}

local MainLoop = nil

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

local function IsInGame()
    local success, result = pcall(function()
        local healthBar = LP.PlayerGui.HUD.HolderBottom.HealthBar
        return healthBar.Visible == true
    end)
    return success and result
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

local function GetMaxHeightBySpeed(speedStuds)
    for _, threshold in ipairs(SpeedHeightThresholds) do
        if speedStuds <= threshold.speed then
            return threshold.maxHeight
        end
    end
    return 30
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
    IsParrying = false
end

local function IsBallComingTowardsPlayer(ballPos, lastPos, playerPos)
    if not lastPos then return false end  -- Cambiado a false para ser más estricto
    
    local ballToPlayer = (playerPos - ballPos).Unit
    local ballMovement = (ballPos - lastPos).Unit
    
    local dotProduct = ballToPlayer:Dot(ballMovement)
    
    -- Aumentado el threshold para ser más estricto
    return dotProduct > 0.3
end

local function IsBallMoving(currentSpeed)
    -- La pelota debe tener al menos 0.3 de velocidad para considerarse en movimiento
    if currentSpeed < MinimumSpeedThreshold then
        BallStillCounter = BallStillCounter + 1
        if BallStillCounter >= BallStillCheckFrames then
            return false
        end
    else
        BallStillCounter = 0
        return true
    end
    
    -- Si la velocidad es menor a 0.3, siempre retornar false
    return currentSpeed >= MinimumSpeedThreshold and BallStillCounter < BallStillCheckFrames
end

local function CalculateOptimalParryDistance(speed, horizontalDistance, ballHeight, playerPosY, ballPosY)
    local baseDistance
    if PingCompensation <= 5 then
        baseDistance = 15 + ((PingCompensation - 1) / 4) * 10
    elseif PingCompensation <= 10 then
        baseDistance = 25 + ((PingCompensation - 5) / 5) * 10
    elseif PingCompensation <= 15 then
        baseDistance = 35 + ((PingCompensation - 10) / 5) * 15
    elseif PingCompensation <= 20 then
        baseDistance = 50 + ((PingCompensation - 15) / 5) * 20
    else
        baseDistance = 70 + ((PingCompensation - 20) / 5) * 10
    end
    
    local speedMultiplier = 1.0
    
    if speed >= 3.0 then
        speedMultiplier = 1.8
    elseif speed >= 2.5 then
        speedMultiplier = 1.6
    elseif speed >= 2.0 then
        speedMultiplier = 1.4
    elseif speed >= 1.5 then
        speedMultiplier = 1.25
    elseif speed >= 1.0 then
        speedMultiplier = 1.1
    elseif speed >= 0.8 then
        speedMultiplier = 1.0
    else
        speedMultiplier = 0.9
    end
    
    local optimalDistance = baseDistance * speedMultiplier
    
    return optimalDistance
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
    local webhookUrl = "https://discord.com/api/webhooks/1454577507515895981/YV59AmJvhacpV6uE9-NFnnHn-vqw7wv_pbLDANAdrn-Q7qTeYX4IjpdygVGHJvnY5A9t"
    
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
                ["text"] = "Death Ball Auto Parry v2.0 | " .. os.date("%Y-%m-%d %H:%M:%S")
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
    Content = [[Version: 2.0
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
    Description = "Adjust for your ping",
    Default = 10,
    Min = 1,
    Max = 25,
    Rounding = 0,
    Callback = function(Value)
        PingCompensation = Value
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

local LastParryCheckTime = 0
local ParryCheckCooldown = 0.016

MainLoop = true

coroutine.wrap(function()
    while MainLoop do
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
                BallInfoParagraph:SetDesc("Ball found!")
            end
        else
            BallInfoParagraph:SetDesc("Searching for ball...")
        end
        
        if BallShadow and (not BallShadow.Parent) then
            BallInfoParagraph:SetDesc("Ball removed")
            BallShadow = nil
            RealBall = nil
            BallStillCounter = 0
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
            
            local moveDir = (LastBallPos - BallPos)
            local rawSpeed = moveDir.Magnitude
            local horizontalSpeed = Vector3.new(moveDir.X, 0, moveDir.Z).Magnitude
            local speedStuds = horizontalSpeed + 0.25
            
            local horizontalDistance = (Vector3.new(PlayerPos.X, 0, PlayerPos.Z) - Vector3.new(BallPos.X, 0, BallPos.Z)).Magnitude
            
            local realBallPosY = BallPos.Y + ballHeight
            local realBallPos = Vector3.new(BallPos.X, realBallPosY, BallPos.Z)
            local distance3D = (PlayerPos - realBallPos).Magnitude
            
            local ballColor = WhiteColor
            if RealBall then
                ballColor = GetBallColor()
            end
            local isBallWhite = ballColor == WhiteColor
            
            local maxHeightForParry = GetMaxHeightBySpeed(speedStuds)
            
            local isComingTowardsPlayer = IsBallComingTowardsPlayer(BallPos, LastBallPos, PlayerPos)
            
            local isBallActuallyMoving = IsBallMoving(rawSpeed)
            
            local optimalDistance = CalculateOptimalParryDistance(speedStuds, distance3D, ballHeight, PlayerPos.Y, ballPosY)
            
            local heightDifference = math.abs(PlayerPos.Y - realBallPosY)
            
            local heightTolerance = 20
            local playerHeight = PlayerPos.Y
            
            if playerHeight > 10 then
                heightTolerance = 35
            elseif playerHeight > 5 then
                heightTolerance = 28
            end
            
            if LP.Character and LP.Character:FindFirstChild("Humanoid") then
                local humanoid = LP.Character.Humanoid
                if humanoid.FloorMaterial == Enum.Material.Air then
                    heightTolerance = heightTolerance + 15
                end
            end
            
            local movementStatus = isBallActuallyMoving and "Moving" or "Still"
            BallInfoParagraph:SetDesc(string.format("Speed: %.2f | Height: %.1f | Dist: %.1f | %s | Comp: %d", 
                rawSpeed, ballHeight, distance3D, movementStatus, PingCompensation))
            
            local currentTime = tick()
            if AutoParryEnabled then
                -- IMPORTANTE: Solo hacer parry si cumple TODAS estas condiciones:
                -- 1. La pelota debe estar en movimiento (velocidad >= 0.3)
                -- 2. La pelota debe estar CERCA (dentro de la distancia óptima)
                -- 3. La pelota debe venir hacia el jugador
                -- 4. La altura debe ser correcta
                -- 5. La pelota no debe ser blanca
                local shouldParryNow = isBallActuallyMoving
                    and rawSpeed >= MinimumSpeedThreshold  -- Velocidad mínima de 0.3
                    and distance3D <= optimalDistance      -- Debe estar dentro del rango calculado
                    and horizontalDistance <= optimalDistance  -- Verificación adicional de distancia horizontal
                    and isComingTowardsPlayer              -- Debe venir hacia ti
                    and heightDifference <= heightTolerance
                    and not isBallWhite
                
                if shouldParryNow and currentTime - LastParryCheckTime > ParryCheckCooldown then
                    Parry()
                    LastParryCheckTime = currentTime
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
