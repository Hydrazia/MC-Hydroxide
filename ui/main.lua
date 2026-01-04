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

-- UNIVERSAL INPUT STATE
getgenv().touchPoints = {}
getgenv().touching = {}
getgenv().conduct = 0
getgenv().pressHold = false
getgenv().mainBase = Interface.Base
mainBase.Active = true

-- BEST TOUCH + LONG PRESS SUPPORT
local UIS = UserInput
local InputState = {
	Touching = false,
	TouchStart = nil,
	TouchId = nil,
	LongPress = false,
	Dragging = false,
}

UIS.TouchStarted:Connect(function(touch)
	if InputState.Touching then return end -- block multi-touch

	InputState.Touching = true
	InputState.TouchId = touch.TouchId
	InputState.TouchStart = touch.Position
	InputState.LongPress = false

	task.delay(0.35, function()
		if InputState.Touching and not InputState.Dragging then
			InputState.LongPress = true
			pressHold = true
		end
	end)
end)

UIS.TouchMoved:Connect(function(touch)
	if touch.TouchId ~= InputState.TouchId then return end

	if (touch.Position - InputState.TouchStart).Magnitude > 10 then
		InputState.Dragging = true
		pressHold = false
	end
end)

UIS.TouchEnded:Connect(function(touch)
	if touch.TouchId ~= InputState.TouchId then return end

	InputState.Touching = false
	InputState.TouchId = nil
	InputState.Dragging = false
	InputState.LongPress = false
	pressHold = false
end)

-- PC CLICK DETECTOR
function getgenv().IsMouseClick(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
end

-- TOUCH TAP DETECTOR
function getgenv().IsTouchTap()
	return InputState.Touching == false and InputState.Dragging == false and InputState.LongPress == false
end

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

getgenv().signaluis = UIS.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		-- handled by universal input layer
	end
end)

-- MODULE LOADING
local moduleId = { "RemoteSpy", "ClosureSpy", "ScriptScanner", "ModuleScanner", "UpvalueScanner", "ConstantScanner" }

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
	reveal = UDim2.new(0.5, -15, 0, 20),
	conceal = UDim2.new(0.5, -15, 0, -75),
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
	if IsMouseClick(input) or (input.UserInputType == Enum.UserInputType.Touch and InputState.Touching == false) then
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

oh.Events.Drag = UIS.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
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
	Open.Active = false
	Open:TweenPosition(constants.conceal, "Out", "Quad", 0.15, true)

	Base.Visible = true
	Base.Active = true
	Base:TweenPosition(constants.opened, "Out", "Quad", 0.15, true)
end)

-- COLLAPSE UI
Collapse.MouseButton1Click:Connect(function()
	Base.Active = false
	Base:TweenPosition(constants.closed, "Out", "Quad", 0.15, true)

	Open.Visible = true
	Open.Active = true
	Open:TweenPosition(constants.reveal, "Out", "Quad", 0.15, true)
end)

-- PARENT UI
Interface.Name = HttpService:GenerateGUID(false)

if getHui then
	Interface.Parent = getHui()
else
	if syn and syn.protect_gui then
		syn.protect_gui(Interface)
	end
	Interface.Parent = CoreGui
end

-- INITIAL STATE (CENTERED, OPEN)
Base.Visible = true
Base.Active = true
Base.Position = constants.opened

Open.Visible = false
Open.Active = false
Open.Position = constants.conceal

return Interface
