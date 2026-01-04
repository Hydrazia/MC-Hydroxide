local CoreGui = game:GetService("CoreGui")
local UserInput = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Interface = import("rbxassetid://11389137937")

if oh.Cache["ui/main"] then
    return Interface
end

import("ui/controls/TabSelector")
local MessageBox, MessageType = import("ui/controls/MessageBox")

local Open = Interface.Open
local Base = Interface.Base
local Drag = Base.Drag
local Collapse = Drag.Collapse

local constants = {
    opened = UDim2.new(0.5, -325, 0.5, -175),
    closed = UDim2.new(0.5, -325, 0, -800),
    reveal = UDim2.new(0.5, -15, 0, 20),
    conceal = UDim2.new(0.5, -15, 0, -200)
}

-- // THE SCROLLING CURE
-- This prevents the "parts touching and glitching" issue by forcing Offset sizing
local function preventOverlap(frame)
    if not frame:IsA("ScrollingFrame") then return end
    
    frame.AutomaticCanvasSize = Enum.AutomaticSize.None
    local layout = frame:FindFirstChildWhichIsA("UIListLayout") or frame:FindFirstChildWhichIsA("UIGridLayout")
    
    if layout then
        local function resize()
            local contentHeight = layout.AbsoluteContentSize.Y
            frame.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 20)
        end
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)
        
        -- Fix existing and new children to not use Scale Y
        local function fixChild(child)
            if child:IsA("GuiObject") and child.Visible then
                if child.Size.Y.Scale > 0 then
                    child.Size = UDim2.new(child.Size.X.Scale, child.Size.X.Offset, 0, child.AbsoluteSize.Y)
                end
            end
        end
        
        frame.ChildAdded:Connect(fixChild)
        for _, child in pairs(frame:GetChildren()) do fixChild(child) end
        resize()
    end
end

for _, v in pairs(Interface:GetDescendants()) do preventOverlap(v) end
Interface.DescendantAdded:Connect(preventOverlap)

-- // CLEAN TOGGLE SYSTEM
local isTransitioning = false
local function toggle(showMain)
    if isTransitioning then return end
    isTransitioning = true
    
    if showMain then
        Open:TweenPosition(constants.conceal, "Out", "Quad", 0.2, true)
        task.wait(0.1)
        Open.Visible = false
        Base.Visible = true
        Base:TweenPosition(constants.opened, "Out", "Quad", 0.2, true)
    else
        Base:TweenPosition(constants.closed, "Out", "Quad", 0.2, true)
        task.wait(0.1)
        Base.Visible = false
        Open.Visible = true
        Open:TweenPosition(constants.reveal, "Out", "Quad", 0.2, true)
    end
    
    task.wait(0.2)
    isTransitioning = false
end

Open.MouseButton1Click:Connect(function() toggle(true) end)
Collapse.MouseButton1Click:Connect(function() toggle(false) end)

-- // INITIAL STATE
Base.Visible = true
Base.Position = constants.opened
Open.Visible = false
Open.Position = constants.conceal

-- // DRAGGING FIX
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

-- // MODULE LOAD
xpcall(function()
    import("ui/modules/RemoteSpy")
    import("ui/modules/ClosureSpy")
    import("ui/modules/ScriptScanner")
    import("ui/modules/ModuleScanner")
    import("ui/modules/UpvalueScanner")
    import("ui/modules/ConstantScanner")
end, function(err)
    warn("Hydroxide Module Error: " .. err)
end)

-- // FINAL SETUP
Interface.Name = HttpService:GenerateGUID(false)
local targetParent = gethui and gethui() or CoreGui
if syn and syn.protect_gui then syn.protect_gui(Interface) end
Interface.Parent = targetParent

return Interface
