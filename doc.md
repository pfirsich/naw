# ecs

*[module]*

ECS module

## ecs.Component

*[class]*

This does not actually hold the data, but just declares a component type/component class.

**Constructor Arguments**:
- *initFunction*: The function that creates the component. It's arguments are forwarded from ecs.Entity:addComponent and the return value should be the actual component data.
- *...*: A list of components that are dependencies of this component.

**Member variables**:
- *initFunction*: The init function passed to the constructor
- *id*: A unique (over the lifetime of the program) component id (number). The component can be retrieved by id, by indexing the Component class: `ecs.Component[compId]`.

**Usage**:
```lua
local PositionComponent = ecs.Component(function(x, y)
    return {x = x or 0, y = y or 0}
end)

local VelocityComponent = ecs.Component(function(x, y)
    return {x = x or 0, y = y or 0}
end, PositionComponent)

local NameComponent = ecs.Component(function(name)
    return name
end)

-- [...]

entity:addComponent(PositionComponent, 0, 0)
entity:addComponent(NameComponent, "foo")
```

**See also**: [ecs.Entity:addComponent](#ecsentityaddcomponent)
## ecs.Entity

*[class]*

Creates an entity without adding it to a world. Most of the time, you want to use `ecs.World:Entity()`.

**Member variables**:
- *id*: A unique (over the lifetime of the program) entity id (number). The entity can be retrieved by id, by indexing the Entity class: `ecs.Entity[entId]`.
- *world*: An array of all the worlds the entity lives in.
- *components*: A table containing all the components the entity has. The keys are the component classes and the values are the component data. You may also access component data by just doing e.g. `entity[PositionComponent]`.

**See also**: [ecs.World:Entity](#ecsworldentity)
### ecs.Entity:addComponent

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

**See also**: [ecs.Component](#ecscomponent)
### ecs.Entity:removeComponent

*[function]*

**Parameters**:
- *componentClass*: The component class of the component to be removed

### ecs.Entity:getComponent

*[function]*

This will error if the component does not exist for that entity

**Parameters**:
- *...*: A list of component classes to return the component data from

**Usage**:
```lua
local pos, vel = entity:getComponent(PositionComponent, VelocityComponent)
```

### ecs.Entity:hasComponent

*[function]*

**Parameters**:
- *...*: A list of components to be checked for existence in the entity

**Return Value**: A boolean indicating whether the passed components are all present in the entity

## ecs.World

*[class]*

This is where entities live

**Member variables**:
- *entities*: An instance of the internal `Set` class. A regular array with all the entities in this world can be found in `world.entities.values`. __Do not every modify the array or the Set itself manually!__ Use `ecs.World.addEntity` and `ecs.World.removeEntity` instead.

### ecs.World:addEntity

*[function]*

**Parameters**:
- *entity*: The entity to add to the world

### ecs.World:removeEntity

*[function]*

**Parameters**:
- *entity*: The entity to remove from the world

### ecs.World:foreachEntity

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

### ecs.World:Entity

*[function]*

Creates an entity and adds it to the world

**Return Value**: The entity created

**Usage**:
```lua
local entity = world:Entity()
entity:addComponent(PositionComponent, 0, 0)
```

