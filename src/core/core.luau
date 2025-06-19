--!strict
local RunService = game:GetService("RunService")

local Modding = require("./modding")
local Reflect = require("./reflect")

type object = { [any]: any }
type set<T> = { [T]: true }
type predicate<T> = (T) -> boolean

type onStart = object & { onStart: (self: object) -> () }
type onInit = object & { onInit: (self: object) -> () }
type onStop = object & { onStop: (self: object) -> () }
type onRender = object & { onRender: (self: object, dt: number) -> () }
type onTick = object & { onTick: (self: object, dt: number) -> () }
type onPhysics = object & { onPhysics: (self: object, dt: number) -> () }

type extender =
    & (<A>(A) -> A)
    & (<A, B>(A, B) -> A & B)
    & (<A, B, C>(A, B, C) -> A & B & C)
    & (<A, B, C, D>(A, B, C, D) -> A & B & C & D)
    & (<A, B, C, D, E>(A, B, C, D, E) -> A & B & C & D & E)
    & (<A, B, C, D, E, F>(A, B, C, D, E, F) -> A & B & C & D & E & F)
    & (<A, B, C, D, E, F, G>(A, B, C, D, E, F, G) -> A & B & C & D & E & F & G)
    & (<A, B, C, D, E, F, G, H>(A, B, C, D, E, F, G, H) -> A & B & C & D & E & F & G & H)
    & (<A, B, C, D, E, F, G, H, I>(A, B, C, D, E, F, G, H, I) -> A & B & C & D & E & F & G & H & I)
    & (<A, B, C, D, E, F, G, H, I, J>(A, B, C, D, E, F, G, H, I, J) -> A & B & C & D & E & F & G & H & I & J)
    & (<A, B, C, D, E, F, G, H, I, J, K>(A, B, C, D, E, F, G, H, I, J, K) -> A & B & C & D & E & F & G & H & I & J & K)
    & (<A, B, C, D, E, F, G, H, I, J, K, L>(A, B, C, D, E, F, G, H, I, J, K, L) -> A & B & C & D & E & F & G & H & I & J & K & L)

local internal = {
    singletons = {} :: { [string]: object },
    components = {} :: { [string]: object },
    instances = {} :: { [Instance]: set<string> },

    ignited = false,
    shutdown = false,
}

local DEFAULT_PRIORITY = 1
local Core = {}

local function saferequire(module: ModuleScript): unknown
    local success, result = pcall(require, module)
    return success and result
end

local function map<T, R>(tbl: { T }, callback: (T) -> (R)): { R }
    local result = {}
    for _, value in tbl do
        table.insert(result, callback(value))
    end
    return result
end

local function extend(...)
	local result = {}
    for i = 1, select("#", ...) do
        local source = select(i, ...)
		for key, value in source do
			result[key] = value
		end
	end
	return result
end

local function topologicalSort(objects: { string }): { [string]: number }
    local currentSize = 0
    local sorted: { [string]: number } = {}
    local visited: { [string]: true } = {}

    local function visitor(node: string)
        visited[node] = true

        local object = internal.singletons[node]
        if not object then return end

        for _, dependency in object do
            if typeof(dependency) ~= "table" then continue end
            if Reflect.readMetadata(dependency, "singleton") == nil then continue end
            
            local name = Reflect.readMetadata(dependency, "name") :: string
            visitor(name)
        end

        currentSize += 1
        sorted[node] = currentSize
    end

    for _, node in objects do
		if visited[node] then continue end
        visitor(node)
    end

    return sorted
end

local function implements(object, id)
    return typeof(object[id]) == "function"
end

function Core.loadDescendants(parent: Instance, predicate: predicate<Instance>?)
    for _, descendant in parent:GetDescendants() do
        if predicate and not predicate(descendant) then continue end
		if not descendant:IsA("ModuleScript") then continue end

        saferequire(descendant)
	end
end

function Core.loadChildren(parent: Instance, predicate: predicate<Instance>?)
    Core.loadDescendants(parent, function(descendant: Instance)
        local isChild = descendant.Parent == parent
        return isChild and (not predicate or predicate(descendant))
    end)
end

function Core.provider<T>(members: T & object, priority: number?): T
    local id = Reflect.getId(members)
    local _priority = if typeof(priority) == "number" then priority else DEFAULT_PRIORITY

    Reflect.defineMetadata(members, "singleton", true)
    Reflect.defineMetadata(members, "priority", _priority)

    internal.singletons[id] = members
    return members
end

function Core.component<T>(members: T & object, tag: string?): T
    local id = Reflect.getId(members)

    Reflect.defineMetadata(members, "component", true)
    Reflect.defineMetadata(members, "tag", tag)

    internal.components[id] = table.clone(members)
    return members
