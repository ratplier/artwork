# Preloading & Ignition

To start the framework, you should load the required modules by calling the `loadDescendants` method. The `loadDescendants` method is a generic module loader that can be used to load modules from a given parent instance. The method accepts a parent of type `Instance` and an optional `predicate` function, which can be used to filter the descendants that should be loaded. If a `predicate` is provided, only the descendants for which the predicate returns `true` will be loaded.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
artwork.loadDescendants(ReplicatedStorage.Shared)

-- loading with custom predicate
artwork.loadDescendants(ReplicatedStorage.Shared, function(instance)
    return instance:HasTag("ignore") == false
end)

-- custom loadChildren implementation
-- this method is already built-in so this is a example
local function loadChildren(parent, predicate)
    return artwork.loadDescendants(parent, function(descendant)
        local isChild = descendant.Parent == parent
        return isChild and (not predicate or predicate(descendant))
    end)
end

loadChildren(ReplicatedStorage.Modules)
```

### Ignition!
After loading the providers you can then ignite the framework! Igniting the framework will initialize all registered providers in the order of their priority. The priority of a provider is used to determine the order in which the providers are registered.

!!! warning
    Loading providers will **NOT** register the module. The [loadDescendants](/artwork/refrence/core/#loaddescendants)/[loadChildren](/artwork/refrence/core/#loadchildren) methods dont have any special features other than loading modules. In order to register a provider, you must use the [`artwork.register`](/artwork/refrence/core/#register) method.

If you want to check if the framework is currently ignited, you can use the [`artwork.ignited`](/artwork/refrence/core/#ignited) method, which returns a boolean indicating whether the framework is currently ignited or not.

```lua
artwork.ignite()
```

