-- @module naw
-- @desc ECS module
local naw = {}

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

-- @class naw.Component
-- @desc This does not actually hold the data, but just declares a component type/component class.
-- @param initFunction The function that creates the component. It's arguments are forwarded from `naw.Entity:addComponent` and the return value should be the actual component data. The environment of this function will contain the function `ensureComponent`, that wraps `ecs.Entity:ensureComponent` for the entity that the component is currently being added to. This is useful for auto-resovling potentially missing dependencies.
-- @param ... A list of components that are dependencies of this component.
-- @field initFunction The init function passed to the constructor.
-- @field id A unique (over the lifetime of the program) component id (number). The component can be retrieved by id, by indexing the Component class: `naw.Component[compId]`.
-- @usage
-- @ local PositionComponent = naw.Component(function(x, y)
-- @     return {x = x or 0, y = y or 0}
-- @ end)
-- @
-- @ local VelocityComponent = naw.Component(function(x, y)
-- @     ensureComponent(PositionComponent)
-- @     return {x = x or 0, y = y or 0}
-- @ end, PositionComponent)
-- @
-- @ local NameComponent = naw.Component(function(name)
-- @     return name
-- @ end)
-- @
-- @ -- [...]
-- @
-- @ local entity = world:Entity()
-- @ entity:addComponent(VelocityComponent, 0, 0)
-- @ entity:addComponent(NameComponent, "foo")
-- @see naw.Entity:addComponent
-- @see naw.Entity:ensureComponent
naw.Component = class()

local componentCounter = 0

function naw.Component:initialize(initFunction, ...)
    componentCounter = componentCounter + 1
    self.id = componentCounter
    naw.Component[self.id] = self
    self.initFunction = initFunction
    self.initFunctionEnv = setmetatable({}, {__index = _G})
    setfenv(self.initFunction, self.initFunctionEnv)
    self.dependencies = {...}
end

-------------------------------------------- ENTITY ---------------------------------------------

-- @class naw.Entity
-- @desc Creates an entity without adding it to a world. Most of the time, you want to use `naw.World:Entity()`.
-- @field id A unique (over the lifetime of the program) entity id (number). The entity can be retrieved by id, by indexing the Entity class: `naw.Entity[entId]` or by indexing `World.entities[entId]`.
-- @field world An array of all the worlds the entity lives in.
-- @field components A table containing all the components the entity has. The keys are the component classes and the values should always be `true`.
-- @see naw.World:Entity
naw.Entity = class()

local entityCounter = 0

function naw.Entity:initialize()
    entityCounter = entityCounter + 1
    self.id = entityCounter
    naw.Entity[self.id] = self
    self.worlds = {}
    self.components = {} -- key = component class, value = true
    self._ensureComponent = function(...) return self:ensureComponent(...) end
end

-- @function naw.Entity:addComponent
-- @desc The added component can be retrieved by indexing the entity itself: e.g. `entity[PositionComponent]`.
-- @param componentClass The component class of the component to be added to the entity
-- @param ... Arguments to be forwarded to the init function of the component class
-- @return The component that was just created
-- @see naw.Component
-- @usage local pos = entity:addComponent(PositionComponent, 0, 0)
function naw.Entity:addComponent(component, ...)
    assert(not self:hasComponent(component), "Component already present")
    component.initFunctionEnv.ensureComponent = self._ensureComponent
    self[component] = component.initFunction(...)
    if type(self[component]) == "table" then
        setmetatable(self[component], {__index = component})
    end
    self.components[component] = true

    for i = 1, #component.dependencies do
        assert(self:hasComponent(component.dependencies[i]), "Component dependency not satisfied")
    end

    for i = 1, #self.worlds do
        self.worlds[i]:componentPool(component):insert(self)
    end

    return self[component]
end

-- @function naw.Entity:ensureComponent
-- @desc Exactly like `naw.Entity:addComponent`, but only adds it, if the component is not already present. If it is, this does nothing.
-- @
-- @ This is mainly used to prepare component dependencies in init functions of components.
-- @see naw.Entity:addComponent
-- @see naw.Component
function naw.Entity:ensureComponent(component, ...)
    if self:hasComponent(component) then
        return self[component]
    else
        return self:addComponent(component, ...)
    end
end

-- @function naw.Entity:removeComponent
-- @param componentClass The component class of the component to be removed
function naw.Entity:removeComponent(component)
    assert(self:hasComponent(component), "Trying to remove a non-existent component")
    self[component] = nil
    self.components[component] = nil
    for i = 1, #self.worlds do
        self.worlds[i]:componentPool(component):remove(self)
    end
end

