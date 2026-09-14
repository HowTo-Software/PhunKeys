PhunKeys = PhunKeys or {
    module = "PhunKeys",
    command = "packVehicle",
    playSoundCommand = "playSound",
    itemType = "PhunKeys.VehicleKeySeller",
    boxItemType = "PhunKeys.TransmutationBox",
    maxDistance = 4
}

AcceptItemFunction = AcceptItemFunction or {}

function AcceptItemFunction.AcceptVanillaCarKey(container, item)
    return item:getFullType() == "Base.CarKey"
end

return PhunKeys
