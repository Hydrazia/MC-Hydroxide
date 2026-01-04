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
	if input.UserInputType == Enum.UserInputType.Touch then
		conduct += 1
		local key, Signal = conduct, true
		touchPoints[key] = input.Position

		local startClock = os.clock()
		task.spawn(function()
			local threshold = 0.4
			repeat task.wait() until (os.clock()-startClock) > threshold or not Signal
			if (os.clock()-startClock) < threshold then return end
			pressHold = true
		end)

		Signal = UserInput.InputEnded:Connect(function()
			for i in pairs(touching) do
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
		message = "The UI has updated, please rejoin.\n\n" .. err
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

-- BEST PC + TOUCH DRAG SUPPORT
Drag.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or (input.UserInputType == Enum.UserInputType.Touch and conduct == 0) then

		dragging = true
		dragStart = input.Position
		startPos = Base.Position

		local dragEnded
		dragEnded = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				dragEnded:Disconnect()
			end
		end)
	end
end)

oh.Events.Drag = UserInput.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
	or input.UserInputType == Enum.UserInputType.Touch) then

		local delta = input.Position - dragStart
		Base.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end
end)

-- FIX A APPLIED HERE
Open.MouseButton1Click:Connect(function()
	Open:TweenPosition(constants.conceal, "Out", "Quad", 0.15, true)
	task.wait(0.1)

	Open.Visible = false
	Open.Active = false

	Base.Active = true
	Base:TweenPosition(constants.opened, "Out", "Quad", 0.15, true)

	-- FASTEST POSSIBLE "NO RESULTS FOUND" FIX
	task.defer(function()
		for _, descendant in ipairs(Interface:GetDescendants()) do
			if descendant.Name == "ResultStatus" and descendant:IsA("TextLabel") then
				
				local parent = descendant.Parent
				local container =
					parent:FindFirstChild("Content")
					or parent:FindFirstChild("Results")
					or parent:FindFirstChild("List")
					or parent:FindFirstChild("Container")

				if container then
					local hasContent = false
					for _, child in ipairs(container:GetChildren()) do
						if child:IsA("GuiObject")
						and not child:IsA("UIListLayout")
						and not child:IsA("UIPadding") then
							hasContent = true
							break
						end
					end
					descendant.Visible = not hasContent
				end
			end
		end
	end)
end)

Collapse.MouseButton1Click:Connect(function()
	Base:TweenPosition(constants.closed, "Out", "Quad", 0.15, true)
	task.wait(0.15)

	Base.Active = false  -- disable input when collapsed

	Open.Visible = true
	Open.Active = true
	Open:TweenPosition(constants.reveal, "Out", "Quad", 0.15, true)
end)

Interface.Name = HttpService:GenerateGUID(false)

task.spawn(function()
	-- Fix ScrollingFrames so they resize properly
	local function FixScrolling(obj)
		if obj:IsA("ScrollingFrame") then
			obj.AutomaticCanvasSize = Enum.AutomaticSize.None
			obj.ScrollBarThickness = 4
			
			local layout = obj:FindFirstChildWhichIsA("UIGridStyleLayout")
			if layout then
				local function update()
					obj.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
				end
				layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
				update()
			end
		end
	end

	-- Apply scrolling fix to all existing descendants
	for _, v in pairs(Interface:GetDescendants()) do
		FixScrolling(v)
	end
	
	-- Apply scrolling fix to new descendants
	Interface.DescendantAdded:Connect(FixScrolling)

	-- Helper: check if container has any real results
	local function hasResults(container)
		if not container then return false end
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("GuiObject")
			and not child:IsA("UIListLayout")
			and not child:IsA("UIPadding") then
				return true
			end
		end
		return false
	end

	-- Update a ResultStatus label
	local function updateResultStatus(resultStatus)
		local parent = resultStatus.Parent
		local container =
			parent:FindFirstChild("Content")
			or parent:FindFirstChild("Results")
			or parent:FindFirstChild("List")
			or parent:FindFirstChild("Container")

		if not container then return end

		local function refresh()
			resultStatus.Visible = not hasResults(container)
		end

		-- Initial refresh
		refresh()

		-- Update when results change
		container.ChildAdded:Connect(function()
			task.defer(refresh)
		end)

		container.ChildRemoved:Connect(function()
			task.defer(refresh)
		end)
	end

	-- Initialize all ResultStatus labels
	for _, descendant in ipairs(Interface:GetDescendants()) do
		if descendant.Name == "ResultStatus" and descendant:IsA("TextLabel") then
			updateResultStatus(descendant)
		end
	end
end)

if getHui then
	Interface.Parent = getHui()
elseif syn and syn.protect_gui then
	syn.protect_gui(Interface)
	Interface.Parent = CoreGui
else
	Interface.Parent = CoreGui
end

-- INITIAL STATE FIX
Base.Visible = true
Base.Active = true
Base.Position = constants.opened

Open.Visible = false
Open.Active = false
Open.Position = constants.conceal

return Interface
