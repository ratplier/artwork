## artwork
the framework for everything roblox  
made with love by [@ratplier](https://github.com/ratplier)

api and syntax inspired by flamework and oh-my-prvd
(https://ratplier.github.io/artwork)

### boilerplate
``` lua
local artwork = require("@packages/artwork")

local provider = {}
artwork.register(provider) --(1)!
```

### example
```lua
local artwork = require("@packages/artwork")

local CoinProvider = {
    balances = {}
}

function CoinProvider.register(self: self, player: Player, amount: number?)
    local startingAmount = if amount ~= nil then amount else 0
    self.balances[player] = startingAmount
end

function CoinProvider.unregister(self: self, player: Player)
    self.balances[player] = nil
end

function CoinProvider.increment(self: self, player: Player, amount: number)
    self.balances[player] += amount
end

type self = typeof(CoinProvider)
return artwork.register(CoinProvider)
```
