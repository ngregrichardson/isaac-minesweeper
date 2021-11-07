local helpers = include("helpers")

local Name = "Minesweeper's Shovel"
local Tag = "minesweepersShovel"
local Id = Isaac.GetItemIdByName(Name)

local function MC_USE_ITEM(_, type, rng, p)
    if minesweeperData.hasWon or minesweeperData.hasLost then return end

    local currentCell = minesweeperData.grid[minesweeperData.currentRoom.x][minesweeperData.currentRoom.y]

    if currentCell.isFlagged then
        SFXManager():Play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ)
        return
    end

    if currentCell.isMine then
        -- spawn bombs
        minesweeperData.hasLost = true
        helpers.CloseDoors()
        helpers.ExplodeRoom()
    else
        currentCell.isRevealed = true
    end

    p:GetData().isUsingShovel = true
    minesweeperHUDAnimations.smiley:Play("Scared")

    return true
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