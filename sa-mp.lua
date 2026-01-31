script_name('Heridas')
script_author('Naito')
script_version('2.0')

require 'moonloader'
require 'sampfuncs'
local sampev = require 'samp.events'
local imgui = require("mimgui")
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local main_window_state = imgui.new.bool(false)
local heridas_dialog_state = imgui.new.bool(false)
local current_heridas_type = ""
local heridas_text = ""

local heridasRecibidas = {}
local heridasCausadas = {}

local weapons = {
    [0] = 'Golpe', [1] = 'Nudillo de hierro', [2] = 'Palo de golf', [3] = 'Porra policial',
    [4] = 'Cuchillo afilado', [5] = 'Bate de beisbol', [6] = 'Pala', [7] = 'Palo de billar',
    [8] = 'Katana', [9] = 'Motosierra', [10] = 'Dildo rosa', [11] = 'Dildo blanco',
    [12] = 'Vibrador blanco', [13] = 'Vibrador grande', [14] = 'Ramo de flores', [15] = 'Baston',
    [16] = 'Granada', [17] = 'Gas lagrimogeno', [18] = 'Molotov', [22] = 'Pistola 9mm',
    [23] = "'Taser-X19'", [24] = 'Desert Eagle', [25] = 'Escopeta', [26] = 'Escopeta recortada',
    [27] = 'Escopeta de combate', [28] = 'Micro Uzi', [29] = 'MP5', [30] = 'AK-47', [31] = 'M4',
    [32] = 'Tec-9', [33] = 'Rifle', [34] = 'Francotirador', [35] = 'Lanza cohetes',
    [36] = 'Dispositivo lanzacohetes', [37] = 'Lanzallamas', [38] = 'Minigun',
    [39] = 'Dinamita', [40] = 'Detonador', [41] = 'Lata de spray', [42] = 'Extintor de fuego',
    [43] = 'Camara', [44] = 'Lentes de vision nocturna', [45] = 'Lentes de vision termica',
    [46] = 'Paracaidas', [49] = 'Veh Crash'
}

local partesCuerpo = {
    [3] = 'Torso', [4] = 'Cintura', [5] = 'Brazo izquierdo', [6] = 'Brazo derecho',
    [7] = 'Pierna izquierda', [8] = 'Pierna derecha', [9] = 'Cabeza'
}

local dialog_colors = {
    weapon = imgui.ImVec4(0.965, 0.855, 0.620, 1.0),
    damage = imgui.ImVec4(0.753, 0.753, 0.753, 1.0),
    player = imgui.ImVec4(0.918, 0.918, 0.627, 1.0),
    time = imgui.ImVec4(1.0, 1.0, 1.0, 1.0),
    title_name = imgui.ImVec4(0.376, 0.741, 0.494, 1.0),
    no_data_blur = imgui.ImVec4(0.5, 0.5, 0.5, 0.6),
    author_text = imgui.ImVec4(1.0, 1.0, 1.0, 0.4)
}

local function aplicarTemaNegro()
    local style = imgui.GetStyle()
    local colors = style.Colors
    
    style.WindowRounding = 10.0
    style.ChildRounding = 8.0
    style.FrameRounding = 6.0
    style.PopupRounding = 6.0
    style.ScrollbarRounding = 12.0
    style.GrabRounding = 8.0
    style.TabRounding = 4.0
    
    colors[imgui.Col.WindowBg] = imgui.ImVec4(0.0, 0.0, 0.0, 0.95)
    colors[imgui.Col.TitleBg] = imgui.ImVec4(0.0, 0.0, 0.0, 1.0)
    colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.1, 0.1, 0.1, 1.0)
    colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.0, 0.0, 0.0, 0.8)
    
    colors[imgui.Col.Button] = imgui.ImVec4(0.15, 0.15, 0.15, 1.0)
    colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.25, 0.25, 0.25, 1.0)
    colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.35, 0.35, 0.35, 1.0)
    
    colors[imgui.Col.Border] = imgui.ImVec4(0.3, 0.3, 0.3, 1.0)
    colors[imgui.Col.BorderShadow] = imgui.ImVec4(0.0, 0.0, 0.0, 0.0)
    
    colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.02, 0.02, 0.02, 0.53)
    colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.31, 0.31, 0.31, 1.0)
    colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.41, 0.41, 0.41, 1.0)
    colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.51, 0.51, 0.51, 1.0)
    
    colors[imgui.Col.ChildBg] = imgui.ImVec4(0.05, 0.05, 0.05, 1.0)
    
    colors[imgui.Col.Separator] = imgui.ImVec4(0.43, 0.43, 0.50, 0.50)
    colors[imgui.Col.SeparatorHovered] = imgui.ImVec4(0.10, 0.40, 0.75, 0.78)
    colors[imgui.Col.SeparatorActive] = imgui.ImVec4(0.10, 0.40, 0.75, 1.00)
    
    colors[imgui.Col.FrameBg] = imgui.ImVec4(0.16, 0.16, 0.16, 0.54)
    colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.26, 0.26, 0.26, 0.40)
    colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.26, 0.26, 0.26, 0.67)
    
    colors[imgui.Col.ResizeGrip] = imgui.ImVec4(0.5, 0.5, 0.5, 0.25)
    colors[imgui.Col.ResizeGripHovered] = imgui.ImVec4(0.6, 0.6, 0.6, 0.67)
    colors[imgui.Col.ResizeGripActive] = imgui.ImVec4(0.7, 0.7, 0.7, 0.95)
