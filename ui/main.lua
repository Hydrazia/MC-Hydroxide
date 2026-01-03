local CoreGui = game:GetService("CoreGui")
local UserInput = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Interface = import("rbxassetid://11389137937")

if oh.Cache["ui/main"] then
    return Interface
end

import("ui/controls/TabSelector")
local MessageBox, MessageType = import("ui/controls/MessageBox")

-- Variables for modules
local RemoteSpy, ClosureSpy, ScriptScanner, ModuleScanner, UpvalueScanner, ConstantScanner

getgenv().touchPoints = {}
getgenv().conduct = 0
getgenv().pressHold = false
getgenv().mainBase = Interface.Base
mainBase.Active = true

-- Optimized Mouse Check
getgenv().MouseInFrame = function(uiobject)
    local mouse = game:GetService("Players").LocalPlayer:GetMouse()
    local pos, size = uiobject.AbsolutePosition, uiobject.AbsoluteSize
    return (mouse.X >= pos.X and mouse.X <= pos.X + size.X and mouse.Y >= pos.Y and mouse.Y <= pos.Y + size.Y)
end

if signaluis then signaluis:Disconnect() end

getgenv().signaluis = UserInput.InputBegan:Connect(function(input, gp)
    if input.UserInputType == Enum.UserInputType.Touch then
        conduct += 1
        local key = conduct
        touchPoints[key] = input.Position
        local startClock = os.clock()
        
        task.spawn(function()
            while (os.clock() - startClock) < 0.4 do task.wait() end
            if touchPoints[key] then pressHold = true end
        end)

        local connection
        connection = UserInput.InputEnded:Connect(function(endInput)
            if endInput == input then
                touchPoints[key] = nil
                conduct -= 1
                pressHold = false
                connection:Disconnect()
            end
        end)
    end
end)

-- Module Loading
xpcall(function()
    RemoteSpy = import("ui/modules/RemoteSpy")
    ClosureSpy = import("ui/modules/ClosureSpy")
    ScriptScanner = import("ui/modules/ScriptScanner")
    ModuleScanner = import("ui/modules/ModuleScanner")
    UpvalueScanner = import("ui/modules/UpvalueScanner")
    ConstantScanner = import("ui/modules/ConstantScanner")
end, function(err)
    local message = err:find("valid member") and "UI Updated. Please rejoin/restart." or "Error: "..err
    MessageBox.Show("An error occurred", message, MessageType.OK)
end)

local constants = {
    opened = UDim2.new(0.5, -325, 0.5, -175),
    closed = UDim2.new(0.5, -325, 0, -500), -- Moved further off screen
    reveal = UDim2.new(0.5, -15, 0, 20),
    conceal = UDim2.new(0.5, -15, 0, -100) -- Moved further off screen
}

local Open = Interface.Open
local Base = Interface.Base
local Drag = Base.Drag
local Status = Base.Status
local Collapse = Drag.Collapse

-- INITIAL STATE: Show Main UI, Hide Open Button
Base.Position = constants.opened
Open.Position = constants.conceal

function oh.setStatus(text) Status.Text = '• Status: ' .. text end

-- Dragging Logic
local dragging, dragStart, startPos
Drag.InputBegan:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        dragging = true
        dragStart = input.Position
        startPos = Base.Position
        
        local connection
        connection = UserInput.InputChanged:Connect(function(change)
            if change.UserInputType == Enum.UserInputType.MouseMovement or change.UserInputType == Enum.UserInputType.Touch then
                local delta = change.Position - dragStart
                Base.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        
        UserInput.InputEnded:Connect(function(endInput)
            if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                connection:Disconnect()
            end
        end)
    end
end)

-- TOGGLE LOGIC: Open Button
Open.MouseButton1Click:Connect(function()
    -- Hide Open Button first
    Open:TweenPosition(constants.conceal, "Out", "Quad", 0.15, true)
    task.wait(0.1)
    -- Show Main UI
    Base:TweenPosition(constants.opened, "Out", "Quad", 0.15, true)
end)

-- TOGGLE LOGIC: Collapse Button (X)
Collapse.MouseButton1Click:Connect(function()
    -- Hide Main UI first
    Base:TweenPosition(constants.closed, "Out", "Quad", 0.15, true)
    task.wait(0.1)
    -- Show Open Button
    Open:TweenPosition(constants.reveal, "Out", "Quad", 0.15, true)
end)

-- Results Status Handler (Cleaned)
task.spawn(function()
    local body = Base:WaitForChild("Body", 5)
    if not body then return end
    
    local function updateResultStatus(label)
        local container = label.Parent:FindFirstChild("Content") or label.Parent:FindFirstChild("Results")
        if not container then return end
        
        local function check() label.Visible = (#container:GetChildren() <= 3) end -- 3 accounts for UI layouts
        container.ChildAdded:Connect(check)
        container.ChildRemoved:Connect(check)
        check()
    end

    for _, v in pairs(Interface:GetDescendants()) do
        if v.Name == "ResultStatus" and v:IsA("TextLabel") then
            updateResultStatus(v)
        end
    end
end)

-- Parent and GUID
Interface.Name = HttpService:GenerateGUID(false)
Interface.Parent = (gethui and gethui()) or (syn and syn.protect_gui and CoreGui) or CoreGui

return Interface
