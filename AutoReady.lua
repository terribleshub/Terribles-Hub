-- Auto Ready Module
-- Part of Extras Modules

local AutoReadyModule = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LP = Players.LocalPlayer

-- Configuración
local ReadyCoordinates = Vector3.new(568.0, 285.3, -777.4)
local ArrivalThreshold = 5
local UpdateRate = 0.05

-- Variables de estado
local IsEnabled = false
local IsWalking = false
local LastGameState = false
local MovementConnection = nil
local LastUserInputTime = 0
local LastUpdateTime = 0
local LastPosition = nil
local StuckCheckTime = 0
local AutoWalkAfterGame = false

-- Función para verificar si está en game
local function IsInGame()
    local success, result = pcall(function()
        if not LP.PlayerGui then return false end
        local hud = LP.PlayerGui:FindFirstChild("HUD")
        if not hud then return false end
        local holderBottom = hud:FindFirstChild("HolderBottom")
        if not holderBottom then return false end
        local healthBar = holderBottom:FindFirstChild("HealthBar")
        if not healthBar then return false end
        return healthBar.Visible == true
    end)
    return success and result
end

-- Función para verificar input del usuario
local function CheckUserInput()
    if not LP.Character or not LP.Character.PrimaryPart then return false end
    
    local humanoid = LP.Character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    
    -- Si no estamos en auto-walk pero el humanoid está moviéndose
    if not AutoWalkAfterGame and humanoid.MoveDirection.Magnitude > 0.1 then
        LastUserInputTime = tick()
        return true
    end
    
    -- Dar tiempo de gracia después del último input
    if tick() - LastUserInputTime < 1.5 then
        return true
    end
    
    return false
end

-- Función para mover el personaje
local function MoveTowardsTarget()
    if not LP.Character or not LP.Character.PrimaryPart then
        return false
    end
    
    local humanoid = LP.Character:FindFirstChild("Humanoid")
    local rootPart = LP.Character.PrimaryPart
    
    if not humanoid or humanoid.Health <= 0 then
        return false
    end
    
    local currentPos = rootPart.Position
    local distance = (ReadyCoordinates - currentPos).Magnitude
    
    -- Verificar si llegamos
    if distance <= ArrivalThreshold then
        IsWalking = false
        AutoWalkAfterGame = false
        humanoid:Move(Vector3.new(0, 0, 0))
        return true
    end
    
    -- Calcular dirección hacia el objetivo
    local targetFlat = Vector3.new(ReadyCoordinates.X, currentPos.Y, ReadyCoordinates.Z)
    local direction = (targetFlat - currentPos).Unit
    
    -- Usar MoveTo para pathfinding automático
    humanoid:MoveTo(ReadyCoordinates)
    
    -- Asegurar velocidad correcta
    if humanoid.WalkSpeed < 16 then
        humanoid.WalkSpeed = 16
    end
    
    -- Detectar si está atascado y saltar
    if LastPosition then
        local movedDistance = (currentPos - LastPosition).Magnitude
        if movedDistance < 0.5 and tick() - StuckCheckTime > 2 then
            humanoid.Jump = true
            StuckCheckTime = tick()
        end
    end
    
    LastPosition = currentPos
    
    return false
end

-- Función para detener el movimiento
local function StopMovement()
    if not LP.Character then return end
    
    local humanoid = LP.Character:FindFirstChild("Humanoid")
    local rootPart = LP.Character.PrimaryPart
    
    if humanoid and rootPart then
        humanoid:Move(Vector3.new(0, 0, 0))
        pcall(function()
            humanoid:MoveTo(rootPart.Position)
        end)
    end
end

-- Loop principal de movimiento
local function MovementLoop()
    if not IsEnabled then return end
    
    local currentTime = tick()
    
    -- Actualizar a la tasa especificada
    if currentTime - LastUpdateTime < UpdateRate then
        return
    end
    LastUpdateTime = currentTime
    
    -- Verificar que el personaje exista
    if not LP.Character or not LP.Character.PrimaryPart then
        return
    end
    
    local inGame = IsInGame()
    
    -- Detectar ENTRADA al game (estaba fuera, ahora está dentro)
    if inGame and not LastGameState then
        -- Acaba de entrar al game
        IsWalking = false
        AutoWalkAfterGame = false
        StopMovement()
        LastGameState = true
        return
    end
    
    -- Detectar SALIDA del game (estaba dentro, ahora está fuera)
    if not inGame and LastGameState then
        -- Acaba de salir del game (murió o terminó)
        LastGameState = false
        AutoWalkAfterGame = true
        LastUserInputTime = 0
        IsWalking = false
        task.wait(0.5) -- Pequeña pausa para estabilizar
    end
    
    -- Si está en game, no hacer nada
    if inGame then
        return
    end
    
    -- Si está en el lobby
    if not inGame then
        -- Verificar si el usuario está dando input manual
        if CheckUserInput() and not AutoWalkAfterGame then
            if IsWalking then
                StopMovement()
                IsWalking = false
            end
            return
        end
        
        -- Si debe auto-caminar (después de salir del game) o está lejos
        local distance = (ReadyCoordinates - LP.Character.PrimaryPart.Position).Magnitude
        
        if AutoWalkAfterGame or distance > ArrivalThreshold then
            IsWalking = true
            local arrived = MoveTowardsTarget()
            
            if arrived then
                AutoWalkAfterGame = false
            end
        else
            if IsWalking then
                IsWalking = false
                StopMovement()
            end
        end
    end
end

-- Función para iniciar el Auto Ready
function AutoReadyModule:Start()
    if IsEnabled then
        return
    end
    
    IsEnabled = true
    IsWalking = false
    LastUserInputTime = 0
    LastUpdateTime = 0
    LastPosition = nil
    StuckCheckTime = 0
    AutoWalkAfterGame = false
    LastGameState = IsInGame()
    
    task.wait(0.1)
    
    MovementConnection = RunService.Heartbeat:Connect(MovementLoop)
end

-- Función para detener el Auto Ready
function AutoReadyModule:Stop()
    if not IsEnabled then
        return
    end
    
    IsEnabled = false
    IsWalking = false
    AutoWalkAfterGame = false
    LastPosition = nil
    
    StopMovement()
    
    if MovementConnection then
        MovementConnection:Disconnect()
        MovementConnection = nil
    end
end

-- Función para verificar si está activo
function AutoReadyModule:IsEnabled()
    return IsEnabled
end

-- Función para cambiar las coordenadas de Ready
function AutoReadyModule:SetReadyCoordinates(newCoords)
    ReadyCoordinates = newCoords
end

-- Función para obtener el estado actual
function AutoReadyModule:GetStatus()
    local distance = 0
    
    if LP.Character and LP.Character.PrimaryPart then
        distance = (ReadyCoordinates - LP.Character.PrimaryPart.Position).Magnitude
    end
    
    return {
        Enabled = IsEnabled,
        Walking = IsWalking,
        InGame = IsInGame(),
        Distance = distance,
        AutoWalk = AutoWalkAfterGame
    }
end

return AutoReadyModule
