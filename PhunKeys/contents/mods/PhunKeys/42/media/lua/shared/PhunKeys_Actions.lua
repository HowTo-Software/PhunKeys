print("[PhunKeys][BOOT][DEBUG2] ENTER SHARED PhunKeys_Actions.lua")
require "PhunKeys_Access"

local function alog(message)
    print("[PhunKeys][ACTIONS] " .. tostring(message))
end

-- B42 executes complete() on the authority. Check both admission and completion:
-- a lock change after the menu opened or after an action started must take effect.
local function guardAction(name, path, vehicleOf)
    local requirePath = path or ("Vehicles/TimedActions/" .. name)
    local okRequire, requireErr = pcall(require, requirePath)
    if not okRequire then
        alog("HOOK FAILED " .. tostring(name) .. ": require '" .. tostring(requirePath) .. "' -> " .. tostring(requireErr))
        return false
    end

    local class = _G[name]
    if not class then
        alog("HOOK FAILED " .. tostring(name) .. ": global class is nil after require '" .. tostring(requirePath) .. "'")
        return false
    end

    local isValid, complete = class.isValid, class.complete
    if type(isValid) ~= "function" then
        alog("HOOK FAILED " .. tostring(name) .. ": class.isValid is " .. tostring(type(isValid)))
        return false
    end
    if type(complete) ~= "function" then
        alog("HOOK FAILED " .. tostring(name) .. ": class.complete is " .. tostring(type(complete)))
        return false
    end

    class.isValid = function(self, ...)
        local vehicle = vehicleOf(self)
        local allowed = PhunKeys.canInteract(self.character, vehicle)
        if not allowed then
            alog("BLOCK isValid " .. tostring(name)
                .. " player=" .. tostring(self.character and self.character:getUsername() or "nil")
                .. " vehicleId=" .. tostring(vehicle and vehicle:getId() or "nil"))
            return false
        end
        return isValid(self, ...)
    end

    class.complete = function(self, ...)
        local vehicle = vehicleOf(self)
        if not PhunKeys.canInteract(self.character, vehicle) then
            alog("BLOCK complete " .. tostring(name)
                .. " player=" .. tostring(self.character and self.character:getUsername() or "nil")
                .. " vehicleId=" .. tostring(vehicle and vehicle:getId() or "nil"))
            return false
        end
        return complete(self, ...)
    end

    -- Fuel/tire actions also mutate during update() and serverStop(), not just
    -- complete(). Keep their existing cadence; never create a polling loop.
    for _, method in ipairs({"update", "serverStop"}) do
        local original = class[method]
        if type(original) == "function" then
            class[method] = function(self, ...)
                local vehicle = vehicleOf(self)
                if not PhunKeys.canInteract(self.character, vehicle) then
                    alog("BLOCK " .. tostring(method) .. " " .. tostring(name)
                        .. " vehicleId=" .. tostring(vehicle and vehicle:getId() or "nil"))
                    return
                end
                return original(self, ...)
            end
        end
    end

    alog("HOOK OK " .. tostring(name) .. " via " .. tostring(requirePath))
    return true
end

local function actionVehicle(action) return action.vehicle end
local hookCount, hookFailures = 0, 0
for _, name in ipairs({
    "ISInstallVehiclePart", "ISUninstallVehiclePart", "ISTakeEngineParts",
    "ISRepairEngine", "ISRepairLightbar", "ISInflateTire", "ISDeflateTire",
    "ISRemoveBurntVehicle", "ISSmashVehicleWindow",
    "ISLockVehicleDoor", "ISLockDoors",
    "ISTakeGasolineFromVehicle", "ISAddGasolineToVehicle", "ISRefuelFromGasPump"
}) do
    if guardAction(name, nil, actionVehicle) then hookCount = hookCount + 1 else hookFailures = hookFailures + 1 end
end

-- Closing a door/window and exiting remain possible even after the car is locked.
local function exitDoorVehicle(action)
    local vehicle = action.vehicle
    if vehicle and action.character:getVehicle() == vehicle
        and vehicle:getPassengerDoor(vehicle:getSeat(action.character)) == action.part then
        return nil -- do not trap a passenger when the owner locks the car
    end
    return vehicle
end

for _, spec in ipairs({
    {"ISOpenVehicleDoor", nil, exitDoorVehicle},
    {"ISUnlockVehicleDoor", nil, exitDoorVehicle},
    {"ISHotwireVehicle", nil, function(action) return action.character:getVehicle() end},
    {"ISOpenCloseVehicleWindow", nil, function(action) if action.open then return action.vehicle end end},
    {"ISFixVehiclePartAction", "TimedActions/ISFixVehiclePartAction", function(action)
        return action.vehiclePart and action.vehiclePart:getVehicle()
    end}
}) do
    if guardAction(spec[1], spec[2], spec[3]) then hookCount = hookCount + 1 else hookFailures = hookFailures + 1 end
end

local okStart, errStart = pcall(require, "Vehicles/TimedActions/ISStartVehicleEngine")
if not okStart then
    alog("HOOK FAILED ISStartVehicleEngine require: " .. tostring(errStart))
    hookFailures = hookFailures + 1
elseif not ISStartVehicleEngine or type(ISStartVehicleEngine.isValid) ~= "function" or type(ISStartVehicleEngine.complete) ~= "function" then
    alog("HOOK FAILED ISStartVehicleEngine: class or expected methods missing")
    hookFailures = hookFailures + 1
else
    local startValid, startComplete = ISStartVehicleEngine.isValid, ISStartVehicleEngine.complete
    ISStartVehicleEngine.isValid = function(self, ...)
        local vehicle = self.character and self.character:getVehicle() or nil
        if not PhunKeys.canInteract(self.character, vehicle) then
            alog("BLOCK isValid ISStartVehicleEngine vehicleId=" .. tostring(vehicle and vehicle:getId() or "nil"))
            return false
        end
        return startValid(self, ...)
    end
    ISStartVehicleEngine.complete = function(self, ...)
        local vehicle = self.character and self.character:getVehicle() or nil
        if PhunKeys.isProtected(vehicle) then
            alog("protected engine start path vehicleId=" .. tostring(vehicle and vehicle:getId() or "nil"))
            return PhunKeys.startProtectedEngine(self.character, vehicle)
        end
        return startComplete(self, ...)
    end
    hookCount = hookCount + 1
    alog("HOOK OK ISStartVehicleEngine")
end

alog("load complete; hooksOK=" .. tostring(hookCount) .. " hooksFailed=" .. tostring(hookFailures))
