-- AutoParry Module for Death Ball
-- Version: 2.1 - Auto Ping Compensation

local AutoParryModule = {}
AutoParryModule.__index = AutoParryModule

-- Services
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Players = game:GetService("Players")

-- Constructor
function AutoParryModule.new()
    local self = setmetatable({}, AutoParryModule)
    
    -- References
    self.LP = Players.LocalPlayer
    self.BallShadow = nil
    self.BallObject = nil
    self.PreviousPosition = nil
    self.WhiteColor = Color3.new(1, 1, 1)
    
    -- Settings
    self.Enabled = false
    self.BaseDistance = 15
    self.ManualCompensation = 1.0  -- Valor del slider manual
    self.AutoCompensationEnabled = true  -- Auto compensation activado por defecto
    self.MinParryCooldown = 0.01
    self.HeightIgnoreThreshold = 20
    
    -- Auto Compensation Settings
    self.PingHistory = {}
    self.MaxPingHistory = 10
    
    -- State
    self.LastParryTime = 0
    self.IsParrying = false
    
    -- Stats
    self.ParryStats = {
        TotalParries = 0,
        SuccessfulParries = 0,
        CurrentCombo = 0,
        MaxCombo = 0
    }
    
    -- Loop
    self.Connection = nil
    
    return self
end

-- Get ball color
function AutoParryModule:GetBallColor(target)
    if not target then return self.WhiteColor end
    
    local highlight = target:FindFirstChildOfClass("Highlight")
    if highlight then
        return highlight.FillColor
    end
    
    return target:IsA("Part") and target.Color or self.WhiteColor
end

-- Calculate visual height from shadow
function AutoParryModule:GetVisualHeight(shadow)
    if not shadow then return 0 end
    
    local shadowIncrease = math.max(0, shadow.Size.X - 5)
    local height = (shadowIncrease * 20) + 3
    
    return math.min(height, 100)
end

-- Add ping to history
function AutoParryModule:AddPingToHistory(ping)
    table.insert(self.PingHistory, ping)
    if #self.PingHistory > self.MaxPingHistory then
        table.remove(self.PingHistory, 1)
    end
end

-- Get average ping
function AutoParryModule:GetAveragePing()
    if #self.PingHistory == 0 then return 0 end
    
    local sum = 0
    for _, p in ipairs(self.PingHistory) do
        sum = sum + p
    end
    return sum / #self.PingHistory
end

-- Calculate automatic compensation based on ping
function AutoParryModule:CalculateAutoCompensation(ping)
    local pingMs = ping * 1000
    
    -- Fórmula de compensación basada en ping
    -- Ping bajo (10-30ms) = +1-3 studs
    -- Ping medio (30-80ms) = +3-10 studs
    -- Ping alto (80-150ms) = +10-20 studs
    -- Ping muy alto (150+ms) = +20-25 studs
    
    local compensation
    
    if pingMs <= 30 then
        -- Ping excelente: compensación mínima
        compensation = 1 + (pingMs / 30) * 2  -- 1-3 studs
    elseif pingMs <= 80 then
        -- Ping bueno a normal: compensación gradual
        compensation = 3 + ((pingMs - 30) / 50) * 7  -- 3-10 studs
    elseif pingMs <= 150 then
        -- Ping alto: compensación fuerte
        compensation = 10 + ((pingMs - 80) / 70) * 10  -- 10-20 studs
    else
        -- Ping muy alto: compensación máxima
        compensation = 20 + math.min((pingMs - 150) / 50 * 5, 5)  -- 20-25 studs
    end
    
    return math.clamp(compensation, 1, 25)
end

-- Execute parry
function AutoParryModule:TriggerParry()
    if self.IsParrying then return end
    
    self.IsParrying = true
    
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    
    self.LastParryTime = tick()
    self.ParryStats.TotalParries = self.ParryStats.TotalParries + 1
    self.ParryStats.SuccessfulParries = self.ParryStats.SuccessfulParries + 1
    self.ParryStats.CurrentCombo = self.ParryStats.CurrentCombo + 1
    
    if self.ParryStats.CurrentCombo > self.ParryStats.MaxCombo then
        self.ParryStats.MaxCombo = self.ParryStats.CurrentCombo
    end
    
    task.wait(0.01)
    self.IsParrying = false
end

