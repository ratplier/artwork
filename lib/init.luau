local core = require(script.core)
local modding = require(script.modding)
local signal = require(script.signal)

local component = require(script.components.component)
local net = require(script.networking.net)
local lifecycles = require(script.lifecycles.lifecycles)

local main = core:extend({
	net = net,
    modding = modding,
    signal = signal,
}, component, lifecycles)

return main