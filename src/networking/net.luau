--!strict
local RunService = game:GetService("RunService")

local remotesLoaded = false
local packets = {}
local invokeListeners = {}
local constants = table.freeze({
	IS_CLIENT = RunService:IsClient(),
	IS_SERVER = RunService:IsServer(),
})

-- types
type callback<A...=(), R...=()> = (A...) -> (R...)
type queueItem<A...=...any> = {
	resolved: callback<(A...), (A...)>,
	rejected: callback<(string), (string)>,
}
type Promise<T...=()> = {
	after: (onResolve: callback<T...>?, onReject: callback<string>?) -> Promise<T...>,
	catch: (onReject: callback<string>?) -> Promise<T...>,
	finally: (callback<()>) -> Promise<T...>,
	await: () -> T...,
}

type Disconnect = () -> ()
type SandboxedSignal<A...> = {
	connect: (fn: callback<A...>) -> Disconnect,
	once: (fn: callback<A...>) -> Disconnect,
}
type Signal<A...> = {
	connect: (fn: callback<A...>) -> Disconnect,
	once: (fn: callback<A...>) -> Disconnect,
	fire: (A...) -> (),
	bind: (event: RBXScriptSignal) -> (),
	wrap: (listeners: { callback<A...> }) -> (),
	sandbox: () -> SandboxedSignal<A...>,
}

type kind = "event" | "function"
type validator<T=any> = (T) -> boolean
type metadata<A...> = {
	validators: { validator },
	returns:  { validator },
	middleware: { middleware<A...> },
	unreliable: boolean,
	kind: kind,
	id: any,
}

export type middleware<A...> = (A...) -> ()
export type packet<A..., R...> = {
	unreliable: () -> packet<A..., R...>,
	returns: ( R... ) -> packet<A..., R...>,
	middleware: (middleware: middleware<A...>) -> packet<A..., R...>,
	metadata: () -> metadata<A...>,
}

export type clientRemote<A...> = {
	connect: (fn: callback<A...>) -> Disconnect,
	once: (fn: callback<A...>) -> Disconnect,
	fire: callback<A...>,
}
export type serverRemote<A...> = {
	connect: (fn: callback<(Player, A...)>) -> Disconnect,
	once: (fn: callback<(Player, A...)>) -> Disconnect,
	fireClient: callback<(Player, A...)>,
	fireAllClients: callback<A...>,
}
export type clientAsyncRemote<A..., R...> = {
	invoke: callback<(A...), (Promise<R...>)>,
}
export type serverAsyncRemote<A..., R...> = {
	handle: callback< callback<(Player, A...), (R...)> >,
}

export type genericRemote<A..., R...> = clientRemote<A...> & serverRemote<A...> & clientAsyncRemote<A..., R...> & serverAsyncRemote<A..., R...>

-- util --

local function len(tbl: { any }): number
	local c=0
	for _,_ in tbl do
		c+=1
	end
	return c
end

local function deepCopy<T>(tbl: T): T
	local result = {}
	for key, value in tbl::any do
		if type(value) == "table" then
			value = deepCopy(value)
		end
		result[key] = value
	end
	return result::any
end

local function getremotes(): { reliable: RemoteEvent, unreliable: UnreliableRemoteEvent, callback: RemoteFunction }
	remotesLoaded = true
	local remotes = {
		reliable = script:FindFirstChildOfClass("RemoteEvent"),
		unreliable = script:FindFirstChildOfClass("UnreliableRemoteEvent"),
		callback = script:FindFirstChildOfClass("RemoteFunction"),
	}
	local names = {"reliable", "unreliable", "callback"}

	if RunService:IsClient() then
		repeat
			task.wait()
			remotes = {
				reliable = script:FindFirstChildOfClass("RemoteEvent"),
				unreliable = script:FindFirstChildOfClass("UnreliableRemoteEvent"),
				callback = script:FindFirstChildOfClass("RemoteFunction"),
			}
		until remotes.reliable and remotes.unreliable and remotes.callback
	else
		for i = 1, #names do
			local name = names[i]
			local remote = remotes[name]
			if remote then continue end

			local className = name == "reliable" and "RemoteEvent" or name == "unreliable" and "UnreliableRemoteEvent" or name == "callback" and "RemoteFunction" or nil
			if not className then continue end

			remote = Instance.new(className, script)
			remote.Name = name
			remotes[name] = remote
		end
	end

	return remotes
end

