local logging = require("lib.lua-mods-libs.logging")
local format = string.format

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
local function isFileExists(filename)
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
    local file = string.format([[%s\options.lua]], modInfo.currentModDirectory)

    if not isFileExists(file) then
        local cmd = string.format([[copy "%s\options.example.lua" "%s\options.lua"]],
            modInfo.currentModDirectory,
            modInfo.currentModDirectory)

        print("Copy example options to options.lua. Execute command: " .. cmd .. "\n")

        os.execute(cmd)
    end

    dofile(file)
end

local function loadDevOptions()
    local file = format([[%s\options.dev.lua]], modInfo.currentDirectory)

    if isFileExists(file) then
        dofile(file)
    end
end

--------------------------------------------------------------------------------

-- Default logging levels. They can be overwritten in the options file.
LOG_LEVEL = "INFO" ---@type _LogLevel
MIN_LEVEL_OF_FATAL_ERROR = "ERROR" ---@type _LogLevel

local options = loadOptions()
OPTIONS = options
loadDevOptions()

LOG = logging.new(LOG_LEVEL, MIN_LEVEL_OF_FATAL_ERROR)
local log = LOG
LOG_LEVEL, MIN_LEVEL_OF_FATAL_ERROR = nil, nil

--------------------------------------------------------------------------------
