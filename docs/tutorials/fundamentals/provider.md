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

### Registering a provider
To register a provider, you can use the [`artwork.register`](refrence/core/#register) function to register a object for listening to lifecycles. the priority can also be passed but it is optional
```luau
return artwork.register(provider, 1)
```

### Load Order
!!! info "Dependency Injection"
    This framework will automatically determine the correct load order for you, so it is recommended to avoid setting this manually.
    The property will take priority over the automatic order but providers with the same load order will still run in the automatic order.

The higher the priority, the earlier the provider is registered on ignition.
The default priority is `1` and providers with lower priority are registered after providers with a higher priority.

```luau
return artwork.register(provider, 0) -- will run BEFORE default priority
```
```luau
return artwork.register(provider, 2) -- will run AFTER default priority
```