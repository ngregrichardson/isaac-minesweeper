local helpers = include("helpers")
local minesweeper = include("minesweeper")

local Name = "Minesweeper's Shovel"
local Tag = "minesweepersShovel"
local Id = Isaac.GetItemIdByName(Name)

local function MC_USE_ITEM(_, type, rng, p)
    local minesweeperData = minesweeperMod.data
    local minesweeperHUDAnimations = minesweeperMod.minesweeperHUDAnimations

    if not minesweeperData.hasTouched then
        minesweeperData.hasTouched = true
        minesweeperData.grid = helpers.InitializeGridSprites(minesweeper.GenerateMinesweeperGrid(minesweeperData.width,
            minesweeperData.height, minesweeperData.mines, minesweeperData.currentRoom))
    end

    local currentCell = minesweeperData.grid[minesweeperData.currentRoom.y][minesweeperData.currentRoom.x]

    if currentCell.isRevealed or minesweeperData.hasWon or minesweeperData.hasLost then return end

    if currentCell.isFlagged then
        SFXManager():Play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ)
        return
    end

    if currentCell.isMine then
        -- spawn bombs
        minesweeperData.hasLost = true
        helpers.CloseDoors()
    else
        minesweeper.RevealNeighboringZeros(minesweeperData.grid, currentCell)
        currentCell.isRevealed = true
    end
    helpers.RevealFloorTile()

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
