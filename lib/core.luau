--!strict
local Modding = require("./modding")
local Reflect = require("./reflect")

type object = { [any]: any }
type set<T> = { [T]: true }
type predicate<T> = (T) -> boolean

type onStart = object & { onStart: (self: onStart) -> () }
type onInit = object & { onInit: (self: onInit) -> () }
type onStop = object & { onStop: (self: onStop) -> () }

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

    ignited = false,
    shutdown = false,
}

local DEFAULT_PRIORITY = 1
local Core = {}

local function saferequire(module: ModuleScript): unknown
    local success, result = pcall(require, module)
    return success and result
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

function Core.register<T>(members: T & object, priority: number?): T
    local id = Reflect.getId(members)
    local _priority = if typeof(priority) == "number" then priority else DEFAULT_PRIORITY

    Reflect.defineMetadata(members, "singleton", true)
    Reflect.defineMetadata(members, "priority", _priority)

    internal.singletons[id] = members
    return members
end

function Core.listen(name: string, listener: (...any) -> ())
    return Modding.addLifecycleListener(name, listener)
end

function Core.ignited()
	return internal.ignited
end

function Core.shutdown()
	return internal.shutdown
end

function Core.ignite()
	if Core.ignited() or Core.shutdown() then return end

	local providerIds: { string } = {}
	local metadata: { [string]: { id: string, priority: number, provider: object } } = {}
	for _, provider in internal.singletons do
		local id = Reflect.getId(provider)
		local priority = Reflect.readMetadata(provider, "priority") :: number

		metadata[id] = { id = id, priority = priority, provider = provider }
		table.insert(providerIds, id)
	end

	local start = Modding.getListeners("onStart") :: { onStart }
	local init = Modding.getListeners("onInit") :: { onInit }
	local stop = Modding.getListeners("onStop") :: { onStop }

	local sortedProviders = topologicalSort(providerIds)

	local function sort(a, b)
		local a_priority = Reflect.readMetadata(a, "priority") :: number
		local b_priority = Reflect.readMetadata(b, "priority") :: number

		if a_priority ~= b_priority then
			return a_priority > b_priority
		end

		local a_id = Reflect.getId(a)
		local b_id = Reflect.getId(b)

		return sortedProviders[a_id] > sortedProviders[b_id]
	end

	table.sort(start, sort)
	table.sort(init, sort)
	table.sort(stop, sort)

	for _, listener in init do
		xpcall(listener.onInit, function(result)
			warn(`[artwork]: Error in onInit listener: {result}`)
		end, listener)
	end

	internal.ignited = true

	for _, listener in start do
		task.spawn(listener.onStart, listener)
	end

	return function()
		if Core.shutdown() then return end

		for _, listener in stop do
			task.spawn(listener.onStop, listener)
		end

		internal.shutdown = true
	end
end

Core.extend = extend :: extender
Core.version = '1.0'

return Core