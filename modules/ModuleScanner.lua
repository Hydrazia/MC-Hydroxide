local ModuleScanner = {}
local ModuleScript = import("objects/ModuleScript")

-- Resolve exploit functions safely
local getLoadedModules = getloadedmodules or getLoadedModules or function()
    return {}
end

local getMenv = getmenv or getMenv or getsenv or function()
    return {}
end

local getScriptClosure = getscriptclosure or getScriptClosure or function()
    return nil
end

local requiredMethods = {
    getMenv = true,
    getProtos = true,
    getConstants = true,
    getScriptClosure = true,
    getLoadedModules = true
}

local function safeName(obj)
    local ok, name = pcall(function()
        return obj.Name
    end)
    return ok and tostring(name) or ""
end

local function safeHasClosure(module)
    local ok, closure = pcall(getScriptClosure, module)
    return ok and type(closure) == "function"
end

local function safeHasEnv(module)
    local ok = pcall(function()
        getMenv(module)
    end)
    return ok
end

local function scan(query)
    local results = {}
    local q = tostring(query or ""):lower()

    for _, module in pairs(getLoadedModules()) do
        if typeof(module) == "Instance" and module:IsA("ModuleScript") then
            local name = safeName(module):lower()

            if name:find(q, 1, true) then
                -- Optional: ensure module is actually loadable
                if safeHasClosure(module) or safeHasEnv(module) then
                    results[module] = ModuleScript.new(module)
                else
                    -- Still include it, but safely
                    results[module] = ModuleScript.new(module)
                end
            end
        end
    end

    return results
end

ModuleScanner.Scan = scan
ModuleScanner.RequiredMethods = requiredMethods
return ModuleScanner
