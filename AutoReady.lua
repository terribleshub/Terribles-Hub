-- Auto Ready Module
-- Part of Extras Modules

local AutoReadyModule = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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
local LastPosition = nil
local StuckCheckTime = 0
local LastUpdateTime = 0
local ShouldAutoWalk = false

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
        ShouldAutoWalk = false
        humanoid:Move(Vector3.new(0, 0, 0))
        pcall(function()
            humanoid:MoveTo(rootPart.Position)
        end)
        return true
    end
    
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

-- Función para detener el movimiento completamente
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
    
    IsWalking = false
end

-- Loop principal de movimiento
local function MovementLoop()
    if not IsEnabled then 
        print("[AutoReady] Not enabled")
        return 
    end
    
    local currentTime = tick()
    
    -- Actualizar a la tasa especificada
    if currentTime - LastUpdateTime < UpdateRate then
        return
    end
    LastUpdateTime = currentTime
    
    -- Verificar que el personaje exista
    if not LP.Character or not LP.Character.PrimaryPart then
        print("[AutoReady] No character or PrimaryPart")
        return
    end
    
    print("[AutoReady] Loop running...")
    
    local inGame = IsInGame()
    
    -- Detectar ENTRADA al game (lobby -> game)
    if inGame and not LastGameState then
        -- Acaba de ENTRAR al game
        LastGameState = true
        ShouldAutoWalk = false
        
        if IsWalking then
            StopMovement()
        end
        
        return
    end
    
    -- Detectar SALIDA del game (game -> lobby)
    if not inGame and LastGameState then
        -- Acaba de SALIR del game
        LastGameState = false
        ShouldAutoWalk = true
        task.wait(0.5)
    end
    
    -- Si está EN GAME, no hacer nada
    if inGame then
        if IsWalking then
            StopMovement()
        end
        return
    end
    
    -- ESTÁ EN LOBBY
    local distance = (ReadyCoordinates - LP.Character.PrimaryPart.Position).Magnitude
    
    -- Debug temporal
    if tick() % 2 < 0.1 then -- cada 2 segundos aprox
        print("[AutoReady] ShouldAutoWalk:", ShouldAutoWalk, "Distance:", math.floor(distance), "Walking:", IsWalking)
    end
    
    -- Solo caminar si ShouldAutoWalk está activo
    if ShouldAutoWalk then
        if distance > ArrivalThreshold then
            IsWalking = true
            MoveTowardsTarget()
        else
            -- Ya llegó, detener y dar control permanente
            if IsWalking then
                StopMovement()
            end
            ShouldAutoWalk = false
        end
    else
        -- No debe auto-caminar, asegurar que no esté caminando
        if IsWalking then
            StopMovement()
        end
    end
end

-- Función para iniciar el Auto Ready
function AutoReadyModule:Start()
    if IsEnabled then
        print("[AutoReady] Already enabled")
        return
    end
    
    print("[AutoReady] Starting module...")
    
    IsEnabled = true
    IsWalking = false
    LastPosition = nil
    StuckCheckTime = 0
    LastUpdateTime = 0
    LastGameState = IsInGame()
    
    print("[AutoReady] InGame status:", LastGameState)
    
    -- Si está en game al iniciar, no auto-caminar
    -- Si está en lobby al iniciar, verificar distancia
    if LastGameState then
        ShouldAutoWalk = false
        print("[AutoReady] In game, ShouldAutoWalk = false")
    else
        -- Está en lobby, verificar si está lejos de las coordenadas
        if LP.Character and LP.Character.PrimaryPart then
            local distance = (ReadyCoordinates - LP.Character.PrimaryPart.Position).Magnitude
            ShouldAutoWalk = distance > ArrivalThreshold
            print("[AutoReady] In lobby, distance:", math.floor(distance), "ShouldAutoWalk:", ShouldAutoWalk)
        else
            ShouldAutoWalk = true
            print("[AutoReady] No character, ShouldAutoWalk = true")
        end
    end
    
    task.wait(0.1)
    
    MovementConnection = RunService.Heartbeat:Connect(MovementLoop)
    print("[AutoReady] Connection established")
end

-- Función para detener el Auto Ready
function AutoReadyModule:Stop()
    if not IsEnabled then
        return
    end
    
    IsEnabled = false
    IsWalking = false
    ShouldAutoWalk = false
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
        AutoWalk = ShouldAutoWalk
    }
end

return AutoReadyModule
