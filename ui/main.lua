local CoreGui = game:GetService("CoreGui")
local UserInput = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Interface = import("rbxassetid://11389137937")

if oh.Cache["ui/main"] then
	return Interface
end

import("ui/controls/TabSelector")
local MessageBox, MessageType = import("ui/controls/MessageBox")

getgenv().mainBase = Interface.Base
mainBase.Active = true

-- Simplified Constants
local constants = {
	opened = UDim2.new(0.5, -325, 0.5, -175),
	closed = UDim2.new(0.5, -325, 0, -600),
	reveal = UDim2.new(0.5, -15, 0, 20),
	conceal = UDim2.new(0.5, -15, 0, -100)
}

local Open = Interface.Open
local Base = Interface.Base
local Drag = Base.Drag
local Collapse = Drag.Collapse

-- 1. FIXING THE SCROLLING GLITCH
local function ApplyScrollFix(frame)
	if not frame:IsA("ScrollingFrame") then return end
	
	-- Disable Roblox's buggy automatic sizing for custom layouts
	frame.AutomaticCanvasSize = Enum.AutomaticSize.None
	frame.ScrollBarThickness = 4
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	
	local layout = frame:FindFirstChildWhichIsA("UIListLayout") or frame:FindFirstChildWhichIsA("UIGridLayout")
	
	if layout then
		local function update()
			-- Force canvas size based on strict pixel math, not scale
			local contentSize = layout.AbsoluteContentSize
			frame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 10)
		end
		
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
		update()
	end
end

-- Monitor for all present and future scrolling frames
Interface.DescendantAdded:Connect(ApplyScrollFix)
for _, v in pairs(Interface:GetDescendants()) do ApplyScrollFix(v) end

-- 2. IMPROVED TOGGLE LOGIC (No glitching on start)
Base.Visible = true
Base.Position = constants.opened
Open.Visible = false
Open.Position = constants.conceal

local function toggleUI(showMain)
	if showMain then
		Open:TweenPosition(constants.conceal, "Out", "Quad", 0.15, true)
		task.wait(0.1)
		Open.Visible = false
		Base.Visible = true
		Base:TweenPosition(constants.opened, "Out", "Quad", 0.15, true)
	else
		Base:TweenPosition(constants.closed, "Out", "Quad", 0.15, true)
		task.wait(0.1)
		Base.Visible = false
		Open.Visible = true
		Open:TweenPosition(constants.reveal, "Out", "Quad", 0.15, true)
	end
end

Open.MouseButton1Click:Connect(function() toggleUI(true) end)
Collapse.MouseButton1Click:Connect(function() toggleUI(false) end)

-- 3. CLEAN DRAGGING (Removed unnecessary touch conduct logic)
local dragging, dragStart, startPos
Drag.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = Base.Position
		
		local connection
		connection = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				connection:Disconnect()
			end
		end)
	end
end)

UserInput.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		Base.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- 4. RESULT STATUS (Cleaner check)
task.spawn(function()
	local pages = Base:WaitForChild("Body", 5):WaitForChild("Pages", 5)
	
	local function updateStatus(label)
		local container = label.Parent:FindFirstChild("Content") or label.Parent:FindFirstChild("Results")
		if container then
			local function refresh()
				local count = 0
				for _, c in pairs(container:GetChildren()) do
					if not c:IsA("UIComponent") then count += 1 end
				end
				label.Visible = (count == 0)
			end
			container.ChildAdded:Connect(refresh)
			container.ChildRemoved:Connect(refresh)
			refresh()
		end
	end

	for _, v in pairs(Interface:GetDescendants()) do
		if v.Name == "ResultStatus" then updateStatus(v) end
	end
end)

-- 5. PARENTING & SECURITY
Interface.Name = HttpService:GenerateGUID(false)
local parentTarget = (gethui and gethui()) or (syn and syn.protect_gui and CoreGui) or CoreGui
if syn and syn.protect_gui then syn.protect_gui(Interface) end
Interface.Parent = parentTarget

return Interface