end

function msg(text)
    sampAddChatMessage('{FFFFFF}[Heridas] '..text, -1)
end

function calcularTiempo(segundos)
    if segundos < 60 then
        return string.format("%d segs", segundos)
    elseif segundos < 3600 then
        return string.format("%d mins", math.floor(segundos / 60))
    elseif segundos < 86400 then
        return string.format("%d hs", math.floor(segundos / 3600))
    else
        return string.format("%d dias", math.floor(segundos / 86400))
    end
end

function calcularTiempoEnTiempoReal(tiempo_inicial)
    local tiempoPasado = os.time() - tiempo_inicial
    return calcularTiempo(tiempoPasado)
end

function generarTextoHeridas(tipo)
    local heridas = {}
    
    if tipo == "recibidas" then
        heridas = heridasRecibidas
    else
        heridas = heridasCausadas
    end
    
    if #heridas == 0 then
        if tipo == "recibidas" then
            return "No tienes heridas registradas."
        else
            return "No has causado dano recientemente."
        end
    end

    return "datos_disponibles"
end

function renderHeridasText(heridas_array)
    if #heridas_array == 0 then
        return
    end
    
    local maxHeridas = 150
    local count = 0
    
    for i = #heridas_array, math.max(#heridas_array - maxHeridas + 1, 1), -1 do
        local v = heridas_array[i]
        local tiempoStr = calcularTiempoEnTiempoReal(v.tiempo)
        
        imgui.TextColored(dialog_colors.weapon, v.arma)
        imgui.SameLine()
        imgui.TextColored(dialog_colors.damage, string.format(" -%.0f en %s", v.dano, v.parte))
        imgui.SameLine()
        imgui.TextColored(dialog_colors.player, " " .. v.jugador)
        imgui.SameLine()
        imgui.TextColored(dialog_colors.time, " hace " .. tiempoStr)
        
        count = count + 1
        if count >= maxHeridas then break end
    end
end

