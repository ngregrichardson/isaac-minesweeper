minesweeperMod = RegisterMod("Minesweeper", 1)

font = Font()
font:Load("font/terminus.fnt")

local items = include("items/registry")
local helpers = include("helpers")
local minesweeper = include("minesweeper.lua")

local rng = RNG()

for _, item in pairs(items) do
    if item.callbacks then
        for _, callback in pairs(item.callbacks) do
            minesweeperMod:AddCallback(table.unpack(callback))
        end
    end
end

local SIZE = 10
local NUM_MINES = 4

local TOP_HUD_OFFSET = 35
local TOP_HUD_WIDTH = 1 / 2.5
local TOP_HUD_FONT_SIZE = 1.4

local MAP_ROOM_WIDTH = 9
local MAP_ROOM_HEIGHT = 8
local MAP_RADIUS = 2
local MAP_RADIUS_WITH_CUTOFF = MAP_RADIUS + 1
local MAP_NUMBER_OF_EDGES = ((MAP_RADIUS_WITH_CUTOFF * 2) + 1) * 2

minesweeperData = {
    grid = nil,
    currentRoom = nil,
    timer = 0,
    hasWon = false,
    hasLost = false
}

minesweeperHUDAnimations = {
    mapBorderXAnimations = {},
    mapBorderYAnimations = {},
    mapBorderCornerAnimations = {}
}

local directionSpawnPositions = {
    Vector(560, 280),
    Vector(320, 400),
    Vector(80, 280),
    Vector(320, 160)
}

local function InitializeGrid()
    minesweeperData.grid = minesweeper.GenerateMinesweeperGrid(SIZE, NUM_MINES)
    minesweeperData.timer = 0
    minesweeperData.hasWon = false
    minesweeperData.hasLost = false
    helpers.SaveData(minesweeperData)
    minesweeperData.currentRoom = { x = rng:RandomInt(SIZE) + 1, y = rng:RandomInt(SIZE) + 1, direction = Direction.NO_DIRECTION }
end

minesweeperMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContinued)
    local game = Game()
    rng:SetSeed(game:GetSeeds():GetStartSeed(), 35)

    game:GetHUD():SetVisible(false)

    game:GetLevel():SetStage(LevelStage.STAGE1_1, StageType.STAGETYPE_ORIGINAL)

    local p = Isaac.GetPlayer(0)
    p:AddCollectible(items.minesweepersShovel.Id)
    p:SetPocketActiveItem(items.minesweepersFlag.Id, ActiveSlot.SLOT_POCKET, true)
    -- p:AddMaxHearts(-4)
    -- p:AddHearts(-1)

    local saveData = helpers.LoadData()

    minesweeperHUDAnimations.smiley = helpers.RegisterSprite("gfx/ui/smileys.anm2")
    minesweeperHUDAnimations.shovel = helpers.RegisterSprite("gfx/items/collectibles/minesweeper_item.anm2", "gfx/items/collectibles/shovel.png")
    minesweeperHUDAnimations.flag = helpers.RegisterSprite("gfx/items/collectibles/minesweeper_item.anm2", "gfx/items/collectibles/flag.png")

    if isContinued and saveData then
        minesweeperData.grid = saveData.grid
        minesweeperData.currentRoom = saveData.currentRoom
    else
        InitializeGrid()
        Isaac.ExecuteCommand("goto d.".."2500")
    end

    for _, col in pairs(minesweeperData.grid) do
        for _, cell in pairs(col) do
            cell.mapCellSprite = helpers.RegisterSprite("gfx/ui/map_background.anm2")
            cell.mapCellIconSprite = helpers.RegisterSprite("gfx/ui/map_icon.anm2")
        end
    end

    for i = 0, MAP_NUMBER_OF_EDGES do
        table.insert(minesweeperHUDAnimations.mapBorderXAnimations, helpers.RegisterSprite("gfx/ui/map_background.anm2", nil, "CellXBorder"))
    end

    for i = 0, MAP_NUMBER_OF_EDGES do
        table.insert(minesweeperHUDAnimations.mapBorderYAnimations, helpers.RegisterSprite("gfx/ui/map_background.anm2", nil, "CellYBorder"))
    end

    for i = 0, 4 do
        table.insert(minesweeperHUDAnimations.mapBorderCornerAnimations, helpers.RegisterSprite("gfx/ui/map_background.anm2", nil, "CellCornerBorder"))
    end
