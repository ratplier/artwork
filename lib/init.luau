local core = require(script.core)
local modding = require(script.modding)
local signal = require(script.signal)

local main = core.extend(core, {
    modding = modding,
    signal = signal,
})

local components = script.components 
local networking = script.networking
local lifecycles = script.lifecycles

local external = {
    component = require(components.component),
    net = require(networking.net),
    lifecycle = require(lifecycles.lifecycles),
    lifecyclePresets = require(lifecycles.bundle),
}

local extras = main:extend({
    net = external.net,
    lifecycle = external.lifecyclePresets,
}, external.lifecycle, external.component)

return extras