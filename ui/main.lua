local CoreGui = game:GetService("CoreGui")
local UserInput = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Interface = import("rbxassetid://11389137937")

if oh.Cache["ui/main"] then
	return Interface
end

oh.Events = oh.Events or {} -- ensure Events table exists

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

getgenv().signaluis = UserInput.InputBegan:Connect(function(input, gp)
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

local moduleId = { "RemoteSpy", "ClosureSpy", "ScriptScanner", "ModuleScanner", "UpvalueScanner", "ConstantScanner" }

function moduleError(err)
	local message
	if err:find("valid member") then
		message = "The UI has updated, please rejoin and restart. If you get this message more than once, screenshot this message and report it in the Hydroxide server.\n\n" .. err
	else
		message = string.format("Report this error in Hydroxide's server:\n\n%s", err)
	end

	MessageBox.Show("An error has occurred", message, MessageType.OK, function()
		--Interface:Destroy()
	end)
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

local constants = {
	opened = UDim2.new(0.5, -325, 0.5, -175),
	closed = UDim2.new(0.5, -325, 0, -400),
	reveal = UDim2.new(0.5, -15, 0, 20),
	conceal = UDim2.new(0.5, -15, 0, -75),
}

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

-- enable input objects
Open.Active = true
Base.Active = true
Drag.Active = true
Collapse.Active = true

local dragging, dragStart, startPos

-- drag start (mouse + touch, with your multitouch guard)
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

-- drag move
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

-- open: hide button, show base
Open.MouseButton1Click:Connect(function()
	Open.Visible = false
	Open.Active = false
	Open:TweenPosition(constants.conceal, "Out", "Quad", 0.15, true)

	Base.Visible = true
	Base.Active = true
	Base:TweenPosition(constants.opened, "Out", "Quad", 0.15, true)
end)

-- collapse: hide base, show button
Collapse.MouseButton1Click:Connect(function()
	Base.Active = false
	Base:TweenPosition(constants.closed, "Out", "Quad", 0.15, true)

	Open.Visible = true
	Open.Active = true
	Open:TweenPosition(constants.reveal, "Out", "Quad", 0.15, true)
end)

Interface.Name = HttpService:GenerateGUID(false)

if getHui then
	Interface.Parent = getHui()
else
	if syn and syn.protect_gui then
		syn.protect_gui(Interface)
	end

	Interface.Parent = CoreGui
end

-- INITIAL STATE: UI starts OPEN, button hidden, centered
Base.Visible = true
Base.Active = true
Base.Position = constants.opened

Open.Visible = false
Open.Active = false
Open.Position = constants.conceal

-- AUTO UPDATE "NO RESULTS FOUND" ACROSS ALL MODULES
task.spawn(function()
	-- check if a container actually has visible results
	local function hasResults(container)
		if not container then return false end
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("GuiObject")
				and not child:IsA("UIListLayout")
				and not child:IsA("UIPadding") then
				if child.Visible ~= false then
					return true
				end
			end
		end
		return false
	end

	-- try to resolve the scrolling container associated with a ResultStatus
	local function resolveContainer(resultStatus)
		local parent = resultStatus.Parent
		if not parent then return nil end

		-- common Hydroxide patterns: Results -> Clip -> Content
		if parent:FindFirstChild("Results") then
			local results = parent.Results
			if results:FindFirstChild("Clip") then
				local clip = results.Clip
				if clip:FindFirstChild("Content") then
					return clip.Content
				end
			end
		end

		-- parent itself might be Results
		if parent.Name == "Results" then
			if parent:FindFirstChild("Clip") and parent.Clip:FindFirstChild("Content") then
				return parent.Clip.Content
			end
		end

		-- generic: direct Content child
		if parent:FindFirstChild("Content") then
			return parent.Content
		end

		-- fallbacks: look for any ScrollingFrame under parent
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

		-- initial
		refresh()

		-- update when children change
		container.ChildAdded:Connect(function()
			task.defer(refresh)
		end)

		container.ChildRemoved:Connect(function()
			task.defer(refresh)
		end)

		-- update when container visibility changes
		container:GetPropertyChangedSignal("Visible"):Connect(function()
			task.defer(refresh)
		end)
	end

	-- bind ALL ResultStatus labels in the entire interface
	for _, d in ipairs(Interface:GetDescendants()) do
		if d:IsA("TextLabel") and d.Name == "ResultStatus" then
			bindResultStatus(d)
		end
	end
end)

return Interface