end)

minesweeperMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()
    local room = Game():GetRoom()

    for i = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
        room:RemoveDoor(i)
    end

    if not minesweeperData.grid then
        InitializeGrid()
    end

    local currentCell = minesweeperData.grid[minesweeperData.currentRoom.y][minesweeperData.currentRoom.x]

    currentCell.hasVisited = true

    local offset = 10

    if minesweeperData.currentRoom.x > 1 then
        local door = helpers.SpawnDoor(DoorSlot.LEFT0, minesweeperData.currentRoom.x - 1, minesweeperData.currentRoom.y)
        door.Position = door.Position - Vector(offset, 0)
        door:GetSprite().Offset = Vector(offset * 2, 0)
    end

    if minesweeperData.currentRoom.y > 1 then
        local door = helpers.SpawnDoor(DoorSlot.UP0, minesweeperData.currentRoom.x, minesweeperData.currentRoom.y - 1)
        door.Position = door.Position - Vector(0, offset)
        door:GetSprite().Offset = Vector(0, offset * 2)
    end

    if minesweeperData.currentRoom.x < SIZE then
        local door = helpers.SpawnDoor(DoorSlot.RIGHT0, minesweeperData.currentRoom.x + 1, minesweeperData.currentRoom.y)
        door.Position = door.Position + Vector(offset, 0)
        door:GetSprite().Offset = Vector(-offset * 2, 0)
    end

    if minesweeperData.currentRoom.y < SIZE then
        local door = helpers.SpawnDoor(DoorSlot.DOWN0, minesweeperData.currentRoom.x, minesweeperData.currentRoom.y + 1)
        door.Position = door.Position + Vector(0, offset)
        door:GetSprite().Offset = Vector(0, -offset * 2)
    end

    if minesweeperData.currentRoom and minesweeperData.currentRoom.direction ~= -1 then
        helpers.ForEachPlayer(function(p)
            p.Position = directionSpawnPositions[minesweeperData.currentRoom.direction + 1]
        end) 
    end
end)

minesweeperMod:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, function(_, entity, collider)
    local p = collider:ToPlayer()
    if p then
        local data = entity:GetData()
        if not data.isClosed then
            minesweeperData.currentRoom = data.nextRoom
            Isaac.ExecuteCommand("goto d.".."2500")
        end
    end
end, 678)

