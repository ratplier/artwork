## artwork
the framework for everything roblox  
made with love by [@ratplier](https://github.com/ratplier)

api and syntax inspired by flamework and prvd-m-wrong
(https://ratplier.github.io/artwork)

### boilerplate
``` lua
local artwork = require("@packages/artwork")

local provider = {}
artwork.register(provider)
```

### example
```lua
local artwork = require("@packages/artwork")

local CoinProvider = {
    balances = {}
}

function CoinProvider.register(player: Player, amount: number?)
    local startingAmount = if amount ~= nil then amount else 0
    CoinProvider.balances[player] = startingAmount
end

function CoinProvider.unregister(player: Player)
    CoinProvider.balances[player] = nil
end

function CoinProvider.increment(player: Player, amount: number)
    CoinProvider.balances[player] += amount
end

return artwork.register(CoinProvider)
```
