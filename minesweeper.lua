local M = {}

local function CountMines(grid)
    local mines = 0

    for _, col in pairs(grid) do
        for _, cell in pairs(col) do
            if cell.isMine then
                mines = mines + 1
            end
        end
    end

    return mines
end

local function CountUnopenedCells(grid)
    local cells = 0

    for _, col in pairs(grid) do
        for _, cell in pairs(col) do
            if cell.isFlagged or not cell.isRevealed then
                cells = cells + 1
            end
        end
    end

    return cells
end

local function GenerateMineLayout(size, numMines)
    local rng = RNG()
    
    local mineLocations = {}
    
    local i = 1

    Isaac.DebugString("starting with " .. numMines .. " mines")
    
    while i <= numMines do
        local xLocation = rng:RandomInt(size) + 1
        local yLocation = rng:RandomInt(size) + 1

        Isaac.DebugString("x: "..xLocation.." | y: "..yLocation)
        
        if #mineLocations == 0 then
            table.insert(mineLocations, { x = xLocation, y = yLocation })
            i = i + 1
        else
            local found = false
            for _, value in pairs(mineLocations) do
                if xLocation == value.x and yLocation == value.y then
                    found = true
                    break
                end
            end
            
            if not found then
                table.insert(mineLocations, { x = xLocation, y = yLocation })
                i = i + 1
            end
        end
    end
    
    return mineLocations
end

local function CreateBlankCell(x, y)
    return {
        x = x,
        y = y,
        isFlagged = false,
        isMine = false,
        isRevealed = false,
        touchingMines = 0,
        hasVisited = false
    }
end

function M.GenerateMinesweeperGrid(size, numMines)
    local grid = {}
    
    for i = 1, size do
        local col = {}
        for j = 1, size do
            table.insert(col, CreateBlankCell(j, i))
        end
        table.insert(grid, col)
    end
    
    local mineLocations = GenerateMineLayout(size, numMines)
    
    for _, cell in pairs(mineLocations) do
        local mineCell = grid[cell.y][cell.x]
        mineCell.isMine = true
        
        local neighboringCells = {}
        
        local hasLeftCells = mineCell.x > 1
        local hasTopCells = mineCell.y > 1
        local hasRightCells = mineCell.x < size
        local hasBottomCells = mineCell.y < size
        
        if hasLeftCells then
            table.insert(neighboringCells, grid[mineCell.y][mineCell.x - 1])
            
            if hasTopCells then
                table.insert(neighboringCells, grid[mineCell.y - 1][mineCell.x - 1])
            end
            
            if hasBottomCells then
                table.insert(neighboringCells, grid[mineCell.y + 1][mineCell.x - 1])
            end
        end
        
        if hasRightCells then
            table.insert(neighboringCells, grid[mineCell.y][mineCell.x + 1])
            
            if hasTopCells then
                table.insert(neighboringCells, grid[mineCell.y - 1][mineCell.x + 1])
            end
            
            if hasBottomCells then
                table.insert(neighboringCells, grid[mineCell.y + 1][mineCell.x + 1])
            end
        end
        
        if hasTopCells then
            table.insert(neighboringCells, grid[mineCell.y - 1][mineCell.x])
        end
        
        if hasBottomCells then
            table.insert(neighboringCells, grid[mineCell.y + 1][mineCell.x])
        end
        
        for _, neighboringCell in pairs(neighboringCells) do
            neighboringCell.touchingMines = neighboringCell.touchingMines + 1
        end
    end
    
    return grid
end

function M.CalculateScore(grid)
    local score = CountMines(grid)
    for _, col in pairs(grid) do
        for _, cell in pairs(col) do
            if cell.isFlagged then
                score = score - 1
            end
        end
    end

    return score
end

function M.RevealNeighboringZeros(grid, cell)
    if not cell.isMine then
        if cell and not cell.isRevealed and not cell.isFlagged then
            cell.isRevealed = true
            if cell.touchingMines == 0 then
                if cell.x > 1 then
                    M.RevealNeighboringZeros(grid, grid[cell.y][cell.x - 1])
                end

                if cell.y > 1 then
                    M.RevealNeighboringZeros(grid, grid[cell.y - 1][cell.x])
                end

                if cell.y < #grid then
                    M.RevealNeighboringZeros(grid, grid[cell.y + 1][cell.x])
                end

                if cell.x < #grid[1] then
                    M.RevealNeighboringZeros(grid, grid[cell.y][cell.x + 1])
                end
            end
        end
    end
end

function M.HasWon(grid)
    return CountMines(grid) == CountUnopenedCells(grid)
end

return M