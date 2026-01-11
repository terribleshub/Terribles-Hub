

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local LoggedSoundIds = {} 

-- UI Variables for Minimize/Maximize
local WINDOW_HEIGHT = 500
local HEADER_HEIGHT = 45
local IsMinimized = false

--// EXECUTOR-SPECIFIC DOWNLOAD FUNCTION //--
local function downloadAsset(id)
    -- 🛑 CRITICAL FIX: Changing the URL to a more direct format
    -- This URL structure often leads directly to the raw binary file, bypassing redirects that confuse writefile.
    local downloadUrl = "https://www.roblox.com/asset/?id=" .. id
    
    local filename = id .. ".mp3" 
    local folderPath = "LoggedAudio/" 
    local fullPath = folderPath .. filename

    if writefile then
        local success, err = pcall(function()
            -- writefile(path, content/url)
            writefile(fullPath, downloadUrl)
        end)
        
        if success then
            return true
        else
            -- Check your executor's console for 'err' messages if it fails again
            return false
        end
    else
        return false 
    end
end

--// UI CREATION //--
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ModernAudioLogger"
ScreenGui.ResetOnSpawn = false

pcall(function()
	ScreenGui.Parent = CoreGui
end)
if ScreenGui.Parent ~= CoreGui then
	ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Main Window
local Main = Instance.new("Frame")
Main.Name = "MainWindow"
Main.Size = UDim2.new(0, 450, 0, WINDOW_HEIGHT)
Main.Position = UDim2.new(0.5, -225, 0.5, -250)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner", Main)
MainCorner.CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Color3.fromRGB(60, 60, 65)
MainStroke.Thickness = 1

-- Header
local Header = Instance.new("Frame", Main)
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
Header.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Header.BorderSizePixel = 0

local HeaderCorner = Instance.new("UICorner", Header)
HeaderCorner.CornerRadius = UDim.new(0, 8)

local HeaderCover = Instance.new("Frame", Header)
HeaderCover.Size = UDim2.new(1, 0, 0, 10)
HeaderCover.Position = UDim2.new(0, 0, 1, -10)
HeaderCover.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
HeaderCover.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(1, -150, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Audio Logger"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(240, 240, 240)
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Control Buttons Container
local Controls = Instance.new("Frame", Header)
Controls.Size = UDim2.new(0, 80, 1, 0)
Controls.Position = UDim2.new(1, -80, 0, 0)
Controls.BackgroundTransparency = 1

-- Minimize Button
local MinimizeBtn = Instance.new("TextButton", Controls)
MinimizeBtn.Name = "Minimize"
MinimizeBtn.Size = UDim2.new(0, 24, 0, 24)
MinimizeBtn.Position = UDim2.new(1, -55, 0.5, -12)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
MinimizeBtn.Text = "—"
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 18
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 4)

-- Exit Button
local ExitBtn = Instance.new("TextButton", Controls)
ExitBtn.Name = "Exit"
ExitBtn.Size = UDim2.new(0, 24, 0, 24)
ExitBtn.Position = UDim2.new(1, -25, 0.5, -12)
ExitBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
ExitBtn.Text = "X"
ExitBtn.Font = Enum.Font.GothamBold
ExitBtn.TextSize = 14
ExitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", ExitBtn).CornerRadius = UDim.new(0, 4)

-- Clear Button (Small, next to Title)
local ClearBtn = Instance.new("TextButton", Header)
ClearBtn.Size = UDim2.new(0, 40, 0, 24)
ClearBtn.Position = UDim2.new(0, 120, 0.5, -12) 
ClearBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
ClearBtn.Text = "Reset"
ClearBtn.Font = Enum.Font.GothamBold
ClearBtn.TextSize = 12
ClearBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
Instance.new("UICorner", ClearBtn).CornerRadius = UDim.new(0, 4)

-- Download All Button (Primary action)
local DownloadAllBtn = Instance.new("TextButton", Header)
DownloadAllBtn.Size = UDim2.new(0, 100, 0, 24)
DownloadAllBtn.Position = UDim2.new(1, -180, 0.5, -12) 
DownloadAllBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 100) 
DownloadAllBtn.Text = "Download All"
DownloadAllBtn.Font = Enum.Font.GothamBold
DownloadAllBtn.TextSize = 12
DownloadAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", DownloadAllBtn).CornerRadius = UDim.new(0, 4)

-- Scrolling List
local List = Instance.new("ScrollingFrame", Main)
List.Position = UDim2.new(0, 10, 0, 55)
List.Size = UDim2.new(1, -20, 1, -65)
List.CanvasSize = UDim2.new(0, 0, 0, 0)
List.BackgroundTransparency = 1
List.ScrollBarThickness = 4
List.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)

local UIList = Instance.new("UIListLayout", List)
UIList.Padding = UDim.new(0, 8)
UIList.SortOrder = Enum.SortOrder.LayoutOrder

--// DRAGGABLE LOGIC //--
local dragging, dragInput, dragStart, startPos
local function update(input)
	local delta = input.Position - dragStart
	Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

Header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = Main.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

Header.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then update(input) end
end)

--// CONTROL LOGIC //--
local function tweenWindow(sizeY, duration, callback)
	TweenService:Create(Main, TweenInfo.new(duration), {Size = UDim2.new(0, 450, 0, sizeY)}):Play()
	if callback then callback() end
end

