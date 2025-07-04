--!strict
local RunService = game:GetService("RunService")

local IS_CLIENT = RunService:IsClient()
local IS_SERVER = RunService:IsServer()

local packets = {}
local invokeListeners = {}

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
	wrap: (listeners: { callback<A...> }, replace: boolean?) -> (),
	sandbox: () -> SandboxedSignal<A...>,
}

type middlewareChain<T...> = {
    add: (fn: middleware<T...>) -> (),
    execute: (T...) -> ...any
}

type kind = "event" | "function"
type validator<T=any> = (T) -> boolean
type metadata<A...> = {
	validators: { validator },
	returns:  { validator },
	middleware: middlewareChain<A...>,
	unreliable: boolean,
	kind: kind,
	id: any,
}

export type middleware<T...> = (next: (T...) -> T..., T...) -> T...
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
	handle: callback< callback<(Player, A...), (R...)>, Disconnect >,
}

export type remoteEvent<A...> = clientRemote<A...> & serverRemote<A...>
export type remoteFunction<A..., R...> = clientAsyncRemote<A..., R...> & serverAsyncRemote<A..., R...>
export type genericRemote<A..., R...> = remoteEvent<A...> & remoteFunction<(A...), (R...)>

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
	local remotes = {
		reliable = script:FindFirstChildOfClass("RemoteEvent"),
		unreliable = script:FindFirstChildOfClass("UnreliableRemoteEvent"),
		callback = script:FindFirstChildOfClass("RemoteFunction"),
	}

	if IS_CLIENT then
		while not remotes.reliable or not remotes.unreliable or not remotes.callback do
			remotes.reliable = script:FindFirstChildOfClass("RemoteEvent")
			remotes.unreliable = script:FindFirstChildOfClass("UnreliableRemoteEvent")
			remotes.callback = script:FindFirstChildOfClass("RemoteFunction")
			task.wait()
		end
	else
		local names = {"reliable", "unreliable", "callback"}
		for _, name in names do
			if not remotes[name] then
				local className = name == "reliable" and "RemoteEvent" or name == "unreliable" and "UnreliableRemoteEvent" or "RemoteFunction"
				local remote = Instance.new(className)
				remote.Name = name
				remote.Parent = script
				remotes[name] = remote
			end
		end
	end

	return remotes
end

local function validate(validators: { validator }, ...: any): boolean
	for i, validatorFunc in validators do
		local arg = select(i, ...)
		if type(validatorFunc) ~= "function" or not validatorFunc(arg) then
			return false
		end
	end
	return true
end

local function middleware<T...>(): middlewareChain<T...>
    local middlewareStack = {}

    local function add(fn: middleware<T...>)
        table.insert(middlewareStack, fn)
    end

    local function execute(...)
        local index = 0

        local function next(...)
            index += 1
            if middlewareStack[index] then
                return middlewareStack[index](next, ...)
            else
                return ...
            end
        end

        return next(...)
    end

    return {
        add = add,
        execute = execute
    }
end

local function pack(...)
	return { n = select("#", ...), ... }
end

