local core = require(script.core)
local modding = require(script.modding)
local signal = require(script.signal)

local component = require(script.component)
local lifecycles = require(script.lifecycles)

local main = core:extend({
    modding = modding,
    signal = signal,
}, component, lifecycles)

return main