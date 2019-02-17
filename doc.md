# naw

*[module]*

ECS module

## naw.Component

*[class]*

This does not actually hold the data, but just declares a component type/component class.

**Constructor Arguments**:
- *initFunction*: The function that creates the component. It's arguments are forwarded from `naw.Entity:addComponent` and the return value should be the actual component data. The environment of this function will contain the function `ensureComponent`, that wraps `ecs.Entity:ensureComponent` for the entity that the component is currently being added to. This is useful for auto-resovling potentially missing dependencies.
- *...*: A list of components that are dependencies of this component.

**Member variables**:
- *initFunction*: The init function passed to the constructor.
- *id*: A unique (over the lifetime of the program) component id (number). The component can be retrieved by id, by indexing the Component class: `naw.Component[compId]`.

**Usage**:
```lua
local PositionComponent = naw.Component(function(x, y)
    return {x = x or 0, y = y or 0}
end)

local VelocityComponent = naw.Component(function(x, y)
    ensureComponent(PositionComponent)
    return {x = x or 0, y = y or 0}
end, PositionComponent)

local NameComponent = naw.Component(function(name)
    return name
end)

-- [...]

local entity = world:Entity()
entity:addComponent(VelocityComponent, 0, 0)
entity:addComponent(NameComponent, "foo")
```

**See also**: [naw.Entity:addComponent](#nawentityaddcomponent), [naw.Entity:ensureComponent](#nawentityensurecomponent)
## naw.Entity

*[class]*

Creates an entity without adding it to a world. Most of the time, you want to use `naw.World:Entity()`.

**Member variables**:
- *id*: A unique (over the lifetime of the program) entity id (number). The entity can be retrieved by id, by indexing the Entity class: `naw.Entity[entId]` or by indexing `World.entities[entId]`.
- *world*: An array of all the worlds the entity lives in.
- *components*: A table containing all the components the entity has. The keys are the component classes and the values should always be `true`.

**See also**: [naw.World:Entity](#nawworldentity)
### naw.Entity:addComponent

*[function]*

The added component can be retrieved by indexing the entity itself: e.g. `entity[PositionComponent]`.

**Parameters**:
- *componentClass*: The component class of the component to be added to the entity
- *...*: Arguments to be forwarded to the init function of the component class

**Return Value**: The component that was just created

**Usage**:
```lua
local pos = entity:addComponent(PositionComponent, 0, 0)
```

**See also**: [naw.Component](#nawcomponent)
### naw.Entity:ensureComponent

*[function]*

Exactly like `naw.Entity:addComponent`, but only adds it, if the component is not already present. If it is, this does nothing.

This is mainly used to prepare component dependencies in init functions of components.

**See also**: [naw.Entity:addComponent](#nawentityaddcomponent), [naw.Component](#nawcomponent)
### naw.Entity:removeComponent

*[function]*

**Parameters**:
- *componentClass*: The component class of the component to be removed

### naw.Entity:getComponent

*[function]*

This will error if the component does not exist for this entity

**Parameters**:
- *componentClass*: The component class to get the component data of.

**See also**: [naw.Entity:getComponents](#nawentitygetcomponents)
### naw.Entity:getComponents

*[function]*

This is a variant of `naw.Entity:getComponent`, but takes a number of component classes and returns the component for each.

**Parameters**:
- *...*: A list of component classes to return the component data of.

**Usage**:
```lua
local pos, vel = entity:getComponents(PositionComponent, VelocityComponent)
```

**See also**: [naw.Entity:getComponent](#nawentitygetcomponent)
### naw.Entity:hasComponent

*[function]*

**Parameters**:
- *componentClass*: The component class to check for existence in the entity.

**Return Value**: A boolean indicating whether the passed component is present in the entity.

**See also**: [naw.Entity:hasComponents](#nawentityhascomponents)
### naw.Entity:hasComponents

*[function]*

**Parameters**:
- *...*: A list of components to be checked for existence in the entity.

**Return Value**: A boolean indicating whether the passed components are all present in the entity

**See also**: [naw.Entity:hasComponent](#nawentityhascomponent)
### naw.Entity:destroy

*[function]*

Removes entity from all worlds, removes all components from the entity (so they can be collected) and invalidates the entity id.

**Entities can not be garbage collected before this function is called**. If you don't want to use an entity anymore, calling `world:removeEntity(entity)` is not enough.

## naw.World

*[class]*

This is where entities live

**Member variables**:
- *entities*: A table that has entity ids as keys and entities as values

### naw.World:addEntity

*[function]*

**Parameters**:
- *entity*: The entity to add to the world

### naw.World:removeEntity

*[function]*

**Parameters**:
- *entity*: The entity to remove from the world

### naw.World:foreachEntity

*[function]*

Returns an iterator over all entities in this world that have the specified component.

**Parameters**:
- *componentClass*: The component class to filter the entities by.

**Return Value**: iterator

**Usage**:
```lua
function physicsSystem(world, dt)
    for entity in world:foreachEntity(VelocityComponent) do
        local pos, vel = entity[PositionComponent], entity[VelocityComponent]
        pos.x = pos.x + vel.x * dt
        pos.y = pos.y + vel.y * dt
    end
end
```

### naw.World:Entity

*[function]*

Creates an entity and adds it to the world

**Return Value**: The entity created

**Usage**:
```lua
local entity = world:Entity()
entity:addComponent(PositionComponent, 0, 0)
```

