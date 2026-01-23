-- Auto Hability Module for Death Ball
-- Version: 4.0 - Visual cooldown detection system with DEBUG

local AutoHabModule = {}
AutoHabModule.__index = AutoHabModule

-- Services
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎮 CONFIGURACIÓN DE PERSONAJES Y HABILIDADES
-- ═══════════════════════════════════════════════════════════════════════════

local CHARACTER_ABILITIES = {
    ["Gazo"] = {Enum.KeyCode.One, Enum.KeyCode.Four},
    ["Saito"] = {Enum.KeyCode.One, Enum.KeyCode.Three, Enum.KeyCode.Four},
    ["Naruto"] = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four},
}

-- ═══════════════════════════════════════════════════════════════════════════

-- Constructor
function AutoHabModule.new(autoParryModule)
    local self = setmetatable({}, AutoHabModule)
    
    -- Referencias
    self.LP = Players.LocalPlayer
    self.PlayerGui = self.LP:WaitForChild("PlayerGui")
    self.AutoParry = autoParryModule
    
    -- Estado
    self.Enabled = false
    self.CurrentCharacter = nil
    self.CharacterAbilities = {}
    
    -- Cooldown tracking
    self.AbilityCooldowns = {
        [Enum.KeyCode.One] = false,
        [Enum.KeyCode.Two] = false,
        [Enum.KeyCode.Three] = false,
        [Enum.KeyCode.Four] = false
    }
    
    -- Deflect button cooldown tracking
    self.DeflectButton = nil
    self.DeflectCooldownFrame = nil
    self.AbilityActivationThreshold = 0.20 -- Activar cuando el cooldown esté al 20% o menos
    self.AbilityUsedInCooldown = false
    self.LastCooldownSize = 0
    
    -- GUI tracking
    self.CharacterGui = nil
    self.GuiConnections = {}
    
    -- Stats
    self.Stats = {
        TotalActivations = 0,
        SuccessfulDeflects = 0,
        FailedAttempts = 0
    }
    
    -- Connections
    self.Connection = nil
    self.CooldownConnection = nil
    
    print("[AutoHab] 🔧 Módulo creado")
    
    return self
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 🔍 DETECCIÓN DE PERSONAJE
-- ═══════════════════════════════════════════════════════════════════════════

function AutoHabModule:IsCharacterGui(text)
    return string.match(text, ".+%s~%sLvl%.%s%d+") ~= nil
end

function AutoHabModule:FindCharacterGui()
    for _, gui in pairs(self.PlayerGui:GetDescendants()) do
        if gui:IsA("TextLabel") or gui:IsA("TextButton") or gui:IsA("TextBox") then
            if self:IsCharacterGui(gui.Text) then
                return gui
            end
        end
    end
    return nil
end

function AutoHabModule:ExtractCharacterName(guiText)
    local name = string.match(guiText, "(.+)%s~%sLvl")
    return name
end

