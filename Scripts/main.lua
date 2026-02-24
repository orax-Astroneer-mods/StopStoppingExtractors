---@class FOutputDevice
---@field Log function

local UEHelpers = require("UEHelpers")
local logging = require("lib.lua-mods-libs.logging")
local format = string.format
local lower = string.lower

local UINT32_MAX = 2 ^ 32 - 1
local PlayerLocation ---@type FVector?
local HandleBackgroundAutoReload
local IsBackgroundAutoReloadEnabled = true

---@type EExtractorAnimStage
local EExtractorAnimStage = {
    Holding = 0,
    Falling = 1,
    Resting = 2,
    Rising = 3,
    Reset = 4,
    ClientSync = 5,
    EExtractorAnimStage_MAX = 6,
}

---@type EExtractorLegStage
local EExtractorLegStage = {
    Extended = 0,
    WaitForRetraction = 1,
    Retracting = 2,
    Retracted = 3,
    WaitForExtension = 4,
    Extending = 5,
    EExtractorLegStage_MAX = 6,
}

---@type EExtractorOperationStage
local EExtractorOperationStage = {
    Paused = 0,
    Processing = 1,
    Finished = 2,
    EExtractorOperationStage_MAX = 3,
}

---@type EResourceExtractorActivationFlags
local EResourceExtractorActivationFlags = {
    None = 0,
    HasPower = 1,
    IsPlaced = 2,
    HasAvailableStorage = 4,
    HasWorkRemaining = 8,
    IsTurnedOn = 16,
    CouldBeTurnedOn = 15,
    CouldProcessWork = 23,
    FullActivation = 31,
    EResourceExtractorActivationFlags_MAX = 32,
}

local modInfo = (function()
    local info = debug.getinfo(2, "S")
    local source = info.source:gsub("\\", "/")
    return {
        name = source:match("@?.+/([^/]+)/[Ss]cripts/"),
        file = source:sub(2),
        currentDirectory = source:match("@?(.+)/"),
        currentModDirectory = source:match("@?(.+)/[Ss]cripts/"),
        modsDirectory = source:match("@?(.+)/[^/]+/[Ss]cripts/")
    }
end)()

---@param filename string
---@return boolean
local function doesFileExist(filename)
    local file = io.open(filename, "r")
    if file ~= nil then
        io.close(file)
        return true
    else
        return false
    end
end

---@return MOD_OPTIONS
local function loadOptions()
    local file = format([[%s\options.lua]], modInfo.currentModDirectory)

    if not doesFileExist(file) then
        local cmd = format([[copy "%s\options.example.lua" "%s\options.lua"]],
            modInfo.currentModDirectory,
            modInfo.currentModDirectory)

        print("Copy example options to options.lua. Execute command: " .. cmd .. "\n")

        os.execute(cmd)
    end

    return dofile(file)
end

local function loadDevOptions()
    local file = format([[%s\options.dev.lua]], modInfo.currentDirectory)

    if doesFileExist(file) then
        dofile(file)
    end
end

local function copyVTableLayout()
    -- Define source and destination paths
    -- Assuming the script runs from the mod's folder
    local source_path = format([[%s\VTableLayout.ini]], modInfo.currentModDirectory)
    local destination_path = format([[%s\..\..\VTableLayout.ini]], modInfo.currentModDirectory)

    if doesFileExist(destination_path) then
        return
    end

    -- Open the source file in binary read mode
    local source_file, err_open = io.open(source_path, "rb")
    if not source_file then
        print(format("Error: Could not open source file: %s", err_open))
        return false
    end

    -- Read the content
    local content = source_file:read("*all")
    source_file:close()

    -- Open the destination file in binary write mode
    local dest_file, err_write = io.open(destination_path, "wb")
    if not dest_file then
        print(format("Error: Could not create destination file: %s", err_write))
        return false
    end

    -- Write content and close
    dest_file:write(content)
    dest_file:close()

    print("Success: VTableLayout.ini has been copied.")
    return true
end

--------------------------------------------------------------------------------

-- Default logging levels. They can be overwritten in the options file.
LOG_LEVEL = "INFO" ---@type _LogLevel
MIN_LEVEL_OF_FATAL_ERROR = "ERROR" ---@type _LogLevel

local options = loadOptions()
OPTIONS = options
loadDevOptions()

copyVTableLayout()

LOG = logging.new(LOG_LEVEL, MIN_LEVEL_OF_FATAL_ERROR)
local log = LOG
LOG_LEVEL, MIN_LEVEL_OF_FATAL_ERROR = nil, nil

--------------------------------------------------------------------------------

