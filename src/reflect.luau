--!strict
type object = {}
type metadata = { [string]: unknown }

local internal = {
    metadata = {} :: { [string]: { [string]: unknown } },
    idToObj = {} :: { [string]: unknown },
    objToId = {} :: { [unknown]: string },
}

local Reflect = {
    idToObj = internal.idToObj
}

local function hash(data: unknown): string
    local str = tostring(data)
    local hash = 5381
    for i = 1, #str do
        local code = string.byte(str)
		hash = bit32.lshift(hash, 5) + hash + code
    end
    return `reflect:{bit32.bxor(hash, 0)}`
end

function Reflect.getId(object: object, create: boolean?): string
    local id = hash(object)

    if internal.idToObj[id] == nil then
        local data = internal.metadata[id]
        internal.metadata[id] = if typeof(data) == "table" then data else {}

        internal.idToObj[id] = object
        internal.objToId[object] = id
    end

    return id :: any
end

function Reflect.getMetadata(object: object): metadata
    local id = Reflect.getId(object, true)
    return internal.metadata[id]
end

function Reflect.readMetadata(object: object, key: string): unknown
    local metadata = Reflect.getMetadata(object)
    return metadata[key]
end

function Reflect.defineMetadata(object: object, key: string, value: unknown)
    local metadata = Reflect.getMetadata(object)
    metadata[key] = value
end

return Reflect