minesweeperMod:AddCallback(ModCallbacks.MC_POST_RENDER, function()
    if minesweeperData.currentRoom then
        local currentCell = minesweeperData.grid[minesweeperData.currentRoom.y][minesweeperData.currentRoom.x]

        if currentCell.isFlagged then
            Isaac.RenderText("Room is flagged!", 50, 65, 1, 1, 1, 1)
        end

        local screenSize = Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight())

        -- Render score
        local score

        if minesweeperData.hasWon then
            score = 0
        else
            score = minesweeper.CalculateScore(minesweeperData.grid)
        end

        local scoreDisplay = ""
        if score <= 9 then
            if score < 0 then
                if score >= -9 then
                    scoreDisplay = "0"..score
                else
                    scoreDisplay = score
                end
            else
                scoreDisplay = "00"..score
            end
        elseif score <= 99 then
            scoreDisplay = "0"..score
        else
            scoreDisplay = score
        end
        helpers.RenderCenteredText(scoreDisplay, screenSize.X * TOP_HUD_WIDTH, TOP_HUD_OFFSET, TOP_HUD_FONT_SIZE, KColor(1, 0, 0, 1))

        -- Smiley
        minesweeperHUDAnimations.smiley:Render(Vector(screenSize.X / 2, TOP_HUD_OFFSET / 2))

        -- Render timer
        local timerDisplay = ""
        if minesweeperData.timer <= 9 then
            timerDisplay = "00"..minesweeperData.timer
        elseif minesweeperData.timer <= 99 then
            timerDisplay = "0"..minesweeperData.timer
        else
            timerDisplay = minesweeperData.timer
        end
        helpers.RenderCenteredText(timerDisplay, screenSize.X - (screenSize.X  * TOP_HUD_WIDTH), TOP_HUD_OFFSET, TOP_HUD_FONT_SIZE, KColor(1, 0, 0, 1))

        -- Items
        if not minesweeperData.hasWon and not minesweeperData.hasLost then
            if currentCell.isRevealed then
                minesweeperHUDAnimations.flag.Color = Color(minesweeperHUDAnimations.flag.Color.R, minesweeperHUDAnimations.flag.Color.G, minesweeperHUDAnimations.flag.Color.B, 0.3)
            else
                minesweeperHUDAnimations.flag.Color = Color(minesweeperHUDAnimations.flag.Color.R, minesweeperHUDAnimations.flag.Color.G, minesweeperHUDAnimations.flag.Color.B, 1)
            end

            if currentCell.isFlagged then
                minesweeperHUDAnimations.shovel.Color = Color(minesweeperHUDAnimations.shovel.Color.R, minesweeperHUDAnimations.shovel.Color.G, minesweeperHUDAnimations.shovel.Color.B, 0.3)
            else
                minesweeperHUDAnimations.shovel.Color = Color(minesweeperHUDAnimations.shovel.Color.R, minesweeperHUDAnimations.shovel.Color.G, minesweeperHUDAnimations.shovel.Color.B, 1)
            end

            minesweeperHUDAnimations.flag:Render(screenSize - Vector(20, 20))
            minesweeperHUDAnimations.shovel:Render(screenSize - Vector(60, 20))
        end

        -- Map
        local isMapEnlarged = Input.IsActionPressed(ButtonAction.ACTION_MAP, 0)

        local scale = 1

        if isMapEnlarged then
            scale = 2
        end

        local scaledCellWidth = MAP_ROOM_WIDTH * scale
        local scaledCellHeight = MAP_ROOM_HEIGHT * scale

        local xPadding = (MAP_RADIUS_WITH_CUTOFF + 1) * scaledCellWidth
        local yPadding = (MAP_RADIUS_WITH_CUTOFF + 1) * scaledCellHeight
        local centerOfMap = Vector(screenSize.X - xPadding, yPadding)

        for _, col in pairs(minesweeperData.grid) do
            for _, cell in pairs(col) do

                local xDiff = cell.x - currentCell.x
                local yDiff = cell.y - currentCell.y

                if math.abs(xDiff) <= MAP_RADIUS_WITH_CUTOFF and math.abs(yDiff) <= MAP_RADIUS_WITH_CUTOFF then

                    local cellPosition = Vector(centerOfMap.X + xDiff * scaledCellWidth - 0.5, centerOfMap.Y + yDiff * scaledCellHeight)

                    local isCurrent = xDiff == 0 and yDiff == 0

                    if not isCurrent then
                        cell.mapCellSprite:Play("VisitedSmall")
                    end

                    if cell.isFlagged then
                        cell.mapCellIconSprite:Play("Flag")
                    elseif cell.isRevealed then
                        cell.mapCellSprite:Play("UnvisitedSmall")
                        cell.mapCellIconSprite:Play(tostring(cell.touchingMines))
                    else
                        cell.mapCellIconSprite:Play("None")
                    end

                    if cell.isMine and minesweeperData.hasLost and not cell.isFlagged then
                        cell.mapCellSprite:Play("UnvisitedSmall")
                        if isCurrent then
                            cell.mapCellSprite.Color:SetTint(1, 0, 0, 0.8)
                        end
                        cell.mapCellIconSprite:Play("Mine")
                    end

                    if isCurrent then
                        cell.mapCellSprite:Play("CurrentSmall")
                    end

                    cell.mapCellSprite.Scale = Vector(scale, scale)
                    cell.mapCellIconSprite.Scale = Vector(scale, scale)

                    cell.mapCellSprite:Render(cellPosition)
                    cell.mapCellIconSprite:Render(cellPosition)
                end
            end
        end

        -- Map border

        for i = -MAP_RADIUS_WITH_CUTOFF, MAP_RADIUS_WITH_CUTOFF do
            local index = i + MAP_RADIUS_WITH_CUTOFF + 1
            local negativeIndex = math.floor(index + MAP_NUMBER_OF_EDGES / 2)

            local xOffset = MAP_RADIUS_WITH_CUTOFF * scaledCellWidth + ((scaledCellWidth / 2) - 1)
            local yOffset = i * scaledCellHeight

            minesweeperHUDAnimations.mapBorderXAnimations[index].Scale = Vector(scale, scale)
            minesweeperHUDAnimations.mapBorderXAnimations[negativeIndex].Scale = Vector(scale, scale)

            minesweeperHUDAnimations.mapBorderXAnimations[index]:Render(Vector(centerOfMap.X + xOffset, centerOfMap.Y + yOffset))
            minesweeperHUDAnimations.mapBorderXAnimations[negativeIndex]:Render(Vector(centerOfMap.X - xOffset, centerOfMap.Y + yOffset))
        end

        for i = -MAP_RADIUS_WITH_CUTOFF, MAP_RADIUS_WITH_CUTOFF do
            local index = i + MAP_RADIUS_WITH_CUTOFF + 1
            local negativeIndex = math.floor(index + MAP_NUMBER_OF_EDGES / 2)

            local xOffset = i * scaledCellWidth
            local yOffset = MAP_RADIUS_WITH_CUTOFF * scaledCellHeight + ((scaledCellHeight / 2) - 1)

            minesweeperHUDAnimations.mapBorderYAnimations[index].Scale = Vector(scale, scale)
            minesweeperHUDAnimations.mapBorderYAnimations[negativeIndex].Scale = Vector(scale, scale)

            minesweeperHUDAnimations.mapBorderYAnimations[index]:Render(Vector(centerOfMap.X + xOffset - 0.5, centerOfMap.Y + yOffset))
            minesweeperHUDAnimations.mapBorderYAnimations[negativeIndex]:Render(Vector(centerOfMap.X + xOffset - 0.5, centerOfMap.Y - yOffset))
        end

        local cornerXOffset = (MAP_RADIUS_WITH_CUTOFF * scaledCellWidth) + ((scaledCellWidth / 2) - 1)
        local cornerYOffset = (MAP_RADIUS_WITH_CUTOFF * scaledCellHeight) + ((scaledCellHeight / 2) - 1)

        minesweeperHUDAnimations.mapBorderCornerAnimations[1].Scale = Vector(scale, scale)
        minesweeperHUDAnimations.mapBorderCornerAnimations[2].Scale = Vector(scale, scale)
        minesweeperHUDAnimations.mapBorderCornerAnimations[3].Scale = Vector(scale, scale)
        minesweeperHUDAnimations.mapBorderCornerAnimations[4].Scale = Vector(scale, scale)

        minesweeperHUDAnimations.mapBorderCornerAnimations[1]:Render(Vector(centerOfMap.X + cornerXOffset, centerOfMap.Y + cornerYOffset))
        minesweeperHUDAnimations.mapBorderCornerAnimations[2]:Render(Vector(centerOfMap.X - cornerXOffset, centerOfMap.Y + cornerYOffset))
        minesweeperHUDAnimations.mapBorderCornerAnimations[3]:Render(Vector(centerOfMap.X + cornerXOffset, centerOfMap.Y - cornerYOffset))
        minesweeperHUDAnimations.mapBorderCornerAnimations[4]:Render(Vector(centerOfMap.X - cornerXOffset, centerOfMap.Y - cornerYOffset))
    end
end)

minesweeperMod:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
    if not minesweeperData.hasWon and not minesweeperData.hasLost then
        if Isaac.GetFrameCount() % 60 == 0 then
            minesweeperData.timer = minesweeperData.timer + 1
        end
    end

    if minesweeper.HasWon(minesweeperData.grid) then
        local allFinished = true
        helpers.ForEachPlayer(function(p)
            if not p:IsExtraAnimationFinished() then
                allFinished = false
            end
        end)

        if allFinished then
            minesweeperData.hasWon = true
            minesweeperHUDAnimations.smiley:Play("Cool")
        end
    end

    helpers.ForEachPlayer(function(p, data)
        if data.isUsingShovel and p:IsExtraAnimationFinished() then
            data.isUsingShovel = nil

            if minesweeperData.hasLost then
                minesweeperHUDAnimations.smiley:Play("Dead")
            else
                minesweeperHUDAnimations.smiley:Play("Happy")
            end
        end
    end)
end)