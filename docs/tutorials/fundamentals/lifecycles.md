# Lifecycle Events

## Built-in Lifecycle Events
### onStart
The `onStart` lifecycle event is similar to `onInit`, however, instead of calling each event sequentially, they are all called at the same time. This means yielding, or failures, in onStart won't affect others.

### onInit
!!! info "Avoid Use"
    You should always use onStart except in very rare circumstances where you need the unique behavior of onInit.

The `onInit` lifecycle event is one of the initialization events. This is only called once, and the function must complete successfully before the framework will call the next onInit or other events. It isnt recommended to yield in `onInit` since yielding will yield ignition. Errors and such will be logged but not pause execution.

### onStop
The `onStop` lifecycle event is the opposite of `onStart`. It is called once right before the framework is shutdown. This is your chance to cleanup any resources that were allocated in `onStart` or anytime during execution.

## Custom Lifecycle Events
### Custom Events

Custom lifecycle events are a powerful feature that allows you to create custom lifecycle events that can be used by any module.
To create a custom lifecycle event you can use the `artwork.createLifecycle` method.

You can create client/server specific lifecycles with `artwork.createClientLifecycle` and `artwork.createServerLifecycle`

```luau
local artwork = require("@packages/artwork")

artwork.createLifecycle("onPlayerAdded", function(fire)
    Players.PlayerAdded:Connect(fire)
    for _, player in Players:GetPlayers() do
        fire(player)
    end
end)

-- then you can use the lifecycle event in any module like so:
local provider = {}

function provider.onPlayerAdded(player)
    print(`Player {player.Name} joined the game! ({player.UserId})`)
end

artwork.register(provider)
```