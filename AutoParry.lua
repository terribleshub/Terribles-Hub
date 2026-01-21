-- AutoParry Module for Death Ball
-- Version: 2.0 - Based on proven shadow method

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
    self.VelocityMultiplier = 0.3
    self.MinParryCooldown = 0.01
    self.HeightIgnoreThreshold = 20
    
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
            ignored = true
        }
    end
    
    -- Calculate velocity if we have previous position
    if self.PreviousPosition then
        local velocity = (currentPos - self.PreviousPosition).Magnitude / dt
        local ping = self.LP:GetNetworkPing()
        
        -- Dynamic distance calculation with ping compensation
        local dynamicDistance = self.BaseDistance + (velocity * ping * self.VelocityMultiplier)
        
        -- Use 3D distance instead of flat distance for accurate parrying from all angles
        local distance3D = (rootPart.Position - currentPos).Magnitude
        
        -- Check ball color (must not be white)
        local ballColor = self:GetBallColor(self.BallObject)
        local isBallWhite = ballColor == self.WhiteColor
        
        -- Auto Parry Logic - Use 3D distance for consistent parrying from all directions
        if not isBallWhite then
            if distance3D <= dynamicDistance and (tick() - self.LastParryTime) > self.MinParryCooldown then
                self:TriggerParry()
            end
        end
        
        self.PreviousPosition = currentPos
        
        -- Calculate flat distance for UI display only
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
            ballColor = ballColor,
            ballFound = true,
            ignored = false
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

-- Set velocity multiplier (ping compensation)
function AutoParryModule:SetVelocityMultiplier(value)
    value = tonumber(value) or 0.3
    self.VelocityMultiplier = math.clamp(value, 0.1, 1.0)
end

-- Set ping compensation (compatible con valores 1-25 del slider)
function AutoParryModule:SetPingCompensation(value)
    value = tonumber(value) or 1
    -- Convierte el rango 1-25 a 0.1-1.0
    local normalizedValue = math.clamp(value / 25, 0.1, 1.0)
    self.VelocityMultiplier = normalizedValue
end

-- Set height ignore threshold
function AutoParryModule:SetHeightIgnoreThreshold(value)
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
