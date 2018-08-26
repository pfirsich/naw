-- @module ecs
-- @desc ECS module
local ecs = {}

-------------------------------------------- HELPERS -------------------------------------------

local function classCall(cls, ...)
    local self = setmetatable({}, cls)
    self.class = cls
    if self.initialize then self:initialize(...) end
    return self
end

local function class()
    local cls = setmetatable({}, {__call = classCall})
    cls.__index = cls
    return cls
end

local function removeByValue(list, value)
    for i = 1, #list do
        if list[i] == value then
            table.remove(list, i)
            return true
        end
    end
end

local Set = class()

function Set:initialize(list)
    self.values = {}
    self.indices = {}
    self.size = 0
end

function Set:insert(value)
    assert(self.indices[value] == nil)
    table.insert(self.values, value)
    self.size = self.size + 1
    self.indices[value] = self.size
end

function Set:remove(value)
    -- insert the value at the end of the list at the position we removed
    local index = self.indices[value]
    assert(index)
    local lastValue = self.values[self.size]
    self.indices[lastValue] = index
    self.values[index] = lastValue
    self.indices[value] = nil
    self.values[self.size] = nil
    self.size = self.size - 1
end

function Set:contains(value)
    return self.indices[value] ~= nil
end

------------------------------------------- COMPONENT -------------------------------------------

-- @class ecs.Component
-- @desc This does not actually hold the data, but just declares a component type/component class.
-- @param initFunction The function that creates the component. It's arguments are forwarded from ecs.Entity:addComponent and the return value should be the actual component data.
-- @param ... A list of components that are dependencies of this component.
-- @field initFunction The init function passed to the constructor
-- @field id A unique (over the lifetime of the program) component id (number). The component can be retrieved by id, by indexing the Component class: `ecs.Component[compId]`.
-- @usage local PositionComponent = ecs.Component(function(x, y)
-- @usage     return {x = x or 0, y = y or 0}
-- @usage end)
-- @usage
-- @usage local VelocityComponent = ecs.Component(function(x, y)
-- @usage     return {x = x or 0, y = y or 0}
-- @usage end, PositionComponent)
-- @usage
-- @usage local NameComponent = ecs.Component(function(name)
-- @usage     return name
-- @usage end)
-- @usage
-- @usage -- [...]
-- @usage
-- @usage entity:addComponent(PositionComponent, 0, 0)
-- @usage entity:addComponent(NameComponent, "foo")
-- @see ecs.Entity:addComponent
ecs.Component = class()

local componentCounter = 0

function ecs.Component:initialize(initFunction, ...)
    self.initFunction = initFunction
    componentCounter = componentCounter + 1
    self.id = componentCounter
    ecs.Component[self.id] = self
    self.dependencies = {...}
end

-------------------------------------------- ENTITY ---------------------------------------------

-- @class ecs.Entity
-- @desc Creates an entity without adding it to a world. Most of the time, you want to use `ecs.World:Entity()`.
-- @field id A unique (over the lifetime of the program) entity id (number). The entity can be retrieved by id, by indexing the Entity class: `ecs.Entity[entId]`.
-- @field world An array of all the worlds the entity lives in.
-- @field components A table containing all the components the entity has. The keys are the component classes and the values are the component data. You may also access component data by just doing e.g. `entity[PositionComponent]`.
-- @see ecs.World:Entity
ecs.Entity = class()

local entityCounter = 0

function ecs.Entity:initialize()
    entityCounter = entityCounter + 1
    self.id = entityCounter
    ecs.Entity[self.id] = self
    self.worlds = {}
    self.components = {} -- key == component class, value = component data
end

-- @function ecs.Entity:addComponent
-- @desc The added component can be retrieved by indexing the entity itself: e.g. `entity[PositionComponent]`.
-- @param componentClass The component class of the component to be added to the entity
-- @param ... Arguments to be forwarded to the init function of the component class
-- @return The component that was just created
-- @see ecs.Component
-- @usage local pos = entity:addComponent(PositionComponent, 0, 0)
function ecs.Entity:addComponent(component, ...)
    assert(self[component] == nil, "Component already present")
    local componentData = component.initFunction(...)
    if type(componentData) == "table" then
        setmetatable(componentData, {__index = component})
    end

    for i = 1, #component.dependencies do
        assert(self[component.dependencies[i]], "Component dependency not satisfied")
    end

    self.components[component] = componentData
    self[component] = componentData

    for i = 1, #self.worlds do
        self.worlds[i]:componentPool(component):insert(self)
    end

    return componentData
