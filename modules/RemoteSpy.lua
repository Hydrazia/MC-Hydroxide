local RemoteSpy = {}
local Remote = import("objects/Remote")

---------------------------------------------------------------------
-- REQUIRED METHODS
---------------------------------------------------------------------
local requiredMethods = {
    ["checkCaller"] = true,
    ["newCClosure"] = true,
    ["hookFunction"] = true,
    ["isReadOnly"] = true,
    ["setReadOnly"] = true,
    ["getInfo"] = true,
    ["getMetatable"] = true,
    ["setClipboard"] = true,
    ["getNamecallMethod"] = true,
    ["getCallingScript"] = true,
}

---------------------------------------------------------------------
-- SAFE RESOLVES / DEBUG HELPERS
---------------------------------------------------------------------
local getInfo      = debug and debug.getinfo      or getInfo
local getUpvalues  = debug and debug.getupvalues  or getupvalues
local getConstants = debug and debug.getconstants or getconstants
local getMeta      = getrawmetatable or getmetatable or getMetatable
local setReadOnly  = setreadonly or make_writeable or setReadOnly
local isReadOnly   = isreadonly or isReadOnly
local getNamecallMethod = getnamecallmethod or getNamecallMethod
local getCallingScript  = getcallingscript or getCallingScript
local hookFunction      = hookfunction or hookFunction
local newCClosure       = newcclosure or newCClosure
local hookMetaMethod    = hookmetamethod or hookMetaMethod
local getGc             = getgc or debug and debug.getgc or function() return {} end

---------------------------------------------------------------------
-- REMOTE METHODS / TYPES
---------------------------------------------------------------------
local remoteMethods = {
    FireServer = true,
    InvokeServer = true,
    Fire = true,
    Invoke = true
}

local remotesViewing = {
    RemoteEvent = true,
    RemoteFunction = false,
    BindableEvent = false,
    BindableFunction = false,
    -- You can enable this if you want unreliable
    -- UnreliableRemoteEvent = true,
}

local methodHooks = {
    RemoteEvent = Instance.new("RemoteEvent").FireServer,
    RemoteFunction = Instance.new("RemoteFunction").InvokeServer,
    BindableEvent = Instance.new("BindableEvent").Fire,
    BindableFunction = Instance.new("BindableFunction").Invoke,
    -- UnreliableRemoteEvent = Instance.new("UnreliableRemoteEvent").FireServer,
}

---------------------------------------------------------------------
-- INTERNAL STATE
---------------------------------------------------------------------
local currentRemotes = {}

local remoteDataEvent = Instance.new("BindableEvent")
local eventSet = false

-- stats
local RemoteStats = {}
local ScriptStats = {}
local globalCallId = 0

---------------------------------------------------------------------
-- UTIL: SAFE STRING, TYPE, HASH
---------------------------------------------------------------------
local function safeTostring(v)
    local ok, str = pcall(tostring, v)
    return ok and str or "<[tostring error]>"
end

local function classifyType(v)
    local t = typeof(v)
    if t == "table" then
        return "table"
    elseif t == "Instance" then
        return "Instance"
    elseif t == "function" then
        return "function"
    elseif t == "thread" then
        return "thread"
    elseif t == "userdata" then
        return "userdata"
    end
    return t
end

local function hashRemote(inst)
    local parts = {
        inst.ClassName or "?",
        (pcall(inst.GetFullName, inst) and inst:GetFullName()) or "<unknown>",
        tostring(inst)
    }
    return "RMT_" .. string.gsub(table.concat(parts, "|"), "%s", "")
end

