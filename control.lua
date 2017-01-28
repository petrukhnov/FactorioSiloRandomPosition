
require("config")

-- once game generated, create silo
script.on_init(function(event)
    SetRandomSiloPosition()
    global.siloGenerated = false
   
end)

script.on_event(defines.events.on_player_created, function(event)
    ChartRocketSiloArea(game.players[event.player_index].force)
end)

script.on_event(defines.events.on_chunk_generated, function(event)
    if (global.siloGenerated == false) then
        GenerateRocketSiloChunk(event)
    end
end)



-- Get a random 1 or -1
function RandomNegPos()
    if (math.random(0,1) == 1) then
        return 1
    else
        return -1
    end
end

function SetRandomSiloPosition()
    if (global.siloPosition == nil) then
        -- Get an X,Y on a circle far away.
        distX = math.random(0,SILO_CHUNK_DISTANCE_X)
        distY = RandomNegPos() * math.floor(math.sqrt(SILO_CHUNK_DISTANCE_X^2 - distX^2))
        distX = RandomNegPos() * distX

        -- Set those values.
        local siloX = distX*CHUNK_SIZE + CHUNK_SIZE/2
        local siloY = distY*CHUNK_SIZE + CHUNK_SIZE/2
        global.siloPosition = {x = siloX, y = siloY}
    end
end


-- Create a rocket silo
local function CreateRocketSilo(surface, chunkArea)
    if CheckIfInArea(global.siloPosition, chunkArea) then

        -- Delete any entities beneat the silo?
        for _, entity in pairs(surface.find_entities_filtered{area = {{global.siloPosition.x-5, global.siloPosition.y-6},{global.siloPosition.x+6, global.siloPosition.y+6}}}) do
            entity.destroy()
        end

        -- Set tiles below the silo
        --local tiles = {}
        --local i = 1
        -- dx = -6,6 do
        --    for dy = -7,6 do
        --        tiles[i] = {name = "grass", position = {global.siloPosition.x+dx, global.siloPosition.y+dy}}
        --        i=i+1
        --    end
        --end
        --surface.set_tiles(tiles, false)
        local tiles = {}
        local i = 1
        for dx = -6,6 do
            for dy = -7,6 do
                tiles[i] = {name = "concrete", position = {global.siloPosition.x+dx, global.siloPosition.y+dy}}
                i=i+1
            end
        end
        surface.set_tiles(tiles, true)

        -- Create silo and assign to a force
        local silo = surface.create_entity{name = "rocket-silo", position = {global.siloPosition.x+0.5, global.siloPosition.y}, force = "player"}
        silo.destructible = false
        silo.minable = false
    end
end

-- Remove rocket silo from recipes
function RemoveRocketSiloRecipe(event)
    RemoveRecipe(event, "rocket-silo")
end

-- Generates the rocket silo during chunk generation event
-- Includes a crop circle
function GenerateRocketSiloChunk(event)
    global.siloGenerated = false
    local surface = event.surface
    if surface.name ~= "nauvis" then return end
    local chunkArea = event.area

    local chunkAreaCenter = {x=chunkArea.left_top.x+(CHUNK_SIZE/2),
                             y=chunkArea.left_top.y+(CHUNK_SIZE/2)}
    local safeArea = {left_top=
                        {x=global.siloPosition.x-250,
                         y=global.siloPosition.y-250},
                      right_bottom=
                        {x=global.siloPosition.x+250,
                         y=global.siloPosition.y+250}}
                             

    -- Clear enemies directly next to the rocket
    if CheckIfInArea(chunkAreaCenter,safeArea) then
        for _, entity in pairs(surface.find_entities_filtered{area = chunkArea, force = "enemy"}) do
            entity.destroy()
        end
    end

    -- Create rocket silo
    CreateRocketSilo(surface, chunkArea)
    CreateCropCircle(surface, global.siloPosition, chunkArea, 40)
end

function ChartRocketSiloArea(force)
    force.chart(game.surfaces["nauvis"], {{global.siloPosition.x-(CHUNK_SIZE*2), global.siloPosition.y-(CHUNK_SIZE*2)}, {global.siloPosition.x+(CHUNK_SIZE*2), global.siloPosition.y+(CHUNK_SIZE*2)}})
end

-- Check if given position is in area bounding box
function CheckIfInArea(point, area)
    if ((point.x >= area.left_top.x) and (point.x <= area.right_bottom.x)) then
        if ((point.y >= area.left_top.y) and (point.y <= area.right_bottom.y)) then
            return true
        end
    end
    return false
end

-- General purpose event function for removing a particular recipe
function RemoveRecipe(event, recipeName)
    local recipes = event.research.force.recipes
    if recipes[recipeName] then
        recipes[recipeName].enabled = false
    end
end

-- Enforce a circle of land, also adds trees in a ring around the area.
function CreateCropCircle(surface, centerPos, chunkArea, tileRadius)

    local tileRadSqr = tileRadius^2

    local dirtTiles = {}
    for i=chunkArea.left_top.x,chunkArea.right_bottom.x,1 do
        for j=chunkArea.left_top.y,chunkArea.right_bottom.y,1 do

            -- This ( X^2 + Y^2 ) is used to calculate if something
            -- is inside a circle area.
            local distVar = math.floor((centerPos.x - i)^2 + (centerPos.y - j)^2)

            -- Fill in all unexpected water in a circle
            if (distVar < tileRadSqr) then
                if (surface.get_tile(i,j).collides_with("water-tile")) then
                    table.insert(dirtTiles, {name = "grass", position ={i,j}})
                end
            end

            -- Create a circle of trees around the spawn point.
            if ((distVar < tileRadSqr-200) and 
                (distVar > tileRadSqr-300)) then
                surface.create_entity({name="tree-01", amount=1, position={i, j}})
            end
        end
    end

    surface.set_tiles(dirtTiles)
end