MinimizeBtn.MouseButton1Click:Connect(function()
	if IsMinimized then
		IsMinimized = false
		MinimizeBtn.Text = "—"
		List.Visible = true
		ClearBtn.Visible = true
		DownloadAllBtn.Visible = true
		tweenWindow(WINDOW_HEIGHT, 0.3)
	else
		IsMinimized = true
		MinimizeBtn.Text = "O" 
		List.Visible = false
		ClearBtn.Visible = false
		DownloadAllBtn.Visible = false
		tweenWindow(HEADER_HEIGHT, 0.3)
	end
end)

ExitBtn.MouseButton1Click:Connect(function()
	ScreenGui:Destroy()
end)

ClearBtn.MouseButton1Click:Connect(function()
	for _, child in pairs(List:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	LoggedSoundIds = {} 
	List.CanvasSize = UDim2.new(0,0,0,0)
end)

DownloadAllBtn.MouseButton1Click:Connect(function()
    local idCount = 0
    for _ in pairs(LoggedSoundIds) do idCount = idCount + 1 end
    
    if idCount == 0 then
        DownloadAllBtn.Text = "Log is Empty!"
        wait(1.5)
        DownloadAllBtn.Text = "Download All"
        return
    end

    local count = 0
    DownloadAllBtn.Text = "Downloading " .. idCount .. " IDs..."
    
    for id, _ in pairs(LoggedSoundIds) do
        local success = downloadAsset(id)
        if success then
            count = count + 1
        end
        wait(0.05) 
    end

    DownloadAllBtn.Text = "Downloaded " .. count .. " IDs!"
    wait(2)
    DownloadAllBtn.Text = "Download All"
end)


--// UTIL & LOGIC //--

local function extractId(sound)
	local id = sound.SoundId or ""
	id = id:gsub("rbxassetid://", "")
	id = id:gsub("rbxasset://", "")
	return id
end

local function createButton(parent, text, color)
	local btn = Instance.new("TextButton")
	btn.Parent = parent
	btn.Text = text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false 
	
	btn.AnchorPoint = Vector2.new(1, 0.5)
	if text == "Play" then
		btn.Size = UDim2.new(0, 60, 0, 28)
		btn.Position = UDim2.new(1, -10, 0.5, 0)
	else
		btn.Size = UDim2.new(0, 60, 0, 28)
		btn.Position = UDim2.new(1, -80, 0.5, 0)
	end
	
	local corner = Instance.new("UICorner", btn)
	corner.CornerRadius = UDim.new(0, 6)
	
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.2}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
	end)
	
	return btn
end

local function addSoundEntry(sound)
	local id = extractId(sound)
	
	if id == "" or not tonumber(id) then return end 

	if LoggedSoundIds[id] == true then 
		return 
	end

	LoggedSoundIds[id] = true

	local item = Instance.new("Frame")
	item.Name = "Sound_" .. id
	item.Size = UDim2.new(1, 0, 0, 50)
	item.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	item.BorderSizePixel = 0
	item.Parent = List
	
	local itemCorner = Instance.new("UICorner", item)
	itemCorner.CornerRadius = UDim.new(0, 6)
	
	local itemStroke = Instance.new("UIStroke", item)
	itemStroke.Color = Color3.fromRGB(50, 50, 55)
	itemStroke.Thickness = 1

	local nameLbl = Instance.new("TextLabel", item)
	nameLbl.Size = UDim2.new(1, -160, 0, 20)
	nameLbl.Position = UDim2.new(0, 10, 0, 5)
	nameLbl.BackgroundTransparency = 1
	nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 14
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	nameLbl.Text = sound.Name

	local idLbl = Instance.new("TextLabel", item)
	idLbl.Size = UDim2.new(1, -160, 0, 15)
	idLbl.Position = UDim2.new(0, 10, 0, 28)
	idLbl.BackgroundTransparency = 1
	idLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
	idLbl.Font = Enum.Font.Gotham
	idLbl.TextSize = 12
	idLbl.TextXAlignment = Enum.TextXAlignment.Left
	idLbl.Text = "ID: " .. id

	local copyBtn = createButton(item, "Copy", Color3.fromRGB(50, 100, 200))
	local listenBtn = createButton(item, "Play", Color3.fromRGB(50, 180, 100))

	copyBtn.MouseButton1Click:Connect(function()
		if setclipboard then
			setclipboard(id)
			copyBtn.Text = "Copied!"
			wait(1)
			copyBtn.Text = "Copy"
		end
	end)

	listenBtn.MouseButton1Click:Connect(function()
		local clone = sound:Clone()
		clone.Parent = workspace
		clone.TimePosition = 0
		clone:Play()
		listenBtn.Text = "..."
		Debris:AddItem(clone, 5)
		wait(1)
		listenBtn.Text = "Play"
	end)

	List.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 10)
	List.CanvasPosition = Vector2.new(0, List.AbsoluteCanvasSize.Y)
end

--// GLOBAL SOUND DETECTION //--

local function deepMonitor(obj)
	if obj:IsA("Sound") then
		obj.Played:Connect(function()
			addSoundEntry(obj)
		end)
	end
	
	obj.DescendantAdded:Connect(function(d)
		if d:IsA("Sound") then
			d.Played:Connect(function()
				addSoundEntry(d)
			end)
		end
	end)
end

-- 1. Connect existing Sound objects
for _, obj in ipairs(game:GetDescendants()) do
	if obj:IsA("Sound") then
		obj.Played:Connect(function()
			addSoundEntry(obj)
		end)
	end
end

-- 2. Connect to the addition of new descendants
game.ChildAdded:Connect(deepMonitor)
game.DescendantAdded:Connect(function(desc)
	if desc:IsA("Sound") then
		desc.Played:Connect(function()
			addSoundEntry(desc)
		end)
	end
end)
