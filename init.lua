-- Sistema HWID by Terribles Hub
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- URLs del repositorio
local hwidListUrl = "https://raw.githubusercontent.com/terribleshub/Terribles-Hub/main/hwid.json"
local loaderUrl = "https://raw.githubusercontent.com/terribleshub/Terribles-Hub/main/loader"

-- Función para obtener HWID del usuario
local function GetHWID()
    if gethwid then
        return gethwid()
    elseif identifyexecutor then
        local executor = identifyexecutor()
        return executor .. "-" .. game:GetService("RbxAnalyticsService"):GetClientId()
    else
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end
end

-- Función para verificar HWID contra el JSON
local function CheckHWID()
    local playerHWID = GetHWID()
    
    print("🔍 Verifying access...")
    print("Your HWID:", playerHWID)
    
    -- Descargar lista de HWIDs desde GitHub
    local success, response = pcall(function()
        return HttpService:GetAsync(hwidListUrl)
    end)
    
    if not success then
        LP:Kick("❌ Failed to connect to authentication server.\n\nError: Unable to verify HWID\n\nPlease try again later.")
        return false
    end
    
    -- Parsear el JSON
    local hwidData
    success, hwidData = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    
    if not success then
        LP:Kick("❌ Authentication error.\n\nPlease contact support.")
        return false
    end
    
    -- Verificar si el sistema HWID está habilitado
    if not hwidData.enabled then
        print("✅ HWID verification disabled. Loading...")
        return true
    end
    
    -- Verificar si el HWID está en la whitelist
    for _, whitelistedHWID in ipairs(hwidData.whitelist) do
        if whitelistedHWID == playerHWID then
            print("✅ Access granted! Loading script...")
            return true
        end
    end
    
    -- HWID no autorizado - Expulsar del juego
    LP:Kick([[❌ ACCESS DENIED - HWID NOT WHITELISTED

Your HWID: ]] .. playerHWID .. [[


To get access to Terribles Hub:
1. Copy your HWID above
2. Send it to the script owner
3. Wait for whitelist approval

Discord: [Your Discord Server Here]
Telegram: [Your Contact Here]]])
    
    return false
end

-- Función para cargar el script principal
local function LoadMainScript()
    print("📥 Downloading Terribles Hub...")
    
    local success, scriptContent = pcall(function()
        return HttpService:GetAsync(loaderUrl)
    end)
    
    if success then
        print("✅ Script downloaded successfully!")
        
        local loadSuccess, loadError = pcall(function()
            loadstring(scriptContent)()
        end)
        
        if not loadSuccess then
            LP:Kick("❌ Script execution failed.\n\nError: " .. tostring(loadError) .. "\n\nPlease report this to support.")
        end
    else
        LP:Kick("❌ Failed to download script.\n\nError: " .. tostring(scriptContent) .. "\n\nPlease check your connection.")
    end
end

-- Ejecutar verificación HWID y cargar script
if CheckHWID() then
    LoadMainScript()
end
