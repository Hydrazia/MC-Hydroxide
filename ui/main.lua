local CoreGui = game:GetService("CoreGui")
local UserInput = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Interface = import("rbxassetid://11389137937")

if oh.Cache["ui/main"] then
	return Interface
end

import("ui/controls/TabSelector")
local MessageBox, MessageType = import("ui/controls/MessageBox")

local RemoteSpy
local ClosureSpy
local ScriptScanner
local ModuleScanner
local UpvalueScanner
local ConstantScanner

getgenv().touchPoints = {}
getgenv().touching = {}
getgenv().conduct = 0
getgenv().pressHold = false
getgenv().mainBase = Interface.Base
mainBase.Active = true

getgenv().MouseInFrame = function(uiobject)
	local mouse = game:GetService("Players").LocalPlayer:GetMouse()
    local y_cond = uiobject.AbsolutePosition.Y <= mouse.Y and mouse.Y <= uiobject.AbsolutePosition.Y + uiobject.AbsoluteSize.Y
    local x_cond = uiobject.AbsolutePosition.X <= mouse.X and mouse.X <= uiobject.AbsolutePosition.X + uiobject.AbsoluteSize.X

	return (y_cond and x_cond)
end

if signaluis then
	signaluis:Disconnect()
end

getgenv().signaluis = UserInput.InputBegan:Connect(function(input,gp)
	if (input.UserInputType == Enum.UserInputType.Touch) then
		conduct += 1
		local key, Signal = conduct, true
		touchPoints[key] = input.Position
		local startClock = os.clock()
		task.spawn(function()
			local threshold = 0.4
			repeat task.wait() until (os.clock()-startClock) > threshold  or not Signal
			if (os.clock()-startClock) < threshold then return end
			pressHold = true
		end)
		Signal = UserInput.InputEnded:Connect(function()
			for i, v in pairs(touching) do
				if v == true then
					
				end
				touching[i] = false
			end
			touchPoints[key] = nil
			conduct -= 1
			Signal:Disconnect()
			Signal = nil
			task.wait()
			pressHold = false
		end)
	end
end)

local moduleId = {"RemoteSpy","ClosureSpy","ScriptScanner","ModuleScanner","UpvalueScanner","ConstantScanner"}

function moduleError(err)
	local message
	if err:find("valid member") then
		message = "The UI has updated, please rejoin and restart.\n\n" .. err
	else
		message = string.format("Error:\n\n%s", err)
	end

	MessageBox.Show("An error has occurred", message, MessageType.OK, function() end)
end

xpcall(function()
	RemoteSpy = import("ui/modules/RemoteSpy");
	ClosureSpy = import("ui/modules/ClosureSpy");
	ScriptScanner = import("ui/modules/ScriptScanner");
	ModuleScanner = import("ui/modules/ModuleScanner");
	UpvalueScanner = import("ui/modules/UpvalueScanner");
	ConstantScanner = import("ui/modules/ConstantScanner"); 
end, function(err)
	moduleError(err)
end)

local constants = {
	opened = UDim2.new(0.5, -325, 0.5, -175),
	closed = UDim2.new(0.5, -325, 0, -600),
	reveal = UDim2.new(0.5, -15, 0, 20),
	conceal = UDim2.new(0.5, -15, 0, -100)
}

local Open = Interface.Open
local Base = Interface.Base
local Drag = Base.Drag
local Status = Base.Status
local Collapse = Drag.Collapse

function oh.setStatus(text)
	Status.Text = '• Status: ' .. text
end

function oh.getStatus()
	return Status.Text:gsub('• Status: ', '')
end

Open.Active = false
Drag.Active = true
Collapse.Active = true
Base.Active = true

local dragging, dragStart, startPos

Drag.InputBegan:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch and conduct == 0) then
		local dragEnded 

		dragging = true
		dragStart = input.Position
		startPos = Base.Position

		dragEnded = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				dragEnded:Disconnect()
			end
		end)
	end
end)

oh.Events.Drag = UserInput.InputChanged:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
		local delta = input.Position - dragStart
		Base.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

