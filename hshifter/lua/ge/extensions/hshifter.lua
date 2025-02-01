local M = {}

-- most of these values are to prevent annoying problems with auto-centering
local stickX, stickY = 0.5, 0.5  
local currentGear = 0
local lockGear = nil  
local r3Pressed = false
local shiftThreshold = 0.15  
local exitThreshold = 0.4    
local neutralThreshold = 0.21 
local reverseInit = false  
local neutralCooldown = 0

-- Define joystick positions for each gear
local gearMap = {
    {x = 0.05, y = 0.90, gear = 1},  -- 1st gear: Top-left
    {x = 0.05, y = 0.10, gear = 2},  -- 2nd gear: Bottom-left
    {x = 0.50, y = 0.90, gear = 3},  -- 3rd gear: Top-center
    {x = 0.50, y = 0.10, gear = 4},  -- 4th gear: Bottom-center
    {x = 0.95, y = 0.90, gear = 5},  -- 5th gear: Top-right
    {x = 0.95, y = 0.10, gear = 6}   -- 6th gear: Bottom-right
}

-- Function triggered when mod loads
local function onExtensionLoaded()
    log("I", "H-Shifter Mod", "H-Shifter mod loaded successfully!")
    log("W", "H-Shifter Mod", "Ensure 'H-Shifter X-Axis', 'H-Shifter Y-Axis', and 'H-Shifter R3 Button' are manually bound in Controls.")
end

-- Function triggered when mod unloads
local function onExtensionUnloaded()
    log("I", "H-Shifter Mod", "H-Shifter mod unloaded.")
    stickX, stickY = 0.5, 0.5
    currentGear, lockGear = 0, nil
    r3Pressed, reverseInit = false, false
end

-- 
function M.updateStickX(value)
    stickX = value

    -- reverse gear logic
    if r3Pressed and stickX > 0.90 then
        reverseInit = true
    end

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

function M.updateR3(state)
    r3Pressed = state
    if not r3Pressed then
        reverseInit = false -- Reset reverse if R3 is released
    end
    log("D", "H-Shifter Mod", "R3 " .. (r3Pressed and "Pressed" or "Released"))
end


local function getClosestGear()
    local minDist = math.huge
    local targetGear = 0

    
    if reverseInit and stickX > 0.90 then
        log("I", "H-Shifter Mod", "Reverse gear engaged!")
        return -1  
    end

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

    if neutralCooldown > 0 then
        neutralCooldown = neutralCooldown - dt
    end

    local newGear = getClosestGear()

    if newGear == 0 then
        if lockGear ~= nil then
            log("W", "H-Shifter Mod", string.format("Stick returned to neutral, unlocking gear %d", lockGear))
            neutralCooldown = 0.3 
        end
        lockGear = nil
        return
    end

    if neutralCooldown > 0 then
        return
    end

    if newGear == currentGear and lockGear == nil then
        log("I", "H-Shifter Mod", string.format("Shifting from %d -> Neutral", currentGear))
        vehicle:queueLuaCommand("controller.mainController.shiftToGearIndex(0)")
        currentGear = 0
        lockGear = nil
        neutralCooldown = 0.3 
        return
    end

    if lockGear and newGear ~= lockGear then
        local lockPos = gearMap[lockGear]
        if lockPos then
            local exitDist = math.sqrt((stickX - lockPos.x)^2 + (stickY - lockPos.y)^2)
            if exitDist < exitThreshold then
                return
            end
        end
        log("W", "H-Shifter Mod", string.format("Unlocked from gear %d", lockGear))
        lockGear = nil
    end

    if newGear and newGear ~= currentGear and not lockGear then
        log("I", "H-Shifter Mod", string.format("Shifting from %d -> %d", currentGear, newGear))
        vehicle:queueLuaCommand("controller.mainController.shiftToGearIndex(" .. newGear .. ")")
        currentGear = newGear
        lockGear = newGear
    end
end

-- Bind functions
M.onPreRender = onPreRender
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.updateR3 = M.updateR3

_G.hshifter = M  

return M
