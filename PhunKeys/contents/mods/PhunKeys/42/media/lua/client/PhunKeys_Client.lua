print("[PhunKeys][BOOT][DEBUG2] ENTER CLIENT PhunKeys_Client.lua")
if isServer() then
    return
end

require "ISUI/ISInventoryPaneContextMenu"
require "PhunKeys_Shared"
require "PhunKeys_Access"

local function clog(scope, message)
    print("[PhunKeys][CLIENT][" .. tostring(scope) .. "] " .. tostring(message))
end

local function safe(valueFn, fallback)
    local ok, value = pcall(valueFn)
    if ok then return value end
    return fallback or "<error>"
end

local function describeItem(item)
    if not item then return "<nil item>" end
    -- Avoid Java reflection here. B42 Java-backed inventory items do not expose
    -- getClass():getName() to Lua consistently, and even pcall() still pollutes
    -- console.txt with stack traces. Full type + item ID are enough to identify it.
    return "type=" .. tostring(safe(function() return item:getFullType() end, "<no getFullType>"))
        .. " id=" .. tostring(safe(function() return item:getID() end, "<no id>"))
end

function PhunKeys.packVehicleClient(player, box)
    if not box then
        clog("Action", "Transmute callback received nil box")
        return
    end
    clog("Action", "Transmute selected; boxId=" .. tostring(box:getID()))
    getSoundManager():PlaySound("PhunKeys_Transmute", false, 0):setVolume(0.50)
    sendClientCommand(player, PhunKeys.module, PhunKeys.command, { boxId = box:getID() })
end

function PhunKeys.grantAccessClient(player, box)
    if not box then
        clog("Action", "Grant Access callback received nil box")
        return
    end
    clog("Action", "Grant Access selected; boxId=" .. tostring(box:getID()))
    sendClientCommand(player, PhunKeys.module, PhunKeys.grantAccessCommand, { boxId = box:getID() })
end

function PhunKeys.lockClient(player, box)
    if not box then
        clog("Action", "Lock callback received nil box")
        return
    end
    clog("Action", "Lock selected; boxId=" .. tostring(box:getID()))
    sendClientCommand(player, PhunKeys.module, PhunKeys.lockCommand, { boxId = box:getID() })
end

function PhunKeys.nearbyVehicleForKeyClient(player, keyId)
    if not player then
        clog("VehicleLookup", "player is nil for keyId=" .. tostring(keyId))
        return nil
    end

    local cell = getCell()
    local vehicles = cell and cell:getVehicles() or nil
    if not vehicles then
        clog("VehicleLookup", "getCell()/getVehicles returned nil for keyId=" .. tostring(keyId))
        return nil
    end

    clog("VehicleLookup", "loadedVehicles=" .. tostring(vehicles:size())
        .. " keyId=" .. tostring(keyId)
        .. " player=" .. tostring(player:getUsername())
        .. " pos=" .. tostring(player:getX()) .. "," .. tostring(player:getY()) .. "," .. tostring(player:getZ()))

    -- IsoCell:getVehicles() is java.util.Set<BaseVehicle> in B42.20.x.
    -- It has size()/iterator(), but no indexed get(i).
    local iterator = vehicles:iterator()
    local i = 0
    while iterator:hasNext() do
        local vehicle = iterator:next()
        if vehicle then
            local vehicleKeyId = safe(function() return vehicle:getKeyId() end, nil)
            if vehicleKeyId == keyId then
                local dx = player:getX() - vehicle:getX()
                local dy = player:getY() - vehicle:getY()
                local dist2 = dx * dx + dy * dy
                local sameZ = math.floor(player:getZ()) == math.floor(vehicle:getZ())
                local protected = safe(function() return PhunKeys.isProtected(vehicle) end, false)
                local guest = safe(function() return PhunKeys.isGuestAccessGranted(vehicle) end, false)
                clog("VehicleLookup", "MATCH iterIndex=" .. tostring(i)
                    .. " vehicleId=" .. tostring(safe(function() return vehicle:getId() end, "?"))
                    .. " pos=" .. tostring(vehicle:getX()) .. "," .. tostring(vehicle:getY()) .. "," .. tostring(vehicle:getZ())
                    .. " dist2=" .. tostring(dist2)
                    .. " maxDist2=" .. tostring(PhunKeys.maxDistance * PhunKeys.maxDistance)
                    .. " sameZ=" .. tostring(sameZ)
                    .. " protected=" .. tostring(protected)
                    .. " guestAccess=" .. tostring(guest))
                if dist2 <= PhunKeys.maxDistance * PhunKeys.maxDistance and sameZ then
                    clog("VehicleLookup", "returning matching nearby vehicle")
                    return vehicle
                end
                clog("VehicleLookup", "matching key vehicle rejected because distance/Z check failed")
            end
        end
        i = i + 1
    end

    clog("VehicleLookup", "no nearby loaded vehicle matched keyId=" .. tostring(keyId))
    return nil