Open.MouseButton1Click:Connect(function()
	Open:TweenPosition(constants.conceal, "Out", "Quad", 0.15, true)
	task.wait(0.1)
    
    Open.Visible = false
    Open.Active = false
    
    Base.Visible = true
	Base:TweenPosition(constants.opened, "Out", "Quad", 0.15, true)
end)

Collapse.MouseButton1Click:Connect(function()
	Base:TweenPosition(constants.closed, "Out", "Quad", 0.15, true)
	task.wait(0.15) 
    
    Base.Visible = false
    
    Open.Visible = true
    Open.Active = true
	Open:TweenPosition(constants.reveal, "Out", "Quad", 0.15, true)
end)

task.spawn(function()
	local function FixScrolling(obj)
		if obj:IsA("ScrollingFrame") then
			obj.AutomaticCanvasSize = Enum.AutomaticSize.None
			obj.ClipsDescendants = true
			
			local layout = obj:FindFirstChildWhichIsA("UIGridStyleLayout")
			if layout then
				local function update()
					local contentSize = layout.AbsoluteContentSize
					obj.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 15)
				end
				
				layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
				
				obj.DescendantAdded:Connect(function(child)
					if child:IsA("GuiObject") then
						if child.Size.Y.Scale > 0 then
							local absSize = child.AbsoluteSize.Y
							child.Size = UDim2.new(child.Size.X.Scale, child.Size.X.Offset, 0, absSize > 0 and absSize or 25)
						end
					end
					update()
				end)
				
				update()
			end
		end
	end

	for _, v in pairs(Interface:GetDescendants()) do
		FixScrolling(v)
	end
	
	Interface.DescendantAdded:Connect(FixScrolling)

	local success, pages = pcall(function()
		return Base:WaitForChild("Body", 5):WaitForChild("Pages", 5)
	end)
	
	if not success or not pages then
		return
	end
	
	local function hasResults(resultsContainer)
		if not resultsContainer then return false end
		local childCount = 0
		for _, child in pairs(resultsContainer:GetChildren()) do
			if not child:IsA("UIListLayout") and 
			   not child:IsA("UIPadding") and 
			   not child:IsA("UICorner") and
			   not child:IsA("UIGridLayout") and
			   not child:IsA("UISizeConstraint") then
				childCount = childCount + 1
			end
		end
		return childCount > 0
	end
	
	local function updateResultStatus(resultStatus)
		if not resultStatus or not resultStatus.Parent then return end
		resultStatus.Active = false
		
		local resultsContainer = resultStatus.Parent:FindFirstChild("Content") 
			or resultStatus.Parent:FindFirstChild("Results")
			or resultStatus.Parent:FindFirstChild("List")
			or resultStatus.Parent:FindFirstChild("Container")
		
		if resultsContainer then
			resultsContainer.Active = true
			
			local function updateVisibility()
				local hasContent = hasResults(resultsContainer)
				resultStatus.Visible = not hasContent
			end
			
			updateVisibility()
			resultsContainer.ChildAdded:Connect(function() task.wait(0.05) updateVisibility() end)
			resultsContainer.ChildRemoved:Connect(function() task.wait(0.05) updateVisibility() end)
		else
			resultStatus.Visible = true
		end
	end
	
	for _, descendant in pairs(Interface:GetDescendants()) do
		if descendant.Name == "ResultStatus" and descendant:IsA("TextLabel") then
			updateResultStatus(descendant)
		end
	end
end)

local originalExit = oh.Exit
oh.Exit = function()
	if oh.Events.ResultStatusConnections then
		for _, connection in pairs(oh.Events.ResultStatusConnections) do
			pcall(function() connection:Disconnect() end)
		end
		oh.Events.ResultStatusConnections = nil
	end
	if originalExit then originalExit() end
end

Interface.Name = HttpService:GenerateGUID(false)
if getHui then
	Interface.Parent = getHui()
elseif syn and syn.protect_gui then
	syn.protect_gui(Interface)
	Interface.Parent = CoreGui
else
	Interface.Parent = CoreGui
end

Base.Visible = true
Base.Position = constants.opened
Open.Visible = false 
Open.Active = false
Open.Position = constants.conceal

return Interface
