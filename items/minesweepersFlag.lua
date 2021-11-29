local Name = "Minesweeper's Flag"
local Tag = "minesweepersFlag"
local Id = Isaac.GetItemIdByName(Name)

local function MC_USE_ITEM(_, type, rng, p)
    local currentCell = minesweeperData.grid[minesweeperData.currentRoom.y][minesweeperData.currentRoom.x]
    if currentCell.isRevealed or minesweeperData.hasWon or minesweeperData.hasLost then return end

    currentCell.isFlagged = not currentCell.isFlagged
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