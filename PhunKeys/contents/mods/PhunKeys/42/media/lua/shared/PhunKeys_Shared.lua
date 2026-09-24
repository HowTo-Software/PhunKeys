print("[PhunKeys][BOOT][DEBUG2] ENTER shared/PhunKeys_Shared.lua")

PhunKeys = PhunKeys or {
    module = "PhunKeys",
    command = "packVehicle",
    grantAccessCommand = "GrantAccess",
    lockCommand = "Lock",
    accessResultCommand = "accessResult",
    playSoundCommand = "playSound",
    itemType = "PhunKeys.VehicleKeySeller",
    boxItemType = "PhunKeys.TransmutationBox",
    maxDistance = 4
}

PhunKeys.buildTag = "DEBUG2-2026-09-24"

AcceptItemFunction = AcceptItemFunction or {}

function AcceptItemFunction.AcceptVanillaCarKey(container, item)
    local fullType = item and item:getFullType() or "<nil>"
    print("[PhunKeys][ACCEPT][DEBUG2] AcceptVanillaCarKey invoked item=" .. tostring(fullType))
    return item ~= nil and fullType == "Base.CarKey"
end

print("[PhunKeys][SHARED][Load][DEBUG2] PhunKeys_Shared.lua loaded; build=" .. tostring(PhunKeys.buildTag) .. " boxItemType=" .. tostring(PhunKeys.boxItemType))

return PhunKeys