-- Main processing loop
function AutoParryModule:ProcessFrame(dt)
    if not self.Enabled then 
        self.PreviousPosition = nil
        return nil
    end
    
    -- Find ball shadow
    self.BallShadow = (self.BallShadow and self.BallShadow.Parent) and self.BallShadow or (workspace:FindFirstChild("FX") and workspace.FX:FindFirstChild("BallShadow"))
    
    -- Find ball object
    self.BallObject = (self.BallObject and self.BallObject.Parent) and self.BallObject or (workspace:FindFirstChild("Ball") or workspace:FindFirstChild("Part"))
    
    -- Validate everything exists
    if not self.BallShadow or not self.BallObject or not self.LP.Character or not self.LP.Character.PrimaryPart then
        self.PreviousPosition = nil
        return nil
    end
    
    local rootPart = self.LP.Character.PrimaryPart
    
    -- Calculate real ball position with height
    local height = self:GetVisualHeight(self.BallShadow)
    local currentPos = Vector3.new(
        self.BallShadow.Position.X,
        self.BallShadow.Position.Y + height,
        self.BallShadow.Position.Z
    )
    
    -- Calculate height difference (positive = ball below, negative = ball above)
    local heightDifference = rootPart.Position.Y - currentPos.Y
    
    -- Ignore if ball is too far below player
    if heightDifference > self.HeightIgnoreThreshold then
        self.PreviousPosition = currentPos
        return {
            velocity = 0,
            flatDistance = (Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z) - Vector3.new(currentPos.X, 0, currentPos.Z)).Magnitude,
            height = height,
            heightDifference = heightDifference,
            dynamicDistance = 0,
            ballFound = true,
            ignored = true,
            autoCompensation = 0,
            currentPing = 0,
            compensationMode = self.AutoCompensationEnabled and "Auto" or "Manual"
        }
    end
    
    -- Calculate velocity if we have previous position
    if self.PreviousPosition then
        local velocity = (currentPos - self.PreviousPosition).Magnitude / dt
        local ping = self.LP:GetNetworkPing()
        
        -- Add ping to history for smoothing
        self:AddPingToHistory(ping)
        local avgPing = self:GetAveragePing()
        
        -- Calculate compensation based on mode
        local compensation
        if self.AutoCompensationEnabled then
            compensation = self:CalculateAutoCompensation(avgPing)
        else
            compensation = self.ManualCompensation
        end
        
        -- Dynamic distance calculation
        local dynamicDistance = self.BaseDistance + compensation
        
        -- Use 3D distance for accurate parrying from all angles
        local distance3D = (rootPart.Position - currentPos).Magnitude
        
        -- Check ball color (must not be white)
        local ballColor = self:GetBallColor(self.BallObject)
        local isBallWhite = ballColor == self.WhiteColor
        
        -- Auto Parry Logic
        if not isBallWhite then
            if distance3D <= dynamicDistance and (tick() - self.LastParryTime) > self.MinParryCooldown then
                self:TriggerParry()
            end
        end
        
        self.PreviousPosition = currentPos
        
        -- Calculate flat distance for UI display
        local flatDistance = (Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z) - Vector3.new(currentPos.X, 0, currentPos.Z)).Magnitude
        
        -- Return data for UI
        return {
            velocity = velocity,
            flatDistance = flatDistance,
            distance3D = distance3D,
            height = height,
            heightDifference = heightDifference,
            dynamicDistance = dynamicDistance,
            ping = ping,
            avgPing = avgPing,
            ballColor = ballColor,
            ballFound = true,
            ignored = false,
            autoCompensation = compensation,
            currentPing = math.floor(ping * 1000),
            compensationMode = self.AutoCompensationEnabled and "Auto" or "Manual"
        }
    end
    
    self.PreviousPosition = currentPos
    return nil
end

-- Start the module
function AutoParryModule:Start()
    if self.Connection then return end
    
    self.Enabled = true
    
    self.Connection = RunService.RenderStepped:Connect(function(dt)
        self:ProcessFrame(dt)
    end)
end

-- Stop the module
function AutoParryModule:Stop()
    self.Enabled = false
    
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    
    self.PreviousPosition = nil
    self.BallShadow = nil
    self.BallObject = nil
    self.PingHistory = {}
end

-- Reset combo
function AutoParryModule:ResetCombo()
    self.ParryStats.CurrentCombo = 0
end

-- Set base distance
function AutoParryModule:SetBaseDistance(value)
    value = tonumber(value) or 15
    self.BaseDistance = math.clamp(value, 10, 30)
end

-- Set manual compensation
function AutoParryModule:SetPingCompensation(value)
    value = tonumber(value) or 1
    self.ManualCompensation = math.clamp(value, 1, 25)
end

-- Toggle auto compensation
function AutoParryModule:SetAutoCompensation(enabled)
    self.AutoCompensationEnabled = enabled
    if enabled then
        self.PingHistory = {}  -- Reset ping history when enabling
    end
end

-- Check if auto compensation is enabled
function AutoParryModule:IsAutoCompensationEnabled()
    return self.AutoCompensationEnabled
end

-- Set velocity multiplier (legacy)
function AutoParryModule:SetVelocityMultiplier(value)
    self:SetPingCompensation(value)
end

-- Set height ignore threshold
function AutoParryModule:SetHeightIgnoreThreshold(value)
    value = tonumber(value) or 20
    self.HeightIgnoreThreshold = math.clamp(value, 10, 50)
end

-- Get stats
function AutoParryModule:GetStats()
    return self.ParryStats
end

-- Enable/Disable
function AutoParryModule:SetEnabled(enabled)
    self.Enabled = enabled
    if not enabled then
        self:ResetCombo()
        self.PreviousPosition = nil
    end
end

-- Check if enabled
function AutoParryModule:IsEnabled()
    return self.Enabled
end

return AutoParryModule
