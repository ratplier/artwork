local RunService = game:GetService("RunService")

local Modding = require("../modding")
local lifecycles = {}

function lifecycles.createClientLifecycle(name: string, manager: (fire: () -> ()) -> ())
    if RunService:IsServer() then return end
    return lifecycles.createLifecycle(name, manager)
end

function lifecycles.createServerLifecycle(name: string, manager: (fire: () -> ()) -> ())
    if not RunService:IsServer() then return end
    return lifecycles.createLifecycle(name, manager)
end

function lifecycles.createLifecycle(name: string, manager: (fire: () -> ()) -> ())
    local listeners = {}

    local adddedConnection = Modding.onListenerAdded(function(listener) listeners[listener] = true end, name)
    local removedConnection = Modding.onListenerRemoved(function(listener) listeners[listener] = nil end, name)

    local function fire(...)
        for listener in listeners do
            task.spawn(listener[name], ...)
        end
    end

    manager(fire)

    return function()
        adddedConnection:Disconnect()
        removedConnection:Disconnect()
    end
end

return lifecycles