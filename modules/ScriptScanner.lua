local ScriptScanner = {}
local LocalScript = import("objects/LocalScript")

-- Resolve exploit functions safely
local getGc = getgc or debug.getgc
local getSenv = getsenv or getfenv
local getScriptClosure = getscriptclosure or getScriptClosure or function() return nil end
local isXClosure = is_synapse_function or isourclosure or isexecutorclosure or function() return false end

local requiredMethods = {
    getGc = true,
    getSenv = true,
    getProtos = true,
    getConstants = true,
    getScriptClosure = true,
    isXClosure = true
}

local function safeGetScriptFromClosure(fn)
    -- getfenv(fn).script is NOT always safe
    local ok, env = pcall(getSenv, fn)
    if not ok or type(env) ~= "table" then
        return nil
    end

    local script = rawget(env, "script")
    if typeof(script) == "Instance" and script:IsA("LocalScript") then
        return script
    end

    return nil
end

local function safeHasClosure(script)
    local ok, closure = pcall(getScriptClosure, script)
    return ok and type(closure) == "function"
end

local function safeHasEnv(script)
    return pcall(function()
        local env = getsenv(script)
        return env ~= nil
    end)
end

local function scan(query)
    local results = {}
    local q = tostring(query or ""):lower()

    for _, fn in pairs(getGc()) do
        if type(fn) == "function" and not isXClosure(fn) then

            local script = safeGetScriptFromClosure(fn)
            if script
                and not results[script]
                and script.Name:lower():find(q, 1, true)
                and safeHasClosure(script)
                and safeHasEnv(script)
            then
                results[script] = LocalScript.new(script)
            end
        end
    end

    return results
end

ScriptScanner.RequiredMethods = requiredMethods
ScriptScanner.Scan = scan
return ScriptScanner