end

-- @function ecs.Entity:removeComponent
-- @param componentClass The component class of the component to be removed
function ecs.Entity:removeComponent(component)
    assert(self[component], "Trying to remove a non-existent component")
    self.components[component] = nil
    self[component] = nil
    for i = 1, #self.worlds do
        self.worlds[i]:componentPool(component):remove(self)
    end
end

-- @function ecs.Entity:getComponent
-- @desc This will error if the component does not exist for that entity
-- @param ... A list of component classes to return the component data from
-- @usage local pos, vel = entity:getComponent(PositionComponent, VelocityComponent)
function ecs.Entity:getComponent(...)
    if select("#", ...) == 1 then
        local componentData = self[component]
        assert(componentData, "Attempt to get non-existent component")
        return componentData
    else
        return self[select(1, ...)], self:getComponent(select(2, ...))
    end
end

-- @function ecs.Entity:hasComponent
-- @param ... A list of components to be checked for existence in the entity
-- @return A boolean indicating whether the passed components are all present in the entity
function ecs.Entity:hasComponent(...)
    if select("#", ...) == 1 then
        return self[component] ~= nil
    else
        return self[select(1, ...)] ~= nil and self:hasComponent(select(2, ...))
    end
end

--------------------------------------------- WORLD ---------------------------------------------

-- @class ecs.World
-- @field entities An instance of the internal `Set` class. A regular array with all the entities in this world can be found in `world.entities.values`. __Do not every modify the array or the Set itself manually!__ Use `ecs.World.addEntity` and `ecs.World.removeEntity` instead.
-- @desc This is where entities live
ecs.World = class()

function ecs.World:initialize()
    self.entities = Set()
    self.componentPools = {} -- key = component.id, value = array of entities (Set)
end

-- @function ecs.World:addEntity
-- @param entity The entity to add to the world
function ecs.World:addEntity(entity)
    -- TODO: Ensure the entity is only added once, because otherwise *everything* breaks
    self.entities:insert(entity)
    table.insert(entity.worlds, self)
    for component, _ in pairs(entity.components) do
        self:componentPool(component):insert(entity)
    end
end

-- @function ecs.World:removeEntity
-- @param entity The entity to remove from the world
function ecs.World:removeEntity(entity)
    self.entities:remove(entity)
    removeByValue(entity.worlds, self) -- entity.worlds is small, so I hope this is fast
    for component, _ in pairs(entity.components) do
        self:componentPool(component):remove(entity)
    end
end

function ecs.World:componentPool(component)
    local pool = self.componentPools[component.id]
    if not pool then
        pool = Set()
        self.componentPools[component.id] = pool
    end
    return pool
end

-- @function ecs.World:foreachEntity
-- @desc Returns an iterator over all entities in this world that have the specified component.
-- @param componentClass The component class to filter the entities by.
-- @return iterator
-- @usage function physicsSystem(world, dt)
-- @usage     for entity in world:foreachEntity(VelocityComponent) do
-- @usage         local pos, vel = entity[PositionComponent], entity[VelocityComponent]
-- @usage         pos.x = pos.x + vel.x * dt
-- @usage         pos.y = pos.y + vel.y * dt
-- @usage     end
-- @usage end
function ecs.World:foreachEntity(component)
    local list = self:componentPool(component).values
    local idx = #list + 1
    return function()
        idx = idx - 1
        return list[idx]
    end
end

-- @function ecs.World:Entity
-- @desc Creates an entity and adds it to the world
-- @return The entity created
-- @usage local entity = world:Entity()
-- @usage entity:addComponent(PositionComponent, 0, 0)
function ecs.World:Entity()
    local entity = ecs.Entity()
    self:addEntity(entity)
    return entity
end

return ecs
