local CoreGui = game:GetService("CoreGui")
local UserInput = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Interface = import("rbxassetid://11389137937")

if oh.Cache["ui/main"] then
	return Interface
end

oh.Events = oh.Events or {}

import("ui/controls/TabSelector")
local MessageBox, MessageType = import("ui/controls/MessageBox")

local RemoteSpy
local ClosureSpy
local ScriptScanner
local ModuleScanner
local UpvalueScanner
local ConstantScanner

-- TOUCH STATE
getgenv().touchPoints = {}
getgenv().touching = {}
getgenv().conduct = 0
getgenv().pressHold = false
getgenv().mainBase = Interface.Base
mainBase.Active = true

-- MOUSE IN FRAME
getgenv().MouseInFrame = function(uiobject)
	local mouse = game:GetService("Players").LocalPlayer:GetMouse()
	local y_cond = uiobject.AbsolutePosition.Y <= mouse.Y and mouse.Y <= uiobject.AbsolutePosition.Y + uiobject.AbsoluteSize.Y
	local x_cond = uiobject.AbsolutePosition.X <= mouse.X and mouse.X <= uiobject.AbsolutePosition.X + uiobject.AbsoluteSize.X
	return (y_cond and x_cond)
end

-- CLEAN TOUCH SIGNAL
if signaluis then
	signaluis:Disconnect()
end

getgenv().signaluis = UserInput.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		conduct += 1
		local key, Signal = conduct, true
		touchPoints[key] = input.Position

		local startClock = os.clock()
		task.spawn(function()
			local threshold = 0.4
			repeat task.wait() until (os.clock() - startClock) > threshold or not Signal
			if (os.clock() - startClock) < threshold then return end
			pressHold = true
		end)

		Signal = UserInput.InputEnded:Connect(function()
			for i in pairs(touching) do touching[i] = false end
			touchPoints[key] = nil
			conduct -= 1
			Signal:Disconnect()
			task.wait()
			pressHold = false
		end)
	end
end)

-- MODULE LOADING
local moduleId = { "RemoteSpy","ClosureSpy","ScriptScanner","ModuleScanner","UpvalueScanner","ConstantScanner" }

function moduleError(err)
	local message
	if err:find("valid member") then
		message = "The UI has updated, please rejoin and restart.\n\n" .. err
	else
		message = string.format("Report this error:\n\n%s", err)
	end
	MessageBox.Show("An error has occurred", message, MessageType.OK, function() end)
end

xpcall(function()
	RemoteSpy = import("ui/modules/RemoteSpy")
	ClosureSpy = import("ui/modules/ClosureSpy")
	ScriptScanner = import("ui/modules/ScriptScanner")
	ModuleScanner = import("ui/modules/ModuleScanner")
	UpvalueScanner = import("ui/modules/UpvalueScanner")
	ConstantScanner = import("ui/modules/ConstantScanner")
end, function(err)
	moduleError(err)
end)

-- UI CONSTANTS
local constants = {
	opened = UDim2.new(0.5, -325, 0.5, -175),
	closed = UDim2.new(0.5, -325, 0, -400),

	-- FIXED: fully off-screen
	reveal = UDim2.new(0.5, -15, 0, 20),
	conceal = UDim2.new(0.5, -15, -1, 0)
}

-- UI ELEMENTS
local Open = Interface.Open
local Base = Interface.Base
local Drag = Base.Drag
local Status = Base.Status
local Collapse = Drag.Collapse

function oh.setStatus(text)
	Status.Text = "• Status: " .. text
end

function oh.getStatus()
	return Status.Text:gsub("• Status: ", "")
end

-- ENABLE INPUT
Open.Active = true
Base.Active = true
Drag.Active = true
Collapse.Active = true

-- DRAGGING
local dragging, dragStart, startPos

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

-- OPEN UI
Open.MouseButton1Click:Connect(function()
	Open.Visible = false
	Open.Active = false
	Open:TweenPosition(constants.conceal, "Out", "Quad", 0.15)

	Base.Visible = true
	Base.Active = true
	Base:TweenPosition(constants.opened, "Out", "Quad", 0.15)
end)

-- COLLAPSE UI (FIXED: FULLY HIDE UI)
Collapse.MouseButton1Click:Connect(function()
	Base.Visible = false      -- FULL HIDE
	Base.Active = false

	Open.Visible = true
	Open.Active = true
	Open:TweenPosition(constants.reveal, "Out", "Quad", 0.15)
end)

-- PARENT UI
Interface.Name = HttpService:GenerateGUID(false)
Interface.Parent = getHui and getHui() or CoreGui

-- FIX: force hide Open button AFTER parenting
task.defer(function()
	Open.Visible = false
	Open.Active = false
	Open.Position = constants.conceal
end)

-- INITIAL STATE
Base.Visible = true
Base.Active = true
Base.Position = constants.opened

Open.Visible = false
Open.Active = false
Open.Position = constants.conceal

-- AUTO UPDATE "NO RESULTS FOUND" ACROSS ALL MODULES
task.spawn(function()

	local function hasResults(container)
		if not container then return false end
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("GuiObject")
				and not child:IsA("UIListLayout")
				and not child:IsA("UIPadding")
				and child.Visible ~= false then
				return true
			end
		end
		return false
	end

	local function resolveContainer(resultStatus)
		local parent = resultStatus.Parent
		if not parent then return nil end

		if parent:FindFirstChild("Results") then
			local results = parent.Results
			if results:FindFirstChild("Clip") and results.Clip:FindFirstChild("Content") then
				return results.Clip.Content
			end
		end

		if parent.Name == "Results" then
			if parent:FindFirstChild("Clip") and parent.Clip:FindFirstChild("Content") then
				return parent.Clip.Content
			end
		end

		if parent:FindFirstChild("Content") then
			return parent.Content
		end

		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("ScrollingFrame") then
				return child
			end
		end

		return nil
	end

	local function bindResultStatus(resultStatus)
		local container = resolveContainer(resultStatus)
		if not container then return end

		local function refresh()
			resultStatus.Visible = not hasResults(container)
		end

		refresh()

		container.ChildAdded:Connect(function() task.defer(refresh) end)
		container.ChildRemoved:Connect(function() task.defer(refresh) end)
		container:GetPropertyChangedSignal("Visible"):Connect(function() task.defer(refresh) end)
	end

	for _, d in ipairs(Interface:GetDescendants()) do
		if d:IsA("TextLabel") and d.Name == "ResultStatus" then
			bindResultStatus(d)
		end
	end
end)

return Interface
