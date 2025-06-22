# Providers
Providers are objects that are registered with the framework. They work like every other `ModuleScript` in your code, but they can listen to lifecycles

You can define a provider like you would define a module
```luau
local provider = {}
provider.a = 1

function provider.hello()
    print("Hello World!")
end
```

To register a provider, you can use the `artwork.register` function:
register a object for listening to lifecycles
```luau
artwork.register(members: object<T>, priority: number?): T
```

The priority of a provider is used to determine the order in which the providers are registered.

The higher the priority, the earlier the provider is registered on ignition.
The default priority is `1` and providers with higher priority are registered after providers with a lower priority.