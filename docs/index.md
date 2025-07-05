The framework for everything roblox  
Made with :heart: by [@ratplier](https://github.com/ratplier)

framework inspired by [flamework](https://flamework.fireboltofdeath.dev/) and [prvdmwrong](https://prvdmwrong.github.io/prvdmwrong/latest/)

## **Boilerplate**
The bare minimal example of a provider , which can listen to any [lifecycle event](/artwork/tutorials/fundamentals/lifecycles)

``` luau
local artwork = require("@packages/artwork")

local provider = {}
artwork.register(provider)
```

## **Full Example**
A more in-depth example of a framework usage

```luau
-- DataProvider.luau
local artwork = require("@packages/artwork")

local DataProvider = {
    registeredPlayers = {},
    data = {},
}

function DataProvider.registerPlayer(player: Player)
    if DataProvider.registeredPlayers[player.UserId] then return end

    DataProvider.data[player.UserId] = {}
    DataProvider.registeredPlayers[player.UserId] = true
end

function DataProvider.setData(player: Player, key: string, value: any)
    DataProvider.registerPlayer(player)
    
    local playerData = DataProvider.data[player.UserId]
    playerData[key] = value
end

return artwork.register(DataProvider)
```

```luau
-- CoinsProvider.luau
local artwork = require("@packages/artwork")

local CoinsProvider = {
    dataProvider = require("DataProvider")
}

function CoinsProvider.setCoins(player: Player, amount: number)
    CoinsProvider.dataProvider.setData(player, "Coins", amount)
end

return artwork.register(CoinsProvider)
```

```luau
-- main.server.luau
local artwork = require("@packages/artwork")

artwork.loadDescendants("@providers")
local shutdown = artwork.ignite()

game:BindToClose(shutdown)
```