local function validate(validators: { validator }, ...: any): boolean
	local length = len(validators)
	if length <= 0 then
		return true
	end
	for i = 1, length do
		local validatorFunc = validators[i]
		local arg = select(i, ...)
		if type(validatorFunc) ~= "function" then
			return false
		end
		if not validatorFunc(arg) then
			return false
		end
	end
	return true
end

local function applyMiddleware<T...>(mw: { middleware<T...> }): (T...) -> any
	return function(...: any)
		local values = { ... }
		local count = #mw
		for i = 1, count do
			local runner = mw[i]
			values = { runner(table.unpack(values)) }
			if #values == 0 then
				return nil
			end
		end
		return table.unpack(values)
	end
end

local function pack(...)
	return { ... }
end

local validator = {} do
	type validator<T> = (unknown) -> T
	
	validator.typeof = function(type): any
		return function(val)
			return typeof(val) == type
		end
	end

	validator.string = validator.typeof("string") :: string
	validator.boolean = validator.typeof("boolean") :: boolean
	validator.number = validator.typeof("number") :: number
	validator.table = validator.typeof("table") :: {}

	validator.udim2 = validator.typeof("UDim2") :: UDim2
	validator.udim = validator.typeof("UDim") :: UDim

	validator.vector2 = validator.typeof("Vector2") :: Vector2
	validator.vector3 = validator.typeof("Vector3") :: Vector3

	validator.cframe = validator.typeof("CFrame") :: CFrame
	validator.color = validator.typeof("Color3") :: Color3

	validator.any = function(val) return true end :: any

	validator.optional = function<T>(optional: T): T?
		return function(val)
			return val == nil or (optional::any)(val)
		end :: any
	end

	validator.interface = function<T>(interface: T): T
		return function(val)
			if not (validator.table::any)(val) then return false end
			for k,v in val do
				if not (interface::any)[k](v) then return false end
			end
			return true
		end :: any
	end

	validator.array = function<V>(value: V): {V}
		return function(val)
			if not (validator.table::any)(val) then return false end
			for k,v in val do
				if not (validator.number::any)(k) then return false end
				if not (value::any)(v) then return false end
			end
			return true
		end :: any
	end

	validator.map = function<K, V>(key: K, value: V): { [K]: V }
		return function(val)
			if not (validator.table::any)(val) then return false end
			for k,v in val do
				if not (key::any)(k) then return false end
				if not (value::any)(v) then return false end
			end
			return true
		end :: any
	end
end

-- libraries --

