local CoreGui = game:GetService("CoreGui")
local UserInput = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Interface = import("rbxassetid://11389137937")

if oh.Cache["ui/main"] then
    return Interface
end

import("ui/controls/TabSelector")
local MessageBox, MessageType = import("ui/controls/MessageBox")

-- // Constants
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

-- // Setup Initial State (Hide Open Button, Show Main)
Base.Visible = true
Base.Position = constants.opened
Open.Visible = false
Open.Position = constants.conceal

-- // Scrolling Fix (Prevents elements touching/glitching)
local function fixScrolling(sf)
    if not sf:IsA("ScrollingFrame") then return end
    sf.AutomaticCanvasSize = Enum.AutomaticSize.None
    sf.ScrollBarThickness = 3
    
    local layout = sf:FindFirstChildWhichIsA("UIListLayout") or sf:FindFirstChildWhichIsA("UIGridLayout")
    if layout then
        local function update()
            sf.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
        end
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
        task.defer(update)
    end
end

for _, v in pairs(Interface:GetDescendants()) do fixScrolling(v) end
Interface.DescendantAdded:Connect(fixScrolling)

-- // Improved Module Loading
xpcall(function()
    import("ui/modules/RemoteSpy")
    import("ui/modules/ClosureSpy")
    import("ui/modules/ScriptScanner")
    import("ui/modules/ModuleScanner")
    import("ui/modules/UpvalueScanner")
    import("ui/modules/ConstantScanner")
end, function(err)
    MessageBox.Show("Error", "Failed to load modules: " .. tostring(err), MessageType.OK)
end)

-- // Toggle Logic
local function toggle(showMain)
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

Open.MouseButton1Click:Connect(function() toggle(true) end)
Collapse.MouseButton1Click:Connect(function() toggle(false) end)

-- // Draggable Logic
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

-- // Final Setup
Interface.Name = HttpService:GenerateGUID(false)
local parent = gethui and gethui() or CoreGui
if syn and syn.protect_gui then syn.protect_gui(Interface) end
Interface.Parent = parent

return Interface
