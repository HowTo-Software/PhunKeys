if isClient() then
    return
end

require "PhunKeys_Shared"

local function log(message)
    print("[PhunKeys] " .. tostring(message))
end

local function isNearVehicle(player, vehicle)
    local dx = player:getX() - vehicle:getX()
    local dy = player:getY() - vehicle:getY()

    return dx * dx + dy * dy <=
        PhunKeys.maxDistance * PhunKeys.maxDistance
end

local function vehicleIsEmpty(vehicle)
    local passengers = vehicle:getMaxPassengers()

    for seat = 0, passengers - 1 do
        if vehicle:getCharacter(seat) then
            return false
        end
    end

    return true
end

local function vehicleStorageIsEmpty(vehicle)
    for index = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(index)

        if part then
            local container = part:getItemContainer()

            if container and not container:getItems():isEmpty() then
                return false
            end
        end
    end

    return true
end

local function findBox(player, boxId)
    local inventory = player:getInventory()
    local items = inventory:getItems()

    for index = 0, items:size() - 1 do
        local item = items:get(index)

        if item
            and item:getID() == boxId
            and item:getFullType() == PhunKeys.boxItemType then

            return item
        end
    end

    return nil
end

local function carKeyInBox(box)
    local inventory = box:getInventory()

    if not inventory then
        log("Box has no internal inventory.")
        return nil
    end

    local items = inventory:getItems()

    if items:size() ~= 1 then
        log("Box must contain exactly one item. Found: " .. tostring(items:size()))
        return nil
    end

    local key = items:get(0)

    if not key then
        log("Box item was nil.")
        return nil
    end

    log(
        "Box contains "
        .. tostring(key:getFullType())
        .. " keyId="
        .. tostring(key:getKeyId())
    )

    if key:getFullType() ~= "Base.CarKey" then
        log("Item is not Base.CarKey.")
        return nil
    end

    if key:getKeyId() == -1 then
        log("Car key has invalid key ID.")
        return nil
    end

    return key
end

local function vehicleForKey(player, keyId)
    local vehicles = getCell():getVehicles()

    if not vehicles then
        log("getCell():getVehicles() returned nil.")
        return nil
    end

    log(
        "Searching "
        .. tostring(vehicles:size())
        .. " loaded vehicles for keyId="
        .. tostring(keyId)
    )

    local iterator = vehicles:iterator()

    while iterator:hasNext() do
        local vehicle = iterator:next()

        if vehicle then
            local vehicleKeyId = vehicle:getKeyId()

            if vehicleKeyId == keyId then
                log("Found vehicle matching key ID.")

                if not isNearVehicle(player, vehicle) then
                    log("Matching vehicle is too far away.")
                    return nil
                end

                if not vehicleIsEmpty(vehicle) then
                    log("Matching vehicle has an occupant.")
                    return nil
                end

                if not vehicleStorageIsEmpty(vehicle) then
                    log("Matching vehicle contains stored items.")
                    return nil
                end

                return vehicle
            end
        end
    end

    log("No loaded vehicle matched key ID.")
    return nil
end

local function packVehicle(player, arguments)
    log("Received packVehicle request from " .. tostring(player:getUsername()))

    if not arguments then
        log("No command arguments received.")
        return
    end

    local boxId = tonumber(arguments.boxId)

    if not boxId then
        log("Invalid box ID.")
        return
    end

    log("Looking for box ID " .. tostring(boxId))

    local box = findBox(player, boxId)

    if not box then
        log("Could not find Vehicle Conversion Box in player inventory.")
        return
    end

    log("Conversion Box found.")

    local key = carKeyInBox(box)

    if not key then
        return
    end

    local keyId = key:getKeyId()
    local vehicle = vehicleForKey(player, keyId)

    if not vehicle then
        return
    end

    log("All checks passed. Beginning conversion.")

    local boxInventory = box:getInventory()

    -- Remove original car key.
    if boxInventory:contains(key) then
        boxInventory:Remove(key)
        sendRemoveItemFromContainer(boxInventory, key)
    else
        log("Key vanished from box before removal.")
        return
    end

    -- Create sellable trade-in key.
    local sellerKey = boxInventory:AddItem(PhunKeys.itemType)

    if not sellerKey then
        log("FAILED to create " .. tostring(PhunKeys.itemType))

        local restoredKey = boxInventory:AddItem("Base.CarKey")

        if restoredKey then
            restoredKey:setKeyId(keyId)
            sendAddItemToContainer(boxInventory, restoredKey)
        end

        return
    end

    sendAddItemToContainer(boxInventory, sellerKey)

    log("Created Vehicle Trade-In Key.")

    -- Remove the actual vehicle.
    log("Removing vehicle.")
    vehicle:permanentlyRemove()

    log("Vehicle conversion complete.")

    sendServerCommand(
        player,
        PhunKeys.module,
        PhunKeys.playSoundCommand,
        {
            sound = "PhunKeys_KeyRemove"
        }
    )
end

Events.OnClientCommand.Add(function(module, command, player, arguments)
    if module ~= PhunKeys.module then
        return
    end

    if command == PhunKeys.command then
        packVehicle(player, arguments)
    end
end)

log("Server Lua loaded.")