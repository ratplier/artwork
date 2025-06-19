local Core = require("../core")
local lifecycles = require("./lifecycles")

local provider = {}

function provider.onInit()
    lifecycles.createLifecycle("onPlayerAdded", function(fire)
        local Players = game:GetService("Players")
        Players.PlayerAdded:Connect(fire)
    end)
    
    lifecycles.createLifecycle("onPlayerRemoving", function(fire)
        local Players = game:GetService("Players")
        Players.PlayerRemoving:Connect(fire)
    end)

    lifecycles.createClientLifecycle("preRender", function(fire)
        local RunService = game:GetService("RunService")
        RunService.PreRender:Connect(fire)
    end)

    lifecycles.createLifecycle("postSimulation", function(fire)
        local RunService = game:GetService("RunService")
        RunService.PostSimulation:Connect(fire)
    end)

    lifecycles.createLifecycle("preSimulation", function(fire)
        local RunService = game:GetService("RunService")
        RunService.PreSimulation:Connect(fire)
    end)

    lifecycles.createLifecycle("preAnimation", function(fire)
        local RunService = game:GetService("RunService")
        RunService.PreAnimation:Connect(fire)
    end)
end

return Core.provider(provider)