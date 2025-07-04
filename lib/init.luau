local core = require(script.core)
local modding = require(script.modding)
local signal = require(script.signal)

local component = require(script.component)
local net = require(script.net)
local lifecycles = require(script.lifecycles)

local main = core:extend({
	net = net,
    modding = modding,
    signal = signal,
}, component, lifecycles)

return main