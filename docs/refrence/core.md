## Types

#### object
The `object` type represents a generic object in the framework. It is used as a base type for structures.
```luau
type object = { [any]: any }
```

#### predicate
The `predicate` type represents a function that takes a value of type `T` and returns a boolean.
```luau
type predicate<T> = (T) -> boolean
```

## Methods

#### artwork.loadDescendants
The `artwork.loadDescendants` method is used to load all modules within the descendants of a given parent instance. This method accepts a parent of type `Instance` and an optional `predicate` function, which can be used to filter the descendants that should be loaded. If a `predicate` is provided, only the descendants for which the predicate returns `true` will be loaded.
```luau
function artwork.loadDescendants(parent: Instance, predicate: predicate<Instance>?): void
```

#### artwork.loadChildren
The `artwork.loadChildren` method is used to load all modules within the children of a given parent instance. This method accepts a parent of type `Instance` and an optional `predicate` function, which can be used to filter the children that should be loaded. If a `predicate` is provided, only the children for which the predicate returns `true` will be loaded.
```luau
function artwork.loadChildren(parent: Instance, predicate: predicate<Instance>?): void
```

#### artwork.register
The `artwork.register` function registers a object for listening to lifecycles. The priority determines the order in which objects are registered when the framework is ignited. If no priority is specified, the default priority of `1` is used. The function returns the same table of members that was passed to it.
```luau
function artwork.register(members: object<T>, priority: number?): T
```

#### artwork.listen
The `artwork.listen` method is used to listen to a specific lifecycle event. It returns a cleanup function to disconnect the listener.
```luau
function artwork.listen(name: string, listener: (...any) -> ()): () -> ()
```

#### artwork.ignited
The `artwork.ignited` method is used to check if the framework is currently ignited.
```luau
function artwork.ignited(): boolean
```

#### artwork.shutdown
The `artwork.shutdown` method is used to check if the framework is currently shutdown.
```luau
function artwork.shutdown(): boolean
```

#### artwork.ignite
The `artwork.ignite` method is used to start the framework by initializing all registered providers and setting up the necessary event listeners. It processes providers based on their priority and also returns a function to shutdown the framework.

```luau
function artwork.ignite(): void
```

#### artwork.extend
The `artwork.extend` method is used to extend a table with other tables. It merges all the tables with the highest priority being the last given argument. It is also fully strictly typed and is very useful in creating [extensions] for the library.
```luau
function artwork.extend(...: object<any>): object<any>
```

## Properties

#### artwork.version
The `artwork.version` method is used to get the current version of the framework. It returns a string of the format `major.minor`.
```luau
string artwork.version
```