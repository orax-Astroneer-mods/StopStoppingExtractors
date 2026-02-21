---@class _Logging
local logging = {} ---@diagnostic disable-line: missing-fields

-- bind to a local variable https://stackoverflow.com/a/1252776
local print = print
local error = error
local type = type
local fmt = string.format
local sub = string.sub

---@enum (key) _LogLevel
local LOG_LEVELS = {
    ALL = 0,
    TRACE = 1,
    DEBUG = 2,
    INFO = 3,
    WARN = 4,
    ERROR = 5,
    FATAL = 6,
    OFF = 7,
}

local indexedLevels = {}

for k, v in pairs(LOG_LEVELS) do
    indexedLevels[v] = k
end

local maxLevel = #indexedLevels

---@param value any
---@param ... any
---@return string
local function getLogMessage(value, ...)
    local msg = value

    if type(value) == "string" then
        if select('#', ...) > 0 then
            msg = fmt(value, ...)
        end
    elseif type(value) == "function" then
        msg = value(...)
    else
        msg = tostring(value)
    end

    local lastChar = sub(msg, -1)
    if lastChar ~= "\r" and lastChar ~= "\n" then
        msg = msg .. "\n"
    end

    return msg
end

---@param level _LogLevel
---@param levelForFatalError _LogLevel
---@return Mod_Logger
function logging.new(level, levelForFatalError)
    local logger = {} ---@type Mod_Logger
    local source = debug.getinfo(2, "S").source:gsub("\\", "/")

    -- previous values
    local prevLevel ---@type _LogLevel?
    local prevLevelForFatalError ---@type _LogLevel?

    ---@type Mod_ModInfo
    local mod = {
        name = source:match("@?.+/Mods/([^/]+)"),
        file = source:sub(2),
        currentDirectory = source:match("@?(.+)/"),
        currentModDirectory = source:match("@?(.+/Mods/[^/]+)"),
        modsDirectory = source:match("@?(.+/Mods)/")
    }

    ---@param newlevel? _LogLevel
    ---@param newlevelForFatalError? _LogLevel
    function logger.setLevel(newlevel, newlevelForFatalError)
        local verb = "Set"
        if newlevel == nil and newlevelForFatalError == nil then verb = "Reset" end

        newlevel = newlevel or level
        newlevelForFatalError = newlevelForFatalError or levelForFatalError

        -- get the number of the level from the string level format
        local numLevel = LOG_LEVELS[newlevel]
        local numMinlevelFatal = LOG_LEVELS[newlevelForFatalError]

        assert(numLevel <= numMinlevelFatal,
            string.format("The log level must be less than or equal to the minimum log level " ..
                "for a fatal error (numLevel=%i numMinlevelFatal=%i).", numLevel, numMinlevelFatal))

        -- if the level has not been changed, do nothing
        if newlevel == prevLevel and newlevelForFatalError == prevLevelForFatalError then
            if numLevel <= LOG_LEVELS.DEBUG then
                print(string.format(
                    "The log level values are the same. The level remains %s-%s.\n",
                    newlevel, newlevelForFatalError))
            end

            return
        end

        -- print "Set" or "Reset" log level...
        print(string.format("[%s] %s log level %s-%s (previous: %s-%s).\n",
            mod.name, verb, newlevel, newlevelForFatalError, prevLevel, prevLevelForFatalError))

        -- create functions for each level
        for i = 1, maxLevel do
            local levelName = indexedLevels[i]
            local funcName = levelName:lower()

            -- default print function
            local printfunc = print

            if i >= numLevel and i < maxLevel then
                if i >= numMinlevelFatal then
                    -- specific print function for fatal errors
                    printfunc = error
                end

                logger[funcName] = function(value, ...)
                    local info = debug.getinfo(2, "nSl")
                    local src = info.source:gsub("\\", "/")
                    local dbgMsg = fmt("[%s] %s ", mod.name, levelName) ..
                        src:gsub(".+/", "") .. ":" ..
                        (info.name or "*") .. ":" ..
                        info.currentline .. " "

                    printfunc(dbgMsg .. getLogMessage(value, ...))
                end
            else
                -- no logging case
                logger[funcName] = function() end
            end
        end

        prevLevel = newlevel
        prevLevelForFatalError = newlevelForFatalError
    end

    logger.setLevel(level, levelForFatalError)

    return logger ---@type Mod_Logger
end

return logging ---@type _Logging
