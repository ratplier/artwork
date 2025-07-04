local RunService = game:GetService("RunService")

local Modding = require("./modding")
local lifecycles = {}

function lifecycles.createClientLifecycle(name: string, manager: (fire: () -> ()) -> (), passSelf: boolean?)
    if RunService:IsServer() then return end
    return lifecycles.createLifecycle(name, manager, passSelf)
end

function lifecycles.createServerLifecycle(name: string, manager: (fire: () -> ()) -> (), passSelf: boolean?)
    if not RunService:IsServer() then return end
    return lifecycles.createLifecycle(name, manager, passSelf)
end

function lifecycles.createLifecycle(name: string, manager: (fire: () -> ()) -> (), passSelf: boolean?)
    local listeners = {}

    local adddedConnection = Modding.onListenerAdded(function(listener) listeners[listener] = true end, name)
    local removedConnection = Modding.onListenerRemoved(function(listener) listeners[listener] = nil end, name)

    local function fire(...)
        for listener in listeners do
            if passSelf then
                task.spawn(listener[name], listener, ...)
                listener[name](listener, ...)
            else
                task.spawn(listener[name], ...)
            end
        end
    end

    manager(fire)

    return function()
        adddedConnection:Disconnect()
        removedConnection:Disconnect()
    end
end

return lifecycles