function AutoHabModule:UpdateCurrentCharacter()
    if not self.CharacterGui then
        self.CharacterGui = self:FindCharacterGui()
        if not self.CharacterGui then
            print("[AutoHab] ❌ No se encontró GUI de personaje")
            return false
        end
        print("[AutoHab] ✅ GUI encontrada:", self.CharacterGui.Text)
    end
    
    local characterName = self:ExtractCharacterName(self.CharacterGui.Text)
    
    if characterName and characterName ~= self.CurrentCharacter then
        self.CurrentCharacter = characterName
        self.CharacterAbilities = CHARACTER_ABILITIES[characterName] or {}
        print("[AutoHab] 🎮 Personaje detectado:", characterName)
        print("[AutoHab] 🎯 Habilidades disponibles:", #self.CharacterAbilities)
        return true
    end
    
    return characterName ~= nil
end

function AutoHabModule:SetupGuiMonitoring()
    if not self.CharacterGui then return end
    
    for _, conn in pairs(self.GuiConnections) do
        conn:Disconnect()
    end
    self.GuiConnections = {}
    
    table.insert(self.GuiConnections, self.CharacterGui:GetPropertyChangedSignal("Text"):Connect(function()
        print("[AutoHab] 📝 Texto de GUI cambió")
        self:UpdateCurrentCharacter()
    end))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎯 DETECCIÓN DEL BOTÓN DE DEFLECT Y SU COOLDOWN
-- ═══════════════════════════════════════════════════════════════════════════

function AutoHabModule:FindDeflectButton()
    local success, result = pcall(function()
        local HUD = self.PlayerGui:FindFirstChild("HUD")
        if not HUD then return nil end
        
        local HolderBottom = HUD:FindFirstChild("HolderBottom")
        if not HolderBottom then return nil end
        
        local ToolbarButtons = HolderBottom:FindFirstChild("ToolbarButtons")
        if not ToolbarButtons then return nil end
        
        local DeflectButton = ToolbarButtons:FindFirstChild("DeflectButton")
        if not DeflectButton then return nil end
        
        return DeflectButton
    end)
    
    return success and result or nil
end

function AutoHabModule:FindDeflectCooldown()
    if not self.DeflectButton then
        self.DeflectButton = self:FindDeflectButton()
        if not self.DeflectButton then
            print("[AutoHab] ❌ No se encontró DeflectButton")
            return nil
        end
        print("[AutoHab] ✅ DeflectButton encontrado")
    end
    
    local cooldown = self.DeflectButton:FindFirstChild("Cooldown")
    if cooldown then
        print("[AutoHab] ✅ Cooldown frame encontrado")
    else
        print("[AutoHab] ❌ No se encontró Cooldown frame")
    end
    return cooldown
end

function AutoHabModule:SetupCooldownMonitoring()
    if self.CooldownConnection then
        self.CooldownConnection:Disconnect()
    end
    
    self.DeflectCooldownFrame = self:FindDeflectCooldown()
    
    if not self.DeflectCooldownFrame then
        print("[AutoHab] ⚠️ No se pudo configurar monitoreo de cooldown")
        return
    end
    
    print("[AutoHab] ✅ Monitoreo de cooldown configurado")
    
    -- Monitorear cambios en Visible
    self.CooldownConnection = self.DeflectCooldownFrame:GetPropertyChangedSignal("Visible"):Connect(function()
        if self.DeflectCooldownFrame.Visible then
            print("[AutoHab] 🔄 Cooldown iniciado, reseteando flags")
            -- Cooldown comenzó, resetear flag
            self.AbilityUsedInCooldown = false
            self.LastCooldownSize = 1
        else
            print("[AutoHab] ✅ Cooldown terminó")
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎯 DETECCIÓN DE COOLDOWNS DE HABILIDADES
-- ═══════════════════════════════════════════════════════════════════════════

function AutoHabModule:IsAbilityOnCooldown(keyCode)
    local keyToButtonMap = {
        [Enum.KeyCode.One] = "AbilityButton1",
        [Enum.KeyCode.Two] = "AbilityButton2",
        [Enum.KeyCode.Three] = "AbilityButton3",
        [Enum.KeyCode.Four] = "AbilityButton4"
    }
    
    local buttonName = keyToButtonMap[keyCode]
    if not buttonName then return true end
    
    local success, isOnCooldown = pcall(function()
        local HUD = self.PlayerGui:FindFirstChild("HUD")
        if not HUD then return true end
        
        local HolderBottom = HUD:FindFirstChild("HolderBottom")
        if not HolderBottom then return true end
        
        local ToolbarButtons = HolderBottom:FindFirstChild("ToolbarButtons")
        if not ToolbarButtons then return true end
        
        local AbilityButton = ToolbarButtons:FindFirstChild(buttonName)
        if not AbilityButton then return true end
        
        local Cooldown = AbilityButton:FindFirstChild("Cooldown")
        if not Cooldown then return false end
        
        -- Si el cooldown está visible, la habilidad está en cooldown
        return Cooldown.Visible
    end)
    
    return success and isOnCooldown or true
end

function AutoHabModule:GetAvailableAbility()
    if #self.CharacterAbilities == 0 then
        return nil
    end
    
    for _, keyCode in ipairs(self.CharacterAbilities) do
        if not self:IsAbilityOnCooldown(keyCode) then
            print("[AutoHab] 💫 Habilidad disponible encontrada:", keyCode.Name)
            return keyCode
        end
    end
    
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ⚡ ACTIVACIÓN DE HABILIDAD
-- ═══════════════════════════════════════════════════════════════════════════

function AutoHabModule:ActivateAbility(keyCode)
    if not keyCode then return false end
    
    print("[AutoHab] ⚡ Enviando input para:", keyCode.Name)
    
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    
    self.Stats.TotalActivations = self.Stats.TotalActivations + 1
    
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎯 LÓGICA: DETECTAR VENTANA DE ACTIVACIÓN
-- ═══════════════════════════════════════════════════════════════════════════

function AutoHabModule:GetDeflectCooldownProgress()
    if not self.DeflectCooldownFrame then
        self.DeflectCooldownFrame = self:FindDeflectCooldown()
        if not self.DeflectCooldownFrame then return 0 end
    end
    
    -- Si no está visible, no hay cooldown
    if not self.DeflectCooldownFrame.Visible then
        return 0
    end
    
    -- El cooldown usa Size.Y.Scale para mostrar el progreso
    -- Va de 1 (inicio) a 0 (fin)
    local cooldownSize = self.DeflectCooldownFrame.Size.Y.Scale
    print("[AutoHab] 📊 Cooldown progress:", math.floor(cooldownSize * 100) .. "%")
    return cooldownSize
end

function AutoHabModule:GetBallData()
    if not self.AutoParry then return nil end
    
    local data = self.AutoParry:ProcessFrame(0.016)
    
    if not data or not data.ballFound or data.ignored then
        return nil
    end
    
    return data
end

function AutoHabModule:ShouldActivateAbility()
    -- Verificar que hay personaje configurado
    if not self.CurrentCharacter or #self.CharacterAbilities == 0 then
        print("[AutoHab] ❌ Sin personaje o sin habilidades configuradas")
        return false
    end
    
    -- Obtener progreso del cooldown
    local cooldownProgress = self:GetDeflectCooldownProgress()
    
    -- Si no hay cooldown activo, no hacer nada
    if cooldownProgress == 0 then
        self.AbilityUsedInCooldown = false
        return false
    end
    
    -- Verificar que estamos en la ventana de activación (últimos 5% del cooldown)
    if cooldownProgress > self.AbilityActivationThreshold then
        print("[AutoHab] ⏳ Esperando ventana de activación... (" .. math.floor(cooldownProgress * 100) .. "% > " .. math.floor(self.AbilityActivationThreshold * 100) .. "%)")
        return false
    end
    
    print("[AutoHab] ✨ ¡Ventana de activación alcanzada! (" .. math.floor(cooldownProgress * 100) .. "%)")
    
    -- Verificar que no hemos usado habilidad en este cooldown
    if self.AbilityUsedInCooldown then
        print("[AutoHab] ⚠️ Ya se usó habilidad en este cooldown")
        return false
    end
    
    -- Verificar que la bola sigue viniendo
    local ballData = self:GetBallData()
    if not ballData then
        print("[AutoHab] ❌ No hay bola detectada")
        return false
    end
    
    print("[AutoHab] ✅ Bola detectada")
    
    -- Verificar que hay habilidad disponible
    if not self:GetAvailableAbility() then
        print("[AutoHab] ❌ Todas las habilidades en cooldown")
        return false
    end
    
    print("[AutoHab] ✅ Habilidad disponible encontrada")
    
    -- Guardar el tamaño actual para detectar cambios
    self.LastCooldownSize = cooldownProgress
    
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 🔄 LOOP PRINCIPAL
-- ═══════════════════════════════════════════════════════════════════════════

function AutoHabModule:ProcessFrame()
    if not self.Enabled then return end
    
    -- Actualizar personaje actual
    self:UpdateCurrentCharacter()
    
    -- Verificar si debemos activar habilidad
    if self:ShouldActivateAbility() then
        local ability = self:GetAvailableAbility()
        
        if ability then
            print("[AutoHab] 🚀 ¡ACTIVANDO HABILIDAD!", ability.Name)
            self:ActivateAbility(ability)
            self.AbilityUsedInCooldown = true
            self.Stats.SuccessfulDeflects = self.Stats.SuccessfulDeflects + 1
            print("[AutoHab] ✅ Habilidad activada exitosamente")
        else
            print("[AutoHab] ❌ Error: No hay habilidad disponible")
            self.Stats.FailedAttempts = self.Stats.FailedAttempts + 1
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎮 CONTROL DEL MÓDULO
-- ═══════════════════════════════════════════════════════════════════════════

function AutoHabModule:Start()
    if self.Connection then 
        print("[AutoHab] ⚠️ El módulo ya está corriendo")
        return 
    end
    
    self.Enabled = true
    print("[AutoHab] 🟢 Módulo iniciado")
    
    -- Detectar personaje inicial
    self:UpdateCurrentCharacter()
    self:SetupGuiMonitoring()
    
    -- Setup cooldown monitoring
    self:SetupCooldownMonitoring()
    
    print("[AutoHab] 📌 Configuración completa")
    print("[AutoHab] 📌 Personaje actual:", self.CurrentCharacter or "Ninguno")
    print("[AutoHab] 📌 Habilidades:", #self.CharacterAbilities)
    
    -- Loop principal
    self.Connection = RunService.Heartbeat:Connect(function()
        self:ProcessFrame()
    end)
end

function AutoHabModule:Stop()
    self.Enabled = false
    print("[AutoHab] 🔴 Módulo detenido")
    
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    
    if self.CooldownConnection then
        self.CooldownConnection:Disconnect()
        self.CooldownConnection = nil
    end
    
    for _, conn in pairs(self.GuiConnections) do
        conn:Disconnect()
    end
    self.GuiConnections = {}
    
    print("[AutoHab] 📊 Stats finales:")
    print("[AutoHab] 📊 Total activaciones:", self.Stats.TotalActivations)
    print("[AutoHab] 📊 Deflects exitosos:", self.Stats.SuccessfulDeflects)
    print("[AutoHab] 📊 Intentos fallidos:", self.Stats.FailedAttempts)
end

function AutoHabModule:SetEnabled(enabled)
    if enabled then
        self:Start()
    else
        self:Stop()
    end
end

function AutoHabModule:IsEnabled()
    return self.Enabled
end

function AutoHabModule:GetStats()
    return self.Stats
end

function AutoHabModule:GetCurrentCharacter()
    return self.CurrentCharacter
end

function AutoHabModule:GetCharacterAbilities()
    return self.CharacterAbilities
end

return AutoHabModule
