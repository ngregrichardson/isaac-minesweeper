
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
    minesweeperHUDAnimations.smiley:Play("Dead")
    for i = 0, 1000 do
        Isaac.ExecuteCommand("spawn 4.4")
    end
end

function H.RenderCenteredText(content, x, y, scale, color)
    font:DrawStringScaled(content, x - 1, y - font:GetLineHeight() * 2, scale, scale, color, 1, true)
end

function H.GetScreenSizeVector()
    local room = Game():GetRoom()
    local pos = room:WorldToScreenPosition(Vector(0,0)) - room:GetRenderScrollOffset() - Game().ScreenShakeOffset
    
    local rx = pos.X + 60 * 26 / 40
    local ry = pos.Y + 140 * (26 / 40)
    
    return Vector(rx*2 + 13*26, ry*2 + 7*26)
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

return H