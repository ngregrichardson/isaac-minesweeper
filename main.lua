minesweeperMod = RegisterMod("Minesweeper", 1)

minesweeperMod.font = Font()
minesweeperMod.font:Load("font/terminus.fnt")

local items = include("items/registry")
local helpers = include("helpers")
local minesweeper = include("minesweeper.lua")

minesweeperMod.rng = RNG()

minesweeperMod.challenges = {
    ["Minesweeper 8x8"] = {
        width = 8,
        height = 8,
        mines = 10
    },
    ["Minesweeper 9x9"] = {
        width = 9,
        height = 9,
        mines = 10
    },
    ["Minesweeper 10x10"] = {
        width = 10,
        height = 10,
        mines = 10
    },
    ["Minesweeper 15x13"] = {
        width = 15,
        height = 13,
        mines = 40
    },
    ["Minesweeper 16x16"] = {
        width = 16,
        height = 16,
        mines = 10
    },
    ["Minesweeper 26x16"] = {
        width = 26,
        height = 16,
        mines = 99
    }
}

for _, item in pairs(items) do
    if item.callbacks then
        for _, callback in pairs(item.callbacks) do
            minesweeperMod:AddCallback(table.unpack(callback))
        end
    end
end

local TOP_HUD_OFFSET = 35
local TOP_HUD_WIDTH = 1 / 2.5
local TOP_HUD_FONT_SIZE = 1.4

local MAP_ROOM_WIDTH = 9
local MAP_ROOM_HEIGHT = 8
local MAP_RADIUS = 2
local MAP_RADIUS_WITH_CUTOFF = MAP_RADIUS + 1
local MAP_NUMBER_OF_EDGES = ((MAP_RADIUS_WITH_CUTOFF * 2) + 1) * 2

minesweeperMod.data = {
    grid = nil,
    currentRoom = nil,
    timer = 0,
    hasWon = false,
    hasLost = false,
    isMapEnlarged = false,
    hasSpawnedTrophy = false,
    width = 0,
    height = 0,
    mines = 0,
    hasTouched = false
}

minesweeperMod.minesweeperHUDAnimations = {
    mapBorderXAnimations = {},
    mapBorderYAnimations = {},
}

local minesweeperData = minesweeperMod.data
local minesweeperHUDAnimations = minesweeperMod.minesweeperHUDAnimations

local directionSpawnPositions = {
    Vector(560, 280),
    Vector(320, 400),
    Vector(80, 280),
    Vector(320, 160)
}

local function InitializeStartupGrid()
    local challenge = helpers.GetChallengeDetails()

    minesweeperData.width = challenge.width
    minesweeperData.height = challenge.height
    minesweeperData.mines = challenge.mines
    minesweeperData.grid = helpers.InitializeGridSprites(minesweeper.GenerateBlankGrid(minesweeperData.width,
        minesweeperData.height))
    minesweeperData.timer = 0
    minesweeperData.hasWon = false
    minesweeperData.hasLost = false
    minesweeperData.hasTouched = false
    minesweeperData.currentRoom = minesweeper.GetRandomCell(minesweeperData.width, minesweeperData.height)
end

