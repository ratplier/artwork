--!strict
export type Signal<T...=...any> = {
	bindable: BindableEvent,

	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> RBXScriptConnection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> RBXScriptConnection,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

local function connect<T...>(self: Signal<T...>, fn: (T...) -> ())
	return self.bindable.Event:Connect(function(args)
		fn(args())
	end)
end

local function once<T...>(self: Signal<T...>, fn: (T...) -> ())
	local connection: RBXScriptConnection
	connection = self.bindable.Event:Connect(function(args)
		if connection.Connected then connection:Disconnect() end
		fn(args())
	end)
	return connection
end

local function wait<T...>(self: Signal<T...>): T...
	return self.bindable.Event:Wait()()
end

local function fire<T...>(self: Signal<T...>, ...: any)
	local args = { ... }
	self.bindable:Fire(function()
		return table.unpack(args)
	end)
end

local function destroy(self: Signal)
	self.bindable:Destroy()
end

function Signal.new<T...>(): Signal<T...>
	return setmetatable({ bindable = Instance.new("BindableEvent") }, Signal) :: any
end

function Signal.wrap<T...>(event: Signal<T...>): Signal<T...>
	return setmetatable({ bindable = event.bindable }, Signal) :: any
end

Signal.Connect = connect
Signal.Once = once
Signal.Wait = wait
Signal.Fire = fire
Signal.Destroy = destroy

return { new = Signal.new, wrap = Signal.wrap }