## Methods

### addListener
Registers an object as a listener. The API scans the object for string keys with function values and subscribes them to the corresponding lifecycle events.

```lua
function Modding.addListener(object: object, ignoreList: { string }?)
```

**Parameters**

- `object` (`table`): The listener object to register.
- `ignoreList` (`{string}?`): An optional array of string keys to ignore. Callbacks with these names will not be registered.

```lua
local MyListener = {
    onStart = function()
        print("MyListener has started!")
    end,

    onStop = function()
        print("MyListener is shutting down.")
    end
}

-- Register the entire object as a listener
Modding.addListener(MyListener)
```

### removeListener
Removes and cleans up all event subscriptions for a given listener object. This is crucial for preventing memory leaks when a listener is disabled or unloaded.

```lua
function Modding.removeListener(object: object)
```

**Parameters**

- `object` (`table`): The listener object to unregister.

```lua
-- Assuming MyListener was added previously
Modding.removeListener(MyListener)
```

### addLifecycleListener
A convenience function for adding a single event listener without creating a full object. It returns a `cleanup` function that can be called to remove the listener.

```lua
function Modding.addLifecycleListener(name: string, callback: (...any) -> ()) -> (() -> ())
```

**Parameters**

- `name` (`string`): The ID of the event to listen for.
- `callback` (`function`): The function to execute when the event fires.

**Returns**

- (`function`): A function that, when called, will remove the listener.

```lua
local function onPlayerChat(player, message)
    print(player.Name .. ": " .. message)
end

-- Add the listener and store the disconnect function
local disconnectChatListener = Modding.addLifecycleListener("onPlayerChat", onPlayerChat)

-- Sometime later, to stop listening...
disconnectChatListener()
```

### getListeners
Gets all the listeners under a specific id. The resulting array is not ordered.

```lua
function Modding.getListeners(id: string) -> { object }
```

**Parameters**

- `id` (`string`): The specific event ID to watch for.

**Returns**

- (`{ object }`): An array of listener objects that implement the given event ID.

```lua
local listeners = Modding.getListeners("onPlayerChat")
```

### onListenerAdded
Connects a callback that fires whenever a listener is added via [`Modding.addListener`](#addlistener).

The function can operate in two modes:
1. **Global:** If `id` is `nil`, the callback fires for *any* listener added.
2. **Specific:** If an `id` is provided, the callback fires only when a listener subscribing to that specific event ID is added.

In both modes, the callback will be immediately fired for all *already existing* listeners that match the criteria.

```lua
function Modding.onListenerAdded(callback: (object: object) -> (), id: string?) -> RBXScriptConnection
```

**Parameters**

- `callback` (`function`): A function that receives the listener object that was added.
- `id` (`string?`): Optional. The specific event ID to watch for.

**Returns**

- (`RBXScriptConnection`): A connection object that can be disconnected to stop listening.

```lua
-- Listen for any listener that implements "OnUpdate"
local connection = Modding.onListenerAdded(function(listenerObject)
    print("A new listener for OnUpdate was just added!")
    -- Maybe do something with listenerObject here
end, "OnUpdate")

-- Listen for any new listener, regardless of its events
Modding.onListenerAdded(function(listenerObject)
    print("A new listener was added to the system.")
end)

-- Stop listening after a while...
connection:Disconnect()
```

### onListenerRemoved
Connects a callback that fires whenever a listener is removed via [`Modding.removeListener`](#removelistener).

```lua
function Modding.onListenerRemoved(callback: (object: object) -> (), id: string?) -> RBXScriptConnection
```

**Parameters**

- `callback` (`function`): A function that receives the listener object that was added.
- `id` (`string?`): Optional. The specific event ID to watch for.

**Returns**

- (`RBXScriptConnection`): A connection object that can be disconnected to stop listening.

```lua
-- Listen for when any listener with an "OnUpdate" event is removed
local connection = Modding.onListenerRemoved(function(listenerObject)
    print("A listener for OnUpdate was removed.")
end, "OnUpdate")

-- Stop listening after a while...
connection:Disconnect()
```