local function unpack(t)
	return table.unpack(t, 1, #t)
end

local validator = {} do
	validator.typeof = function(t: string)
		return function(v: any): boolean
			return typeof(v) == t
		end
	end
	validator.string = validator.typeof("string")
	validator.boolean = validator.typeof("boolean")
	validator.number = validator.typeof("number")
	validator.table = validator.typeof("table")
	validator.udim2 = validator.typeof("UDim2")
	validator.udim = validator.typeof("UDim")
	validator.vector2 = validator.typeof("Vector2")
	validator.vector3 = validator.typeof("Vector3")
	validator.cframe = validator.typeof("CFrame")
	validator.color = validator.typeof("Color3")
	validator.any = function() return true end

	validator.optional = function(valType: validator)
		return function(v: any): boolean
			return v == nil or valType(v)
		end
	end
	validator.interface = function(interface: { [string]: validator })
		return function(v: any): boolean
			if not validator.table(v) then return false end
			for key, valValidator in pairs(interface) do
				if not v[key] or not valValidator(v[key]) then return false end
			end
			return true
		end
	end
	validator.array = function(valType: validator)
		return function(v: any): boolean
			if not validator.table(v) then return false end
			for _, item in ipairs(v) do
				if not valType(item) then return false end
			end
			return true
		end
	end
	validator.map = function(keyType: validator, valType: validator)
		return function(v: any): boolean
			if not validator.table(v) then return false end
			for key, value in pairs(v) do
				if not keyType(key) or not valType(value) then return false end
			end
			return true
		end
	end
end

local function compactSignal<A...>(): Signal<A...>
	local listeners: { callback<A...> } = {}

	local function connect(fn: callback<A...>): Disconnect
		table.insert(listeners, fn)
		return function()
			local index = table.find(listeners, fn)
			if index then table.remove(listeners, index) end
		end
	end

	local function once(fn: callback<A...>): Disconnect
		local disconnect: Disconnect
		disconnect = connect(function(...: A...)
			task.spawn(fn, ...)
			if disconnect then disconnect() end
		end)
		return disconnect
	end

	local function fire(...: A...)
		for _, listener in ipairs(table.clone(listeners)) do
			task.spawn(listener, ...)
		end
	end

	local function bind(event: RBXScriptSignal)
		event:Connect(fire)
	end

	local function wrap(listenerGroup: { callback<A...> }, replace: boolean?)
		if replace then
			listeners = listenerGroup
		else
			table.move(listenerGroup, 1, #listenerGroup, #listeners + 1, listeners)
		end
	end

	local function sandbox(): SandboxedSignal<A...>
		return { connect = connect, once = once }
	end

	return {
        connect = connect,
        once = once,
        fire = fire,
        bind = bind,
        wrap = wrap,
        sandbox = sandbox
    }
end

local function compactPromise<A...>(executor: callback< callback<A...>, callback<string> >): Promise<A...>
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
			
			pcall(callback, unpack(result))
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

	local function andThen<A...>(onResolve: callback<A...>?, onReject: callback<string>?): Promise<A...>
		local resolve: callback<A...> = if type(onResolve) == "function" then onResolve else noop
		local reject: callback<string> = if type(onReject) == "function" then onReject else noop
		return compactPromise(function(nextResolve, nextReject)
			local nextItem: queueItem<A...> = {
				resolved = function(...)
                    resolve(...)
                    nextResolve(...)
                    return ...
                end,
				rejected = function(err)
                    reject(err)
                    nextReject(err)
                    return err
                end,
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
			coroutine.resume(co, true, ...)
		end).catch(function(message)
			coroutine.resume(co, false, message)
		end)
		return coroutine.yield()
	end

	task.spawn(xpcall, executor, reject, resolve, reject)

	return {
		after = after,
		catch = catch,
		finally = finally,
		await = await,
	}
end

local function packet<A..., R...>(id: any, ...: A...): packet<A..., R...>
	assert(id, "Invalid packet ID")
	assert(not packets[id], `Duplicate packet ID given: {id}`)
	packets[id] = true

	local metadata: metadata<A...> = {
		validators = pack(...),
        middleware = middleware(),
		returns = {},
		unreliable = false,
		kind = "event",
		id = id,
	}

	local self = {}

	function self.unreliable()
		if metadata.kind == "event" then metadata.unreliable = true end
		return self
	end

	function self.returns(...: R...)
		metadata.unreliable = false
		metadata.kind = "function"
		metadata.returns = pack(...)
		return self
	end

	function self.middleware(...)
        for _, fn in {...} do
            metadata.middleware.add(fn)
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

local remotes = getremotes()

if IS_SERVER then
	remotes.callback.OnServerInvoke = function(player, id, ...)
		local data = invokeListeners[id]
		if not data then return end
		if not data.validate(...) then return end

		local results = {data.middleware.execute(player, ...)}
		return data.listener(unpack(results))
	end
end

local function clientRemote<A...>(packetBuilder: packet<A..., ()>): clientRemote<A...>
	assert(IS_CLIENT, "Cannot build client remote from server")
	local signal = compactSignal()
	local data = packetBuilder.metadata()
	local event = (data.unreliable and remotes.unreliable or remotes.reliable) :: RemoteEvent
	
	signal.bind(event.OnClientEvent)

	local function handleConnection(fn, id, ...)
		if id ~= data.id then return end
		if not validate(data.validators, ...) then return end
		fn( data.middleware.execute(...) )
	end

	local function connect(fn: callback<A...>): Disconnect
		return signal.connect(function(...) handleConnection(fn, ...) end)
	end

	local function once(fn: callback<A...>): Disconnect
		local disconnect: Disconnect
		disconnect = signal.connect(function(...)
			if disconnect then disconnect() end
			handleConnection(fn, ...)
		end)
		return disconnect
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
	assert(IS_SERVER, "Cannot build server remote from client")
	local signal = compactSignal()
	local data = packetBuilder.metadata()
	local event = (data.unreliable and remotes.unreliable or remotes.reliable) :: RemoteEvent
	
	signal.bind(event.OnServerEvent)

	local function handleConnection(fn, player, id, ...: any)
		if id ~= data.id then return end
		if not validate(data.validators, ...) then return end
		fn( player, data.middleware.execute(...) )
	end

	local function connect(fn: callback<(Player, A...)>): Disconnect
		return signal.connect(function(...) handleConnection(fn, ...) end)
	end
	
	local function once(fn: callback<(Player, A...)>): Disconnect
		local disconnect: Disconnect
		disconnect = signal.connect(function(...)
			handleConnection(fn, ...)
			if disconnect then disconnect() end
		end)
		return disconnect
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
	assert(IS_CLIENT, "Cannot build client remote from server")
	local data = packetBuilder.metadata()
	local event = remotes.callback
	
	local function invoke(...: A...): Promise<R...>
        local args = pack(...)
        return compactPromise(function(resolve, reject)
            local result = { event:InvokeServer(data.id, unpack(args)) }
            if not validate(data.returns, unpack(result)) then return end
            resolve(unpack(result))
        end)
    end

	return {
		invoke = invoke,
	}
end

local function serverAsync<A..., R...>(packetBuilder: packet<A..., R...>): serverAsyncRemote<A..., R...>
	assert(IS_SERVER, "Cannot build server remote from client")
	local data = packetBuilder.metadata()
    local function handle(listener: callback<(Player, A...), (R...)>): Disconnect
        invokeListeners[data.id] = {
            middleware = data.middleware,
            validate = function(...) return validate(data.validators, ...) end,
            listener = listener,
        }
        return function() invokeListeners[data.id] = nil end
    end
    
    return {
        handle = handle,
    }
end

local function buildRemoteEvent<A...>(packetBuilder: packet<A...>): remoteEvent<A...>
	local data = packetBuilder.metadata()
	local remote: any
	
	if data.kind == "event" and IS_CLIENT then
		remote = clientRemote(packetBuilder)
	elseif data.kind == "event" and IS_SERVER then
		remote = serverRemote(packetBuilder)
	end
	
	return remote
end

local function buildRemoteFunction<A..., R...>(packetBuilder: packet<A..., R...>): remoteFunction<A..., R...>
	local data = packetBuilder.metadata()
	local remote: any

	if data.kind == "function" and IS_CLIENT then
		remote = clientAsync(packetBuilder)
	elseif data.kind == "function" and IS_SERVER then
		remote = serverAsync(packetBuilder)
	end

	return remote
end

local function buildRemote<A..., R...>(packetBuilder: packet<A...> & packet<A..., R...>): genericRemote<A..., R...>
	local data = packetBuilder.metadata()
	local remote: any

    if data.kind == "event" then
        remote = buildRemoteEvent(packetBuilder)
    elseif data.kind == "function" then
        remote = buildRemoteFunction(packetBuilder)
    end
	
	return remote
end

local function ratelimit(rate: number, timePeriod: number)
    local count = 0
	return function(next, player: Player, ...)
        if count >= rate then return end
        count += 1
        task.delay(timePeriod, function()
            count -= 1
        end)
        return next(player, ...)
	end
end

return {
	client = clientRemote,
	clientAsync = clientAsync,

	server = serverRemote,
	serverAsync = serverAsync,

	build = buildRemote,
    buildEvent = buildRemoteEvent,
    buildFunction = buildRemoteFunction,
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