-- @function naw.Entity:getComponent
-- @param componentClass The component class to get the component data of.
-- @desc This will error if the component does not exist for this entity
-- @see naw.Entity:getComponents
function naw.Entity:getComponent(componentClass)
    assert(self:hasComponent(componentClass), "Attempt to get non-existent component")
    return self[componentClass]
end

-- @function naw.Entity:getComponents
-- @desc This is a variant of `naw.Entity:getComponent`, but takes a number of component classes and returns the component for each.
-- @param ... A list of component classes to return the component data of.
-- @usage local pos, vel = entity:getComponents(PositionComponent, VelocityComponent)
-- @see naw.Entity:getComponent
function naw.Entity:getComponents(...)
    if select("#", ...) == 1 then
        return self:getComponent(...)
    else
        return self:getComponent(...), self:getComponents(select(2, ...))
    end
end

-- @function naw.Entity:hasComponent
-- @param componentClass The component class to check for existence in the entity.
-- @return A boolean indicating whether the passed component is present in the entity.
-- @see naw.Entity:hasComponents
function naw.Entity:hasComponent(componentClass)
    return self.components[componentClass]
end

-- @function naw.Entity:hasComponents
-- @param ... A list of components to be checked for existence in the entity.
-- @return A boolean indicating whether the passed components are all present in the entity
-- @see naw.Entity:hasComponent
function naw.Entity:hasComponents(...)
    if select("#", ...) == 1 then
        return self:hasComponent(...)
    else
        return self:hasComponent(...) and self:hasComponents(select(2, ...))
    end
end

-- @function naw.Entity:destroy
-- @desc Removes entity from all worlds, removes all components from the entity (so they can be collected) and invalidates the entity id.
-- @
-- @ **Entities can not be garbage collected before this function is called**. If you don't want to use an entity anymore, calling `world:removeEntity(entity)` is not enough.
function naw.Entity:destroy()
    for i = #self.worlds, 1, -1 do -- will be removed from while iterating
        self.worlds[i]:removeEntity(self)
    end
    for component, v in pairs(self.components) do
        assert(v == true)
        self:removeComponent(component)
    end
    naw.Entity[self.id] = nil
    self.id = nil
end

--------------------------------------------- WORLD ---------------------------------------------

-- @class naw.World
-- @field entities An instance of the internal `Set` class. A regular array with all the entities in this world can be found in `world.entities.values`. __Do not every modify the array or the Set itself manually!__ Use `naw.World.addEntity` and `naw.World.removeEntity` instead.
-- @desc This is where entities live
naw.World = class()

function naw.World:initialize()
    self.entities = Set()
    self.componentPools = {} -- key = component.id, value = array of entities (Set)
end

-- @function naw.World:addEntity
-- @param entity The entity to add to the world
function naw.World:addEntity(entity)
    -- TODO: Ensure the entity is only added once, because otherwise *everything* breaks
    self.entities:insert(entity)
    table.insert(entity.worlds, self)
    for component, v in pairs(entity.components) do
        assert(v == true)
        self:componentPool(component):insert(entity)
    end
end

-- @function naw.World:removeEntity
-- @param entity The entity to remove from the world
function naw.World:removeEntity(entity)
    self.entities:remove(entity)
    removeByValue(entity.worlds, self) -- entity.worlds is small, so I hope this is fast
    for component, v in pairs(entity.components) do
        assert(v == true)
        self:componentPool(component):remove(entity)
    end
end

function naw.World:componentPool(component)
    local pool = self.componentPools[component.id]
    if not pool then
        pool = Set()
        self.componentPools[component.id] = pool
    end
    return pool
end

-- @function naw.World:foreachEntity
-- @desc Returns an iterator over all entities in this world that have the specified component.
-- @param componentClass The component class to filter the entities by.
-- @return iterator
-- @usage
-- @ function physicsSystem(world, dt)
-- @     for entity in world:foreachEntity(VelocityComponent) do
-- @         local pos, vel = entity[PositionComponent], entity[VelocityComponent]
-- @         pos.x = pos.x + vel.x * dt
-- @         pos.y = pos.y + vel.y * dt
-- @     end
-- @ end
function naw.World:foreachEntity(component)
    local list = self:componentPool(component).values
    local idx = #list + 1
    return function()
        idx = idx - 1
        return list[idx]
    end
end

-- @function naw.World:Entity
-- @desc Creates an entity and adds it to the world
-- @return The entity created
-- @usage local entity = world:Entity()
-- @usage entity:addComponent(PositionComponent, 0, 0)
function naw.World:Entity()
    local entity = naw.Entity()
    self:addEntity(entity)
    return entity
end

return naw
