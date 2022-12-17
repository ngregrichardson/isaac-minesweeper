local json = include("json")
local H = {}

function H.SaveData(value)
    minesweeperMod:SaveData(json.encode(value))
end

function H.LoadData()
    if minesweeperMod:HasData() then
        return json.decode(minesweeperMod:LoadData())
    end
end

function H.SaveKey(key, value)
    local savedData = {}
    if minesweeperMod:HasData() then
        savedData = json.decode(minesweeperMod:LoadData())
    end
    savedData[key] = value
    minesweeperMod:SaveData(json.encode(savedData))
end

function H.LoadKey(key)
    if minesweeperMod:HasData() then
        return json.decode(minesweeperMod:LoadData())[key]
    end
end

function H.SpawnDoor(doorSlot, x, y)
    local startingDirection = 270
    local room = Game():GetRoom()
    local doorPosition = room:GetDoorSlotPosition(doorSlot)
    room:GetGridEntityFromPos(doorPosition).CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
    local coolDoor = Isaac.Spawn(678, 0, 0, doorPosition, Vector.Zero, nil)
    coolDoor.SpriteRotation = startingDirection + (90 * doorSlot)
    coolDoor.Friction = 0
    coolDoor:AddEntityFlags(EntityFlag.FLAG_NO_KNOCKBACK | EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
    coolDoor:GetData().nextRoom = { x = x, y = y, direction = doorSlot }
    coolDoor:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
    coolDoor.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
    coolDoor.DepthOffset = -10000

    return coolDoor
end

function H.CloseDoors()
    local doors = Isaac.FindByType(678, 0, 0)
    for _, door in pairs(doors) do
        Game():GetRoom():GetGridEntityFromPos(door.Position).CollisionClass = GridCollisionClass.COLLISION_WALL
        door:GetSprite():Play("Close")
        door:GetData().isClosed = true
    end
end

function H.ForEachPlayer(callback, collectibleId)
    local shouldReturn = nil
    for x = 0, Game():GetNumPlayers() - 1 do
        local p = Isaac.GetPlayer(x)
        if not collectibleId or (collectibleId and p:HasCollectible(collectibleId)) then
            p = Isaac.GetPlayer(x)
            if callback(p, p:GetData()) == false then
                shouldReturn = false
            end
        end
    end
    return shouldReturn
end

function H.ExplodeRoom()
    minesweeperMod.minesweeperHUDAnimations.smiley:Play("Dead")
    Game():GetRoom():MamaMegaExplosion(H.GetMine().Position)
    for i = 0, Game():GetNumPlayers() - 1 do
        local p = Isaac.GetPlayer(i)
        p:TakeDamage(1, DamageFlag.DAMAGE_EXPLOSION, EntityRef(H.GetMine()), 0)
        p:Die()
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BOMB_EXPLOSION, 0, p.Position, Vector.Zero, H.GetMine())
    end
end

function H.RenderCenteredText(content, x, y, scale, color)
    minesweeperMod.font:DrawStringScaled(content, x - 1, y - minesweeperMod.font:GetLineHeight() * 2, scale, scale, color
        , 1, true)
end

function H.GetScreenSizeVector()
    return Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2)
end

function H.RegisterSprite(anm2Root, sprRoot, anmName)
    local sprite = Sprite()
    sprite:Load(anm2Root, true)
    sprite:Play(anmName and anmName or sprite:GetDefaultAnimationName(), true)
    sprite:Update()
    if sprRoot then sprite:ReplaceSpritesheet(0, sprRoot) end
    sprite:LoadGraphics()

    return sprite
end

function H.RevealFloorTile()
    local tile
    for _, entity in pairs(Isaac.GetRoomEntities()) do
        if entity.Type == Isaac.GetEntityTypeByName("Minesweeper Floor") then
            tile = entity
        end
    end

    if tile then
        local sprite = tile:GetSprite()
        local currentCell = minesweeperMod.data.grid[minesweeperMod.data.currentRoom.y][
            minesweeperMod.data.currentRoom.x]

        if currentCell.isMine then
            Isaac.Spawn(EntityType.ENTITY_EFFECT, Isaac.GetEntityVariantByName("Minesweeper Mine"), 0, tile.Position,
                Vector.Zero, nil)
            if minesweeperMod.rng:RandomInt(100) < 1 then
                SFXManager():Play(Isaac.GetSoundIdByName("GusDeath"))
            end
        else
            if currentCell.touchingMines > 0 then
                sprite:ReplaceSpritesheet(1, "gfx/floor" .. currentCell.touchingMines .. ".png")
                sprite:LoadGraphics()
                sprite:Play("Revealing")
            end
        end
    end
end

function H.GetMine()
    local mine
    for _, entity in pairs(Isaac.GetRoomEntities()) do
        if entity.Variant == Isaac.GetEntityVariantByName("Minesweeper Mine") then
            mine = entity
        end
    end

    return mine
end

function H.GetFlag()
    local flag
    for _, entity in pairs(Isaac.GetRoomEntities()) do
        if entity.Variant == Isaac.GetEntityVariantByName("Minesweeper Flag") then
            flag = entity
        end
    end

    return flag
end

function H.GetFrameCount(sprite)
    local newSprite = Sprite()
    newSprite:Load(sprite:GetFilename())
    newSprite:Play(sprite:GetAnimation())
    local currentFrame = newSprite:GetFrame()
    local lastFrame = 0

    newSprite:SetLastFrame()
    newSprite:Update()
    lastFrame = newSprite:GetFrame()
    newSprite:SetFrame(currentFrame)
    newSprite:Update()

    return lastFrame
end

function H.IsInChallenge()
    for name in pairs(minesweeperMod.challenges) do
        local id = Isaac.GetChallengeIdByName(name)

        if Isaac.GetChallenge() == id then
            return true
        end
    end
end

function H.GetChallengeDetails()
    for name, details in pairs(minesweeperMod.challenges) do
        local id = Isaac.GetChallengeIdByName(name)

        if Isaac.GetChallenge() == id then
            return details
        end
    end
end

return H
