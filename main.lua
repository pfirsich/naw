local ecs = require("naw")

local function randf(min, max)
    return min + love.math.random() * (max - min)
end

local PositionComponent = ecs.Component(function(x, y)
    return {
        x = x or 0,
        y = y or 0,
    }
end)

local VelocityComponent = ecs.Component(function(x, y)
    return {
        x = x or 0,
        y = y or 0,
    }
end, PositionComponent)

local ColorComponent = ecs.Component(function(color)
    return color or {1, 1, 1}
end)

local RectangleRenderComponent = ecs.Component(function(width, height, color)
    ensureComponent(ColorComponent, color)
    return {
        width = width or 100,
        height = height or 100,
    }
end, PositionComponent, ColorComponent)

local world = ecs.World()

local winW, winH = love.graphics.getDimensions()
for i = 1, 100 do
    local speed = randf(100, 200)
    local entity = world:Entity()
    entity:addComponent(PositionComponent, randf(0, winW), randf(0, winH))
    entity:addComponent(VelocityComponent, randf(-1, 1) * speed, randf(-1, 1) * speed)
    -- this adds the color component right away
    entity:addComponent(RectangleRenderComponent, nil, nil, {randf(0,1), randf(0,1), randf(0,1)})
end

function physicsSystem(world, dt)
    local winW, winH = love.graphics.getDimensions()

    for entity in world:foreachEntity(VelocityComponent) do
        local pos = entity[PositionComponent]
        local vel = entity[VelocityComponent]
        pos.x = pos.x + vel.x * dt
        pos.y = pos.y + vel.y * dt

        if pos.x < 0 then pos.x = pos.x + winW end
        if pos.y < 0 then pos.y = pos.y + winH end
        if pos.x > winW then pos.x = pos.x - winW end
        if pos.y > winH then pos.y = pos.y - winH end
    end
end

function rectangleRenderSystem(world)
    for entity in world:foreachEntity(RectangleRenderComponent) do
        local pos = entity[PositionComponent]
        local rect = entity[RectangleRenderComponent]
        love.graphics.setColor(entity[ColorComponent])
        love.graphics.rectangle("fill", pos.x - rect.width/2, pos.y - rect.height/2,
                                rect.width, rect.height)
    end
end

function love.update(dt)
    physicsSystem(world, dt)
end

function love.draw()
    rectangleRenderSystem(world)
    love.window.setTitle(("FPS: %d"):format(love.timer.getFPS()))
end
