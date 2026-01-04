local ConstantScanner = {}
local Closure = import("objects/Closure")
local Constant = import("objects/Constant")

-- Resolve exploit functions safely
local getGc = getgc or debug.getgc
local getInfo = debug.getinfo or getinfo or getInfo
local isXClosure = is_synapse_function or isourclosure or isexecutorclosure or function() return false end
local isLClosure = islclosure or is_l_closure or function() return true end
local getConstants = debug.getconstants or getconstants or function(fn)
    local t = {}
    local i = 1
    while true do
        local ok, const = pcall(getconstant or debug.getconstant, fn, i)
        if not ok or const == nil then break end
        t[i] = const
        i += 1
    end
    return t
end

local requiredMethods = {
    getGc = true,
    getInfo = true,
    isXClosure = true,
    getConstant = true,
    setConstant = true,
    getConstants = true
}

-- Safe compare
local function compareConstant(query, constant)
    local q = tostring(query or "")
    local ctype = typeof(constant)

    if ctype == "string" then
        local a = q:lower()
        local b = constant:lower()
        return a == b or b:find(a, 1, true) ~= nil
    end

    if ctype == "number" then
        local qNum = tonumber(q)
        if qNum and qNum == constant then
            return true
        end
        return ("%.2f"):format(constant) == q
    end

    if ctype == "Instance" then
        local name = constant.Name
        return name == q or name:lower():find(q:lower(), 1, true) ~= nil
    end

    if ctype == "userdata" then
        return tostring(constant) == q
    end

    if ctype == "function" then
        local info = getInfo(constant) or {}
        local name = tostring(info.name or ""):lower()
        local ql = q:lower()
        return ql == name or name:find(ql, 1, true) ~= nil
    end

    return false
end

local function scan(query)
    local results = {}
    local q = tostring(query or "")

    for _, closure in pairs(getGc()) do
        if type(closure) == "function"
            and not isXClosure(closure)
            and isLClosure(closure)
            and not results[closure]
        then
            local constants = getConstants(closure)

            for index, constant in pairs(constants) do
                if compareConstant(q, constant) then
                    local storage = results[closure]

                    if not storage then
                        local newClosure = Closure.new(closure)
                        newClosure.Constants[index] = Constant.new(newClosure, index, constant)
                        results[closure] = newClosure
                    else
                        storage.Constants[index] = Constant.new(storage, index, constant)
                    end
                end
            end
        end
    end

    return results
end

ConstantScanner.Scan = scan
ConstantScanner.RequiredMethods = requiredMethods
return ConstantScanner