local function InitializeGame(isContinued)
    local game = Game()
    minesweeperMod.rng:SetSeed(game:GetSeeds():GetStartSeed(), 35)

    game:GetHUD():SetVisible(false)

    game:GetLevel():SetStage(LevelStage.STAGE1_1, StageType.STAGETYPE_ORIGINAL)

    local p = Isaac.GetPlayer(0)

    for i = 0, 3 do
        p:SetCard(i, 0)
    end

    p:AddCollectible(items.minesweepersShovel.Id)
    p:SetPocketActiveItem(items.minesweepersFlag.Id, ActiveSlot.SLOT_POCKET, true)
    p:AddBombs(-p:GetNumBombs())
    p:AddCacheFlags(CacheFlag.CACHE_SPEED)
    p:EvaluateItems()

    local saveData = helpers.LoadData()

    minesweeperHUDAnimations.smiley = helpers.RegisterSprite("gfx/ui/smileys.anm2")
    minesweeperHUDAnimations.shovel = helpers.RegisterSprite("gfx/items/collectibles/minesweeper_item.anm2",
        "gfx/items/collectibles/shovel.png")
    minesweeperHUDAnimations.flag = helpers.RegisterSprite("gfx/items/collectibles/minesweeper_item.anm2",
        "gfx/items/collectibles/flag.png")

    if isContinued and saveData then
        minesweeperMod.data = saveData
        minesweeperData = minesweeperMod.data
    else
        InitializeStartupGrid()
        minesweeperData = minesweeperMod.data
        Isaac.ExecuteCommand("goto d." .. "2500")
    end

    for _ = 0, minesweeperData.width * minesweeperData.height do
        table.insert(minesweeperHUDAnimations.mapBorderXAnimations,
            helpers.RegisterSprite("gfx/ui/map_background.anm2", nil, "CellXBorder"))
        table.insert(minesweeperHUDAnimations.mapBorderYAnimations,
            helpers.RegisterSprite("gfx/ui/map_background.anm2", nil, "CellYBorder"))
    end
end

minesweeperMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContinued)
    if helpers.IsInChallenge() then
        InitializeGame(isContinued)
    end
end)

minesweeperMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, function(_, p, f)
    p.MoveSpeed = 2
end, CacheFlag.CACHE_SPEED)

local function InitializeRoom()
    local room = Game():GetRoom()

    for i = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
        room:RemoveDoor(i)
    end

    if not minesweeperData.grid then
        InitializeStartupGrid()
    end

    local currentCell = minesweeperData.grid[minesweeperData.currentRoom.y][minesweeperData.currentRoom.x]

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

    if minesweeperData.currentRoom.x < minesweeperData.width then
        local door = helpers.SpawnDoor(DoorSlot.RIGHT0, minesweeperData.currentRoom.x + 1, minesweeperData.currentRoom.y)
        door.Position = door.Position + Vector(offset, 0)
        door:GetSprite().Offset = Vector(-offset * 2, 0)
    end

    if minesweeperData.currentRoom.y < minesweeperData.height then
        local door = helpers.SpawnDoor(DoorSlot.DOWN0, minesweeperData.currentRoom.x, minesweeperData.currentRoom.y + 1)
        door.Position = door.Position + Vector(0, offset)
        door:GetSprite().Offset = Vector(0, -offset * 2)
    end

    if minesweeperData.currentRoom and minesweeperData.currentRoom.direction and minesweeperData.currentRoom.direction > -1 then
        helpers.ForEachPlayer(function(p)
            p.Position = directionSpawnPositions[minesweeperData.currentRoom.direction + 1]
        end)
    end

    local floorTile = Isaac.Spawn(Isaac.GetEntityTypeByName("Minesweeper Floor"), 0, 0, room:GetCenterPos(), Vector.Zero
        , nil)
    floorTile.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
    floorTile.DepthOffset = -10000
    floorTile:AddEntityFlags(EntityFlag.FLAG_NO_BLOOD_SPLASH | EntityFlag.FLAG_NO_FLASH_ON_DAMAGE |
        EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK | EntityFlag.FLAG_NO_KNOCKBACK)
    floorTile:ClearEntityFlags(EntityFlag.FLAG_APPEAR)

    if currentCell.isRevealed then
        if not currentCell.isMine and currentCell.touchingMines > 0 then
            local floorTileSprite = floorTile:GetSprite()
            floorTileSprite:ReplaceSpritesheet(1, "gfx/floor" .. currentCell.touchingMines .. ".png")
            floorTileSprite:LoadGraphics()
            floorTileSprite:Play("Revealed")
        end
    end

    if currentCell.isFlagged then
        local flag = Isaac.Spawn(EntityType.ENTITY_EFFECT, Isaac.GetEntityVariantByName("Minesweeper Flag"), 0,
            room:GetCenterPos(), Vector.Zero, nil)
        flag:AddEntityFlags(EntityFlag.FLAG_NO_BLOOD_SPLASH | EntityFlag.FLAG_NO_FLASH_ON_DAMAGE |
            EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK | EntityFlag.FLAG_NO_KNOCKBACK)
        flag:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
        local flagSprite = flag:GetSprite()
        flagSprite:Play("Idle")
    end
