local UpvalueScanner = {}
local Closure = import("objects/Closure")
local Upvalue = import("objects/Upvalue")

local getGc = getgc or debug.getgc
local getInfo = debug.getinfo or getinfo or getInfo
local isXClosure = is_synapse_function or isourclosure or isexecutorclosure or isexecutorclosure or function() return false end
local getUpvalue = debug.getupvalue or getupvalue
local getUpvalues = debug.getupvalues or getupvalues or function(fn)
    local t = {}
    local i = 1
    while true do
        local name, value = getUpvalue(fn, i)
        if not name then break end
        t[i] = value
        i += 1
    end
    return t
end

local requiredMethods = {
    getGc = true,
    getInfo = true,
    isXClosure = true,
    getUpvalue = true,
    setUpvalue = true,
    getUpvalues = true,
}

local function compareUpvalue(query, upvalue, ignoreNumber)
    local upvalueType = typeof(upvalue)

    if upvalueType == "string" then
        local q = tostring(query)
        local val = upvalue
        q = q:lower()
        val = val:lower()
        return q == val or val:find(q, 1, true) ~= nil
    end

    if not ignoreNumber and upvalueType == "number" then
        local qNum = tonumber(query)
        if qNum and qNum == upvalue then
            return true
        end
        if ("%.2f"):format(upvalue) == tostring(query) then
            return true
        end
    end

    if upvalueType == "Instance" then
        local name = upvalue.Name
        return name == query or name:find(query, 1, true) ~= nil
    end

    if upvalueType == "userdata" then
        return tostring(upvalue) == tostring(query)
    end

    if upvalueType == "function" then
        local info = getInfo(upvalue) or {}
        local name = info.name or ""
        local q = tostring(query):lower()
        local n = tostring(name):lower()
        return q == n or n:find(q, 1, true) ~= nil
    end

    return false
end

local function scan(query, deepSearch)
    local upvalues = {}
    local q = tostring(query or "")

    for _, closure in pairs(getGc()) do
        if type(closure) == "function" and not isXClosure(closure) and not upvalues[closure] then
            local ups = getUpvalues(closure)
            for index, value in pairs(ups) do
                local valueType = typeof(value)

                if valueType ~= "table" and compareUpvalue(q, value, false) then
                    local storage = upvalues[closure]

                    if not storage then
                        local newClosure = Closure.new(closure)
                        newClosure.Upvalues[index] = Upvalue.new(newClosure, index, value)
                        upvalues[closure] = newClosure
                    else
                        storage.Upvalues[index] = Upvalue.new(storage, index, value)
                    end

                elseif deepSearch and valueType == "table" then
                    local storage = upvalues[closure]
                    local tableUpv

                    for i, v in pairs(value) do
                        if (i ~= value and v ~= value) and (compareUpvalue(q, i, true) or compareUpvalue(q, v, false)) then
                            if not storage then
                                local newClosure = Closure.new(closure)
                                storage = newClosure
                                upvalues[closure] = newClosure
                            end

                            if not tableUpv then
                                tableUpv = Upvalue.new(storage, index, value)
                                tableUpv.Scanned = {}
                                storage.Upvalues[index] = tableUpv
                            end

                            tableUpv.Scanned[i] = v
                        end
                    end
                end
            end
        end
    end

    return upvalues
end

UpvalueScanner.Scan = scan
UpvalueScanner.RequiredMethods = requiredMethods

return UpvalueScanner