local function compactSignal<A...>(): Signal<A...>
	local listeners: { callback<A...> } = {}

	local function connect(fn: callback<A...>): Disconnect
		table.insert(listeners, fn)
		return function()
			local index = table.find(listeners, fn)
			if index then
				table.remove(listeners, index)
			end
		end
	end

	local function once(fn: callback<A...>): Disconnect
		local disconnect: Disconnect
		disconnect = connect(function(...: A...)
			task.spawn(fn, ...)
			if disconnect then
				disconnect()
			end
		end)
		return disconnect
	end

	local function fire(...: A...)
		local clone = table.clone(listeners)
		for i = 1, #clone do
			local listener = clone[i]
			task.spawn(listener, ...)
		end
	end

	local function bind(event: RBXScriptSignal)
		event:Connect(function(...: any)
			fire(...)
		end)
	end

	local function wrap(listenerGroup: { callback<A...> }, replace: boolean)
		if replace then
			listeners = listenerGroup
			return
		end
		listeners = table.move(listenerGroup, 1, #listenerGroup, #listeners + 1, listeners)
	end

	local function sandbox(): SandboxedSignal<A...>
		return {
			connect = connect,
			once = once,
		}
	end

	return {
		connect = connect,
		once = once,
		fire = fire,
		bind = bind,
		wrap = wrap,
		sandbox = sandbox,
	} :: Signal<A...>
end

local function compactPromise<A...>(
	executor: callback< callback<A...>, callback<string> >
): Promise<A...>
	type state = "pending" | "resolved" | "rejected"
	
	local noop = function(...) return ... end
	
	local state = "pending"
	local result = {}
	local queue = {}

	local function process()
		if state == "pending" then
			return
		end
		local length = #queue
		for i = 1, length do
			local exe = queue[i]
			local callback = state == "resolved" and exe.resolved or exe.rejected
			
			pcall(callback, table.unpack(result))
		end
		queue = {}
	end

	local function resolve(...)
		if state ~= "pending" then
			return
		end
		state = "resolved"
		result = { ... }
		process()
	end

	local function reject(err: string)
		if state ~= "pending" then
			return
		end
		state = "rejected"
		result = { err }
		process()
	end

	local function andThen<Args...>(onResolve: callback<Args...>?, onReject: callback<string>?): Promise<Args...>
		local onResolve: callback<Args...> = if type(onResolve) == "function" then onResolve else noop
		local onReject: callback<string> = if type(onReject) == "function" then onReject else noop
		return compactPromise(function(nextResolve, nextReject)
			local nextItem: queueItem<Args...> = {
				resolved = function(...) onResolve(...) return ... end,
				rejected = function(err) onReject(err) return err end,
			}
			
			table.insert(queue, nextItem)
			
			if state ~= "pending" then
				process()
			end
		end)
	end
	
	local function after(onResolve: callback<A...>?, onReject: callback<string>?): Promise<A...>
		return andThen(onResolve, onReject)
	end
	
	local function catch(onReject): Promise<A...>
		return andThen(nil, onReject)
	end

	local function finally(onFinally: callback<...any>): Promise<A...>
		return andThen(onFinally, onFinally)
	end

	local function await(): A...
		local co = coroutine.running()
		andThen(function(...)
			coroutine.resume(co, ...)
		end).catch(function(...)
			coroutine.resume(co, nil, ...)
		end)
		return coroutine.yield()
	end

	task.spawn(xpcall, executor, reject, resolve, reject)

	return {
		after = after,
		catch = catch,
		finally = finally,
		await = await,
	} :: Promise<A...>
end

-- packet --

local function packet<A..., R...>(id: any, ...: A...): packet<A..., R...>
	assert(id, "Invalid packet ID")
	assert(packets[id] == nil, `Duplicate packet ID given: {id}`)
	packets[id] = true

	local metadata: metadata<A...> = {
		validators = pack(...),
		returns = {},
		middleware = {},
		unreliable = false,
		kind = "event",
		id = id,
	}

	local self = {}

	function self.unreliable()
		if metadata.kind == "event" then
			metadata.unreliable = true
		end
		return self
	end

	function self.returns(...: R...)
		metadata.unreliable = false
		metadata.kind = "function"
		metadata.returns = pack(...)
		return self
	end

	function self.middleware(...)
		local list = pack(...)
		for _,middleware in list do
			table.insert(metadata.middleware, middleware)
		end
		return self
	end

	function self.metadata()
		return table.freeze(deepCopy(metadata))
	end
	
	return self
end

local function namespace<T>(t: T): T
	return t
end

-- builder --

local remotes = getremotes()

if constants.IS_SERVER then
	remotes.callback.OnServerInvoke = function(plr, id, ...)
		local data = invokeListeners[id]
		if not data then return nil end

		local args = { data.middleware(...) }
		if not data.validate(...) then return nil end

		return data.listener(plr, table.unpack(args))
	end
end

local function clientRemote<A...>(packetBuilder: packet<A..., ()>): clientRemote<A...>
	assert(constants.IS_CLIENT, "Cannot build client remote from server")
	local signal = compactSignal()
	local data = packetBuilder.metadata()
	local validators = data.validators
	local appliedMiddleware = applyMiddleware(data.middleware)

	local event = (data.unreliable and remotes.unreliable or remotes.reliable) :: RemoteEvent
	signal.bind(event.OnClientEvent)

	local function connect(fn: callback<A...>): Disconnect
		return signal.connect(function(id: any, ...: A...)
			if id ~= data.id then
				return
			end
			if not validate(validators, ...) then
				return
			end
			local mwResult = { appliedMiddleware(...) }
			if #mwResult == 0 then
				return
			end
			fn(table.unpack(mwResult))
		end)
	end

	local function once(fn: callback<A...>): Disconnect
		return signal.once(function(id: any, ...: A...)
			if id ~= data.id then
				return
			end
			if not validate(validators, ...) then
				return
			end
			local mwResult = { appliedMiddleware(...) }
			if #mwResult == 0 then
				return
			end
			fn(table.unpack(mwResult))
		end)
	end

	local function fire(...: A...)
		event:FireServer(data.id, ...)
	end

	return {
		connect = connect,
		once = once,
		fire = fire,
	}
end

local function serverRemote<A...>(packetBuilder: packet<A..., ()>): serverRemote<A...>
	assert(constants.IS_SERVER, "Cannot build server remote from client")
	local signal = compactSignal()
	local data = packetBuilder.metadata()
	local validators = data.validators
	local appliedMiddleware = applyMiddleware(data.middleware)

	local event = (data.unreliable and remotes.unreliable or remotes.reliable) :: RemoteEvent
	signal.bind(event.OnServerEvent)

	local function connect(fn: callback<(Player, A...)>): Disconnect
		return signal.connect(function(plr: Player, id: any, ...: A...)
			if id ~= data.id then
				return
			end
			if not validate(validators, ...) then
				return
			end
			
			local mwResult = { appliedMiddleware(...) }
			if select("#", ...) ~= 0 and #mwResult == 0 then
				return
			end
			fn(plr, table.unpack(mwResult))
		end)
	end
	
	local function once(fn: callback<(Player, A...)>): Disconnect
		return signal.once(function(plr: Player, id: any, ...: A...)
			if id ~= data.id then
				return
			end
			if not validate(validators, ...) then
				return
			end
			local mwResult = { appliedMiddleware(...) }
			if #mwResult == 0 then
				return
			end
			fn(plr, table.unpack(mwResult))
		end)
	end

	local function fireClient(player: Player, ...: A...)
		event:FireClient(player, data.id, ...)
	end

	local function fireAllClients(...: A...)
		event:FireAllClients(data.id, ...)
	end

	return {
		connect = connect,
		once = once,
		fireClient = fireClient,
		fireAllClients = fireAllClients,
	}
end

local function clientAsync<A..., R...>(packetBuilder: packet<A..., R...>): clientAsyncRemote<A..., R...>
	assert(constants.IS_CLIENT, "Cannot build client remote from server")
	local data = packetBuilder.metadata()
	local returns = data.returns
	local event = remotes.callback
	
	local function invoke(...: A...): Promise<R...>
		local args = pack(...)
		return compactPromise(function(resolve, reject)
			local data = { event:InvokeServer(data.id, table.unpack(args)) }
			if not validate(returns, table.unpack(data)) then return end
			resolve(table.unpack(data))
		end)
	end
	
	return {
		invoke = invoke,
	}
end

local function serverAsync<A..., R...>(packetBuilder: packet<A..., R...>): serverAsyncRemote<A..., R...>
	assert(constants.IS_SERVER, "Cannot build server remote from client")
	local data = packetBuilder.metadata()
	local validators = data.validators
	local appliedMiddleware = applyMiddleware(data.middleware)

	local event = remotes.callback

	local function handle(listener: callback<(Player, A...), (R...)>): ()
		invokeListeners[data.id] = {
			middleware = appliedMiddleware,
			validate = function(...) return validate(validators, ...) end,
			listener = listener,
		}
		
		return function()
			invokeListeners[data.id] = nil
		end
	end

	return {
		handle = handle,
	}
end

local function buildRemote<A..., R...>(packetBuilder: packet<A...> & packet<A..., R...>): genericRemote<A..., R...>
	local data = packetBuilder.metadata()
	local remote: any
	
	if data.kind == "event" and constants.IS_CLIENT then
		remote = clientRemote(packetBuilder)
	elseif data.kind == "event" and constants.IS_SERVER then
		remote = serverRemote(packetBuilder)
	elseif data.kind == "function" and constants.IS_CLIENT then
		remote = clientAsync(packetBuilder)
	elseif data.kind == "function" and constants.IS_SERVER then
		remote = serverAsync(packetBuilder)
	end
	
	return remote
end

-- middleware presets

local function ratelimit(rate: number, time: number)
	local queue = {}
	local index = 0
	return function(...)
		if index >= rate then return nil end
		index += 1
		queue[index] = true
		task.delay(time, function()
			queue[index] = nil
			index -= 1
		end)
		return ...
	end
end

return {
	client = clientRemote,
	clientAsync = clientAsync,

	server = serverRemote,
	serverAsync = serverAsync,

	build = buildRemote,
	packet = packet,
	namespace = namespace,

	-- middleware
	ratelimit = ratelimit,

	-- validators
	number = validator.number,
	string = validator.string,
	table = validator.table,
	boolean = validator.boolean,
	color = validator.color,
	udim = validator.udim,
	udim2 = validator.udim2,
	vector2 = validator.vector2,
	vector3 = validator.vector3,
	cframe = validator.cframe,
	any = validator.any,

	-- custom
	interface = validator.interface,
	map = validator.map,
	array = validator.array,
	optional = validator.optional,
}