end

local function unwrapContextEntry(entry, index)
    if not entry then
        clog("ContextMenu", "entry[" .. tostring(index) .. "] is nil")
        return nil
    end

    local isInventoryItem = false
    local ok, result = pcall(function() return instanceof(entry, "InventoryItem") end)
    if ok then isInventoryItem = result == true end

    if isInventoryItem then
        clog("ContextMenu", "entry[" .. tostring(index) .. "] is InventoryItem: " .. describeItem(entry))
        return entry
    end

    -- Match B42 vanilla ISInventoryPaneContextMenu: non-InventoryItem entries
    -- are ContextMenuItemStack tables with their InventoryItems in .items.
    local stackItems = safe(function() return entry.items end, nil)
    if stackItems then
        local count = safe(function() return #stackItems end, 0)
        local first = safe(function() return stackItems[1] end, nil)
        clog("ContextMenu", "entry[" .. tostring(index) .. "] is stack/table; count="
            .. tostring(count) .. " first=" .. describeItem(first))
        return first
    end

    clog("ContextMenu", "entry[" .. tostring(index) .. "] is neither InventoryItem nor recognized stack; luaType="
        .. tostring(type(entry)) .. " tostring=" .. tostring(entry))
    return nil
end

function PhunKeys.onFillInventoryObjectContextMenu(playerNum, context, items)
    clog("ContextMenu", "EVENT FIRED playerNum=" .. tostring(playerNum)
        .. " context=" .. tostring(context)
        .. " itemsLuaType=" .. tostring(type(items))
        .. " itemsCount=" .. tostring(type(items) == "table" and #items or "?"))

    local player = getSpecificPlayer(playerNum)
    if not player then
        clog("ContextMenu", "ABORT: getSpecificPlayer(" .. tostring(playerNum) .. ") returned nil")
        return
    end

    if type(items) ~= "table" then
        clog("ContextMenu", "ABORT: items is not a Lua table")
        return
    end

    local seen = {}
    local added = 0

    for index, entry in ipairs(items) do
        local item = unwrapContextEntry(entry, index)
        if item then
            local fullType = safe(function() return item:getFullType() end, nil)
            if fullType ~= PhunKeys.boxItemType then
                clog("ContextMenu", "entry[" .. tostring(index) .. "] skip: fullType="
                    .. tostring(fullType) .. " expected=" .. tostring(PhunKeys.boxItemType))
            else
                local itemId = safe(function() return item:getID() end, nil)
                clog("ContextMenu", "FOUND TRANSMUTATION BOX: " .. describeItem(item))

                if itemId and seen[itemId] then
                    clog("ContextMenu", "skip duplicate box id=" .. tostring(itemId))
                else
                    if itemId then seen[itemId] = true end

                    local inventory = safe(function() return item:getInventory() end, nil)
                    if not inventory then
                        clog("ContextMenu", "NO OPTION: box:getInventory() returned nil")
                    else
                        local contents = safe(function() return inventory:getItems() end, nil)
                        if not contents then
                            clog("ContextMenu", "NO OPTION: box inventory:getItems() returned nil")
                        else
                            local size = safe(function() return contents:size() end, -1)
                            clog("ContextMenu", "box contents size=" .. tostring(size))

                            if size ~= 1 then
                                clog("ContextMenu", "NO OPTION: box must contain exactly one item")
                            else
                                local key = safe(function() return contents:get(0) end, nil)
                                if not key then
                                    clog("ContextMenu", "NO OPTION: contents:get(0) returned nil")
                                else
                                    local keyType = safe(function() return key:getFullType() end, nil)
                                    local keyId = safe(function() return key:getKeyId() end, nil)
                                    local favorite = safe(function() return key:isFavorite() end, nil)
                                    clog("ContextMenu", "contained item: " .. describeItem(key)
                                        .. " keyId=" .. tostring(keyId)
                                        .. " favorite=" .. tostring(favorite))

                                    if keyType ~= "Base.CarKey" then
                                        clog("ContextMenu", "NO OPTION: contained item is not Base.CarKey")
                                    elseif keyId == nil or keyId == -1 then
                                        clog("ContextMenu", "NO OPTION: invalid/nil keyId=" .. tostring(keyId))
                                    elseif favorite == true then
                                        local vehicle = PhunKeys.nearbyVehicleForKeyClient(player, keyId)
                                        if vehicle and PhunKeys.isProtected(vehicle)
                                            and not PhunKeys.isGuestAccessGranted(vehicle) then
                                            context:addOption("Grant Access", player, PhunKeys.grantAccessClient, item)
                                            added = added + 1
                                            clog("ContextMenu", "ADDED OPTION: Grant Access")
                                        else
                                            context:addOption("Lock", player, PhunKeys.lockClient, item)
                                            added = added + 1
                                            if not vehicle then
                                                clog("ContextMenu", "ADDED OPTION: Lock (no nearby matching vehicle resolved client-side; server will validate)")
                                            else
                                                clog("ContextMenu", "ADDED OPTION: Lock; protected="
                                                    .. tostring(PhunKeys.isProtected(vehicle))
                                                    .. " guestAccess=" .. tostring(PhunKeys.isGuestAccessGranted(vehicle)))
                                            end
                                        end
                                    elseif favorite == false then
                                        context:addOption("Transmute", player, PhunKeys.packVehicleClient, item)
                                        added = added + 1
                                        clog("ContextMenu", "ADDED OPTION: Transmute")
                                    else
                                        clog("ContextMenu", "NO OPTION: key:isFavorite() could not be read")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    clog("ContextMenu", "EVENT COMPLETE; optionsAdded=" .. tostring(added))
end

function PhunKeys.onServerCommandClient(module, command, arguments)
    if module ~= PhunKeys.module then return end
    clog("ServerCommand", "module=" .. tostring(module) .. " command=" .. tostring(command)
        .. " args=" .. tostring(arguments))

    if command == PhunKeys.playSoundCommand and arguments and arguments.sound then
        getSoundManager():PlaySound(arguments.sound, false, 0):setVolume(0.50)
        return
    end

    if command == PhunKeys.accessResultCommand and arguments then
        local player = getSpecificPlayer(arguments.playerNum or 0)
        if player then player:Say(arguments.message) end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(PhunKeys.onFillInventoryObjectContextMenu)
Events.OnServerCommand.Add(PhunKeys.onServerCommandClient)

clog("Load", "DEBUG3 SET-ITERATOR | PhunKeys_Client.lua loaded; boxItemType=" .. tostring(PhunKeys.boxItemType)
    .. " maxDistance=" .. tostring(PhunKeys.maxDistance)
    .. " context handler registered=" .. tostring(PhunKeys.onFillInventoryObjectContextMenu ~= nil))
