local M = {}

local stickX, stickY = 0.5, 0.5  
local currentGear = 0
local lockGear = nil  -- Gear lock to prevent false shifts
local shiftThreshold = 0.15  -- Minimum distance to enter a gear
local exitThreshold = 0.4    -- How far the stick must move to unlock a gear
local neutralThreshold = 0.3 -- Stick must be fully back in neutral before shifting again

local gearMap = {
    {x = 0.05, y = 0.90, gear = 1},  -- 1st gear: Top-left
    {x = 0.05, y = 0.10, gear = 2},  -- 2nd gear: Bottom-left
    {x = 0.50, y = 0.90, gear = 3},  -- 3rd gear: Top-center
    {x = 0.50, y = 0.10, gear = 4},  -- 4th gear: Bottom-center
    {x = 0.95, y = 0.90, gear = 5},  -- 5th gear: Top-right
    {x = 0.95, y = 0.10, gear = 6}   -- 6th gear: Bottom-right
}

local function onExtensionLoaded()
    log("I", "H-Shifter Mod", "H-Shifter mod loaded successfully!")
    log("I", "H-Shifter Mod", "Ensure 'H-Shifter X-Axis' and 'H-Shifter Y-Axis' are manually bound in Controls.")
end

local function onExtensionUnloaded()
    log("I", "H-Shifter Mod", "H-Shifter mod unloaded.")
    stickX = 0.5
    stickY = 0.5
    currentGear = 0
    lockGear = nil
end

function M.updateStickX(value)
    stickX = value
    if stickX < 0.3 or stickX > 0.7 then
        log("D", "H-Shifter Mod", string.format("Updated Stick X: %.2f", stickX))
    end
end

function M.updateStickY(value)
    stickY = value
    if stickY < 0.3 or stickY > 0.7 then
        log("D", "H-Shifter Mod", string.format("Updated Stick Y: %.2f", stickY))
    end
end

local function getClosestGear()
    local minDist = math.huge
    local targetGear = 0

    for _, pos in ipairs(gearMap) do
        local dist = math.sqrt((stickX - pos.x)^2 + (stickY - pos.y)^2)
        if dist < minDist then
            minDist = dist
            targetGear = pos.gear
        end
    end

    if minDist < shiftThreshold then
        return targetGear
    elseif minDist < neutralThreshold then
        return 0  
    end

    return nil  
end

local function onPreRender(dt)
    local vehicle = be:getPlayerVehicle(0)
    if not vehicle then
        log("E", "H-Shifter Mod", "No active vehicle found!")
        return
    end

    local newGear = getClosestGear()

    if newGear == 0 then
        if lockGear ~= nil then
            log("D", "H-Shifter Mod", string.format("Stick returned to neutral, unlocking gear %d", lockGear))
        end
        lockGear = nil
        return
    end

    if lockGear and newGear ~= lockGear then
        local lockPos = gearMap[lockGear]
        if lockPos then
            local exitDist = math.sqrt((stickX - lockPos.x)^2 + (stickY - lockPos.y)^2)
            if exitDist < exitThreshold then
                return -- Stay locked in gear
            end
        end
        log("D", "H-Shifter Mod", string.format("Unlocked from gear %d", lockGear))
        lockGear = nil
    end

    if newGear and newGear ~= currentGear and not lockGear then
        log("D", "H-Shifter Mod", string.format("Shifting from %d -> %d", currentGear, newGear))
        vehicle:queueLuaCommand("controller.mainController.shiftToGearIndex(" .. newGear .. ")")
        currentGear = newGear
        lockGear = newGear  -- Lock the gear to prevent accidental shifts
    end
end


M.onPreRender = onPreRender
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded

_G.hshifter = M  -- Had probblems with context so made it globally available

return M