end

function Core.listen(name: string, listener: (...any) -> ())
    Modding.addLifecycleListener(name, listener)
end

Core.onInit = function(listener: () -> ()) Core.listen("onInit", listener) end
Core.onStart = function(listener: () -> ()) Core.listen("onStart", listener) end
Core.onStop = function(listener: () -> ()) Core.listen("onStop", listener) end

Core.onRender = function(listener: (dt: number) -> ()) Core.listen("onRender", listener) end
Core.onTick = function(listener: (dt: number) -> ()) Core.listen("onTick", listener) end
Core.onPhysics = function(listener: (dt: number) -> ()) Core.listen("onPhysics", listener) end

function Core.ignited()
	return internal.ignited
end

function Core.shutdown()
	return internal.shutdown
end

function Core.ignite()
	if Core.ignited() or Core.shutdown() then return end

	local metadata: { { id: string, priority: number, provider: object } } = {}
	for _, provider in internal.singletons do
		local id = Reflect.getId(provider)
		local priority = Reflect.readMetadata(provider, "priority") :: number

		table.insert(metadata, {
            id = id,
			priority = priority,
			provider = provider,
		})
	end

	local providerIds = map(metadata, function(metadata)
		return metadata.id
	end)

	local sortedProviders = topologicalSort(providerIds)
	table.sort(metadata, function(a, b)
		if a.priority ~= b.priority then
			return a.priority < b.priority
		end

		local aIndex = sortedProviders[a.id]
		local bIndex = sortedProviders[b.id]
		return aIndex < bIndex
	end)

	local start: { onStart } = {}
	local init: { onInit } = {}
	local stop: { onStop } = {}

	local update: set<onTick> = {}
	local render: set<onRender> = {}
	local physics: set<onPhysics> = {}

	Modding.onListenerAdded(function(provider) update[provider::onTick] = true end, "onTick")
	Modding.onListenerAdded(function(provider) render[provider::onRender] = true end, "onRender")
	Modding.onListenerAdded(function(provider) physics[provider::onPhysics] = true end, "onPhysics")

	Modding.onListenerRemoved(function(provider) update[provider::onTick] = nil end, "onTick")
	Modding.onListenerRemoved(function(provider) render[provider::onRender] = nil end, "onRender")
	Modding.onListenerRemoved(function(provider) physics[provider::onPhysics] = nil end, "onPhysics")
	
	Modding.onListenerAdded(function(provider)
		local index = table.find(stop, provider::onStop)
		if index then return end
		table.insert(stop, provider::onStop)
	end, "onStop")
	Modding.onListenerRemoved(function(provider)
		local index = table.find(stop, provider::onStop)
		if not index then return end
		table.remove(stop, index)
	end, "onStop")

	for _, dependency in metadata do
		local provider = dependency.provider
		if implements(provider, "onInit") then table.insert(init, provider::onInit) end
		if implements(provider, "onStart") then table.insert(start, provider::onStart) end

		Modding.addListener(provider)
	end
	
	Modding.onListenerAdded(function(provider)
		if table.find(init, provider::onInit) then return end
		table.insert(init, provider::onInit)
	end, "onInit"):Disconnect()

	Modding.onListenerAdded(function(provider)
		if table.find(start, provider::onStart) then return end
		table.insert(start, provider::onStart)
	end, "onStart"):Disconnect()

	for _, object in init do
		object:onInit()
	end
	
	local onTickConnection = RunService.Heartbeat:Connect(function(...)
		for object in update do
			task.spawn(object.onTick, object, ...)
		end
	end)

	local onPhysicsConnection = RunService.PreSimulation:Connect(function(...)
		for object in physics do
			task.spawn(object.onPhysics, object, ...)
		end
	end)

	local onRenderConnection
	if RunService:IsClient() then
		onRenderConnection = RunService.RenderStepped:Connect(function(...)
			for object in render do
				task.spawn(object.onRender, object, ...)
			end
		end)
	end

	internal.ignited = true

	for _, object in start do
		task.spawn(object.onStart, object)
	end

	Modding.addLifecycleListener("onStop", function()
		onTickConnection:Disconnect()
		onPhysicsConnection:Disconnect()
		if onRenderConnection then onRenderConnection:Disconnect() end
	end)

	return function()
		if Core.shutdown() then return end

		for i=#stop, 1, -1 do
			local object = stop[i]
			table.remove(stop, i)
			
			task.spawn(object.onStop, object)
		end

		internal.shutdown = true
	end
end

Core.extend = extend :: extender
Core.version = '1.0'

return Core