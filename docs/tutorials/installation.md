
```luau
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
return artwork.register(CoinProvider) --(1)!
```
