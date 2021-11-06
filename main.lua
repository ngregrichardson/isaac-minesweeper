minesweeperMod = RegisterMod("Minesweeper", 1)

minesweeperMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()
    local room = Game():GetRoom()

    for i = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
        room:RemoveDoor(i)
    end

    for i = 0, DoorSlot.DOWN0 do
        local doorPosition = room:GetDoorSlotPosition(i)
        room:SpawnGridEntity(room:GetClampedGridIndex(doorPosition), 8460, 0, 0, 0)
    end
end)