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

local SIZE = 2
local NUM_MINES = 1

minesweeperData = {
    grid = nil,
    currentRoom = nil,
    timer = 0,
    hasWon = false,
    hasLost = false
}

minesweeperHUDAnimations = {}

local directionSpawnPositions = {
    Vector(560, 280),
    Vector(320, 400),
    Vector(80, 280),
    Vector(320, 160)
}

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
        minesweeperData.grid = minesweeper.GenerateMinesweeperGrid(SIZE, NUM_MINES)
        minesweeperData.timer = 0
        minesweeperData.hasWOn = false
        minesweeperData.hasLost = false
        Isaac.ExecuteCommand("goto d.".."2500")
        helpers.SaveData(minesweeperData)
    end
end)

minesweeperMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()
    local room = Game():GetRoom()

    for i = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
        room:RemoveDoor(i)
    end

    if not minesweeperData.currentRoom then
        minesweeperData.currentRoom = { x = rng:RandomInt(SIZE) + 1, y = rng:RandomInt(SIZE) + 1, direction = Direction.NO_DIRECTION }
    end

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

local TOP_HUD_OFFSET = 35
local TOP_HUD_WIDTH = 1 / 2.5
local TOP_HUD_FONT_SIZE = 1.4

minesweeperMod:AddCallback(ModCallbacks.MC_POST_RENDER, function()
    if minesweeperData.currentRoom then
        local currentCell = minesweeperData.grid[minesweeperData.currentRoom.x][minesweeperData.currentRoom.y]

        if currentCell.isRevealed and not currentCell.isMine then
            local worldToScreenVector = Isaac.WorldToScreen(Game():GetRoom():GetCenterPos())
            helpers.RenderCenteredText(tostring(currentCell.touchingMines), worldToScreenVector.X, worldToScreenVector.Y, 4, KColor(1, 1, 1, 1))
        end

        if currentCell.isFlagged then
            Isaac.RenderText("Room is flagged!", 50, 65, 1, 1, 1, 1)
        end

        local screenSize = helpers.GetScreenSizeVector()

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