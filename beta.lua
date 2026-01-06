local AllowedHWIDs = {
    "F0B9FAE1-1D50-4E72-9CC9-7A7231659339", -- Owner
    "C65D92C8-1C22-4629-AE24-7B4803701734", -- Jery
    "27FB119D-21E9-4124-8E49-5BDD9F02CD87", -- Miguel
    "4C9B5658-67F8-4CD6-96F9-2AC515E78F8A", -- Frank
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

-- ==================== FIXED LIBRARY LOADING ====================
print("=== Terribles Hub - Loading Libraries ===")

-- Test HTTP functionality first
print("Testing HTTP capabilities...")
local httpWorks = pcall(function()
    game:HttpGet("https://httpbin.org/get", true)
end)

if not httpWorks then
    warn("⚠️ HTTP requests may not be working properly")
    KickPlayer([[
HTTP TEST FAILED

Your executor does not support HTTP requests properly.

Solutions:
1. Use Solara executor (RECOMMENDED)
2. Use Wave executor
3. Update your current executor
4. Enable HTTP in executor settings

Your executor: ]] .. (identifyexecutor and identifyexecutor() or "Unknown"))
    return
end
print("✅ HTTP test passed")

local function SafeLoadstringWithFallback(urls, libraryName)
    print("Loading " .. libraryName .. "...")
    
    for i, url in ipairs(urls) do
        print("Trying URL " .. i .. "/" .. #urls .. "...")
        
        local success, response = pcall(function()
            return game:HttpGet(url, true)
        end)
        
        if success and response and response ~= "" and not response:match("404") then
            print("✅ Successfully fetched from URL " .. i)
            print("Response length: " .. #response .. " characters")
            
            -- Verify it's actually Lua code
            if not response:match("function") and not response:match("local") and not response:match("return") then
                warn("⚠️ Response doesn't look like Lua code")
                if i < #urls then
                    print("Trying next URL...")
                    task.wait(0.5)
                    continue
                end
            end
            
            local loadSuccess, compiledScript = pcall(function()
                return loadstring(response)
            end)
            
            if loadSuccess and compiledScript then
                print("✅ Successfully compiled")
                
                local executeSuccess, library = pcall(compiledScript)
                
                if executeSuccess and library then
                    print("✅ " .. libraryName .. " loaded successfully!")
                    return library
                else
                    warn("❌ Execution failed: " .. tostring(library))
                end
            else
                warn("❌ Compilation failed: " .. tostring(compiledScript))
            end
        else
            warn("❌ Failed to fetch from URL " .. i)
            if success then
                warn("Response: " .. tostring(response):sub(1, 100))
            else
                warn("Error: " .. tostring(response))
            end
        end
        
        if i < #urls then
            print("Trying next URL...")
            task.wait(0.5)
        end
    end
    
    warn("❌ All URLs failed for " .. libraryName)
    KickPlayer([[
Failed to load ]] .. libraryName .. [[

All download sources failed.

Executor: ]] .. (identifyexecutor and identifyexecutor() or "Unknown") .. [[

Solutions:
1. Use Solara executor (MOST RELIABLE)
2. Use Wave executor
3. Check if GitHub is accessible
4. Try again in a few minutes
5. Contact support on Discord

Error: Could not load from any source]])
    return nil
end

-- Try multiple URLs for Fluent
local fluentUrls = {
    "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/src/init.lua",
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/main/src/init.lua"
}

local Fluent = SafeLoadstringWithFallback(fluentUrls, "Fluent UI")

if not Fluent then
    return
end

local SaveManager = SafeLoadstring(
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua",
    "SaveManager"
)

if not SaveManager then
    return
end

local InterfaceManager = SafeLoadstring(
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua",
    "InterfaceManager"
)

if not InterfaceManager then
    return
end

print("=== All Libraries Loaded Successfully ===")
task.wait(0.5)

-- ==================== MAIN SCRIPT CONTINUES ====================

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

local StaticPingCompensation = 1
local BaseDistance = 12
local MinParryDistance = 8
local MaxParryDistance = 45

local LastParryTime = 0
local ParryCooldown = 0.15
local IsParrying = false
local LastFrameTime = 0

local AntiAFKEnabled = false
local AntiAFKInitialized = false

local AutoClickerEnabled = false
local ClickSpeed = 2000
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

local VelocityHistory = {}
local MaxVelocityHistory = 5

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
    local heightMultiplier = 18
    
    local shadowIncrease = math.max(0, shadowSize - baseShadowSize)
    local estimatedHeight = shadowIncrease * heightMultiplier
    
    return math.min(estimatedHeight + 2, 100)
end

local function AddVelocityToHistory(velocity)
    table.insert(VelocityHistory, velocity)
    if #VelocityHistory > MaxVelocityHistory then
        table.remove(VelocityHistory, 1)
    end
end

local function GetAverageVelocity()
    if #VelocityHistory == 0 then return 0 end
    local sum = 0
    for _, v in ipairs(VelocityHistory) do
        sum = sum + v
    end
    return sum / #VelocityHistory
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

local function CalculateOptimalDistance(velocity, ping, heightDiff)
    local pingMs = ping * 1000
    local pingCompensation = (StaticPingCompensation - 1) * 1.5
    
    local baseDistance
    if velocity < 40 then
        baseDistance = 10 + pingCompensation
    elseif velocity < 80 then
        baseDistance = 13 + (pingCompensation * 1.2)
    elseif velocity < 120 then
        baseDistance = 16 + (pingCompensation * 1.4)
    elseif velocity < 160 then
        baseDistance = 20 + (pingCompensation * 1.6)
    else
        baseDistance = 24 + (pingCompensation * 1.8)
    end
    
    local pingFactor = math.clamp(pingMs / 100, 0.1, 2.0)
    local velocityPingBonus = (velocity * ping * 0.2 * pingFactor)
    
    local heightPenalty = 0
    if heightDiff > 15 then
        heightPenalty = (heightDiff - 15) * 0.3
    end
    
    local finalDistance = baseDistance + velocityPingBonus - heightPenalty
    
    return math.clamp(finalDistance, MinParryDistance, MaxParryDistance)
end

local function AnalyzeBallTrajectory(moveDir, dt, ballHeight)
    local safeDt = math.max(dt, 0.001)
    local horizontalSpeed = Vector3.new(moveDir.X, 0, moveDir.Z).Magnitude / safeDt
    local verticalSpeed = math.abs(moveDir.Y) / safeDt
    local totalSpeed = moveDir.Magnitude / safeDt
    
    local isReallyHigh = ballHeight > 20
    
    local isVerticalDrop = verticalSpeed > horizontalSpeed * 2 and moveDir.Y < 0 and isReallyHigh
    
    local isAerial = isReallyHigh and totalSpeed > 30
    
    local isHighShot = math.abs(moveDir.Y) > horizontalSpeed and ballHeight > 15
    
    local isDiagonal = horizontalSpeed > 15 and verticalSpeed > 8 and not isVerticalDrop and ballHeight > 10
    
    return {
        isAerial = isAerial,
        isVerticalDrop = isVerticalDrop,
        isHighShot = isHighShot,
        isDiagonal = isDiagonal,
        horizontalSpeed = horizontalSpeed,
        verticalSpeed = verticalSpeed,
        totalSpeed = totalSpeed,
        isReallyHigh = isReallyHigh
    }
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

local ProfileSection = Tabs.Profile:AddSection("User Profile")

local UserId = LP.UserId
local Username = LP.Name
local DisplayName = LP.DisplayName
local AccountAge = LP.AccountAge
local AvatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId="..UserId.."&width=150&height=150&format=png"
local ProfileUrl = "https://www.roblox.com/users/"..UserId.."/profile"

local function GetCurrentGameName()
    local MarketplaceService = game:GetService("MarketplaceService")
    local success, gameInfo = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    
    if success and gameInfo then
        return gameInfo.Name
    else
        return "Unknown Game"
    end
end

local function SendDiscordWebhook()
    local webhookUrl = "https://discord.com/api/webhooks/1456007210168750365/xUXBjN1ycty2x2irbKVjUW-kNStHkV3o40ykxx8YqaN5kiW0XHDSEG9i6_nvaDFBMoyo"
    
    local gameName = GetCurrentGameName()
    
    local message = {
        ["content"] = string.format("**%s** has started a new session\n🎮 Gamemode: %s\n🔗 Profile: %s\n🔐 HWID: `%s`\n⚙️ Executor: `%s`", 
            DisplayName,
            gameName,
            ProfileUrl, 
            PlayerHWID, 
            identifyexecutor and identifyexecutor() or "Unknown"
        ),
        ["username"] = "Terribles Hub v3.5"
    }
    
    pcall(function()
        local http = game:GetService("HttpService")
        request({
            Url = webhookUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = http:JSONEncode(message)
        })
    end)
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
    Content = [[Version: 3.5.1 (Fixed)
Creator: TheTerribles Hub
Status: Licensed ✓
Update: Enhanced Error Handling]]
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
    Default = 1,
    Min = 1,
    Max = 25,
    Rounding = 0,
    Callback = function(Value)
        StaticPingCompensation = Value
    end
})

local AutoClickerToggle = Tabs.Main:AddToggle("AutoClickerToggle", {
    Title = "Auto Clicker",
    Description = "Ultra-fast auto clicker at maximum speed",
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

local GameModeParagraph = Tabs.Info:AddParagraph({
    Title = "Current Game",
    Content = "Gamemode: " .. GetCurrentGameName()
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

local TrajectoryInfoParagraph = Tabs.Info:AddParagraph({
    Title = "Trajectory Analysis",
    Content = "Analyzing..."
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
            
            GameInfoParagraph:SetDesc(string.format(
                "FPS: %d | Ping: %d ms",
                fps, ping
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
                BallInfoParagraph:SetDesc("Ball found! Enhanced 3D system active")
            end
        else
            BallInfoParagraph:SetDesc("Searching for ball...")
        end
        
        if BallShadow and (not BallShadow.Parent) then
            BallInfoParagraph:SetDesc("Ball removed")
            BallShadow = nil
            RealBall = nil
            VelocityHistory = {}
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
            local currentVelocity = moveDir.Magnitude / (dt > 0 and dt or 0.016)
            
            AddVelocityToHistory(currentVelocity)
            local avgVelocity = GetAverageVelocity()
            
            local trajectory = AnalyzeBallTrajectory(moveDir, dt, ballHeight)
            
            local realBallPos = Vector3.new(BallPos.X, ballPosY, BallPos.Z)
            local distance3D = (PlayerPos - realBallPos).Magnitude
            
            local flatDistance = (Vector3.new(PlayerPos.X, 0, PlayerPos.Z) - Vector3.new(BallPos.X, 0, BallPos.Z)).Magnitude
            
            local ballColor = WhiteColor
            if RealBall then
                ballColor = GetBallColor()
            end
            local isBallWhite = ballColor == WhiteColor
            
            local heightDifference = math.abs(PlayerPos.Y - ballPosY)
            
            local baseHeightTolerance = 15
            local velocityHeightBonus = math.clamp(avgVelocity / 10, 0, 12)
            
            if ballHeight > 25 then
                baseHeightTolerance = 30
                velocityHeightBonus = velocityHeightBonus * 2
            elseif trajectory.isAerial or trajectory.isHighShot then
                baseHeightTolerance = 22
                velocityHeightBonus = velocityHeightBonus * 1.5
            end
            
            local heightTolerance = baseHeightTolerance + velocityHeightBonus
            
            local ping = LP:GetNetworkPing()
            local optimalDistance = CalculateOptimalDistance(avgVelocity, ping, heightDifference)
            
            BallInfoParagraph:SetDesc(string.format(
                "Speed: %.2f | Avg: %.2f | Height: %.1f | Dist: %.1f", 
                currentVelocity, avgVelocity, ballHeight, distance3D
            ))
            
            SystemInfoParagraph:SetDesc(string.format(
                "Optimal: %.1f | Flat: %.1f | H-Diff: %.1f | Tolerance: %.1f",
                optimalDistance,
                flatDistance,
                heightDifference,
                heightTolerance
            ))
            
            local trajectoryType = "Ground"
            if trajectory.isVerticalDrop then
                trajectoryType = "Vertical Drop"
            elseif trajectory.isDiagonal then
                trajectoryType = "Diagonal"
            elseif trajectory.isHighShot then
                trajectoryType = "High Shot"
            elseif trajectory.isAerial then
                trajectoryType = "Aerial"
            end
            
            TrajectoryInfoParagraph:SetDesc(string.format(
                "Type: %s | H-Speed: %.1f | V-Speed: %.1f | Total: %.1f",
                trajectoryType,
                trajectory.horizontalSpeed,
                trajectory.verticalSpeed,
                trajectory.totalSpeed
            ))
            
            if AutoParryEnabled then
                local currentTime = tick()
                
                local toBall = (BallPos - PlayerPos).Unit
                local ballDirection = moveDir.Unit
                
                local isMovingTowardsPlayer = false
                local lastDistance = LastBallPos and (PlayerPos - Vector3.new(LastBallPos.X, PlayerPos.Y, LastBallPos.Z)).Magnitude or flatDistance
                local isGettingCloser = flatDistance < lastDistance + 2
                
                if trajectory.isVerticalDrop then
                    isMovingTowardsPlayer = flatDistance < optimalDistance * 1.6
                elseif ballHeight > 20 then
                    isMovingTowardsPlayer = isGettingCloser or flatDistance < optimalDistance * 1.4
                elseif trajectory.isDiagonal then
                    local horizontalApproach = ballDirection:Dot(toBall) < -0.2
                    isMovingTowardsPlayer = horizontalApproach or isGettingCloser
                else
                    isMovingTowardsPlayer = ballDirection:Dot(toBall) < -0.4 or isGettingCloser
                end
                
                local isAccelerating = currentVelocity > (avgVelocity * 1.3)
                
                local effectiveDistance = flatDistance
                local effectiveOptimalDistance = optimalDistance
                
                if trajectory.isVerticalDrop then
                    effectiveOptimalDistance = optimalDistance * 1.5
                elseif ballHeight > 25 then
                    effectiveDistance = flatDistance * 0.9
                    effectiveOptimalDistance = optimalDistance * 1.4
                elseif trajectory.isAerial or trajectory.isHighShot then
                    effectiveDistance = flatDistance * 0.95
                    effectiveOptimalDistance = optimalDistance * 1.25
                elseif trajectory.isDiagonal then
                    effectiveDistance = (distance3D + flatDistance) / 2
                    effectiveOptimalDistance = optimalDistance * 1.15
                end
                
                local shouldParry = not isBallWhite
                    and currentTime - LastParryTime > ParryCooldown
                    and effectiveDistance <= effectiveOptimalDistance
                    and avgVelocity > 18
                    and isMovingTowardsPlayer
                    and not isAccelerating
                    and flatDistance >= MinParryDistance * 0.8
                    and (ballHeight > 15 or heightDifference <= heightTolerance)
                
                if shouldParry then
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
