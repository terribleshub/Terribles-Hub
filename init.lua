-- Sistema HWID by Terribles Hub (Versión con mejor debugging)
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
    
    print("=================================")
    print("🔍 TERRIBLES HUB - HWID VERIFICATION")
    print("=================================")
    print("Your HWID:", playerHWID)
    print("Checking authentication...")
    
    -- Descargar lista de HWIDs desde GitHub
    local success, response = pcall(function()
        return game:HttpGet(hwidListUrl)
    end)
    
    if not success then
        warn("❌ Failed to connect to authentication server.")
        warn("Error details:", response)
        LP:Kick("❌ Failed to connect to authentication server.\n\nError: Unable to verify HWID\n\nPlease try again later.\n\nYour HWID: " .. playerHWID)
        return false
    end
    
    print("✅ Connected to authentication server")
    print("Response length:", #response, "characters")
    
    -- Parsear el JSON
    local hwidData
    success, hwidData = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    
    if not success then
        warn("❌ JSON Parse Error:", hwidData)
        warn("Raw response:", response)
        LP:Kick("❌ Authentication error.\n\nJSON parsing failed.\n\nPlease contact support.\n\nYour HWID: " .. playerHWID)
        return false
    end
    
    print("✅ JSON parsed successfully")
    
    -- Verificar estructura del JSON
    if type(hwidData) ~= "table" then
        warn("❌ Invalid JSON structure: not a table")
        LP:Kick("❌ Authentication error.\n\nInvalid data structure.\n\nPlease contact support.")
        return false
    end
    
    if hwidData.enabled == nil then
        warn("⚠️ Warning: 'enabled' field not found in JSON, assuming enabled=true")
        hwidData.enabled = true
    end
    
    if type(hwidData.whitelist) ~= "table" then
        warn("❌ Invalid whitelist structure")
        LP:Kick("❌ Authentication error.\n\nInvalid whitelist data.\n\nPlease contact support.")
        return false
    end
    
    print("Whitelist entries:", #hwidData.whitelist)
    
    -- Verificar si el sistema HWID está habilitado
    if not hwidData.enabled then
        print("⚠️ HWID verification is DISABLED")
        print("✅ Bypassing HWID check...")
        return true
    end
    
    print("🔒 HWID verification is ENABLED")
    print("Checking whitelist...")
    
    -- Verificar si el HWID está en la whitelist
    for index, whitelistedHWID in ipairs(hwidData.whitelist) do
        print("Checking entry", index .. ":", whitelistedHWID)
        if whitelistedHWID == playerHWID then
            print("✅ MATCH FOUND!")
            print("✅ Access granted! Loading script...")
            return true
        end
    end
    
    -- HWID no autorizado - Expulsar del juego
    warn("❌ HWID NOT FOUND IN WHITELIST")
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
    print("=================================")
    print("📥 DOWNLOADING TERRIBLES HUB LOADER")
    print("=================================")
    print("URL:", loaderUrl)
    
    local success, scriptContent = pcall(function()
        return game:HttpGet(loaderUrl)
    end)
    
    if not success then
        warn("❌ Failed to download loader")
        warn("Error details:", scriptContent)
        LP:Kick("❌ Failed to download script.\n\nError: " .. tostring(scriptContent) .. "\n\nPlease check your connection or contact support.")
        return
    end
    
    print("✅ Loader downloaded successfully!")
    print("Script size:", #scriptContent, "characters")
    
    -- Verificar que el script no esté vacío
    if scriptContent == "" or scriptContent == nil then
        warn("❌ Loader file is empty!")
        LP:Kick("❌ Script file is empty.\n\nThe loader file on GitHub appears to be empty.\n\nPlease contact the developer.")
        return
    end
    
    -- Mostrar primeras líneas para debug
    local firstLines = scriptContent:sub(1, 200)
    print("First 200 chars of loader:", firstLines)
    
    print("=================================")
    print("⚙️ EXECUTING LOADER")
    print("=================================")
    
    -- Intentar compilar el script primero
    local scriptFunc, compileError = loadstring(scriptContent)
    
    if not scriptFunc then
        warn("❌ Script compilation failed!")
        warn("Compilation error:", compileError)
        LP:Kick("❌ Script compilation failed.\n\nError: " .. tostring(compileError) .. "\n\nThere's a syntax error in the loader file.\n\nPlease report this to support.")
        return
    end
    
    print("✅ Script compiled successfully!")
    print("Executing script...")
    
    -- Ejecutar el script compilado
    local executeSuccess, executeError = pcall(scriptFunc)
    
    if not executeSuccess then
        warn("❌ Script execution failed!")
        warn("Execution error:", executeError)
        LP:Kick("❌ Script execution failed.\n\nError: " .. tostring(executeError) .. "\n\nPlease report this to support.")
        return
    end
    
    print("✅ Terribles Hub loaded successfully!")
    print("=================================")
end

-- Ejecutar verificación HWID y cargar script
print("\n")
print("=================================")
print("🚀 TERRIBLES HUB INITIALIZING")
print("=================================")
print("Version: 2.0")
print("Player:", LP.DisplayName, "(@" .. LP.Name .. ")")
print("Executor:", identifyexecutor and identifyexecutor() or "Unknown")
print("=================================")
print("\n")

local initSuccess, initError = pcall(function()
    if CheckHWID() then
        LoadMainScript()
    else
        warn("❌ HWID verification failed")
    end
end)

if not initSuccess then
    warn("❌ Critical error in init.lua")
    warn("Error details:", initError)
    LP:Kick("❌ Critical initialization error.\n\nError: " .. tostring(initError) .. "\n\nPlease report this to support.")
end
