local RemoteSpy = {}
local Remote = import("objects/Remote")

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
    UnreliableRemoteEvent = true,
}

local methodHooks = {
    RemoteEvent = Instance.new("RemoteEvent").FireServer,
    RemoteFunction = Instance.new("RemoteFunction").InvokeServer,
    BindableEvent = Instance.new("BindableEvent").Fire,
    BindableFunction = Instance.new("BindableFunction").Invoke,
    UnreliableRemoteEvent = Instance.new("UnreliableRemoteEvent").FireServer,
}

local currentRemotes = {}

local remoteDataEvent = Instance.new("BindableEvent")
local eventSet = false

local function connectEvent(callback)
    remoteDataEvent.Event:Connect(callback)
    if not eventSet then
        eventSet = true
    end
end

local nmcTrampoline
nmcTrampoline = hookMetaMethod(game, "__namecall", function(self,...)
    local args = {...}
    if typeof(self) ~= "Instance" then
        return nmcTrampoline(self,...)
    end

    local method = getNamecallMethod():lower()
    if method == "fireserver" then
        method = "FireServer"
    elseif method == "invokeserver" then
        method = "InvokeServer"
    end
        
    if remotesViewing[self.ClassName] and self ~= remoteDataEvent and remoteMethods[method] then
        local remote = currentRemotes[self]
        if not remote then
            remote = Remote.new(self)
            currentRemotes[self] = remote
        end

        local remoteIgnored = remote.Ignored
        local remoteBlocked = remote.Blocked
        local argsIgnored = remote.AreArgsIgnored(remote, args)
        local argsBlocked = remote.AreArgsBlocked(remote, args)

        if eventSet and (not remoteIgnored and not argsIgnored) then
            local call = {
                script = getCallingScript((PROTOSMASHER_LOADED ~= nil and 2) or nil),
                args = args,
                func = getInfo(3).func
            }
            remote.IncrementCalls(remote, call)
            remoteDataEvent.Fire(remoteDataEvent, self, call)
        end

        if remoteBlocked or argsBlocked then
            return
        end
    end

    return nmcTrampoline(self,...)
end)

local pcall = pcall

local function checkPermission(self)
    if (self.ClassName) then end
end

for _name, hook in pairs(methodHooks) do
    local originalMethod
    originalMethod = hookFunction(hook, newCClosure(function(self,...)
        local args = {...}

        if typeof(self) ~= "Instance" then
            return originalMethod(self,...)
        end
                
        do
            local success = pcall(checkPermission, self)
            if not success then return originalMethod(self,...) end
        end

        if self.ClassName == _name and remotesViewing[_name] and self ~= remoteDataEvent then
            local remote = currentRemotes[self]
            if not remote then
                remote = Remote.new(self)
                currentRemotes[self] = remote
            end

            local remoteIgnored = remote.Ignored 
            local argsIgnored = remote:AreArgsIgnored(args)
            
            if eventSet and (not remoteIgnored and not argsIgnored) then
                local call = {
                    script = getCallingScript((PROTOSMASHER_LOADED ~= nil and 2) or nil),
                    args = args,
                    func = getInfo(3).func
                }
                remote:IncrementCalls(call)
                remoteDataEvent:Fire(self, call)
            end

            if remote.Blocked or remote:AreArgsBlocked(args) then
                return
            end
        end
        
        return originalMethod(self,...)
    end))

    oh.Hooks[originalMethod] = hook
end

RemoteSpy.RemotesViewing = remotesViewing
RemoteSpy.CurrentRemotes = currentRemotes
RemoteSpy.ConnectEvent = connectEvent
RemoteSpy.RequiredMethods = requiredMethods

return RemoteSpy