end

minesweeperMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()
    if helpers.IsInChallenge() then
        InitializeRoom()
    end
end)

minesweeperMod:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, function(_, entity, collider)
    if helpers.IsInChallenge() then
        local p = collider:ToPlayer()
        if p then
            local data = entity:GetData()
            if not data.isClosed then
                minesweeperData.currentRoom = data.nextRoom
                Isaac.ExecuteCommand("goto d." .. "2500")
            end
        end
    end
end, 678)

minesweeperMod:AddCallback(ModCallbacks.MC_POST_RENDER, function()
    if helpers.IsInChallenge() and minesweeperData.currentRoom then
        local currentCell = minesweeperData.grid[minesweeperData.currentRoom.y][minesweeperData.currentRoom.x]

        local screenSize = Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight())

        if Input.IsActionTriggered(ButtonAction.ACTION_MAP, 0) then
            minesweeperData.isMapEnlarged = not minesweeperData.isMapEnlarged
        end

        local isMapEnlarged = minesweeperData.isMapEnlarged

        local hudOpacity = 1

        if isMapEnlarged then
            hudOpacity = 0.5
        end

        -- Items
        if not currentCell.isRevealed and not minesweeperData.hasWon and not minesweeperData.hasLost then
            local alpha = 1
            if currentCell.isFlagged then
                alpha = 0.3
            end

            minesweeperHUDAnimations.shovel.Color = Color(minesweeperHUDAnimations.shovel.Color.R,
                minesweeperHUDAnimations.shovel.Color.G, minesweeperHUDAnimations.shovel.Color.B,
                math.min(hudOpacity, alpha))
            
            minesweeperHUDAnimations.flag.Color = Color(minesweeperHUDAnimations.flag.Color.R,
                minesweeperHUDAnimations.flag.Color.G, minesweeperHUDAnimations.flag.Color.B,
                hudOpacity)

            minesweeperHUDAnimations.flag:Render(screenSize - Vector(20, 20))
            minesweeperHUDAnimations.shovel:Render(Vector(20, 20))
        end

        -- Map

        local scale = 1

        if isMapEnlarged then
            scale = 2
        end

        local scaledCellWidth = MAP_ROOM_WIDTH * scale
        local scaledCellHeight = MAP_ROOM_HEIGHT * scale

        local xPadding = (MAP_RADIUS_WITH_CUTOFF + 1) * scaledCellWidth
        local yPadding = (MAP_RADIUS_WITH_CUTOFF + 1) * scaledCellHeight
        local centerOfMap = Vector(screenSize.X - xPadding, yPadding)
        local xNumCellsRadius = MAP_RADIUS_WITH_CUTOFF
        local yNumCellsRadius = MAP_RADIUS_WITH_CUTOFF

        if isMapEnlarged then
            centerOfMap = screenSize / 2
            xNumCellsRadius = minesweeperData.width / 2 - 0.5
            yNumCellsRadius = minesweeperData.height / 2 - 0.5
        end

        for _, col in pairs(minesweeperData.grid) do
            for _, cell in pairs(col) do

                local xDiff = cell.x - currentCell.x
                local yDiff = cell.y - currentCell.y

                if isMapEnlarged or
                    math.abs(xDiff) <= xNumCellsRadius and math.abs(yDiff) <= yNumCellsRadius then

                    local cellPosition = Vector(centerOfMap.X + xDiff * scaledCellWidth - 0.5,
                        centerOfMap.Y + yDiff * scaledCellHeight)

                    if isMapEnlarged then
                        local cellPositionX = centerOfMap.X -
                            (((minesweeperData.width / 2) - (cell.x - 1)) * scaledCellWidth - (scaledCellWidth / 2))
                        cellPosition = Vector(cellPositionX, cellPosition.Y)
                    end

                    if isMapEnlarged then
                        local cellPositionY = centerOfMap.Y -
                            (((minesweeperData.height / 2) - (cell.y - 1)) * scaledCellHeight - (scaledCellHeight / 2))

                        cellPosition = Vector(cellPosition.X, cellPositionY)
                    end

                    local isCurrent = xDiff == 0 and yDiff == 0

                    local suffix = "Small"

                    if isMapEnlarged then
                        suffix = ""
                    end

                    if not isCurrent then
                        cell.mapCellSprite:Play("Visited" .. suffix)
                    end

                    if cell.isFlagged then
                        cell.mapCellIconSprite:Play("Flag")
                    elseif cell.isRevealed then
                        cell.mapCellSprite:Play("Unvisited" .. suffix)
                        cell.mapCellIconSprite:Play(tostring(cell.touchingMines))
                    else
                        cell.mapCellIconSprite:Play("None")
                    end

                    if cell.isMine and minesweeperData.hasLost and not cell.isFlagged then
                        cell.mapCellSprite:Play("Unvisited" .. suffix)
                        if isCurrent and cell.mapCellSprite.Color then
                            local color = cell.mapCellSprite.Color
                            local newColor = Color(color.R, color.G, color.B, color.A)
                            newColor:SetTint(1, 0, 0, 0.8)
                            cell.mapCellSprite.Color = newColor
                        end
                        cell.mapCellIconSprite:Play("Mine")
                    end

                    if isCurrent then
                        cell.mapCellSprite:Play("Current" .. suffix)
                    end

                    if isMapEnlarged then
                        cell.mapCellSprite.Color = Color(cell.mapCellSprite.Color.R, cell.mapCellSprite.Color.G,
                            cell.mapCellSprite.Color.B, 0.9)
                    end

                    cell.mapCellSprite:Render(cellPosition)
                    cell.mapCellIconSprite:Render(cellPosition - Vector(0, 0.5))
                end
            end
        end

        -- Map border

        local xNumOfEdges = MAP_NUMBER_OF_EDGES / 2
        local yNumOfEdges = MAP_NUMBER_OF_EDGES / 2

        if isMapEnlarged then
            xNumOfEdges = minesweeperData.width / 2 - 1
            yNumOfEdges = minesweeperData.height / 2 - 1
        end

        for i = -yNumCellsRadius, yNumCellsRadius do
            local index = i + yNumCellsRadius + 1
            local negativeIndex = math.floor(index + xNumOfEdges)

            local xOffset = xNumCellsRadius * scaledCellWidth + ((scaledCellWidth / 2) - 1)
            local yOffset = i * scaledCellHeight

            minesweeperHUDAnimations.mapBorderXAnimations[index].Scale = Vector(1, scale)
            minesweeperHUDAnimations.mapBorderXAnimations[negativeIndex].Scale = Vector(1, scale)

            minesweeperHUDAnimations.mapBorderXAnimations[index]:Render(Vector(centerOfMap.X + xOffset,
                centerOfMap.Y + yOffset))
            minesweeperHUDAnimations.mapBorderXAnimations[negativeIndex]:Render(Vector(centerOfMap.X - xOffset,
                centerOfMap.Y + yOffset))
        end

        for i = -xNumCellsRadius, xNumCellsRadius do
            local index = i + xNumCellsRadius + 1
            local negativeIndex = math.floor(index + yNumOfEdges)

            local xOffset = i * scaledCellWidth
            local yOffset = yNumCellsRadius * scaledCellHeight + ((scaledCellHeight / 2) - 1)

            minesweeperHUDAnimations.mapBorderYAnimations[index].Scale = Vector(scale, 1)
            minesweeperHUDAnimations.mapBorderYAnimations[negativeIndex].Scale = Vector(scale, 1)

            local padding = 0.5
            if isMapEnlarged then
                padding = 1
            end

            minesweeperHUDAnimations.mapBorderYAnimations[index]:Render(Vector(centerOfMap.X + xOffset - padding,
                centerOfMap.Y + yOffset))
            minesweeperHUDAnimations.mapBorderYAnimations[negativeIndex]:Render(Vector(centerOfMap.X + xOffset - padding
                , centerOfMap.Y - yOffset))
        end

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
                    scoreDisplay = "0" .. tostring(score)
                else
                    scoreDisplay = tostring(score)
                end
            else
                scoreDisplay = "00" .. tostring(score)
            end
        elseif score <= 99 then
            scoreDisplay = "0" .. tostring(score)
        else
            scoreDisplay = tostring(score)
        end
        helpers.RenderCenteredText(scoreDisplay, screenSize.X * TOP_HUD_WIDTH, TOP_HUD_OFFSET, TOP_HUD_FONT_SIZE,
            KColor(1, 0, 0, hudOpacity))

        -- Smiley
        local smileyColor = minesweeperHUDAnimations.smiley.Color
        minesweeperHUDAnimations.smiley.Color = Color(smileyColor.R, smileyColor.G, smileyColor.B, hudOpacity)
        minesweeperHUDAnimations.smiley:Render(Vector(screenSize.X / 2, TOP_HUD_OFFSET / 2))

        -- Render timer
        local timerDisplay = ""
        if minesweeperData.timer <= 9 then
            timerDisplay = "00" .. tostring(minesweeperData.timer)
        elseif minesweeperData.timer <= 99 then
            timerDisplay = "0" .. tostring(minesweeperData.timer)
        else
            timerDisplay = tostring(minesweeperData.timer)
        end
        helpers.RenderCenteredText(timerDisplay, screenSize.X - (screenSize.X * TOP_HUD_WIDTH), TOP_HUD_OFFSET,
            TOP_HUD_FONT_SIZE, KColor(1, 0, 0, hudOpacity))
    end