---@param extractor AResourceExtractorLarge_BP_C
local function isExtractorValid(extractor)
    if not extractor:IsValid() then
        log.warn("Extractor is not a valid UObject.")
        return false
    end

    if extractor.ManagerIndex == UINT32_MAX then
        log.debug("Extractor not in Extractor Manager; ignoring.")
        return false
    end

    return true
end

---@param extractor AResourceExtractorLarge_BP_C
local function isExtractorStopped(extractor)
    local isHolding = extractor.AnimStage == EExtractorAnimStage.Holding
    local hasPower = extractor.PowerComponent.CurrentAvailablePower > 0
    local isTurnedOn = extractor.bIsTurnedOn == true

    local isPausedOrFinished =
        extractor.OpStage == EExtractorOperationStage.Paused or
        extractor.OpStage == EExtractorOperationStage.Finished

    log.debug("isHolding=%s hasPower=%s isTurnedOn=%s isPausedOrFinished=%s",
        isHolding, hasPower, isTurnedOn, isPausedOrFinished)

    if isHolding and hasPower and isTurnedOn and isPausedOrFinished then
        return true
    end

    log.debug("Extractor not stopped; ignoring.")

    return false
end

---@param extractor AResourceExtractorLarge_BP_C
---@param resourceExtractorManager UResourceExtractorManager
local function reloadExtractor(extractor, resourceExtractorManager)
    if resourceExtractorManager:IsValid() and extractor:IsValid() then
        log.debug("Reload extractor.")
        resourceExtractorManager:OnActivationStatusChanged(
            extractor,
            EResourceExtractorActivationFlags.IsPlaced,
            true)
    else
        log.warn("Extractor or ExtractorManager is invalid.")
    end
end

---@param slotsComponent USlotsComponent
---@param name string
---@return FSlot?
local function getSlotByName(slotsComponent, name)
    if not slotsComponent:IsValid() then
        log.warn("`SlotsComponent` is invalid.")
        return
    end

    local slot
    slotsComponent.Slots:ForEach(function(index, element)
        slot = element:get() ---@cast slot FSlot
        if slot.Name:ToString() == name then
            return true
        end
    end)

    return slot
end

---@param extractor AResourceExtractorLarge_BP_C
local function isExtractorStorageEmpty(extractor)
    local slotName = "Output Slot"
    local slot = getSlotByName(extractor.SlotsComponent, slotName)

    if not slot then
        log.warn("Unable to find slot: " .. slotName)
    else
        if #slot.SlottedItems > 0 then
            local item = slot.SlottedItems[1]

            -- Item "Unclickable" means that the resource nugget is partial.
            -- In this case, the extractor can extract more resources,
            -- and the Output Slot storage is not full.
            if item.ClickableComponent.Unclickable then
                return extractor
            else
                log.debug("Extractor storage is full; ignoring.")
            end
        else
            log.warn("There is no `SlottedItems`.")
        end
    end
end

---@return UResourceExtractorManager?
local function getResourceExtractorManager()
    local resourceExtractorManager = FindFirstOf("ResourceExtractorManager")
    if not resourceExtractorManager:IsValid() then
        log.warn("ResourceExtractorManager is invalid.")
        return
    end
    ---@cast resourceExtractorManager UResourceExtractorManager

    return resourceExtractorManager
end

