--!strict
local Signal = require("./signal")

type object = {}
type set<T> = { [T]: true }
type listener = {
    eventIds: set<string>,
    involvement: { set<object> },
}

type signal<T...> = Signal.Signal<T...>
type ListenerAddedEvent = signal<object>
type ListenerRemovedEvent = signal<object>

local internal = {
    listeners = {} :: { [object]: listener } ,
    lifecycleListeners = {} :: { [string]: set<object> },

    singletons = {} :: { [string]: object },

    listenerAdded = Signal.new() :: ListenerAddedEvent,
    listenerRemoved = Signal.new() :: ListenerRemovedEvent,
    listenerAddedEvents = {} :: { [string]: ListenerAddedEvent },
    listenerRemovedEvents = {} :: { [string]: ListenerRemovedEvent },
}

local Modding = {}

function Modding.addListener(object: object)
	if typeof(object) ~= "table" then return end

    local listener: listener = {
        eventIds = {},
        involvement = {},
    }

    for lifecycleEvent, callback in object do
		if typeof(lifecycleEvent) ~= "string" then continue end
		if typeof(callback) ~= "function" then continue end
		if listener.eventIds[lifecycleEvent] then continue end

		local lifecycleListener = internal.lifecycleListeners[lifecycleEvent]
		if not lifecycleListener then 
			lifecycleListener = {}
			internal.lifecycleListeners[lifecycleEvent] = lifecycleListener
		end

        lifecycleListener[object] = true
        listener.eventIds[lifecycleEvent] = true
        table.insert(listener.involvement, lifecycleListener)
		
		local eventSignal = internal.listenerAddedEvents[lifecycleEvent]
		if eventSignal then
			eventSignal:Fire(object)
		end
    end

	internal.listeners[object] = listener
	internal.listenerAdded:Fire(object)
end

function Modding.removeListener(object: object)
    local listener = internal.listeners[object]
    if not listener then return end

    for _, set in listener.involvement do
        set[object] = nil
    end

	for id in listener.eventIds do
		local eventSignal = internal.listenerRemovedEvents[id]
		if not eventSignal then continue end
		eventSignal:Fire(object)
    end

	internal.listeners[object] = nil
	internal.listenerRemoved:Fire(object)
end

function Modding.addLifecycleListener(name: string, callback: (...any) -> ())
    local object = {
        [name] = callback,
    }

    Modding.addListener(object)
    return function()
        Modding.removeListener(object)
    end
end

function Modding.onListenerAdded(callback: (object: object) -> (), id: string?)
	if id ~= nil then
        local existingListeners = internal.lifecycleListeners[id]
		if existingListeners then
            for existingListener in existingListeners do
                task.spawn(callback, existingListener)
            end
        end

        local event = internal.listenerAddedEvents[id]
        if not event then
            event = Signal.new()
            internal.listenerAddedEvents[id] = event
        end

        return event:Connect(callback)
    else
        for object in internal.listeners do
            task.spawn(callback, object)
        end

        return internal.listenerAdded:Connect(callback)
    end
end

function Modding.onListenerRemoved(callback: (object: object) -> (), id: string?)
    if id ~= nil then
        local event = internal.listenerRemovedEvents[id]
        if not event then
            event = Signal.new()
            internal.listenerRemovedEvents[id] = event
        end

        return event:Connect(callback)
	else
        return internal.listenerRemoved:Connect(callback)
    end
end

return Modding
