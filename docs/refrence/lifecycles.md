## Methods

#### lifecycles.createLifecycle
Creates a lifecycle that can be used inside of `providers` and `components`
```luau
function lifecycles.createLifecycle(name: string, manager: (fire: () -> ()) -> ()): () -> ()
```

#### lifecycles.createClientLifecycle
Creates a lifecycle that will only register on the server
```luau
function lifecycles.createClientLifecycle(name: string, manager: (fire: () -> ()) -> ()): () -> ()
```

#### lifecycles.createServerLifecycle
Creates a lifecycle that will only register on the client
```luau
function lifecycles.createServerLifecycle(name: string, manager: (fire: () -> ()) -> ()): () -> ()
```

## Extras
The bundle module includes some presets for lifecycles you can use