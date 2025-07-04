## Methods

### Reflect.defineMetadata
Defines or updates a piece of metadata for an object. This is the primary function for writing metadata. If the object has not been seen by the API before, it will be registered automatically.

```lua
function Reflect.defineMetadata(object: object, key: string, value: unknown)
```

**Parameters**

- `object` (`table`): The target object to associate metadata with.
- `key` (`string`): The key for the piece of metadata.
- `value` (`any`): The value of the metadata to store.

```lua
local player = { name = "Alice", health = 100 }

-- Associate some metadata with the 'player' object
Reflect.defineMetadata(player, "LastLogin", os.time())
Reflect.defineMetadata(player, "IsAdmin", false)

-- Note: The 'player' table itself remains unchanged.
-- player.IsAdmin is still nil
```

### Reflect.readMetadata
Reads a piece of metadata from an object for a given key.

```lua
function Reflect.readMetadata(object: object, key: string): unknown
```

**Parameters**

- `object` (`table`): The target object.
- `key` (`string`): The key of the metadata to retrieve.

**Returns**

- (`any`): The value of the metadata, or `nil` if the key or object does not have metadata defined.

```lua
local isAdmin = Reflect.readMetadata(player, "IsAdmin")
print("Is Admin:", isAdmin)
-- > Is Admin: false
```

### Reflect.getMetadata
Retrieves the entire metadata table for a given object. This is useful if you need to read multiple metadata keys at once. If the object has no metadata, it will be registered automatically.

```lua
function Reflect.getMetadata(object: object): metadata
```

**Parameters**

- `object` (`table`): The target object.

**Returns**

- (`table`): The complete metadata table for the object. Changes to this table will be persisted.

```lua
-- Get the whole metadata container
local allMeta = Reflect.getMetadata(player)

-- You can read from it...
print("Is Admin:", allMeta.IsAdmin) -- > false

-- ...or write to it directly
allMeta.NewValue = "hello"
print(Reflect.readMetadata(player, "NewValue")) -- > hello
```

### Reflect.register
Explicitly registers an object with the Reflect API, preparing it for metadata storage.

> [Note] In normal usage, you do not need to call this function. `defineMetadata` and `getMetadata` will call it automatically. It's provided for edge cases where you might want to pre-register a batch of objects.

```lua
function Reflect.register(object: object)
```

**Parameters**

- `object` (`table`): The object to register.

```lua
local someObject = {}
Reflect.register(someObject)
-- someObject is now known to the Reflect API
```

### Reflect.getId
Gets the unique internal ID string generated for an object. This is mainly useful for debugging.

```lua
function Reflect.getId(object: object): string
```

**Parameters**

- `object` (`table`): The target object.

**Returns**

- (`string`): The unique ID used by the API to track the object (e.g., `reflect:12345678`).

```lua
local myObject = {}
local id = Reflect.getId(myObject)
print(id) -- e.g., "reflect:59103819"
```