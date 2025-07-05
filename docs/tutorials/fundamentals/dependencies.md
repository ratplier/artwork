To add dependencies to a provider, you can assign other registered providers to specific keys within your provider table. The key names are arbitrary, but using descriptive names is recommended.

To set up a dependency, first require the module where the dependency is defined, and then assign it to a key in your provider table. Ensure the dependency is registered before registering your provider to allow proper injection.

When done correctly, providers with fewer dependencies will load before those with many, ensuring an efficient loading order.

### Example
```lua
local Dependency = {}

function Depdendency.hello()
    print("Hello world!")
end

return artwork.register(Dependency)
-- IMPORTANT: make sure to register your dependencies else
-- the dependency injection will not work
```
```lua
-- Provider.luau
local Dependency = require("Dependency")
local Provider = {
    myDependency = Dependency,
}

Provider.myDependency.hello()

return artwork.register(Provider)
-- only when Dependency is registered, the dependency
-- will be injected
```
