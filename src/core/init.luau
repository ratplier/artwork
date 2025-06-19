local core = require(script.core)
local modding = require(script.modding)
local signal = require(script.signal)

local lib = core.extend(core, {
    modding = modding,
    signal = signal
})

return lib