---@return AResourceExtractorLarge_BP_C[]
local function getStoppedExtractors()
    ---@type AResourceExtractorLarge_BP_C[]
    local extractors = {}

    local instances = FindAllOf("ResourceExtractorLarge_BP_C") ---@type AResourceExtractorLarge_BP_C[]?
    if not instances then
        log.debug("No extractors found.")
        return extractors
    end

    log.debug("Total extractors found: " .. #instances)

    for index, instance in ipairs(instances) do
        log.debug("Extractor " .. index .. "/" .. #instances)

        if isExtractorValid(instance) and isExtractorStopped(instance) and isExtractorStorageEmpty(instance) then
            log.debug("Add extractor.")
            table.insert(extractors, instance)
        end
    end

    if #extractors == 0 then
        log.debug("No stopped extractors found.")
    end

    return extractors
end

---@param keyBindOption {key: Key, modifierKey: ModifierKey[]|nil}
---@param func function
local function registerKeyBindOption(keyBindOption, func)
    if type(keyBindOption) == "table" then
        if type(keyBindOption.key) == "number" then
            if type(keyBindOption.modifierKey) == "table" then
                RegisterKeyBind(keyBindOption.key, keyBindOption.modifierKey, func)
            else
                RegisterKeyBind(keyBindOption.key, func)
            end
        end
    end
end

---@param key number
---@param modifierKeys? number[]
---@return string
local function getKeybindName(key, modifierKeys)
    local parts = {}

    if type(modifierKeys) == "table" then
        for _, modifierValue in ipairs(modifierKeys) do
            for name, value in pairs(ModifierKey) do
                if modifierValue == value then
                    table.insert(parts, name)
                    break
                end
            end
        end
    end

    local keyName = ""
    for name, value in pairs(Key) do
        if key == value then
            keyName = name
            break
        end
    end

    if keyName == "" then return "" end
    table.insert(parts, keyName)

    return " [" .. table.concat(parts, "+") .. "]"
end

---@param outputDevice FOutputDevice?
local function cmd_reloadExtractors(outputDevice)
    local extractors = getStoppedExtractors()
    if #extractors == 0 then return end

    local resourceExtractorManager = getResourceExtractorManager()
    if not resourceExtractorManager then return end

    log.debug("Temporarily disabled BackgroundAutoReload loop.")
    IsBackgroundAutoReloadEnabled = false

    ExecuteInGameThread(function()
        for index, extractor in ipairs(extractors) do
            if extractor:IsValid() then
                log.debug("Pick up extractor n° %d/%d | %s",
                    index, #extractors, extractor:GetFullName())
                extractor:PickUpFromWorld(false)
            end
        end
    end)

    ExecuteInGameThreadWithDelay(1000, function()
        for index, extractor in ipairs(extractors) do
            log.debug("Reload extractor n° %d/%d | %s",
                index, #extractors, extractor:GetFullName())
            reloadExtractor(extractor, resourceExtractorManager)
        end

        log.debug("Restoring BackgroundAutoReload loop.")
        IsBackgroundAutoReloadEnabled = true
    end)
end

---@param outputDevice FOutputDevice?
local function cmd_reloadExtractorsWithPlayerTeleportation(outputDevice)
    local msg = ""

    local extractors = getStoppedExtractors()
    if #extractors == 0 then
        msg = "No extractors found."
        log.info(msg)
        if outputDevice then outputDevice:Log(msg) end
        return
    end

    local resourceExtractorManager = getResourceExtractorManager()
    if not resourceExtractorManager then
        log.warn("ExtractorManager is not valid.")
        return
    end

    local player = UEHelpers:GetPlayer()
    if not player:IsValid() then return end
    local originLocationToReTeleportPlayer = player:K2_GetActorLocation()

    log.debug("Temporarily disabled BackgroundAutoReload loop.")
    IsBackgroundAutoReloadEnabled = false

    local reteleportPlayer = false

    msg = format("Reloading extractors in %d frames.", options.delays.loopInterval)
    log.info(msg)
    if outputDevice then outputDevice:Log(msg) end

    -- Loop for reloading stopped extractors.
    local i = 0
    local loopHandle
    loopHandle = LoopInGameThreadAfterFrames(options.delays.loopInterval, function()
        i = i + 1

        if i > #extractors then
            if CancelDelayedAction(loopHandle) then
                log.debug("Reload extractors loop canceled.")
            else
                log.warn("Failed to stop the reload extractors loop.")
            end

            -- Once finished, re-teleport player to his origin location.
            reteleportPlayer = true

            log.debug("Restoring BackgroundAutoReload loop.")
            IsBackgroundAutoReloadEnabled = true

            return
        end

        local hit = {}
        local extractorLocation = extractors[i]:K2_GetActorLocation()
        local extractorUpVector = extractors[i]:GetActorUpVector()

        local offsetUp = options.offsetUp
        extractorLocation = {
            X = extractorLocation.X + (extractorUpVector.X * offsetUp),
            Y = extractorLocation.Y + (extractorUpVector.Y * offsetUp),
            Z = extractorLocation.Z + (extractorUpVector.Z * offsetUp)
        }

        log.debug("Moving player to extractor location.")
        player:K2_SetActorLocation(extractorLocation, false, hit, false)

        log.debug("Reload extractor (with teleportation) n° %d/%d | %s",
            i, #extractors, extractors[i]:GetFullName())

        extractors[i]:PickUpFromWorld(false)

        if not PauseDelayedAction(loopHandle) then
            log.warn("Unable to pause delayed action.")
        end
        ExecuteInGameThreadWithDelay(options.delays.delayBeforeReload, function()
            reloadExtractor(extractors[i], resourceExtractorManager)
            if not UnpauseDelayedAction(loopHandle) then
                log.warn("Unable to unpause delayed action.")
            end
        end)
    end)

    -- When reteleportPlayer is true, the player will be teleported back to their original location.
    local loopTpPlayerHandle
    loopTpPlayerHandle = LoopInGameThreadWithDelay(500, function()
        if reteleportPlayer == true then
            log.debug("Teleport the player back to his original location.")

            if CancelDelayedAction(loopTpPlayerHandle) then
                log.debug("Back-teleportation loop canceled.")
            else
                log.warn("Failed to stop the back-teleportation loop.")
            end

            ExecuteInGameThreadAfterFrames(options.delays.teleportBack, function()
                local hit = {}
                if player:IsValid() then
                    player:K2_SetActorLocation(originLocationToReTeleportPlayer, false, hit, false)
                else
                    log.warn("`player` is not a valid UObject.")
                end
            end)
        end
    end)
end

---@param outputDevice FOutputDevice?
local function cmd_pickUpFromWorld(outputDevice)
    local instances = FindAllOf("ResourceExtractorLarge_BP_C") ---@type AResourceExtractorLarge_BP_C[]?
    if instances then
        ExecuteInGameThread(function()
            for _, extractor in ipairs(instances) do
                if extractor:IsValid() then
                    extractor:PickUpFromWorld(false)
                end
            end
        end)
    else
        local msg = "No extractors found."
        log.info(msg)
        if outputDevice then outputDevice:Log(msg) end
    end
end

---@param outputDevice FOutputDevice?
local function cmd_getNumberOfExtractors(outputDevice)
    local extractors = FindAllOf("ResourceExtractorLarge_BP_C") ---@type AResourceExtractorLarge_BP_C[]?

    local msg = format("Number of extractors: %d", #extractors)
    log.info(msg)
    if outputDevice then outputDevice:Log(msg) end

    local stoppedExtractors = getStoppedExtractors()

    msg = format("Number of stopped extractors: %d", #stoppedExtractors)
    log.info(msg)
    if outputDevice then outputDevice:Log(msg) end
end

---@param outputDevice FOutputDevice?
---@param ... table
local function cmd_teleportToExtractor(outputDevice, ...)
    local args = { ... }
    local extractors = FindAllOf("ResourceExtractorLarge_BP_C") ---@type AResourceExtractorLarge_BP_C[]?
    if not extractors then return end

    local num = tonumber(args[1])
    if not num then
        num = 1
    elseif num > #extractors then
        num = #extractors
    end

    local player = UEHelpers:GetPlayer()
    if not player:IsValid() then return end
    if not PlayerLocation then
        PlayerLocation = player:K2_GetActorLocation()
    end

    local hit = {}
    local extractorLocation = extractors[num]:K2_GetActorLocation()
    local extractorUpVector = extractors[num]:GetActorUpVector()

    local offsetUp = options.offsetUp
    extractorLocation = {
        X = extractorLocation.X + (extractorUpVector.X * offsetUp),
        Y = extractorLocation.Y + (extractorUpVector.Y * offsetUp),
        Z = extractorLocation.Z + (extractorUpVector.Z * offsetUp)
    }

    local msg = format("Moving player to extractor location. Extractor %d/%d.", num, #extractors)
    log.debug(msg)
    if outputDevice then outputDevice:Log(msg) end

    ExecuteInGameThread(function()
        if player:IsValid() then
            player:K2_SetActorLocation(extractorLocation, false, hit, false)
        end
    end)
end

---@param outputDevice FOutputDevice?
---@param ... table
local function cmd_teleportToStoppedExtractor(outputDevice, ...)
    local args = { ... }
    local extractors = getStoppedExtractors()
    if #extractors == 0 then return end

    local num = tonumber(args[1])
    if not num then
        num = 1
    elseif num > #extractors then
        num = #extractors
    end

    local player = UEHelpers:GetPlayer()
    if not player:IsValid() then return end
    if not PlayerLocation then
        PlayerLocation = player:K2_GetActorLocation()
    end

    local hit = {}
    local extractorLocation = extractors[num]:K2_GetActorLocation()
    local extractorUpVector = extractors[num]:GetActorUpVector()

    local offsetUp = options.offsetUp
    extractorLocation = {
        X = extractorLocation.X + (extractorUpVector.X * offsetUp),
        Y = extractorLocation.Y + (extractorUpVector.Y * offsetUp),
        Z = extractorLocation.Z + (extractorUpVector.Z * offsetUp)
    }

    local msg = format("Moving player to stopped extractor location. Extractor %d/%d.", num, #extractors)
    log.debug(msg)
    if outputDevice then outputDevice:Log(msg) end

    ExecuteInGameThread(function()
        if player:IsValid() then
            player:K2_SetActorLocation(extractorLocation, false, hit, false)
        end
    end)
end

---@param outputDevice FOutputDevice?
local function cmd_teleportBack(outputDevice)
    if not PlayerLocation then
        local msg = format("No location saved. Use the `%s` command first.",
            options.commands.sub_commands.teleportToStoppedExtractor.command_name)
        log.warn(msg)
        if outputDevice then outputDevice:Log(msg) end
        return
    end

    local msg = "Teleport the player back to his original location."
    log.info(msg)
    if outputDevice then outputDevice:Log(msg) end

    ExecuteInGameThread(function()
        local hit = {}
        local player = UEHelpers.GetPlayer()
        if player:IsValid() then
            player:K2_SetActorLocation(PlayerLocation, false, hit, false)
        else
            log.warn("`player` is not a valid UObject.")
        end
    end)
end

---@param outputDevice FOutputDevice?
local function cmd_stopBackgroundAutoReload(outputDevice)
    if HandleBackgroundAutoReload ~= nil then
        if CancelDelayedAction(HandleBackgroundAutoReload) then
            HandleBackgroundAutoReload = nil
            local msg = "BackgroundAutoReload stopped."
            log.info(msg)
            if outputDevice then outputDevice:Log(msg) end
        else
            local msg = "Unable to stop BackgroundAutoReload."
            log.warn(msg)
            if outputDevice then outputDevice:Log(msg) end
        end
    end
end

---@param outputDevice FOutputDevice?
local function cmd_destroyExtractor(outputDevice, ...)
    local args = { ... }
    local msg = ""
    local extractors = FindAllOf("ResourceExtractorLarge_BP_C") ---@type AResourceExtractorLarge_BP_C[]?
    if not extractors then
        msg = "No extractors found."
        log.info(msg)
        if outputDevice then outputDevice:Log(msg) end
        return
    end

    local num = tonumber(args[1])
    if not num then
        num = 1
    elseif num > #extractors then
        num = #extractors
    end

    msg = format("Destroy extractor %d/%d.", num, #extractors)
    log.info(msg)
    if outputDevice then outputDevice:Log(msg) end
    extractors[num]:K2_DestroyActor()
end

---@param outputDevice FOutputDevice?
local function cmd_help(outputDevice)
    local keys = {}
    for k in pairs(options.commands.sub_commands) do
        table.insert(keys, k)
    end

    table.sort(keys)

    for _, key in ipairs(keys) do
        local config = options.commands.sub_commands[key]

        local bind = config.key_bind or {}
        local keybindName = getKeybindName(bind.key, bind.modifierKey)

        local line = format(" - %s%s : %s\n\n",
            config.command_name,
            keybindName,
            config.help_message or "")

        log.info(line)
        if outputDevice then outputDevice:Log(line) end
    end

    cmd_getNumberOfExtractors(outputDevice)
end

--------------------------------------------------------------------------------

if options.delays.enableBackgroundAutoReload then
    HandleBackgroundAutoReload = LoopInGameThreadWithDelay(options.delays.backgroundAutoReloadDelay, function()
        if IsBackgroundAutoReloadEnabled then
            cmd_reloadExtractors()
        end
    end)
end

local commandFunctions = {
    help = cmd_help,
    pickUpFromWorld = cmd_pickUpFromWorld,
    reloadExtractors = cmd_reloadExtractors,
    reloadExtractorsWithPlayerTeleportation = cmd_reloadExtractorsWithPlayerTeleportation,
    teleportToExtractor = cmd_teleportToExtractor,
    teleportToStoppedExtractor = cmd_teleportToStoppedExtractor,
    teleportBack = cmd_teleportBack,
    getNumberOfExtractors = cmd_getNumberOfExtractors,
    stopBackgroundAutoReload = cmd_stopBackgroundAutoReload,
    destroyExtractor = cmd_destroyExtractor
}

---@param fullCommand string
---@param args table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler(options.commands.root_command_name, function(fullCommand, args, outputDevice)
    local inputParam = #args > 0 and lower(args[1]) or "help"

    for key, func in pairs(commandFunctions) do
        local config = options.commands.sub_commands[key]

        if config and inputParam == lower(config.command_name) then
            func(outputDevice, table.unpack(args, 2))
            return true
        end
    end

    local msg = "Unknown sub-command: " .. inputParam
    log.warn(msg)
    outputDevice:Log(msg)
    cmd_help(outputDevice)
    return true
end)

for key, func in pairs(commandFunctions) do
    local subCommand = options.commands.sub_commands[key]
    if subCommand and subCommand.key_bind then
        registerKeyBindOption(subCommand.key_bind, func)
    end
end