---------------------------------------------------------------------
-- SNAPSHOT ENGINE (INLINE)
---------------------------------------------------------------------
local function deepCopyValue(value, mode, depth, maxDepth, visited)
    depth = depth or 0
    visited = visited or {}

    if depth > maxDepth then
        return "<[max depth reached]>"
    end

    local t = typeof(value)

    if t ~= "table" and t ~= "Instance" then
        return value
    end

    if visited[value] then
        return "<[cycle:" .. visited[value] .. "]>"
    end

    local tag = "R" .. tostring(#visited + 1)
    visited[value] = tag

    if t == "Instance" then
        return {
            __snapType = "Instance",
            ClassName = value.ClassName,
            Name = value.Name,
            Path = (pcall(value.GetFullName, value) and value:GetFullName()) or "<unknown>",
        }
    end

    local copy = {}
    copy.__snapType = "table"
    copy.__refTag = tag

    for k, v in pairs(value) do
        local nextDepth = depth + 1
        local ck, cv

        if mode == "full" then
            ck = deepCopyValue(k, "full", nextDepth, maxDepth, visited)
            cv = deepCopyValue(v, "full", nextDepth, maxDepth, visited)
        else
            ck = deepCopyValue(k, "shallow", nextDepth, maxDepth, visited)
            cv = deepCopyValue(v, "shallow", nextDepth, maxDepth, visited)
        end

        copy[ck] = cv
    end

    local mt = getmetatable(value)
    if mt then
        copy.__metatable = deepCopyValue(mt, "shallow", depth + 1, maxDepth, visited)
    end

    return copy
end

local function snapshotArgs(args)
    local cloned = {}
    local pretty = {}
    local types = {}

    for i, v in ipairs(args) do
        cloned[i] = deepCopyValue(v, "full", 0, 32, {})
        pretty[i] = safeTostring(v)
        types[i] = classifyType(v)
    end

    return cloned, pretty, types
end

local function snapshotUpvalues(func)
    local out = {}
    if not func or not getUpvalues then return out end

    local ok, ups = pcall(getUpvalues, func)
    if not ok or not ups then
        return out
    end

    for i, v in ipairs(ups) do
        out[i] = deepCopyValue(v, "full", 0, 16, {})
    end

    return out
end

local function snapshotConstants(func)
    local out = {}
    if not func or not getConstants then return out end

    local ok, consts = pcall(getConstants, func)
    if not ok or not consts then
        return out
    end

    for i, v in ipairs(consts) do
        out[i] = deepCopyValue(v, "full", 0, 16, {})
    end

    return out
end

local function snapshotEnv(scriptOrFunc)
    local env
    local ok

    if not getfenv then
        return {}
    end

    ok, env = pcall(getfenv, scriptOrFunc)
    if not ok or type(env) ~= "table" then
        return {}
    end

    return deepCopyValue(env, "shallow", 0, 6, {})
end

local function snapshotStack(maxFrames)
    maxFrames = maxFrames or 15
    local frames = {}

    if not getInfo then
        return frames
    end

    for level = 3, maxFrames + 2 do
        local info = getInfo(level, "nSl")
        if not info then break end

        frames[#frames + 1] = {
            source = info.source,
            shortSource = info.short_src,
            linedefined = info.linedefined,
            currentline = info.currentline,
            name = info.name,
            what = info.what,
        }
    end

    return frames
end

---------------------------------------------------------------------
-- STATS ENGINE (INLINE)
---------------------------------------------------------------------
local function ensureRemoteStats(hash)
    local stats = RemoteStats[hash]
    if not stats then
        stats = {
            totalCalls = 0,
            blockedCalls = 0,
            ignoredCalls = 0,
            lastCallTime = 0,
            perMethod = {},
        }
        RemoteStats[hash] = stats
    end
    return stats
end

local function ensureScriptStats(script)
    if not script then return nil end
    local key = tostring(script)
    local stats = ScriptStats[key]
    if not stats then
        stats = {
            script = script,
            totalCalls = 0,
            lastCallTime = 0,
        }
        ScriptStats[key] = stats
    end
    return stats
end

local function recordCall(call)
    local now = os.clock()

    local rStats = ensureRemoteStats(call.remoteHash)
    rStats.totalCalls += 1
    rStats.lastCallTime = now
    rStats.perMethod[call.method] = (rStats.perMethod[call.method] or 0) + 1

    local sStats = ensureScriptStats(call.script)
    if sStats then
        sStats.totalCalls += 1
        sStats.lastCallTime = now
    end
end

local function recordBlocked(call)
    local rStats = ensureRemoteStats(call.remoteHash)
    rStats.blockedCalls += 1
end

local function recordIgnored(call)
    local rStats = ensureRemoteStats(call.remoteHash)
    rStats.ignoredCalls += 1
end

---------------------------------------------------------------------
-- CALL BUILDER
---------------------------------------------------------------------
local function getScriptPath(script)
    if not script or not script.GetFullName then
        return "<unknown>"
    end
    local ok, path = pcall(script.GetFullName, script)
    return ok and path or "<error>"
end

local function buildCall(remoteInst, method, args)
    globalCallId += 1

    local script
    if getCallingScript then
        local ok, s = pcall(getCallingScript, (PROTOSMASHER_LOADED ~= nil and 2) or nil)
        if ok then
            script = s
        end
    end

    local funcInfo = getInfo and getInfo(3, "nSl") or nil
    local func = funcInfo and funcInfo.func or nil

    local rawArgs, prettyArgs, argTypes = snapshotArgs(args)
    local upvalues = snapshotUpvalues(func)
    local constants = snapshotConstants(func)
    local environment = snapshotEnv(script or func or remoteInst)
    local stackTrace = snapshotStack(20)

    local call = {
        callId = globalCallId,
        timestamp = os.clock(),

        remote = remoteInst,
        remoteType = remoteInst.ClassName,
        remoteHash = hashRemote(remoteInst),

        method = method,

        args = args,          -- live args
        rawArgs = rawArgs,    -- deep snapshot
        prettyArgs = prettyArgs,
        argTypes = argTypes,

        script = script,
        scriptPath = getScriptPath(script),
        origin = script and script.Name or "<unknown>",

        func = func,
        funcInfo = funcInfo,

        stackTrace = stackTrace,
        upvalues = upvalues,
        constants = constants,
        environment = environment,
    }

    recordCall(call)
    return call
end

---------------------------------------------------------------------
-- CONNECT EVENT
---------------------------------------------------------------------
local function connectEvent(callback)
    remoteDataEvent.Event:Connect(callback)

    if not eventSet then
        eventSet = true
    end
end

---------------------------------------------------------------------
-- SAFE REMOTE OBJECT GETTER
---------------------------------------------------------------------
local function getRemoteObject(instance)
    local remote = currentRemotes[instance]
    if not remote then
        remote = Remote.new(instance)
        currentRemotes[instance] = remote
    end
    return remote
end

---------------------------------------------------------------------
-- NAMECALL HOOK
---------------------------------------------------------------------
local nmcTrampoline
nmcTrampoline = hookMetaMethod(game, "__namecall", newCClosure(function(self,...)
    local args = {...}
    
    if typeof(self) ~= "Instance" then
        return nmcTrampoline(self,...)
    end

    local method = getNamecallMethod and getNamecallMethod()
    if not method then
        return nmcTrampoline(self, ...)
    end

    local lower = method:lower()

    if lower == "fireserver" then
        method = "FireServer"
    elseif lower == "invokeserver" then
        method = "InvokeServer"
    end
        
    if remotesViewing[self.ClassName] and self ~= remoteDataEvent and remoteMethods[method] then
        local remote = getRemoteObject(self)

        local remoteIgnored = remote.Ignored
        local remoteBlocked = remote.Blocked
        local argsIgnored = remote:AreArgsIgnored(args)
        local argsBlocked = remote:AreArgsBlocked(args)

        local call

        if eventSet and (not remoteIgnored and not argsIgnored) then
            call = buildCall(self, method, args)
            remote:IncrementCalls(call)
            remoteDataEvent:Fire(self, call)
        elseif remoteIgnored or argsIgnored then
            call = buildCall(self, method, args)
            recordIgnored(call)
        end

        if remoteBlocked or argsBlocked then
            if not call then
                call = buildCall(self, method, args)
            end
            recordBlocked(call)
            return
        end
    end

    return nmcTrampoline(self,...)
end))

---------------------------------------------------------------------
-- vuln fix (DIRECT METHOD HOOKS)
---------------------------------------------------------------------
local pcall = pcall

local function checkPermission(self)
    if (self.ClassName) then end
end

for _name, hook in pairs(methodHooks) do
    local originalMethod
    originalMethod = hookFunction(hook, newCClosure(function(self,...)
        local args = {...}

        -- original bug: typeof(args) ~= "Instance" (args is always a table)
        if typeof(self) ~= "Instance" then
            return originalMethod(self,...)
        end
                
        do
            local success = pcall(checkPermission, self)
            if (not success) then return originalMethod(self,...) end
        end

        if self.ClassName == _name and remotesViewing[_name] and self ~= remoteDataEvent then
            local remote = getRemoteObject(self)

            local remoteIgnored = remote.Ignored 
            local argsIgnored = remote:AreArgsIgnored(args)
            
            local method = (_name == "RemoteFunction" or _name == "BindableFunction") and "Invoke" or "Fire"
            local call

            if eventSet and (not remoteIgnored and not argsIgnored) then
                call = buildCall(self, method, args)
                remote:IncrementCalls(call)
                remoteDataEvent:Fire(self, call)
            elseif remoteIgnored or argsIgnored then
                call = buildCall(self, method, args)
                recordIgnored(call)
            end

            if remote.Blocked or remote:AreArgsBlocked(args) then
                if not call then
                    call = buildCall(self, method, args)
                end
                recordBlocked(call)
                return
            end
        end
        
        return originalMethod(self,...)
    end))

    if oh and oh.Hooks then
        oh.Hooks[originalMethod] = hook
    end
end

---------------------------------------------------------------------
-- EXPORT
---------------------------------------------------------------------
RemoteSpy.RemotesViewing = remotesViewing
RemoteSpy.CurrentRemotes = currentRemotes
RemoteSpy.ConnectEvent = connectEvent
RemoteSpy.RequiredMethods = requiredMethods
RemoteSpy.RemoteStats = RemoteStats
RemoteSpy.ScriptStats = ScriptStats

return RemoteSpy