local function render_main_menu()
    local displaySize = imgui.GetIO().DisplaySize
    local windowSize = imgui.ImVec2(300, 170)
    
    local centerX = (displaySize.x - windowSize.x) / 2
    local centerY = (displaySize.y - windowSize.y) / 2
    
    imgui.SetNextWindowPos(imgui.ImVec2(centerX, centerY), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowSize(windowSize, imgui.Cond.FirstUseEver)
    
    if imgui.Begin(u8"Heridas", main_window_state, imgui.WindowFlags.NoCollapse) then
        
        imgui.SetCursorPosX((imgui.GetWindowWidth() - 250) / 2)
        if imgui.Button(u8"RECIBIDAS", imgui.ImVec2(250, 40)) then
            current_heridas_type = "recibidas"
            heridas_text = generarTextoHeridas("recibidas")
            heridas_dialog_state[0] = true
            main_window_state[0] = false
        end
        
        imgui.Spacing()
        
        imgui.SetCursorPosX((imgui.GetWindowWidth() - 250) / 2)
        if imgui.Button(u8"CAUSADAS", imgui.ImVec2(250, 40)) then
            current_heridas_type = "causadas"
            heridas_text = generarTextoHeridas("causadas")
            heridas_dialog_state[0] = true
            main_window_state[0] = false
        end
        
        imgui.Spacing()
        imgui.Spacing()
        
        local byNaitoText = u8"By Naito"
        local textSize = imgui.CalcTextSize(byNaitoText)
        imgui.SetCursorPosX((imgui.GetWindowWidth() - textSize.x) / 2)
        
        imgui.TextColored(dialog_colors.author_text, byNaitoText)
        
    end
    imgui.End()
end

local function render_heridas_dialog()
    local displaySize = imgui.GetIO().DisplaySize
    local windowSize = imgui.ImVec2(600, 400)
    
    local centerX = (displaySize.x - windowSize.x) / 2
    local centerY = (displaySize.y - windowSize.y) / 2
    
    imgui.SetNextWindowPos(imgui.ImVec2(centerX, centerY), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowSize(windowSize, imgui.Cond.FirstUseEver)
    
    local miNombre = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(playerPed)))
    local titulo = ""
    if current_heridas_type == "recibidas" then
        titulo = "Heridas recibidas de " .. miNombre
    else
        titulo = "Heridas causadas de " .. miNombre
    end
    
    if imgui.Begin(u8(titulo), heridas_dialog_state, imgui.WindowFlags.NoCollapse) then
        
        local heridas_array = current_heridas_type == "recibidas" and heridasRecibidas or heridasCausadas
        
        if #heridas_array == 0 then
            local windowSize = imgui.GetWindowSize()
            local textSize = imgui.CalcTextSize(u8(heridas_text))
            
            imgui.SetCursorPosX((windowSize.x - textSize.x) / 2)
            imgui.SetCursorPosY((windowSize.y - textSize.y) / 2 - 20)
            
            imgui.TextColored(dialog_colors.no_data_blur, u8(heridas_text))
        else
            imgui.BeginChild("HeridasScrollable", imgui.ImVec2(0, -60), false, imgui.WindowFlags.AlwaysVerticalScrollbar)
            renderHeridasText(heridas_array)
            imgui.EndChild()
            
            imgui.Separator()
            imgui.Spacing()
        end
        
        imgui.SetCursorPosX((imgui.GetWindowWidth() - 100) / 2)
        if imgui.Button(u8"Cerrar", imgui.ImVec2(100, 30)) then
            heridas_dialog_state[0] = false
        end
        
    end
    imgui.End()
end

imgui.OnFrame(function() return main_window_state[0] end, render_main_menu)
imgui.OnFrame(function() return heridas_dialog_state[0] end, render_heridas_dialog)

function sampev.onSendTakeDamage(playerID, damage, weaponID, bodypart)
    if damage > 0 then
        local nickname = sampGetPlayerNickname(playerID)
        local weaponName = weapons[weaponID] or "Desconocido"
        local parteCuerpo = partesCuerpo[bodypart] or "Desconocida"
        local danoEntero = math.floor(damage)
        local tiempo = os.time()

        table.insert(heridasRecibidas, {jugador = nickname, arma = weaponName, dano = danoEntero, parte = parteCuerpo, tiempo = tiempo})
    end
end

function sampev.onSendGiveDamage(playerID, damage, weaponID, bodypart)
    if damage > 0 then
        local nickname = sampGetPlayerNickname(playerID)
        local weaponName = weapons[weaponID] or "Desconocido"
        local parteCuerpo = partesCuerpo[bodypart] or "Desconocida"
        local danoEntero = math.floor(damage)
        local tiempo = os.time()

        table.insert(heridasCausadas, {jugador = nickname, arma = weaponName, dano = danoEntero, parte = parteCuerpo, tiempo = tiempo})
    end
end

function sampev.onSendVehicleDamage(vehicleID, damage)
    if damage > 0 then
        local miNombre = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(playerPed)))
        local danoEntero = math.floor(damage)
        local tiempo = os.time()

        table.insert(heridasRecibidas, {jugador = miNombre, arma = "Veh Crash", dano = danoEntero, parte = "Vehiculo", tiempo = tiempo})
    end
end

function main()
    while not isSampAvailable() do wait(1000) end

    checkScriptName()

    msg("Cargado!")
    msg("Comando: /.heridas")
    
    sampRegisterChatCommand(".heridas", function() 
        main_window_state[0] = not main_window_state[0]
    end)

    while true do
        wait(1000)
    end
end

function checkScriptName()
    local name = "Heridas_Naito.lua"
    if thisScript().filename ~= name then
        sampAddChatMessage("No cambies el nombre del script | " .. name, 0xFF0000)
        thisScript():unload()
        return
    end
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    aplicarTemaNegro()
end)
