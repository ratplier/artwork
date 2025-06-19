--!strict
local CollectionService = game:GetService("CollectionService")

local Reflect = require("../reflect")
local Modding = require("../modding")
local Signal = require("../signal")

type object = {}
type set<T> = { [T]: true }
type component<T=any> = {
    tag: string?,
    members: T & object,
}

local internal = {
    bin = {} :: { [any]: any },

    attachedTags = {} :: set<string>,
    components = {} :: set<component>,
    activeComponents = {} :: { [Instance]: { [component]: object } },

    componentAdded = Signal.new(),
    componentRemoving = Signal.new(),
}

local Component = {}

local function constructComponent(instance: Instance, component: component): object
    local object = { instance = instance }
    return setmetatable(object, { __index = component.members }) :: any
end

local function registerInstance(instance: Instance)
    if not internal.activeComponents[instance] then
        internal.activeComponents[instance] = {}
    end
end

local function attachToTag(tag: string, component: component)
    if internal.attachedTags[tag] then return end
    internal.attachedTags[tag] = true

    local function instanceAdded(instance: Instance)
        Component.addComponent(instance, component)
    end

    local function instanceRemoved(instance: Instance)
        Component.removeComponent(instance, component)
    end

    local addedConnection = CollectionService:GetInstanceAddedSignal(tag):Connect(instanceAdded)
    local removingConnection = CollectionService:GetInstanceRemovedSignal(tag):Connect(instanceRemoved)

    for _, instance in CollectionService:GetTagged(tag) do
        instanceAdded(instance)
    end

    return function()
        addedConnection:Disconnect()
        removingConnection:Disconnect()
    end
end

function Component.registerComponent<T>(members: T & object, tag: string?): component<T>
    local component = {
        tag = tag,
        members = members
    }
    local componentId = Reflect.getId(component)

    if typeof(component.tag) == "string" then
        internal.bin[componentId] = attachToTag(component.tag, component)
    end

    internal.components[component] = true
    return component
end

function Component.addComponent(instance: Instance, component: component)
    if internal.activeComponents[instance] and internal.activeComponents[instance][component] then return end
    if typeof(instance) ~= "Instance" then return end

    registerInstance(instance)

    local object = constructComponent(instance, component)
    local objectId = Reflect.getId(object)

    internal.bin[objectId] = instance.Destroying:Connect(function()
        Component.removeComponent(instance, component)
    end)

    internal.activeComponents[instance][component] = object
    Modding.addListener(object, { "onInit", "onStart", "onStop" })

    internal.componentAdded:Fire(object, instance)
end

function Component.removeComponent(instance: Instance, component: component)
    if not internal.activeComponents[instance] or not internal.activeComponents[instance][component] then return end
    if typeof(instance) ~= "Instance" then return end

    local object = internal.activeComponents[instance][component]
    local objectId = Reflect.getId(object)
    
    local connection = internal.bin[objectId]
    if connection.Connected then
        connection:Disconnect()
    end

    internal.activeComponents[instance][component] = nil
    Modding.removeListener(object)

    internal.componentRemoving:Fire(object, instance)
end

function Component.clearAllComponents(instance: Instance)
    if not internal.activeComponents[instance] then return end

    for component in internal.activeComponents[instance] do
        Component.removeComponent(instance, component)
    end
end

function Component.getComponent<T>(instance: Instance, component: component<T>): T & object
    return internal.activeComponents[instance][component] :: any
end

function Component.getComponents(instance: Instance): { [component]: unknown }
    return internal.activeComponents[instance]
end

function Component.onComponentAdded(callback: (object: object, instance: Instance) -> ())
    return internal.componentAdded:Connect(callback)
end

function Component.onComponentRemoving(callback: (object: object, instance: Instance) -> ())
    return internal.componentRemoving:Connect(callback)
end

return Component