end)

minesweeperMod:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
    if helpers.IsInChallenge() then
        if not minesweeperData.hasWon and not minesweeperData.hasLost and minesweeperData.hasTouched then
            if Isaac.GetFrameCount() % 60 == 0 then
                minesweeperData.timer = minesweeperData.timer + 1
            end
        end

        if not minesweeperData.hasWon and minesweeper.HasWon(minesweeperData.grid) then
            local allFinished = true
            helpers.ForEachPlayer(function(p)
                if not p:IsExtraAnimationFinished() then
                    allFinished = false
                end
            end)

            if allFinished then
                helpers.CloseDoors()
                minesweeperData.hasWon = true
                minesweeperHUDAnimations.smiley:Play("Cool")
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TROPHY, 0, Game():GetRoom():GetCenterPos(),
                    Vector.Zero, nil)
            end
        end

        if minesweeperData.hasWon then
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
        end
    end
end)

minesweeperMod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, function(_, effect)
    local sprite = effect:GetSprite()

    if sprite:IsFinished("Emerge") then
        sprite:Play("Pulse")
    end

    if sprite:IsFinished("Pulse") then
        helpers.ExplodeRoom()
        effect:Remove()
    end
end, Isaac.GetEntityVariantByName("Minesweeper Mine"))

minesweeperMod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, function(_, effect)
    local sprite = effect:GetSprite()

    if sprite:IsFinished("Emerge") then

        sprite:Play("Idle")
    end

    if sprite:IsFinished("Exit") then
        effect:Remove()
    end
end, Isaac.GetEntityVariantByName("Minesweeper Flag"))

minesweeperMod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function(_, shouldSave)
    if shouldSave then
        helpers.SaveData(minesweeperData)
    end
end)
