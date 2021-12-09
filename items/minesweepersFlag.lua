local helpers = include("helpers")

local Name = "Minesweeper's Flag"
local Tag = "minesweepersFlag"
local Id = Isaac.GetItemIdByName(Name)

local function MC_USE_ITEM(_, type, rng, p)
    local currentCell = minesweeperData.grid[minesweeperData.currentRoom.y][minesweeperData.currentRoom.x]
    if currentCell.isRevealed or minesweeperData.hasWon or minesweeperData.hasLost then return end

    currentCell.isFlagged = not currentCell.isFlagged

    local existingFlag = helpers.GetFlag()

    if currentCell.isFlagged then
        if existingFlag then
            local flagSprite = existingFlag:GetSprite()

            if flagSprite:IsPlaying("Exit") then
                local previousFrame = flagSprite:GetFrame()
                flagSprite:Play("Emerge")
                flagSprite:SetFrame(helpers.GetFrameCount(flagSprite) - previousFrame)
            else
                flagSprite:Play("Emerge")
            end
        else
            existingFlag = Isaac.Spawn(EntityType.ENTITY_EFFECT, Isaac.GetEntityVariantByName("Minesweeper Flag"), 0, Game():GetRoom():GetCenterPos(), Vector.Zero, nil)
            local flagSprite = existingFlag:GetSprite()
            flagSprite:Play("Emerge")
        end
    else
        if existingFlag then
            local flagSprite = existingFlag:GetSprite()

            if flagSprite:IsPlaying("Emerge") then
                local previousFrame = flagSprite:GetFrame()
                flagSprite:Play("Exit")
                flagSprite:SetFrame(helpers.GetFrameCount(flagSprite) - previousFrame)
            else
                flagSprite:Play("Exit")
            end
        end
    end
end

return {
    Name = Name,
    Tag = Tag,
	Id = Id,
    callbacks = {
        {
            ModCallbacks.MC_USE_ITEM,
            MC_USE_ITEM,
            Id
        }
    }
}